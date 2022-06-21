---
title: "Opentelemetry是怎么做链路追踪的"
date: 2021-12-12T11:11:38+08:00
draft: false
categories: [ "undefined"]
tags: ["可观测性"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

云原生可观测技术是云原生下很火的一个命题，opentelemetry的定位是统一metrics,trace和log的协议、api、sdk和exporter，他越来越成为云原生技术体系下的可观测性标准。这个博客就是来探究下opentelemetry是什么，做什么，怎么做的。

> OpenTelemetry is a collection of tools, APIs, and SDKs. Use it to instrument, generate, collect, and export telemetry data (metrics, logs, and traces) to help you analyze your software’s performance and behavior.

上面是[opentelemetry官网](https://opentelemetry.io/)对自己的定位。抽取一下关键词，opentelemetry仅提供了api和SDK，不负责后端实现（后端由prometheus、jaeger等实现），用这些api和SDK，你可以做性能数据埋点，生成、收集和导出（generate, collect, and export）监控数据。对这段话最终的理解是opentelemetry只做SDK层面的事，职责的边缘是export数据即止。

<!--more-->

概念性的东西不多讲，可以自己到opentelemetry的官网看。我个人的感受是，如果对trace比较了解，完全不用看官网一大堆的Concepts或者specification，他只是定义了一堆convention，也就是标准和协议的部分。对trace比较了解的话，就直接看代码吧。下面的行文采用自下而上的方式，也就是先看看怎么用上opentelemtry（建立信心：opentelemetry就这），然后在看设计层面的东西（深入了解，变成专家）。

## 使用demo

pom依赖：

```xml
<dependencyManagement>
    	<dependencies>
						<dependency>
                <groupId>io.opentelemetry</groupId>
                <artifactId>opentelemetry-bom</artifactId>
                <version>1.7.1</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    
    <dependencies>
        <dependency>
            <groupId>io.opentelemetry</groupId>
            <artifactId>opentelemetry-api</artifactId>
        </dependency>
        <dependency>
            <groupId>io.opentelemetry</groupId>
            <artifactId>opentelemetry-sdk</artifactId>
        </dependency>
        <dependency>
            <groupId>io.opentelemetry</groupId>
            <artifactId>opentelemetry-sdk-trace</artifactId>
        </dependency>
        <dependency>
            <groupId>io.opentelemetry</groupId>
            <artifactId>opentelemetry-exporter-logging</artifactId>
        </dependency>
    </dependencies>
```


测试代码：

```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanBuilder;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator;
import io.opentelemetry.context.Scope;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.exporter.logging.LoggingSpanExporter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.trace.export.SimpleSpanProcessor;
import io.opentelemetry.sdk.trace.samplers.Sampler;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Date;

public enum Tracer {

    INSTANCE;

    private io.opentelemetry.api.trace.Tracer delegate;

    Tracer() {
        // 创建TracerProvider，可以自定义TraceId，spanId生成规则；采样规则；后端（jaeger,otlp,logging）
        SdkTracerProvider sdkTracerProvider = SdkTracerProvider.builder()
                .setSampler(Sampler.alwaysOn())
                .setResource(Resource.getDefault().toBuilder().put("service.name", serviceName()).build())
                .addSpanProcessor(SimpleSpanProcessor.create(new LoggingSpanExporter()))
                .build();

        OpenTelemetry openTelemetry = OpenTelemetrySdk.builder()
                .setTracerProvider(sdkTracerProvider)
                // 跨进程传播规则
                .setPropagators(ContextPropagators.create(W3CTraceContextPropagator.getInstance()))
                .buildAndRegisterGlobal();
        this.delegate = openTelemetry.getTracer("http-proxy");
    }

    private String serviceName() {
        String hostName = null;
        try {
            hostName = InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException e) {
            hostName = "unknown";
        }
        return hostName;
    }

    public static SpanBuilder spanBuilder(String s) {
        return INSTANCE.delegate.spanBuilder(s);
    }

    public static void main(String[] args) throws InterruptedException {
        Span root = Tracer.spanBuilder("stream")
                .setSpanKind(SpanKind.SERVER)
                .setAttribute("class",Tracer.class.getSimpleName())
                .startSpan();

        try (Scope scope = root.makeCurrent()) {
            Span span1 = Tracer.spanBuilder("process1")
                    .setSpanKind(SpanKind.SERVER)
                    .startSpan();
            span1.end();
        } finally {
            root.end();
        }
        Thread.sleep(10000000);
    }
}
```


输出：

```shell
12月 12, 2021 11:53:28 上午 io.opentelemetry.exporter.logging.LoggingSpanExporter export
信息: 'process1' : 44706cc954af501b82881a94ee00894c b16e9b02a44596e1 SERVER [tracer: main:] {}
12月 12, 2021 11:53:28 上午 io.opentelemetry.exporter.logging.LoggingSpanExporter export
信息: 'stream' : 44706cc954af501b82881a94ee00894c 797ac60da89b6d0c SERVER [tracer: main:] AttributesMap{data={class=Tracer}, capacity=128, totalAddedValues=1}
```

## 再看下类图

![](/img/opentelemetry-trace-class-view.png)

## 重要类解析

### public interface Context

上下文，kv结构，用于保存span和baggage，存放在ThreadLocalContextStorage中，因此是Threadlocal的。

静态方法 `current()` 获取当前threadlocal的span和baggage

成员方法 `get(ContextKey<V> key)` 相当于map的get，key可以是`SpanContextKey.KEY`或者`BaggageContextKey.KEY`，分别对应Span和Baggage

成员方法 `with(ContextKey<V> k1, V v1);` 相当于map的put

成员方法 `Scope makeCurrent()`，将this设置到当前线程的threadlocal中，**返回的scope是一个闭包，捕获了之前的threadlocal的Context，调用scope的close方法会将之前的Context恢复到threadlocal中。Scope是必须close的。**

若干个`wrap`方法，跨线程封装Runnable、Callable、Executor，进入子线程前备份当前threadlocal，退出时恢复备份。

### Scope

```java
public interface Scope extends AutoCloseable {

  /**
   * Returns a {@link Scope} that does nothing. Represents attaching a {@link Context} when it is
   * already attached.
   */
  static Scope noop() {
    return NoopScope.INSTANCE;
  }

  @Override
  void close();
}
```

scope指span的生效范围。类比方法执行的压栈出栈，进入一个scope前要先备份局部变量，退出scope时要恢复这些备份。opentelemetry里用闭包来捕获备份，具体见**ThreadLocalContextStorage#attach**，如下：

```java
  @Override
  public Scope attach(Context toAttach) {
    if (toAttach == null) {
      // Null context not allowed so ignore it.
      return NoopScope.INSTANCE;
    }

    Context beforeAttach = current(); // 进入scope前的Context，被下面的闭包补货
    if (toAttach == beforeAttach) {
      return NoopScope.INSTANCE;
    }

    THREAD_LOCAL_STORAGE.set(toAttach);

    return () -> {
      if (current() != toAttach) {
        logger.log(
            Level.FINE,
            "Context in storage not the expected context, Scope.close was not called correctly");
      }
      THREAD_LOCAL_STORAGE.set(beforeAttach);
    };
  }
```



### Span

```java
@ThreadSafe
final class RecordEventsReadableSpan implements ReadWriteSpan {
    private static final Logger logger = Logger.getLogger(RecordEventsReadableSpan.class.getName());
    private final SpanLimits spanLimits;
    private final SpanContext context; // 需要传递给子span和跨进程传递的内容：traceId、spanId、flags(采样标识）、traceState（不同trace实现供应商所传递的系统信息）
    private final SpanContext parentSpanContext;
    private final SpanProcessor spanProcessor; // span的处理器，在结束时调用
    private final List<LinkData> links; // 父子关系外的其他关系
    private final int totalRecordedLinks;
    private final SpanKind kind; // INTERNAL、SERVER、CLIENT、PRODUCER、CONSUMER
    private final AnchoredClock clock;
    private final Resource resource; // 系统信息
    private final InstrumentationLibraryInfo instrumentationLibraryInfo;
    private final long startEpochNanos;
    private final Object lock = new Object();
    private String name;
    @Nullable
    private AttributesMap attributes; // 无时间属性的埋点
    private final List<EventData> events; // 有时间属性的埋点
    private int totalRecordedEvents = 0;
    private StatusData status = StatusData.unset();
    private long endEpochNanos;
    private boolean hasEnded;
```
