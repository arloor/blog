---
title: "Clickhouse存储Trace调研"
date: 2022-06-28T15:35:44+08:00
draft: false
categories: [ "undefined"]
tags: ["可观测性"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

探索几种clickhouse存储trace的方案
<!--more-->

## uptrace实现

[开源地址](https://github.com/uptrace/uptrace)

uptrace创建了两张表，一张是spans_index索引表，用于搜索，另一张是原始数据表。

```sql
CREATE TABLE spans_index (
  project_id UInt32 Codec(DoubleDelta, ?CODEC),
  "span.system" LowCardinality(String) Codec(?CODEC),
  "span.group_id" UInt64 Codec(Delta, ?CODEC),

  "span.trace_id" UUID Codec(?CODEC),
  "span.id" UInt64 Codec(?CODEC),
  "span.parent_id" UInt64 Codec(?CODEC),
  "span.name" LowCardinality(String) Codec(?CODEC),
  "span.event_name" String Codec(?CODEC),
  "span.kind" LowCardinality(String) Codec(?CODEC),
  "span.time" DateTime Codec(Delta, ?CODEC),
  "span.duration" Int64 Codec(Delta, ?CODEC),
  "span.count" Float32 Codec(?CODEC),

  "span.status_code" LowCardinality(String) Codec(?CODEC),
  "span.status_message" String Codec(?CODEC),

  "span.link_count" UInt8 Codec(?CODEC),
  "span.event_count" UInt8 Codec(?CODEC),
  "span.event_error_count" UInt8 Codec(?CODEC),
  "span.event_log_count" UInt8 Codec(?CODEC),

  attr_keys Array(LowCardinality(String)) Codec(?CODEC),
  attr_values Array(String) Codec(?CODEC),

  "service.name" LowCardinality(String) Codec(?CODEC),
  "host.name" LowCardinality(String) Codec(?CODEC),

  "db.system" LowCardinality(String) Codec(?CODEC),
  "db.statement" String Codec(?CODEC),
  "db.operation" LowCardinality(String) Codec(?CODEC),
  "db.sql.table" LowCardinality(String) Codec(?CODEC),

  "log.severity" LowCardinality(String) Codec(?CODEC),
  "log.message" String Codec(?CODEC),

  "exception.type" LowCardinality(String) Codec(?CODEC),
  "exception.message" String Codec(?CODEC),

  INDEX idx_attr_keys attr_keys TYPE bloom_filter(0.01) GRANULARITY 8,
  INDEX idx_duration "span.duration" TYPE minmax GRANULARITY 1
)
ENGINE = ?(REPLICATED)MergeTree()
ORDER BY (project_id, "span.system", "span.group_id", "span.time")
PARTITION BY toDate("span.time")
TTL toDate("span.time") + INTERVAL ?TTL DELETE
SETTINGS ttl_only_drop_parts = 1

--migration:split

CREATE TABLE spans_data (
  trace_id UUID Codec(?CODEC),
  id UInt64 Codec(?CODEC),
  parent_id UInt64 Codec(?CODEC),
  time DateTime Codec(Delta, ?CODEC),
  data String Codec(?CODEC)
)
ENGINE = ?(REPLICATED)MergeTree()
ORDER BY (trace_id, id)
PARTITION BY toDate(time)
TTL toDate(time) + INTERVAL ?TTL DELETE
SETTINGS ttl_only_drop_parts = 1,
         index_granularity = 128
```

查询spanData很简单，就是根据traceId来点查，主要看根据spanIndex搜索，这个过程中也能看到很多clickhouse的聚合、分位线等操作。

### spanIndex查询

核心方法在

```go
func buildSpanIndexQuery(f *SpanFilter, minutes float64) *ch.SelectQuery {
	q := f.CH().NewSelect().
		Model((*SpanIndex)(nil)).
		Apply(f.whereClause) // 补充通用的where
	q, f.columnMap = compileUQL(q, f.parts, minutes) //拼接sql
	return q
}
```

compileUQL分为结果列和where语句。

**select结果列**

```go
// expr as name
func uqlColumn(q *ch.SelectQuery, name uql.Name, minutes float64) *ch.SelectQuery {
	var b []byte
	b = appendUQLColumn(b, name, minutes)
	b = append(b, " AS "...)
	b = append(b, '"')
	b = name.Append(b)
	b = append(b, '"')
	return q.ColumnExpr(string(b))
}

func appendUQLColumn(b []byte, name uql.Name, minutes float64) []byte {
    // 根据函数名判断，转译成clickhouse的函数
	switch name.FuncName {
	case "p50", "p75", "p90", "p99":
		return chschema.AppendQuery(b, "quantileTDigest(?)(toFloat64OrDefault(?))",
			quantileLevel(name.FuncName), chColumn(name.AttrKey))
	case "top3":
		return chschema.AppendQuery(b, "topK(3)(?)", chColumn(name.AttrKey))
	case "top10":
		return chschema.AppendQuery(b, "topK(10)(?)", chColumn(name.AttrKey))
	}

	switch name.String() {
	case xattr.SpanCount:
		return chschema.AppendQuery(b, "sum(`span.count`)")
	case xattr.SpanCountPerMin:
		return chschema.AppendQuery(b, "sum(`span.count`) / ?", minutes)
	case xattr.SpanErrorCount:
		return chschema.AppendQuery(b, "sumIf(`span.count`, `span.status_code` = 'error')", minutes)
	case xattr.SpanErrorPct:
		return chschema.AppendQuery(
			b, "sumIf(`span.count`, `span.status_code` = 'error') / sum(`span.count`)", minutes)
    // 查询具体的列
	default:
		if name.FuncName != "" {
			b = append(b, name.FuncName...)
			b = append(b, '(')
		}

		b = appendCHColumn(b, name.AttrKey)

		if name.FuncName != "" {
			b = append(b, ')')
		}

		return b
	}
}

func chColumn(key string) ch.Safe {
	return ch.Safe(appendCHColumn(nil, key))
}

func appendCHColumn(b []byte, key string) []byte {
    // 以span开头的列，直接返回
	if strings.HasPrefix(key, "span.") {
		return chschema.AppendIdent(b, key)
	}
    // 加入索引的列，例如service.name, host.name, db.name等等
	if _, ok := indexedAttrSet[key]; ok {
		return chschema.AppendIdent(b, key)
	}
    // 未索引的列，key在attr_keys，value在attr_values中
	return chschema.AppendQuery(b, "attr_values[indexOf(attr_keys, ?)]", key)
}
```


**where语句**

```go
func uqlWhere(q *ch.SelectQuery, ast *uql.Where, minutes float64) *ch.SelectQuery {
	var where []byte
	var having []byte

	for _, cond := range ast.Conds {
		bb, isAgg := uqlWhereCond(cond, minutes)
		if bb == nil {
			continue
		}

		if isAgg {
			having = appendCond(having, cond, bb)
		} else {
			where = appendCond(where, cond, bb)
		}
	}

	if len(where) > 0 {
		q = q.Where(string(where))
	}
	if len(having) > 0 {
		q = q.Having(string(having))
	}

	return q
}

func uqlWhereCond(cond uql.Cond, minutes float64) (b []byte, isAgg bool) {
	isAgg = isAggColumn(cond.Left)

	switch cond.Op {
	case uql.ExistsOp, uql.DoesNotExistOp:
		if isAgg {
			return nil, false
		}

		if strings.HasPrefix(cond.Left.AttrKey, "span.") {
			b = append(b, '1')
			return b, false
		}
		b = chschema.AppendQuery(b, "has(all_keys, ?)", cond.Left.AttrKey)
		return b, false
	case uql.ContainsOp, uql.DoesNotContainOp:
		if cond.Op == uql.DoesNotContainOp {
			b = append(b, "NOT "...)
		}

		values := strings.Split(cond.Right.Text, "|")
		b = append(b, "multiSearchAnyCaseInsensitiveUTF8("...)
		b = appendUQLColumn(b, cond.Left, minutes)
		b = append(b, ", "...)
		b = chschema.AppendQuery(b, "[?]", ch.In(values))
		b = append(b, ")"...)

		return b, isAgg
	}

	if cond.Right.Kind == uql.NumberValue {
		b = append(b, "toFloat64OrDefault("...)
	}
	b = appendUQLColumn(b, cond.Left, minutes)
	if cond.Right.Kind == uql.NumberValue {
		b = append(b, ")"...)
	}

	b = append(b, ' ')
	b = append(b, cond.Op...)
	b = append(b, ' ')

	b = cond.Right.Append(b)

	return b, isAgg
}

func appendCond(b []byte, cond uql.Cond, bb []byte) []byte {
	if len(b) > 0 {
		b = append(b, cond.Sep.Op...)
		b = append(b, ' ')
	}
	if cond.Sep.Negate {
		b = append(b, "NOT "...)
	}
	return append(b, bb...)
}
```

### 聚合出每分钟的平均耗时，错误率等

```go
func (h *SpanHandler) Percentiles(w http.ResponseWriter, req bunrouter.Request) error {
	ctx := req.Context()

	f, err := DecodeSpanFilter(h.App, req)
	if err != nil {
		return err
	}

	groupPeriod := calcGroupPeriod(&f.TimeFilter, 300)
	minutes := groupPeriod.Minutes()

	m := make(map[string]interface{})

    // 子查询作为表
    // groupBy time =》 一行是一分钟的聚合数据（分位线、个数、错误数）
    // orderBy time asc，控制递增
	subq := h.CH().NewSelect().
		Model((*SpanIndex)(nil)).
		WithAlias("qsNaN", "quantilesTDigest(0.5, 0.9, 0.99)(`span.duration`)").
		WithAlias("qs", "if(isNaN(qsNaN[1]), [0, 0, 0], qsNaN)").
		ColumnExpr("sum(`span.count`) AS count").
		ColumnExpr("sum(`span.count`) / ? AS rate", minutes).
		ColumnExpr("toStartOfInterval(`span.time`, INTERVAL ? minute) AS time", minutes).
		Apply(func(q *ch.SelectQuery) *ch.SelectQuery {
			if isEventSystem(f.System) {
				return q
			}
			return q.ColumnExpr("sumIf(`span.count`, `span.status_code` = 'error') AS errorCount").
				ColumnExpr("sumIf(`span.count`, `span.status_code` = 'error') / ? AS errorRate",
					minutes).
				ColumnExpr("round(qs[1]) AS p50").
				ColumnExpr("round(qs[2]) AS p90").
				ColumnExpr("round(qs[3]) AS p99")
		}).
		Apply(f.whereClause).
		GroupExpr("time").
		OrderExpr("time ASC").
		Limit(10000)

    // groupBy 空元组，表示都放在一行
    // groupArray 表示将所有值变成一个数组
	if err := h.CH().NewSelect().
		ColumnExpr("groupArray(count) AS count").
		ColumnExpr("groupArray(rate) AS rate").
		ColumnExpr("groupArray(time) AS time").
		Apply(func(q *ch.SelectQuery) *ch.SelectQuery {
			if isEventSystem(f.System) {
				return q
			}
			return q.ColumnExpr("groupArray(errorCount) AS errorCount").
				ColumnExpr("groupArray(errorRate) AS errorRate").
				ColumnExpr("groupArray(p50) AS p50").
				ColumnExpr("groupArray(p90) AS p90").
				ColumnExpr("groupArray(p99) AS p99")
		}).
		TableExpr("(?)", subq).
		GroupExpr("tuple()").
		Limit(1000).
		Scan(ctx, &m); err != nil {
		return err
	}

	fillHoles(m, f.TimeGTE, f.TimeLT, groupPeriod)

	return httputil.JSON(w, m)
}
```

类似的功能Mtrace目前是使用Es的date_histogram和avg的两层聚合来做的，查询DSL是：

```json
{
	"size": 0,
	"timeout": "10s",
	"query": {
		"bool": {
			"must": [{
				"range": {
					"mt_datetime": {
						"from": "2022-06-29 14:09:48+0800",
						"to": "2022-06-29 15:09:48+0800",
						"include_lower": true,
						"include_upper": true,
						"boost": 1.0
					}
				}
			}],
			"adjust_pure_negative": true,
			"boost": 1.0
		}
	},
	"aggregations": {
		"trace_date": {
			"date_histogram": {
				"field": "mt_datetime",
				"format": "yyyy-MM-dd HH:mm:ss",
				"interval": "1m",
				"offset": 0,
				"order": {
					"_key": "asc"
				},
				"keyed": false,
				"min_doc_count": 0
			},
			"aggregations": {
				"duration": {
					"avg": {
						"field": "slow_query"
					}
				}
			}
		}
	}
}
```

### 测试数据集

```sql
CREATE TABLE IF NOT EXISTS spans_index (
  "span.trace_id" String ,
  "span.id" UInt64,
  "span.duration" Int64,
  attr_keys Array(LowCardinality(String)) ,
  attr_values Array(String) 
)
ENGINE = MergeTree()
ORDER BY ("span.trace_id");

truncate table spans_index;

insert into table spans_index  ("span.trace_id","span.id",attr_keys,attr_values) values 
('aaaaaaa',1,array('a','b','c'),['a','b','c']),
('bbbbbbb',2,array('a','b','c'),['b','c','d']),
('ccccccc',3,array('a','b','c'),['c','d','e']),
('ddddddd',4,array('a','b','c'),['d','e','f']),
('eeeeeee',5,array('a','b','c'),['e','f','g'])
;

---- 根据tag搜索
select * from spans_index where attr_values[indexOf(attr_keys, 'a')] = 'a';
select groupArray(`span.id`) from spans_index group by tuple();
---- 根据tag groupby
select attr_values[indexOf(attr_keys, 'a')] as a, count(1),groupArray(`span.id`) from spans_index group by a order by a;
```