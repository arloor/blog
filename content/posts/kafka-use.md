---
title: "Kafka Use"
date: 2020-02-27T22:57:05+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

记录下kafka怎么用....
<!--more-->

## 安装

```
#设置http代理环境变量
#. pass
wget -O kafka_2.12-2.4.0.tgz https://downloads.apache.org/kafka/2.4.0/kafka_2.12-2.4.0.tgz
tar -xzf kafka_2.12-2.4.0.tgz
cd kafka_2.12-2.4.0
vim config/server.properties
#内网ip
#listeners=PLAINTEXT://192.168.0.115:9092
#外网ip
#advertised.listeners=PLAINTEXT://121.36.xx.xx:9092
#启动zookeeper
(bin/zookeeper-server-start.sh config/zookeeper.properties &)
#启动kafka
(bin/kafka-server-start.sh config/server.properties &)
# 创建topic
bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic test
# 查看相关进程
jps -l
#11040 org.apache.zookeeper.server.quorum.QuorumPeerMain
#11042 kafka.Kafka
```

## demo

没错，我就是kafa都需要demo的人

[丑陋的demo](https://github.com/arloor/kafka-demo)