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
curl 'http://localhost:8080/raptor/r/hosts/metric/bigGraph' \
  -H 'Connection: keep-alive' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.135 Safari/537.36' \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://raptor.mws-test.sankuai.com' \
  -H 'Referer: http://raptor.mws-test.sankuai.com/application/hosts?reportType=hour&date=&startDate=20200825190000&endDate=20200825195900&r=31494&ip=set-yp-infsh-cat-cat-mq-consumer-test01&group=set-yp-infsh-cat-cat-mq-consumer-test01&domain=RT_root.xr_realtime.hadoop-rt.c7_banma_ssd' \
  -H 'Accept-Language: zh,en;q=0.9,zh-CN;q=0.8' \
  -H 'Cookie: iam_organization=2; iam_project=53168; _ga=GA1.2.290940288.1595590424; _lxsdk_cuid=172b60f4ee1c8-03a6f2dbd86ecb-143e6257-168000-172b60f4ee1c8; _lxsdk=172b60f4ee1c8-03a6f2dbd86ecb-143e6257-168000-172b60f4ee1c8; deviceId=54c3c1e0-d6c8-11ea-8834-fbd709d2f352; al=jdqrmxjcpoccsoihcdvmgzsegeazslnc; uu=6ed50940-d6c8-11ea-900a-8dd95abad704; cid=1; ssoid=eAGFjy1LBFEYhblt2CQLgnHi7obhft_7mpy7rBgXDIJF7sdMXItiMbgGmyg2NymIcZdVQYMKrmLzF1hEGByriNkRMVsOnHAenhOhqc_7MYoHr8dfk4RGEgMlWsBsnHOHMeEStGccqIWqtXKpBMUEqNLmGdWbS5lb9Fkv25w3KjVKctJhTAhopybtSAO4bZjiGkR8O3k6f0waiP4L1j9Cc2hhePb-cZd0b0YvD9fJNiK1Wur96npvrbsR6tPlxWmxd1ns7xajnbejfjk8KUf9GRRvXR02G7-bAxT9-Q1QQjF3XNjArOAAiknsqiPc5RCstkGuEAFSgaZSYqaWY-ed9hasli3HQyZclYICC1znQTj5DatHaEA**eAENx8kBwCAIBMCWlGOBclwD_Zdg5jdMUwmmfRot6jQ4Ksq4mx0h-67sNQL3U3cU_jdxmH1t8AAa3RER; yun_portal_ssoid=eAGFjy1LBFEYhblt2CQLgnHi7obhft_7mpy7rBgXDIJF7sdMXItiMbgGmyg2NymIcZdVQYMKrmLzF1hEGByriNkRMVsOnHAenhOhqc_7MYoHr8dfk4RGEgMlWsBsnHOHMeEStGccqIWqtXKpBMUEqNLmGdWbS5lb9Fkv25w3KjVKctJhTAhopybtSAO4bZjiGkR8O3k6f0waiP4L1j9Cc2hhePb-cZd0b0YvD9fJNiK1Wur96npvrbsR6tPlxWmxd1ns7xajnbejfjk8KUf9GRRvXR02G7-bAxT9-Q1QQjF3XNjArOAAiknsqiPc5RCstkGuEAFSgaZSYqaWY-ed9hasli3HQyZclYICC1znQTj5DatHaEA**eAENx8kBwCAIBMCWlGOBclwD_Zdg5jdMUwmmfRot6jQ4Ksq4mx0h-67sNQL3U3cU_jdxmH1t8AAa3RER; u=1824058890; logan_session_token=j29likzrcgpt6d22izbt; _lxsdk_s=1742969dc5e-2e2-21a-06c%7C%7C234' \
  --data-binary '{"domain":"RT_root.xr_realtime.hadoop-rt.c7_banma_ssd","group":"","endpoints":[],"startDate":"202008251900","endDate":"202008251959","sample":"avg","metric":"load.1minPerCPU","topK":20,"second":false}' \
  --compressed \
  --insecure
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






