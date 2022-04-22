---
title: "Skywalking v8.9.1 源码阅读——深入了解STAM实现"
date: 2022-04-20T14:18:04+08:00
draft: false
categories: [ "undefined"]
tags: ["可观测性"]
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
    // Entry Span(server span)会有此字段，表服务端的地址
    string networkAddressUsedAtPeer = 8;
}

message SpanObject {
    ......
    // RPC和MQ场景下，Exit Span(client Span)会包含此字段，表服务端的地址
    string peer = 7;
    ......
}
```


networkAddressUsedAtPeer被以下两个类用到，他们都是在`agent-analyzer`模块下，接下来我们就可以进入到阅读代码的阶段，看看这两个类到底是如何做STAM的。

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

## STAM实现解析

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

接下来聚焦**NetworkAddressAliasMappingListener**，这个类的java doc写了一段话：使用EntrySpan的segment reference中的信息，设置network address与Server、ServiceInstance之间的别名映射。这个别名映射将在MultiScopesAnalysisListener解析ExitSpan时使用，用以设置正确的目标Service和ServiceInstance。**这就是STAM的关键**

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

具体代码见如下，也比较简单就是构造了一个network address、Service、ServiceInstance的三元组，然后交给了core模块的SourceReciever。

```java
    @Override
    public void parseEntry(SpanObject span, SegmentObject segmentObject) {
        if (span.getSkipAnalysis()) { // 跳过分析
            return;
        }
        if (log.isDebugEnabled()) {
            log.debug("service instance mapping listener parse reference");
        }
        if (!span.getSpanLayer().equals(SpanLayer.MQ)) { // 非MQ
            span.getRefsList().forEach(segmentReference -> {
                if (RefType.CrossProcess.equals(segmentReference.getRefType())) { // 是跨进程类型
                    final String networkAddressUsedAtPeer = namingControl.formatServiceName( // 格式化上游的network地址
                        segmentReference.getNetworkAddressUsedAtPeer());
                    if (config.getUninstrumentedGatewaysConfig().isAddressConfiguredAsGateway( // 是网关地址则跳过映射，网关应该是透明的，不属于具体的Service
                        networkAddressUsedAtPeer)) {
                        /*
                         * If this network address has been set as an uninstrumented gateway, no alias should be set.
                         */
                        return;
                    }
                    final String serviceName = namingControl.formatServiceName(segmentObject.getService()); //下游的Service
                    final String instanceName = namingControl.formatInstanceName( // 下游的ServiceInstance
                        segmentObject.getServiceInstance());

                    // 构造别名关系
                    final NetworkAddressAliasSetup networkAddressAliasSetup = new NetworkAddressAliasSetup();
                    networkAddressAliasSetup.setAddress(networkAddressUsedAtPeer);
                    networkAddressAliasSetup.setRepresentService(serviceName);
                    networkAddressAliasSetup.setRepresentServiceNodeType(NodeType.Normal);
                    networkAddressAliasSetup.setRepresentServiceInstance(instanceName);
                    networkAddressAliasSetup.setTimeBucket(TimeBucket.getMinuteTimeBucket(span.getStartTime()));

                    //发送给core模块的SourceReceiver
                    sourceReceiver.receive(networkAddressAliasSetup);
                }

            });
        }
    }
