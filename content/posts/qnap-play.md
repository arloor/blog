---
title: "威联通NAS折腾"
date: 2022-09-17T14:55:19+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

入手了一台威联通T564，当作给自己的奖励。
<!--more-->

## 容器

1. 在appcentor安装Container Station
2. 搜索centos8-stream的LXD镜像，并创建容器
3. 修改容器的网络为Bridge，这样就和局域网里其他的机器网络共通了
4. 开启nas的ssh功能
5. ssh到nas上，执行`lxc exec ${容器名} -- /bin/bash`

lxd的容器完全可以当成富容器来用，除了不能ssh，也是有systemd的，可以运行daemon程序，这点很重要。
