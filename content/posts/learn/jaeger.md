---
title: "Jaeger学习"
date: 2020-07-16T17:45:02+08:00
draft: false
categories: [ "undefined"]
tags: ["middleware"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

Jaeger是一个链路追踪系统，适合用于分布式的调用链路分析，服务依赖分析，性能和延迟优化。使用OpenTracing标准的语意和与其兼容的类库，使用灵活的抽样策略，支持多种后端存储（Cassandra, Elasticsearch, memory）
<!--more-->

## OpenTracing介绍

jaeger使用了OpenTracing的语意和类库，OpenTracing的目的是创建一个平台无关，厂商无关的trace系统标准。在介绍jaeger前先说一下OpenTracing抽象出来的几个概念。

[英文说明](https://github.com/opentracing/specification/blob/master/specification.md) 不长，对理解有帮助

[中文翻译](https://wu-sheng.gitbooks.io/opentracing-io/content/pages/api/cross-process-tracing.html)

### trace由span组成

![](/img/opentracing-trace-spans.png)

span可以理解为一个“过程”，在图片中用一个有跨度的线（长方形）表示，长度即消耗的时间。

trace则由多个span组成。将多个独立的span联系起来的的是requestID，也就是span的上下文信息。span和span之间有两种关系：`childOf`和`FollowsFrom`。上图的左边将函数调用链描述成一个树，`childOf`就是树中的父子关系，`followsFrom`就是兄弟关系。

span包含的信息：

- An operation name
- A start timestamp
- A finish timestamp
- A set of zero or more key:value Span Tags. The keys must be strings. The values may be strings, bools, or numeric types.
- A set of zero or more Span Logs, each of which is itself a key:value map paired with a timestamp. The keys must be strings, though the values may be of any type. Not all OpenTracing implementations must support every value type.
- A SpanContext (see below)
- References(childOf/followsFrom) to zero or more causally-related Spans (via the SpanContext of those related Spans)


SpanContext包含两部分信息：

1. 能定位到一个特定span的状态信息（traceId和spanId）
2. 在进程之间传递的Baggage Items（分布式trace需要上下文信息）

### Tracer

创建Span，在进程间在载体（例如Http Header）上Inject和Extract SpanContxt。


## Jaeger架构

组件：client、agent、collector、DB、web展示

**一种部署架构**

![](/img/architecture-v1.png)

**包含kafka的部署架构**

![](/img/architecture-v2.png)

### client说明

client部分负责将span中的信息通过agent传递给后端，从而写入存储；同时，向下游发送请求时，会将SpanContext附加在请求中，从而将trace的信息向下传播。

client为了减小负载，会进行采样，仅仅采样约0.1%的数据（可配置）

![](/img/jaeger-context-prop.png)

## 使用以及代码侵入型分析

[示例代码](https://github.com/signalfx/tracing-examples/blob/master/jaeger-java/src/main/java/com/signalfx/tracing/examples/jaeger/App.java) 这份代码展示了如何在单进程中使用Jaeger Client。可以看到创建了一个单例的Tracer对象，定义好该Trace如何进行采样，以及如何向agent上报数据（Http、rpc、udp）

在微服务环境下，涉及trace的跨进程传播，首先可以在Controller上增加切面，抽取SpanContext信息，其次可以对向外发送请求的对象进行adapt，例如对HttpClient进行代理，增加相关Header以Inject SpanContext信息。另外，因为Tracer对象是单例的，所以Tracer可以作为Spring的一个Bean进行初始化和使用。



