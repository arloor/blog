---
title: "Async Profiler使用"
date: 2023-12-02T16:31:58+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

Async Profile是Java应用profiling的强大工具，可以方便地输出火焰图html或者jfr格式给Java Mission Control查看，这里记录下如何使用。
<!--more-->

开源地址：[Async-Profiler Github](https://github.com/async-profiler/async-profiler)

## linux使用

注意，linux中的pid我填的是1，因为我的应用跑在docker容器中，默认进程号就是1

```bash
curl -LO http://cdn.arloor.com/async-profiler-2.9-linux-x64.tar.gz
tar -zxvf async-profiler-2.9-linux-x64.tar.gz
cd async-profiler-2.9-linux-x64
export PATH=$PATH:$PWD
# CPU profiling
profiler.sh -e cpu -i 5ms -d 60 -f /a.html -o flamegraph  1
# ALLOCATION profiling
profiler.sh -e alloc --alloc 500k -d 60 -f /b.html -o flamegraph  1
# multi event, with jfr as output format, use IDEA/JMC to view
profiler.sh -e cpu,alloc --alloc 500k -i 5ms -d 60 -f /a.jfr -o jfr  1
```

## macos使用

```bash
cd /data
curl -LO https://github.com/jvm-profiling-tools/async-profiler/releases/download/v2.9/async-profiler-2.9-macos.zip
unzip async-profiler-2.9-macos.zip
cd async-profiler-2.9-macos
export PATH=$PATH:$PWD
cd ~
# CPU profiling
profiler.sh -e cpu-i 5ms -d 60 -f a.html -o flamegraph ${pid}
# ALLOCATION profiling
profiler.sh -e alloc --alloc 500k -d 60 -f b.html -o flamegraph ${pid}
```

## Wall-clock profiling：观测Spring应用启动耗时

参考: [#wall-clock-profiling](https://github.com/async-profiler/async-profiler#wall-clock-profiling)

在线服务通常使用 Spring Boot 作为基本框架，Spring Boot 会打印一条 “JVM running for” 的日志，表示进程启动使用了多长时间，那么在这个时长中，到底耗时在哪里，可以用下面的命令查看，注意要在应用一启动就运行。

```bash
# 250 指的是持续观测 250秒，可以根据服务实际启动时长修改，1 指的是进程号⁢
./profiler.sh -e wall -t -I 'org/springframework/boot/loader/JarLauncher.main' -f a.html -d 250 1
```

> 我们往往会使用 Async Profiler 工具 Attach 到 JVM 来诊断 CPU利用率问题，采样堆栈并生成火焰图，这类火焰图只会记录 on-CPU 状态的线程，即 R 和 D 状态的线程。但进程启动时可能有很多等待 IO 或锁的操作，此时线程已让出CPU，所以应该改用时钟模式（Wall-Clock）采样 on-CPU 和 off-CPU 的堆栈。此外 Spring 初始化时会创建一些中间件客户端并关联生成一些线程，为了避免无关堆栈的干扰，应该只保留 Spring Boot 启动的 main 线程

## 可视化

### 浏览器打开火焰图的html

![Alt text](/img/async-profiler-alloc-flamescope.png)

### jfr文件可视化

**使用Jetbrians IDEA查看**

![Alt text](/img/jfr-idea-view.png)


**使用Java Mission Control查看**

![Alt text](/img/jfr-JMC-view.png)

注意，高版本的JDK不再默认安装JMC，参考下面的文档安装

- [JMC下载](https://www.oracle.com/java/technologies/javase/products-jmc8-downloads.html)
- [JMC安装](https://www.oracle.com/java/technologies/javase/jmc8-install.html)

