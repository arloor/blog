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

```
sudo -iu sankuai
export http_proxy="http://11.39.114.32:3128"
export https_proxy="http://11.39.114.32:3128"
cd ~
mkdir arthas;cd arthas;wget "https://arthas.aliyun.com/download/latest_version?mirror=aliyun" -O arthas-packaging-3.5.3-bin.zip;unzip -o arthas-packaging-3.5.3-bin.zip;cd ..

java -jar ~/arthas/arthas-boot.jar
```

## 安装idea插件

[arthas idea](https://plugins.jetbrains.com/plugin/13581-arthas-idea)

## 官方文档

[quick-start.html](https://arthas.aliyun.com/doc/quick-start.html)