---
title: "Skywalking v8.9.1文档学习"
date: 2022-04-19T21:16:14+08:00
draft: false
categories: [ "undefined"]
tags: ["obs","middleware"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

看看skywalking
<!--more-->

## 官方文档

[https://skywalking.apache.org/docs/main/v8.9.1/readme/](https://skywalking.apache.org/docs/main/v8.9.1/readme/)

## 概念

- Service：具有相同职责的一组工作负载的集合，美团是appkey
- Service Instance：一个具体的工作负载。美团是一台机器，一个进程，或者k8s里的一个pod
- Endpoint：请求的路径：http URL或者RPC中的class+method

## 设计目标

- 维持可观察性：不管目标系统的部署方式，skywalking都提供一种集成方式。
- topology、metrics、trace相结合：这三者有从整体到局部的递进关系。当我们理解一个分布式系统时，首先要可以从拓扑图入手（topology），看懂服务的依赖关系。之后，可以关注跨进程调用的性能指标(metrics)，读懂系统的依赖压力点（qps高）、易故障点（失败率高）、耗时瓶颈点，确认架构演进方向。最后，针对具体问题，可以找到trace进行故障定位。个人理解，这三者是full  bicture到each phase到some case的关系，不展开讲。
- 轻量级：在SDK层面，仅依赖网络传输框架（GPRC），避免包冲突和增加性能损耗。在skywalking后端，**使用自己的轻量框架搭建应用核心，避免用户使用大数据技术栈来做流处理**（这启示了我为什么我们监控团队没有用大数据那一套）。
- 插件化，可拓展：skywalking提供了很多客户端实现，但是不可能面面俱到，于是提供了插件化的方式，允许用户扩展埋点方式
- 可移植：支持多种环境：1）传统注册中心，eruka的http可用列表。2）RPC框架的服务注册和发现，Spring Cloud、Appache Dubbo。3）service mesh。4)使用云服务。5）跨云部署
- 互操作性：**可观测性的全景是如此广阔**，以至于skywalking不太可能覆盖所有的系统。skywalking支持zipkin、jaeger、opentracing、openCensus的SDK前端，并将他们的数据转换成skywalking的协议，用户因此不需要切换客户端实现。

## 探针

### 自动埋点

agent方式，用户不需要改代码，运行时agent修改代码来进行埋点。

局限性：

1. 只支持固定的框架或者库。只有代码对agent是已知的，agent才知道需要改哪里，如何改。
2. 跨线程操作支持不好。

### 手动埋点

- Go2Sky. Go SDK follows the SkyWalking format.
- C++. C++ SDK follows the SkyWalking format.

### service mesh探针

支持istio和envoy的service mesh架构。

![](/img/istio-arch.svg)

从数据面的sidercar(envoy)收集请求的来源地址、目标地址、延迟和状态。service mesh探针对每一个请求会生成一个client实体和一个server实体，用于生成metrics和topology。

service mesh探针不是基于trace的，没有traceId，但是也能聚合出服务topology，因为有来源地址、目标地址等信息。

## 后端

### 能力

skywalking是OAP系统(可观测性分析系统)，工作在三大领域：

- Tracing: SkyWalking原生的数据格式，包括zipkin V1和V2，以及jager
- Metrics: service mesh探针数据，以及以metrics模式运行的agent采集的数据
- Logging：从磁盘和网络收集的日志。agent可以自动绑定trace和log（client层面）。skywalking也可以通过文本内容进行日志和trace的绑定（后端层面）。

提供了三大语言处理引擎：

- Observability Analysis Language（OAL） 处理原生trace和service mesh数据
- Meter Analysis Language（MAL） 负责计算原生meter(度量)数据，和适配其他metrics系统，例如promethues和opentelemetry。
- Log Analysis Language（LAL） 专注于日志内容，并与meter系统合作

如何“语言处理引擎”？

一句话说就是，基于配置的流程处理引擎。高雅一些，将配置升华成领域特定语言，即“使用领域特定语言，定义可控输入和可控输出，并装配出完整处理流程”。

### OAL

**OAL处理trace以生成metrics，trace数据是未经客户端聚合的，完全依赖后端的聚合。**

OAL负责流式地分析数据，专注于Service、Service Instance、Endpoint的metrics。

从6.3版本开始，OAL以`oal-rt`的形式内嵌在OAP的运行时中。OAL的脚本在/config目录下，OAL是编译型语言，会生成对应的java代码。用户可以修改OAL脚本，并重启服务端以生效。

OAL脚本定义了原始数据的来源from、过滤规则filter和处理函数function，最终生成了指标数据。具体语法见：[https://skywalking.apache.org/docs/main/v8.9.1/en/concepts-and-designs/oal/](https://skywalking.apache.org/docs/main/v8.9.1/en/concepts-and-designs/oal/)

**局限**，没有多指标的符合运算——没有美团的business复合指标，大盘聚合指标

### MAL

**MAL处理原生metrics数据，他们是本身做过客户端聚合的**

Sample family：同名不同tag的指标

MAL处理metrics数据和其他系统的metrics数据，例如opencensus和prometheus。指标数据的格式跟prometheus很像：metricname+tags+value。具体metrics的协议见[Meter.proto](https://github.com/apache/skywalking-data-collect-protocol/blob/master/language-agent/Meter.proto)

```
instance_trace_count{region="us-west",az="az-1"} 100
instance_trace_count{region="us-east",az="az-3"} 20
instance_trace_count{region="asia-north",az="az-1"} 33
```


MAL支持tag过滤、value过滤、单指标加减乘除常数、多指标加减乘除（复合指标）、上卷（降维，根据某个维度进行max、min、sum、avg）、类prometheus的函数（rate、irate、increase、histogram ）、降采样（将原始数据聚合为分钟级、小时级、天级）

### LAL

LAL本质上是领域特定语言（官方文档仅认为LAL是领域特定语言，但是OAL、MAL也是吧）。使用LAL来解析、抽取、保存日志，并且可以通过抽取traceId、segmentId、spanId来与trace协作，或者生成metrics并送给MAL处理。*这里有一个命题就是三种引擎之间的协作，有必要探究下*