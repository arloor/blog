---
title: "Hosts Metric"
date: 2020-08-26T14:48:55+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## bigGraph接口，查询hosts指标的代码

```
/r/hosts/metric/bigGraph
```

## 1

**HostsDashboardController::doQuery**查询hosts指标

入参： 开始时间 结束时间 时间enum endpoints（hosts） 指标 采样方法（avg、min、max） ——指标s例如cpu，JVM gc，内存使用量

对每一个时间enum 都会执行 **HostsQueryService::getDashboards**（endpoints,指标s）

## 2

如果时间enum是分钟级或者秒级，调用**HostsQueryService::queryWithEncode**
 
入参： 开始时间 结束时间 endpoint<>指标s 采样方法(avg,min,max) 时间enum

首先会从meta中根据指标名获取对应的 HostsMetric。（如果没有对应指标，则返回空）

HostsMetric中会有指标的一些信息，例如 JVM 内存使用量是否有秒级指标，是否包含在某个指标组中（例如“内存”）



## 3

然后走到 **HostsQueryService::doQueryWithEncode**

入参： 开始时间 结束时间 机器<>指标s 抽样方法 时间enum

这里面最重要的是rowKeyBuilder，

EndpointMetricsCode endpointMetricsCode = rowkeyBuider.queryCode(endpointMetrics) 会调用meta将endpotins编码成3字节 将指标名编码成2字节

然后有开关会控制是否从redis读取最近时间的数据 HostsQueryService::queryRedis

查询Hbase的部分如下：

首先会增加hbase正在执行的task计数，如果超过阀值之间返回，防止拉挂

然后获取查询Hbase的batch size

long beginAggTime = metricNeedAggConfigManager.needAggByCode(metricCode)  ？？？  agg啥

然后进行batch查询 具体步骤请看4

最后： for (Future<List<RequestAndResponse>> future : futures) 获取hbase查询结果future

## 4

EncodeHBaseQueryService::query会携带endpointCode(3bytes)和metricCode(2bytes)和开始时间 结束时间 及时间enum进行batch查询

首先会根据时间enum查询habse的表，分钟级指标在raptor_system_minute_metrics中

还有一个family的byte[] 固定值{'m'} 是collumFamily

然后就是重点： buildRowKeyAndColumns 

## 5

buildRowKeyAndColumns 

入参： 开始时间 结束时间 时间enum `BiConsumer<rowKeyPeriod, colum>`

这里面就是计算出某个时间戳对应的整小时时间戳  及 偏移量=timestamp - 该整小时时间戳）除以粒度（1000（秒），60000（分钟））

整小时时间戳 将作为build rowkey的一部分，偏移量是columnId

然后BiCounsumer将endpointCode、metricCode、整小时时间戳一起编码到一个bytes[]，这就是rowKey






