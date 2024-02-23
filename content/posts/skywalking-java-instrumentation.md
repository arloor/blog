---
title: "Skywalking Java 自动埋点实现"
date: 2022-10-11T11:47:02+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

看过skywalking的oap后端代码，也看过otel的自动埋点实现，今天看下skywalking-java的java-agent实现。

## 如何编译

```bash
git checkout ce1f8c0c2
mvn -DskipTests clean package -Pall
```

## Premain Class

skywalking不支持动态attach加载agent的方式，只支持premain的方式。我们先看premain class： `SkyWalkingAgent`。
