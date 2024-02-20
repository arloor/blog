---
title: "Opentelemetry Java自动埋点实现"
date: 2022-06-22T11:11:07+08:00
draft: false
categories: [ "undefined"]
tags: ["observability"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

[Opentelemetry是怎么做链路追踪的](/posts/opentelemetry-trace/)介绍了opentelemetry的API和SDK实现，也介绍了如何进行手动买点。这篇博客是介绍如何进行自动埋点，这当然要用到javaagent技术了。[Java Agent实现指南](/posts/java-agent/)有写过javaagent的实现指南和类加载的坑，今天看看opentelemetry是如何做的，其github地址是[opentelemetry-java-instrumentation](https://github.com/open-telemetry/opentelemetry-java-instrumentation)，接下来应该就是跟着代码流水账了。
<!--more-->

## OpenTelemetryAgent类

这是javaagent的Premain-class和Agent-class，也是javaagent的启动类。注释中写到，该类会被SystemClassLoader加载，其他类会被BootstrapClassLoader加载。如果在其他类中再**反向引用该类**，则会导致该类再被BootStrapClassLoader加载，导致出现两个不同的OpenTelemetryAgent类（因为**类加载器不同**）。为了防止这件事发生，注释里提了几个注意点：

1. 该类尽可能做少的事情
2. 绝对不要从其他类引用该类
3. 不要在该类中存储static数据（如果真出现两个类的情况，那么其实是两份static数据）
4. 不要在该类中初始化任何日志组件。

那么该类做了哪些事呢？

1. 拿到agentJar，并将该jar设置到BootStrapClassLoader的搜索路径（为了由bootstrapClassLoader加载其他类）
2. 将instrumention对象放置到Holder的类中，以便在其他地方使用
3. 调用**AgentInitializer**，进入真正的agent初始化工作。

步骤1和2应该是所有javaagent都需要的工作，自己实现agent也可以借鉴。第3步是opentelemetry的核心了，接下来进入这一部分。

## AgentInitializer类

还是先看注释：这个类被OpenTelemetryAgent调用，因此由bootstrapClassLoader加载，因此可以**畅通地使用**agent的其他类（因为其他类同样被bootstrapClassLoader加载）

> 这也符合在上面提到的，在premain和agentmain的类中做尽可能少的事

这个类实际上做了三件事：

1. 创建AgentClassloader
2. 使用AgentClassloader加载AgentStarterImpl类
3. 调用AgentStarterImpl进行agent的初始化（该类所加载的所有类都是由AgentClassLoader加载的，**该类的所有活动都在AgentClassLoader的范围内**）

### AgentClassloader

otel的classloader整体思想是目标jar在agent.jar中，目标jar中都是.classdata文件，以确保不会被其他类加载器加载到。

该classloader的父亲类加载器在jdk8及以下是null(BootstrapClassLoader)，在jdk9及以上是PlatformClassLoader（目测应该类似BootstrapClassLoader）。

除此之外，还有一些细节在代码中，例如

1. 不能在AgentClassLoader中使用slfj
2. 为了获取agent.jar中的resource，需要一个proxy对象
3. 针对promtheus的exporter类使用到的jdk httpserver做了加载的排除
4. 对otel自身用到的grpc类做了排除

### AgentStarterImpl

构造如下，涉及到一个类型强转：

```java
  private static AgentStarter createAgentStarter(
      ClassLoader agentClassLoader, Instrumentation instrumentation, File javaagentFile)
      throws Exception {
    Class<?> starterClass =
        agentClassLoader.loadClass("io.opentelemetry.javaagent.tooling.AgentStarterImpl");
    Constructor<?> constructor =
        starterClass.getDeclaredConstructor(Instrumentation.class, File.class);
    // 这里有类型强转到interface
    return (AgentStarter) constructor.newInstance(instrumentation, javaagentFile);
  }
```

这里分析下为什么这个类型强转没有遇到类加载问题？不要觉得这里啰嗦，自动埋点的难点只有两个，一个是怎么做字节码修改，另一个就是处理类加载隔离。

AgentStarterImpl是AgentClassLoader加载的，他是AgentStarter这个接口的实现类（由BootstrapClassloader加载）。因为AgentStartImpl extends(impl) AgentStartImpl, 且 AgentClassLoader extends BootstrapClassLoader（逻辑上的父子关系）。

AgentStarterImpl又创建了各种插件的extensionClassLoader，独立classloader的目的是为了避免与用户代码的影响。

最后将extensionClassLoader设置为线程上下文的Classloader，并安装BytebuddyAgent来做字节码修改。

```java
  @Override
  public void start() {
    extensionClassLoader = createExtensionClassLoader(getClass().getClassLoader(), javaagentFile);
    ClassLoader savedContextClassLoader = Thread.currentThread().getContextClassLoader();
    try {
      Thread.currentThread().setContextClassLoader(extensionClassLoader);
      AgentInstaller.installBytebuddyAgent(instrumentation);
    } finally {
      Thread.currentThread().setContextClassLoader(savedContextClassLoader);
    }
  }
```

### BytebuddyAgent

这里是字节码修改的部分，暂时不深究，无非就是插入一些代码。




