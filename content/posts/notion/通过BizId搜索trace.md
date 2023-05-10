---
title: "通过BizId搜索trace"
date: 2023-05-10T11:24:49+08:00
draft: false
categories: [ "undefined"]
tags: ["notion"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

# 通过BizId搜索trace

```sql
drop table if exists tracing_kv on cluster default_cluster;
create table if not exists tracing_kv on cluster default_cluster
(
    key   String,
    value SimpleAggregateFunction(groupUniqArrayArray,Array(String)),
    time  DateTime
) ENGINE = SummingMergeTree
      PARTITION BY toDate(time)
      order by key
			ttl toDate(time) + toIntervalDay(21);
      --TTL toDate(time) + toIntervalDay(1) TO DISK 'hdd', toDateTime(time) + toIntervalDay(21)
			--SETTINGS index_granularity = 8192, storage_policy = 'ssd_hdd_cos';

CREATE TABLE if not exists tracing_kv_distributed on cluster default_cluster
(
    key   String,
    value SimpleAggregateFunction(groupUniqArrayArray,Array(String)),
    time  DateTime
)
    ENGINE = Distributed('default_cluster', '', 'tracing_kv', rand());
```

```sql
select arrayJoin(groupUniqArrayArray(value)) 
from tracing_kv_distributed
where key=#{key}
/*时间为空，则无此条件*/and time between toStartOfDay(toDateTime(#{time})) and toStartOfDay(toDateTime(#{time}))+toIntervalDay(1)
        
```
