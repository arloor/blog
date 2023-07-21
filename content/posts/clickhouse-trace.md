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

clickhouse是开源的纯列式数据库，定位是OLAP数据库。因为他的一些特性，也广泛用于监控领域，一方面代替时序数据库，存储多维度指标，另一方面也用于存储trace数据。这个博客的目的就是调研下业界如何使用clickhouse存储trace的，围绕表结构和查询sql语句展开，主要调研[uptrace](https://github.com/uptrace/uptrace)的实现。
<!--more-->

## 表结构

uptrace创建了两张表，一张是`spans_index`索引表，用于搜索，另一张是原始数据表`spans_data`。

### spans_index索引表

- 对于trace元数据中固定字段（span.system、span.group_id等）直接设置单独字段。
- 对于用户自定义的attribute（本身是个map的数据结构），使用两个array分别存储key和value。

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

  INDEX idx_attr_keys attr_keys TYPE bloom_filter(0.01) GRANULARITY 8, /*使用布隆过滤器索引attribute key*/
  INDEX idx_duration "span.duration" TYPE minmax GRANULARITY 1
)
ENGINE = ?(REPLICATED)MergeTree()
ORDER BY (project_id, "span.system", "span.group_id", "span.time")
PARTITION BY toDate("span.time")
TTL toDate("span.time") + INTERVAL ?TTL DELETE
SETTINGS ttl_only_drop_parts = 1
```

### spans_data原始数据表

```sql
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

查询spanData很简单，就是根据traceId来点查，不做过多分析。我们主要看根据spanIndex搜索，这个过程中也能看到很多clickhouse的聚合、分位线等操作。

## spans_index查询

sql实例：

```sql
---- 根据attribute搜索
select * from spans_index where 'project_id'='xxxx' and xxxxx and  attr_values[indexOf(attr_keys, 'a')] = 'a';
```

精髓在于使用attr_keys和attr_values这两个array来实现map的效果，经过和同行的一些交流，这种用法是公认比较成熟的做法。

### uptrace实现解析

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

## 使用聚合函数计算耗时、qps等性能指标

sql实例：

```sql
select
    groupArray(count) AS count,
    groupArray(rate) AS rate,
    groupArray(time) AS time,
    groupArray(errorCount) AS errorCount,
    groupArray(errorRate) AS errorRate,
    groupArray(p50) AS p50,
    groupArray(p90) AS p90,
    groupArray(p99) AS p99
from
    (
		-- 以一分钟为聚合粒度
        WITH 1 as interval,
		-- 计算qps时，一分钟=60秒
		60 as intervalTime,
        quantilesTDigest(0.5, 0.9, 0.99)(`span.duration`) as qsNaN,
        if(isNaN(qsNaN [1]), [0, 0, 0], qsNaN) as qs,
        select
            sum(`span.count`) AS count,
            sum(`span.count`) / $ intervalTime AS rate,
            toStartOfInterval(`span.time`, INTERVAL interval minute) AS time,
            sumIf(`span.count`, `span.status_code` = 'error') AS errorCount,
            sumIf(`span.count`, `span.status_code` = 'error') / intervalTime AS errorRate,
            round(qs [1]) AS p50,
            round(qs [2]) AS p90,
            round(qs [3]) AS p99
      	where xxxxxxxxxxxx
        group by
            time
        order by
            time ASC
        limit
            10000
    )
group by
    -- 以空元组为group by，最终结果为一行
    tuple() 
limit
    1000
```

对应的聚合功能在es也是支持的，需要使用date_histogram和avg的两层聚合，DSL如下：

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

### uptrace代码实现

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