```

接下来走到core模块的SourceReceiverImpl,这个类将不同类型的source分派到不同的处理流程上，NetworkAddressAliasSetup类型的source分配到NetworkAddressAliasSetupDispatcher上，其代码是：

```java
public class NetworkAddressAliasSetupDispatcher implements SourceDispatcher<NetworkAddressAliasSetup> {
    @Override
    public void dispatch(final NetworkAddressAliasSetup source) { 
        // 在这里将source转换成metric。变成了metric，就能进入指标处理系统了，可以认为是脱胎换骨了。
        final NetworkAddressAlias networkAddressAlias = new NetworkAddressAlias();
        networkAddressAlias.setTimeBucket(source.getTimeBucket());
        networkAddressAlias.setAddress(source.getAddress());
        networkAddressAlias.setRepresentServiceId(source.getRepresentServiceId());
        networkAddressAlias.setRepresentServiceInstanceId(source.getRepresentServiceInstanceId());
        networkAddressAlias.setLastUpdateTimeBucket(source.getTimeBucket());
        MetricsStreamProcessor.getInstance().in(networkAddressAlias); // 丢进指标处理系统
    }
}
```

MetricsStreamProcessor是指标聚合、计算的入口类，其将指标根据class丢进对应的**MetricsAggregateWorker**，这是一个非常重要的类，承担着L1 aggregation（一级聚合）的职责，将原始的数据，聚合成一分钟的数据，减少网络和内存占用。关于一级聚合和二级聚合可以参见[Skywalking项目后台oap-server的指标聚合](https://blog.liguohao.cn/2021/09/30/skywalking-oap-server-roles)。这个MetricsAggregateWorker的功能其实比较简单，类似Raptor用的QueueThread，包含一个queue，异步enqueue，同时还有线程poll，做的工作也简单，combine相同的指标，例如total++，最大耗时重算等等，但是**抽象的封装的是真好，可以学习**。执行完聚合后，交给pipeline的下一个worker处理。

```java
        MetricsRemoteWorker remoteWorker = new MetricsRemoteWorker(moduleDefineHolder, remoteReceiverWorkerName);
        MetricsAggregateWorker aggregateWorker = new MetricsAggregateWorker(
            moduleDefineHolder, remoteWorker, stream.getName(), l1FlushPeriod);
```

看上面的代码，**MetricsAggregateWorker**的nextWorker是MetricsRemoteWorker，就是发送给L2 aggregation。部署模型又能决定这里的发送方式了，[Skywalking项目后台oap-server的指标聚合](https://blog.liguohao.cn/2021/09/30/skywalking-oap-server-roles)讲到默认情况下，L1和L2聚合是Mixed部署的，所以不涉及到跨进程传输，非Mixed就涉及到路由设计了。skywalking的路由比较简单，从zk或k8s获取机器列表，三种路由策略：ForeverFirst、HashCode(默认)、Rolling。

这条路继续往下有点深了，先暂且收收，快进到NetAddressAlias怎么用于STAM吧。首先注意到**MultiScopesAnalysisListener**有一个networkAddressAliasCache，这个缓存是在如下地方定时更新的，从dao里查询更新，并更新缓存，常规操作。

```
    /**
     * Update the cached data updated in last 1 minutes.
     */
    private void updateNetAddressAliasCache(ModuleDefineHolder moduleDefineHolder) {
        INetworkAddressAliasDAO networkAddressAliasDAO = moduleDefineHolder.find(StorageModule.NAME)
                                                                           .provider()
                                                                           .getService(
                                                                               INetworkAddressAliasDAO.class);
        NetworkAddressAliasCache addressInventoryCache = moduleDefineHolder.find(CoreModule.NAME)
                                                                           .provider()
                                                                           .getService(NetworkAddressAliasCache.class);
        long loadStartTime;
        if (addressInventoryCache.currentSize() == 0) {
            /**
             * As a new start process, load all known network alias information.
             */
            loadStartTime = TimeBucket.getMinuteTimeBucket(System.currentTimeMillis() - 60_000L * 60 * 24 * ttl);
        } else {
            loadStartTime = TimeBucket.getMinuteTimeBucket(System.currentTimeMillis() - 60_000L * 10);
        }
        List<NetworkAddressAlias> addressInventories = networkAddressAliasDAO.loadLastUpdate(loadStartTime);

        addressInventoryCache.load(addressInventories);
    }
