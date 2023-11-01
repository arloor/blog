---
title: "Arthas"
date: 2021-09-02T22:21:36+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

arthas用来动态调试很好用
<!--more-->

## 安装arthas

```bash
curl -O https://arthas.aliyun.com/arthas-boot.jar
java -jar arthas-boot.jar #--repo-mirror aliyun --use-http
```

## 安装idea插件

[arthas idea](https://plugins.jetbrains.com/plugin/13581-arthas-idea)

## 官方文档

[quick-start.html](https://arthas.aliyun.com/doc/quick-start.html)

## Java直接内存溢出的诊断

netty相关的直接内存溢出诊断很方便，没有用netty的直接内存溢出诊断可以用下面的方法：

```shell
options unsafe true
stack java.nio.ByteBuffer allocateDirect  -n 5
```

找到频繁申请直接内存的地方，就是可以的点。之前遇到的一个case是Hbase的客户端申请的直接内存因为一直没有GC得不到回收，通过此方法找到了，当时对排查的人惊为天人。