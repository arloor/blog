---
title: "Async Profiler"
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

## linux使用

```bash
curl -LO http://cdn.arloor.com/async-profiler-2.9-linux-x64.tar.gz
tar -zxvf async-profiler-2.9-linux-x64.tar.gz
cd async-profiler-2.9-linux-x64
export PATH=$PATH:$PWD
profiler.sh  -e cpu -i 5ms -d 60 -f /a.html -o flamegraph  1
profiler.sh  -e alloc --alloc 500k -d 60 -f /b.html -o flamegraph  1
```

## macos使用

```bash
cd /data
curl -LO https://github.com/jvm-profiling-tools/async-profiler/releases/download/v2.9/async-profiler-2.9-macos.zip
unzip async-profiler-2.9-macos.zip
cd async-profiler-2.9-macos
export PATH=$PATH:$PWD
cd ~
profiler.sh -i 5ms -d 60 -f a.html -o flamegraph ${pid}
profiler.sh  -e alloc --alloc 500k -d 60 -f b.html -o flamegraph ${pid}
```