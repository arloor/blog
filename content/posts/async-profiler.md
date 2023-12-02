---
title: "Async Profiler使用"
date: 2023-12-02T16:31:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
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

