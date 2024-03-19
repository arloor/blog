---
title: "Arthas"
date: 2021-09-02T22:21:36+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
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

- [arthas idea](https://plugins.jetbrains.com/plugin/13581-arthas-idea)

## 官方文档

- [quick-start.html](https://arthas.aliyun.com/doc/quick-start.html)
- [命令列表](https://arthas.aliyun.com/doc/commands.html)

## 查看类的静态字段/静态方法

- [ognl.html](https://arthas.aliyun.com/doc/ognl.html#%E4%BD%BF%E7%94%A8%E5%8F%82%E8%80%83)

```shell
# 调用静态方法
$ ognl '@java.lang.System@out.println("hello")'
null
# 查看静态字段
$ ognl '@demo.MathGame@random'
@Random[
    serialVersionUID=@Long[3905348978240129619],
    seed=@AtomicLong[125451474443703],
    multiplier=@Long[25214903917],
    addend=@Long[11],
    mask=@Long[281474976710655],
    DOUBLE_UNIT=@Double[1.1102230246251565E-16],
    BadBound=@String[bound must be positive],
    BadRange=@String[bound must be greater than origin],
    BadSize=@String[size must be non-negative],
    seedUniquifier=@AtomicLong[-3282039941672302964],
    nextNextGaussian=@Double[0.0],
    haveNextNextGaussian=@Boolean[false],
    serialPersistentFields=@ObjectStreamField[][isEmpty=false;size=3],
    unsafe=@Unsafe[sun.misc.Unsafe@28ea5898],
    seedOffset=@Long[24],
]
```

`@demo.MathGame@random` 也可以用在watch中

## Java直接内存溢出的诊断

netty相关的直接内存溢出诊断很方便，没有用netty的直接内存溢出诊断可以用下面的方法：

```shell
options unsafe true
stack java.nio.ByteBuffer allocateDirect  -n 5
```

找到频繁申请直接内存的地方，就是可疑的点。之前遇到的一个case是Hbase的客户端申请的直接内存因为一直没有GC得不到回收，通过此方法找到了，当时对排查的人惊为天人。