## 测试数据集

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
--- 这里根据array中的值group by，最好增加attr_keys的布隆过滤跳数索引，减少数据访问量。对用常用的group by，可以考虑增加物化视图（通过放大写，加速查询）
```

## 优化效果

原来我们使用es存储span的索引，因为大数据部门的es维护状况差，es的查询和写入性能很差（维护状况好的话，相信es也可以有很好的表现的）。切换到clickhouse后，在查询性能、写入性能、存储用量上都有明显的提升。

- clickhouse部署情况：3分片2副本，共6台机器（64核/256G/89424G）
- es部署情况：每日创建索引，450分片，单副本；日写入720亿记录，占用13TB存储。
- 查询性能：平均耗时降低至原来的十分之一，tp99降低至原来的八分之一，消除超时的情况（超时时间为15秒）。**目前clickhouse在复杂查询、大结果集等情况下表现比es稳定，表现在tp90等耗时较低**，具体查询性能见下表（35qps下，并不严肃仅供参考）：

| 存储 | TP50 | TP90 | TP99 |
|  ---- | ---- | ---- | ---- |
| es | 850ms | 1966ms | 4000ms |
| ck | 103ms | 184ms | 537ms |

- 写入性能：每日写入2000亿原始数据（全量数据的16%），是原ES方案的3倍。待clickhouse扩容后还可提升写入量。
- 磁盘空间占用：结论：磁盘占用是es的1/9（相同写入量，相同副本数）。每天2000亿记录下，每天写入4TB，双副本是8TB，压缩率是18%。
- 查询qps峰值：我们没有对clickhouse进行专门压测，目前峰值qps为50qps，clickhouse无压力。压测可参考[ClickHouse与Elasticsearch压测实践（京东云）](https://www.toutiao.com/article/7137119576009048609/?app=news_article&timestamp=1661759655&use_new_style=1&req_id=20220829155415010158147053180502E7&group_id=7137119576009048609&share_token=95add52e-5ec3-42d7-84b3-1f975de2fc65&tt_from=copy_link&utm_source=copy_link&utm_medium=toutiao_android&utm_campaign=client_share&source=m_redirect)，引用其结论(**压测环境请在原文中查看**)：

> 1）clickhouse对并发有一定的支持，并不是不支持高并发，可以通过调整max_thread提高并发
> - max_thread=32时，支持最大TPS 是37，相应TP99是122
> - max_thread=2时，支持最大TPS 是66，相应TP99是155
> - max_thread=1时，支持最大TPS 是86，相应TP99是206
>  
> 2）在并发方面Elasticsearch比clickhouse支持的更好，但是相应的响应速度慢很多
> - Elasticsearch：对应的TPS是192，TP99是3050
> - clickhouse：对应的TPS 是86，TP99是206

## ClickHouse存储统计sql

```sql
with 'xxxxx' as table_name --只能查本地表
SELECT
    table,
    sum(rows) AS num_row,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompress,
    formatReadableSize(sum(data_compressed_bytes)) AS compress,
    round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS compress_ratio
FROM system.parts
WHERE active=1
and database!='system'
-- and table = table_name
GROUP BY table
order by num_row desc
```

```bash
Query id: d79e4c12-100a-487f-8f9d-4f32ea4f3791

┌─table────────────────────┬─────num_row─┬─uncompress─┬─compress─┬─compress_ratio─┐
│        xxxxx(只能查本地表) │ 66920399971 │ 7.43 TiB   │ 1.33 TiB │             18 │
└──────────────────────────┴─────────────┴────────────┴──────────┴────────────────┘

1 rows in set. Elapsed: 0.004 sec. 
```

如果要查整个集群的占用，from后面可以跟：`clusterAllReplicas('cluster_name', system, parts)`

例如如下的shell命令

```bash
query=$(cat <<EOF
SELECT
    table,
    sum(rows) AS num_row,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompress,
    formatReadableSize(sum(data_compressed_bytes)) AS compress,
    round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS compress_ratio
FROM clusterAllReplicas('default_cluster', system, parts)
WHERE active=1
and database!='system'
GROUP BY table
order by num_row desc
EOF
)
clickhouse client -h 10.0.214.26 --database xxxx --send_logs_level=trace --log-level=trace --server_logs_file='/tmp/query.log' --query "$query Format PrettyCompactMonoBlock" |sed 's/\x1b\[[0-9;]*m//g'
```