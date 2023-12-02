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

## linux使用

```bash
curl -LO http://cdn.arloor.com/async-profiler-2.9-linux-x64.tar.gz
tar -zxvf async-profiler-2.9-linux-x64.tar.gz
cd async-profiler-2.9-linux-x64
export PATH=$PATH:$PWD
# CPU profiling
profiler.sh -e cpu -i 5ms -d 60 -f /a.html -o flamegraph  1
# ALLOCATION profiling
profiler.sh -e alloc --alloc 500k -d 60 -f /b.html -o flamegraph  1

# multi event, with jfr as output format
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

### 火焰图

![Alt text](/img/async-profiler-alloc-flamescope.png)

### jfr文件可视化

