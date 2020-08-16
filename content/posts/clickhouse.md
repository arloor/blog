---
title: "Clickhouse使用学习"
date: 2020-08-14T14:37:51+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

- 机器环境：centos7 2G内存
- [clickhouse文档](https://clickhouse.tech/docs/en/)
<!--more-->

## 安装

[安装文档](https://clickhouse.tech/docs/en/getting-started/install/)

```shell
# 需要cpu支持 SSE 4.2
grep -q sse4_2 /proc/cpuinfo &&{
echo "SSE 4.2 supported" 
yum install -y yum-utils
rpm --import https://repo.clickhouse.tech/CLICKHOUSE-KEY.GPG
yum-config-manager --add-repo https://repo.clickhouse.tech/rpm/stable/x86_64
yum install clickhouse-server clickhouse-client
service clickhouse-server start
service clickhouse-server status
echo "config @ /etc/clickhouse-server/config.xml"
echo 
} || echo "SSE 4.2 not supported"
```

注：clickhouse的服务是用的`/etc/init.d`下的启动脚本

**测试安装是否成功**

```
clickhouse-client
select 1
```

效果如下图
<img src="/img/clickhouse-client.png" alt="" width="600px" style="max-width: 100%;">

## 测试

和很多数据库管理系统一样，clickhouse也有database和table的概念

**创建数据库**

```shell
CREATE DATABASE IF NOT EXISTS test
use test
```

**创建表**

创建表和mysql也差不多，需要指定以下内容：

1. 表名
2. 表scheme：字段名和字段类型
3. Table engine and its settings——决定查询怎么被执行

```sql
CREATE TABLE tutorial.hits_v1
(
    `WatchID` UInt64,
    `JavaEnable` UInt8,
    `Title` String,
    `GoodEvent` Int16,
    `EventTime` DateTime,
    `EventDate` Date,
    `CounterID` UInt32,
    `ClientIP` UInt32,
    ................
    `URLHash` UInt64,
    `CLID` UInt32,
    `YCLID` UInt64,
    `ShareService` String,
    `ShareURL` String,
    `ShareTitle` String,
    `ParsedParams` Nested(
        Key1 String,
        Key2 String,
        Key3 String,
        Key4 String,
        Key5 String,
        ValueDouble Float64),
    `IslandID` FixedString(16),
    `RequestNum` UInt32,
    `RequestTry` UInt8
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(EventDate)
ORDER BY (CounterID, EventDate, intHash32(UserID))
SAMPLE BY intHash32(UserID)
SETTINGS index_granularity = 8192
```

**查询**

```sql
SELECT
    StartURL AS URL,
    AVG(Duration) AS AvgDuration
FROM tutorial.visits_v1
WHERE StartDate BETWEEN '2014-03-23' AND '2014-03-30'
GROUP BY URL
ORDER BY AvgDuration DESC
LIMIT 10
```