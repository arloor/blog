---
title: "K8s"
date: 2021-04-19T20:17:09+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

new post with no content


![](/img/components-of-kubernetes.svg)

- 控制面
- nodes 

## 控制面

关于集群的全局决策，例如调度。一键搭建脚本通常将控制面的组件放在一台机器上

### Kube-apiserver

是k8s的控制面的前端，暴露k8s的api

可水平扩展，部署多台kube-apiserver来负载均衡

### etcd

k8s数据存储

### kube-scheduler

监视没有分配node的pod，并且为其分配node

### kube-controller-manager

运行controller进程的组件

逻辑上，不同的控制其是不同的进程，但是为了降低复杂度，他们被组合进一个可执行文件，并在但进程运行

## Node

维护运行的pods，提供k8s运行时

### kubelet

运行在每个node上的agent，保证容器运行在一个pod中

kubelet使用PodSpecs来运行容器，并保证他们健康

### kube-proxy

控制网络传输，使用操作系统包过滤层或者自己进行流量转发

### 容器运行时

docker、containerd 负责运行容器的软件

## DNS

集群需要DNS





