---
title: "Opentelemetry Java自动埋点实现"
date: 2022-06-22T11:11:07+08:00
draft: false
categories: [ "undefined"]
tags: ["可观测性"]
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

还是先看注释：这个类被OpenTelemetryAgent调用，因此由bootstrapClassLoader加载，因此可以畅通地使用agent的其他类（同样被bootstrapClassLoader加载）

## 未完待续...

