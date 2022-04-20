---
title: "Skywalking v8.9.1 源码阅读——深入了解STAM实现"
date: 2022-04-20T14:18:04+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

skywalking搞了STAM流拓扑分析方法，具体见[README-cn.md](https://github.com/wu-sheng/STAM/blob/master/README-cn.md)，简单来说就是将上游的Service、Service Instance等信息放在下游span中，从而一个span就具有上游Service和下游Service的信息，从而直接聚合出一个依赖关系，避免了通过时间窗口聚合。这篇文章里还介绍了暂存Peer network address <-> Service Name关系，从而解决“下游并不知道自己上游的Service名是什么的问题”，今天的目标是看看这到底是如何解决的。

<!--more-->

## Tracing协议

通信协议定义哪些字段会跨进程传递，在skywalking中，就是agent与后端的传输哪些字段（因为trace的分布式特点，tracing还有agent与agent传输的协议，这里不谈）。那么协议就决定了STAM能用哪些字段。

详细Tracing协议见：[trace-data-protocol-v3](https://skywalking.apache.org/docs/main/v8.9.1/en/protocols/trace-data-protocol-v3/)

1. segment是skywalking独有的一个概念，是一个线程内所有span的集合
2. 三种类型的span
- EntrySpan：入口span，http服务、rpc服务、MQ消费者

- LocalSpan：不与远程服务交互的span

- ExitSpan：出口span，各种clientSpan，比如httpclient的请求

3. 跨线程、进程父子关系被称为 “reference”. Reference包含上游的trace ID, segment ID, span ID, service name, service instance name, endpoint name,和客户端的目标地址 （跨线程场景中没有该字段）. reference中的这些字段是通过[Cross Process Propagation Headers Protocol v3](https://skywalking.apache.org/docs/main/v8.9.1/en/protocols/skywalking-cross-process-propagation-headers-protocol-v3/)在agent与agent之间传递的。

4. Span#skipAnalysis：如果该span不需要分析，则为true

简单总结下：一个segement代表一个线程内的所有span，跨进程的span使用reference传递上游信息。那么STAM具体使用了哪些字段呢？在协议proto中搜索STAM即可找到：

```java
message SegmentReference {
    ......
    // Entry Span(server span)会有此字段，表客户端地址
    string networkAddressUsedAtPeer = 8;
}

message SpanObject {
    ......
    // RPC和MQ场景下，Exit Span(client Span)会包含此字段，表服务端的地址
    string peer = 7;
    ......
}
```


client和server都有远端地址字段，这样拓扑分析既可以从client视角进行，也可以从server视角进行。networkAddressUsedAtPeer被以下两个类用到，他们都是在`agent-analyzer`模块下，接下来我们就可以进入到阅读代码的阶段，看看这两个类到底是如何做STAM的。

```shell
MultiScopesAnalysisListener
NetworkAddressAliasMappingListener
```


## 代码编译

需要参考[How-to-build.md](https://github.com/apache/skywalking/blob/8.9.1/docs/en/guides/How-to-build.md)

1. 设置maven代理，编译前端时需要使用到npm，npm相关的包需要用到maven的代理
2. clone仓库，并且clone子模块
3. maven clean compile编译protobuf和grpc

## 启动流程

上面已经找到了关键类，但目前还不知道skywalking是怎么走到这段代码的，需要看下启动流程才行。skywalking的模块化设计还是挺值得借鉴的。

### 加载server-starter下的application.yml，读取模块配置（ApplicationConfigLoader类）

application.yml定义了需要启动哪些模块，和每个模块的配置。每个模块有一个名字，多个provider，每个provider有自己的配置，并通过selector决定使用哪个provider。其大体结构如下

```yaml
agent-analyzer:
  selector: ${SW_AGENT_ANALYZER:default}
  default:
    # The default sampling rate and the default trace latency time configured by the 'traceSamplingPolicySettingsFile' file.
    traceSamplingPolicySettingsFile: ${SW_TRACE_SAMPLING_POLICY_SETTINGS_FILE:trace-sampling-policy-settings.yml}
    slowDBAccessThreshold: ${SW_SLOW_DB_THRESHOLD:default:200,mongodb:100} # The slow database access thresholds. Unit ms.
    forceSampleErrorSegment: ${SW_FORCE_SAMPLE_ERROR_SEGMENT:true} # When sampling mechanism active, this config can open(true) force save some error segment. true is default.
    segmentStatusAnalysisStrategy: ${SW_SEGMENT_STATUS_ANALYSIS_STRATEGY:FROM_SPAN_STATUS} # Determine the final segment status from the status of spans. Available values are `FROM_SPAN_STATUS` , `FROM_ENTRY_SPAN` and `FROM_FIRST_SPAN`. `FROM_SPAN_STATUS` represents the segment status would be error if any span is in error status. `FROM_ENTRY_SPAN` means the segment status would be determined by the status of entry spans only. `FROM_FIRST_SPAN` means the segment status would be determined by the status of the first span only.
    # Nginx and Envoy agents can't get the real remote address.
    # Exit spans with the component in the list would not generate the client-side instance relation metrics.
    noUpstreamRealAddressAgents: ${SW_NO_UPSTREAM_REAL_ADDRESS:6000,9000}
    meterAnalyzerActiveFiles: ${SW_METER_ANALYZER_ACTIVE_FILES:} # Which files could be meter analyzed, files split by ","
```

### 通过spi机制加载module，并按照依赖顺序启动所有模块（ModuleManager类）

通过spi加载的有ModuleDefine和ModuleProvider，他们是定义和实现的关系。ModuleDefine有模块名和对外暴露的接口，这有点像nodejs的模块管理。NodeManager会将NodeManager的引用（this）、ModuleDefine、模块配置传递给ModuleProvider，最后调用**ModuleProvider的prepare**，注册对外暴露接口的实现（registerServiceImplementation），即可完成模块的初始化。

至此，所有模块的初始化工作都完成了（配置注入、接口实现注册）。接下来BootstrapFlow类按照模块之间的依赖关系决定模块启动的排序，然后按顺序调用模块的start方法，启动所有模块。此时所有模块都已启动，需要跨模块调用时可以调用如下代码：

```
nodeManager.find(StorageModule.NAME).provider().getService(StorageDAO.class)
```

## agent-analyzer模块代码阅读

我们先看看其对外暴露的ISegmentParserService.class被哪些模块使用了，可以看到agent-analyzer直接被三个trace上报的api依赖。

![](/img/agent-analyzer-usage.png)

再看其内部实现，agent-analyzer模块整体基于监听器模式，也是事件驱动的：来一个segment，则通知已注册的监听器。监听器注册逻辑如下：

```java
    private SegmentParserListenerManager listenerManager() {
        SegmentParserListenerManager listenerManager = new SegmentParserListenerManager();
        if (moduleConfig.isTraceAnalysis()) {
            listenerManager.add(new MultiScopesAnalysisListener.Factory(getManager()));  // 我们关注的类
            listenerManager.add(new NetworkAddressAliasMappingListener.Factory(getManager())); // 我们关注的类
        }
        listenerManager.add(new SegmentAnalysisListener.Factory(getManager(), moduleConfig));

        return listenerManager;
    }
```

再看ISegmentParserService.class的实现类，其创建了一个TracerAnalyzer的实例，并调用doAnalysis方法，doAnalysis就是通知注册上去的各种监听器。

```java
    public void doAnalysis(SegmentObject segmentObject) {
        if (segmentObject.getSpansList().size() == 0) {
            return;
        }
        // 由listener工厂类创建工厂
        createSpanListeners();
        // 通知能处理segment的listener
        notifySegmentListener(segmentObject);

        segmentObject.getSpansList().forEach(spanObject -> {
            if (spanObject.getSpanId() == 0) {
                // 处理spanId=0的span，trace的起点
                notifyFirstListener(spanObject, segmentObject);
            }

            // 处理三种span
            if (SpanType.Exit.equals(spanObject.getSpanType())) {
                notifyExitListener(spanObject, segmentObject);
            } else if (SpanType.Entry.equals(spanObject.getSpanType())) {
                notifyEntryListener(spanObject, segmentObject);
            } else if (SpanType.Local.equals(spanObject.getSpanType())) {
                notifyLocalListener(spanObject, segmentObject);
            } else {
                log.error("span type value was unexpected, span type name: {}", spanObject.getSpanType()
                                                                                          .name());
            }
        });

        // 一个segment处理完毕，将分析结果发送给Core模块的source receiver处理
        notifyListenerToBuild();
    }
```

接下来聚焦**NetworkAddressAliasMappingListener**，这个类的java doc写了一段话：使用segment reference中的信息，设置network address与Server、ServiceInstance之间的别名映射。这个别名映射将在MultiScopesAnalysisListener解析ExitSpan时使用，用以设置正确的目标Service和ServiceInstance。**这就是STAM的关键**

```
/**
 * NetworkAddressAliasMappingListener use the propagated data in the segment reference, set up the alias relationship
 * between network address and current service and instance. The alias relationship will be used in the {@link
 * MultiScopesAnalysisListener#parseExit(SpanObject, SegmentObject)} to setup the accurate target destination service
 * and instance.
 *
 * This is a key point of SkyWalking header propagation protocol.
 */
 ```