```


再细看**MultiScopesAnalysisListener**是如何处理ExitSpan的，并不神奇哈：

```java
    /**
     * The exit span should be transferred to the service, instance and relationships from the client side detect
     * point.
     */
    @Override
    public void parseExit(SpanObject span, SegmentObject segmentObject) {
        if (span.getSkipAnalysis()) {
            return;
        }

        SourceBuilder sourceBuilder = new SourceBuilder(namingControl);

        final String networkAddress = span.getPeer(); // 获取到服务端的网络地址
        if (StringUtil.isEmpty(networkAddress)) {
            return;
        }

        // 设置客户端信息
        sourceBuilder.setSourceServiceName(segmentObject.getService());
        sourceBuilder.setSourceNodeType(NodeType.Normal);
        sourceBuilder.setSourceServiceInstanceName(segmentObject.getServiceInstance());

        final NetworkAddressAlias networkAddressAlias = networkAddressAliasCache.get(networkAddress);
        if (networkAddressAlias == null) { // 如果服务端网络地址没有别名映射
            sourceBuilder.setDestServiceName(networkAddress);
            sourceBuilder.setDestServiceInstanceName(networkAddress);
            sourceBuilder.setDestNodeType(NodeType.fromSpanLayerValue(span.getSpanLayer()));
        } else {// 如果服务端网络地址没有别名映射，使用别名映射
            /*
             * If alias exists, mean this network address is representing a real service.
             */
            final IDManager.ServiceID.ServiceIDDefinition serviceIDDefinition = IDManager.ServiceID.analysisId(
                networkAddressAlias.getRepresentServiceId());
            final IDManager.ServiceInstanceID.InstanceIDDefinition instanceIDDefinition = IDManager.ServiceInstanceID
                .analysisId(
                    networkAddressAlias.getRepresentServiceInstanceId());
            sourceBuilder.setDestServiceName(serviceIDDefinition.getName());
            /*
             * Some of the agent can not have the upstream real network address, such as https://github.com/apache/skywalking-nginx-lua.
             * Keeping dest instance name as NULL makes no instance relation generate from this exit span.
             */
            if (!config.shouldIgnorePeerIPDue2Virtual(span.getComponentId())) {
                sourceBuilder.setDestServiceInstanceName(instanceIDDefinition.getName());
            }
            sourceBuilder.setDestNodeType(NodeType.Normal);
        }

        sourceBuilder.setDetectPoint(DetectPoint.CLIENT);
        sourceBuilder.setComponentId(span.getComponentId());
        setPublicAttrs(sourceBuilder, span);
        exitSourceBuilders.add(sourceBuilder);

        // 数据库慢访问，这里不关注
        if (RequestType.DATABASE.equals(sourceBuilder.getType())) {
            boolean isSlowDBAccess = false;

            DatabaseSlowStatementBuilder slowStatementBuilder = new DatabaseSlowStatementBuilder(namingControl);
            slowStatementBuilder.setServiceName(networkAddress);
            slowStatementBuilder.setId(segmentObject.getTraceSegmentId() + "-" + span.getSpanId());
            slowStatementBuilder.setLatency(sourceBuilder.getLatency());
            slowStatementBuilder.setTimeBucket(TimeBucket.getRecordTimeBucket(span.getStartTime()));
            slowStatementBuilder.setTraceId(segmentObject.getTraceId());
            for (KeyStringValuePair tag : span.getTagsList()) {
                if (SpanTags.DB_STATEMENT.equals(tag.getKey())) {
                    String sqlStatement = tag.getValue();
                    if (StringUtil.isNotEmpty(sqlStatement)) {
                        if (sqlStatement.length() > config.getMaxSlowSQLLength()) {
                            slowStatementBuilder.setStatement(sqlStatement.substring(0, config.getMaxSlowSQLLength()));
                        } else {
                            slowStatementBuilder.setStatement(sqlStatement);
                        }
                    }
                } else if (SpanTags.DB_TYPE.equals(tag.getKey())) {
                    String dbType = tag.getValue();
                    DBLatencyThresholdsAndWatcher thresholds = config.getDbLatencyThresholdsAndWatcher();
                    int threshold = thresholds.getThreshold(dbType);
                    if (sourceBuilder.getLatency() > threshold) {
                        isSlowDBAccess = true;
                    }
                }
            }

            if (StringUtil.isEmpty(slowStatementBuilder.getStatement())) {
                String statement = StringUtil.isEmpty(
                    span.getOperationName()) ? "[No statement]" : "[No statement]/" + span.getOperationName();
                slowStatementBuilder.setStatement(statement);
            }
            if (isSlowDBAccess) {
                dbSlowStatementBuilders.add(slowStatementBuilder);
            }
        }
    }
```

## skywalking数据流图

上面的内容主要是关于STAM实现的细节，文字描述有点复杂，画个图就比较清晰了。

![](/img/skywalking-process.svg)