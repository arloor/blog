---
title: "使用Redis异步拷贝实现异地数据中心同步"
date: 2019-09-03T23:44:09+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

为实现redis异地数据中心实时同步功能，有两种方案，其中一种方案是利用redis主从节点的异步拷贝，伪装一个slave节点，获取主节点的异步拷贝信息。将该异步拷贝信息同步到异地数据中心，从而实现redis集群异地同步。虽然redis文档有介绍主从以及异步拷贝，但是其实现并没有详细介绍，因此我阅读了redis中的`cluster.c`、`replicate.c`（redis版本为4.0.1），探查其实现的细节，并使用netcat软件进行了一些实验。最终结论是：实验结果反映“伪装slave获取异步拷贝”方案是可行的，并且复杂度可接受。
<!--more-->

## 为什么可行？（复杂度为什么可接受）

**1.redis集群和master-slave 依赖 异步拷贝机制，而不是反过来的那样**

 —— 实现slave的异步拷贝不需要处理redis集群的协议。复杂度比预期的低很多。

**2. 我们仅需要实现“异步拷贝”，而不需要实现slave其他的功能，例如选举、failover**

 —— 我们的方案一直被称之为“伪slave”，我们也一直觉得需要实现一个完整的slave。其实不需要，我们仅需要实现“异步拷贝”，异步拷贝不依赖slave的其他功能。

以上两点是在阅读源码、进行实验后确定的，恰恰证明了大幅度提升复杂度的细节我们都不需要处理，也证明了该方案的可行性。
 
关于可行性，“实验”章节展示了获取异步拷贝的正常流程，很直观。看完该实验，相信大家能认可该方案的可行性。

## 异步拷贝机制简介

redis使用主从异步拷贝机制实现较高的可用性。其宏观流程如下：

1. 客户端向mater节点写
2. 主节点通知客户端写成功（+OK）
3. 主节点向slave节点推送该写请求

所谓异步拷贝就是不等待slave成功拷贝，即向客户端发送成功响应。其中的问题是拷贝可能会有部分写丢失，当slave被选举为master时，这一部分丢失就导致了不一致。采取异步拷贝的设计是redis架构设计中性能与可用性的权衡。

异步拷贝机制是master-slave机制重要的一部分。redis的高可用方案：哨兵和redis cluster都是基于master-slave的异步拷贝。在单主节点+从节点的中，可以使用`SLAVEOF IP PORT`命令宣称自己是某节点的从节点，从而接收异步拷贝信息。在redis cluster中，需要使用`CLUSTER REPLICATE nodeID`来实现相同的功能。两者不能混用，但有做相同的事（获取目标主节点的ip和端口）。

从微观流程看，异步拷贝会在第一次拷贝时传播rdb文件，进行一次全量同步，之后通过`offset`偏移量这个变量进行增量同步。`replicID`和`offset`一起确定增量同步的起点，每收到一个字节，`offset`增加一。其整体工作原理如下（从SLAVE的视角看）：

1. 调用SLAVEOF或CLUSTER REPLICATE命令，获取master的ip、port
2. redis的定时任务创建到master的tcp连接（在发现没有有效连接的情况下）
3. 通过该tcp连接发送`PING AUTH REPLCONF`等指令，完成与master的握手
4. 如果是第一次拿拷贝，没有`replicID`和`offset`，转到5。如果不是第一次拿拷贝，则转到6
5. 发送`PSYNC ? -1`，接收master的rdb格式的全量同步数据、`replicID`和`offset`，转到7
6. 发送`PSYNC replicID offset`，收到`+CONTINUE nodeID`，表示主节点继续“增量”地发送异步拷贝信息 ，转到7
7. 主节点会不断发送自己收到的写请求的tcp报文，从节点执行这些写请求，并增加offset。直到该tcp连接异常断开，转到2（定时任务创建新的连接）

## 源码解析

以上微观流程就是从redis源码中总结出来的。我是从`CLUSTER REPLICATE <NODE ID>`指令的实现找到redis源码的打开口的。

`CLUSTER REPLICATE nodeID`指定自己拷贝nodeID所指的主节点（也就是成为他的从节点）。其实现在`cluster.c`。其关键步骤为调用`clusterSetMaster(n);`这获取了主节点的ip和port，这将在之后的异步拷贝中使用到。

另外一方面，`serverCron`函数每秒钟被执行一次，其中有`replicationCron();`

`replicationCron`会通过`connectWithMaster`连接上主节点的ip和port。连接成功的回调事件是：`syncWithMaster`。

`syncWithMaster`会发送握手所需的`PING`、`AUTH <passwd>`(可选)、`REPLCONF listening-port <port>`、`REPLCONF ip-address <ip>`(可选)、`REPLCONF capa eof capa psync2`。以上即完成握手环节，下面开始真正的同步。

同步分为`PSYNC ? -1`和`PSYNC replicID offset`，其实现在`slaveTryDResynchronization`函数中。该函数会根据有没有`replicID`决定是传输rdb进行全量同步，还是利用`offset`进行增量同步。

redis源码挺好读的，并且有丰富的注释。在这里没有贴详细的代码，相信按照这个顺序去读`replicate.c`的代码，大家都能清楚地理解slave获取异步拷贝的流程，代码不会骗人的。

## 实验——也是将来的实现

代码不会骗人，所以我按照阅读源码后总结出的步骤，使用`nc`向redis主节点发送相关命令，从而获取异步拷贝。

### 模拟第一次全量同步

执行`nc ip port`后，依次输入：

1. PING
2. REPLCONF listening-port 8888
3. REPLCONF capa eof capa psync2
4. PSYNC ? -1

控制台输出（redis的响应）如下：

```
$nc  redis-ip redis-port
PING
+PONG
REPLCONF listening-port 8888
+OK
REPLCONF capa eof capa psync2
+OK
PSYNC ? -1
+FULLRESYNC b8e7eba438f7ee357d2f0978a9ed307ef250e1fd 3638988293
$272
REDIS0008▒      redis-ver4.0.1▒
redis-bits▒@▒ctime▒zDn]used-mem▒▒▒,▒repl-stream-db▒▒▒
aof-preamble▒▒repl-id(b8e7eba438f7ee357d2f0978a9ed307ef250e1fd▒
                                                               repl-offset
3638988293▒▒▒
{a}aaaaaaaaaaaaaa▒{{a}aaa▒}aaaaaa
aaaaa▒*1        {a}a▒
$4
PING
*1
$4
PING
*1
$4
PING

```

我们通过该实验模拟第一次获取异步拷贝的情况，即上一节我们提到的流程3->5->7。

我们执行`PSYNC ? -1`，返回`+FULLRESYNC replicID offset`——第一次不知道replicID和offset；返回全量同步标志、replicID和offset。

`$272`表示rdb全量同步一共有272字节——这是一个基于长度的tcp流分割方案

在输出的最后我们看到好几个PING，这是redis集群其他节点发送过来的请求，被主节点异步地发送给我们实验的这个伪slave。


### 模拟以后的增量同步

执行`nc ip port`后，依次输入：

1. PING
2. REPLCONF listening-port 8888
3. REPLCONF capa eof capa psync2
4. PSYNC b8e7f...e1fd 3638988293

控制台输出（redis的响应）如下：

```
$nc 99.47.149.27 6428
PING
+PONG
REPLCONF listening-port 8888
+OK
REPLCONF capa eof capa psync2
+OK
PSYNC b8e7eba438f7ee357d2f0978a9ed307ef250e1fd 3638988293
+CONTINUE b8e7eba438f7ee357d2f0978a9ed307ef250e1fd

*1
$4
PING
*1
$4
PING
*2
$6
SELECT
$1
0
*3
$3
set
$7
{a}test
$3
vvv

```

这次实验，replicID和offset都为有效值，表示一次从offset开始的增量同步。

`+CONTINUE replicateID`表示继续这个replicate的同步，而不是一次全新的同步。

后面这个tcp连接就收到master转发的来自cluster其他节点的PING命令的拷贝。之后的SLECT、set是我手动set时出现的异步拷贝。

以上实验，是在阅读redis4.0.1源码中replicate.c，确定其tcp协议细节后进行的，覆盖了简单的正常流程，当然还有一些细节并没有覆盖。在真正实现“利用异步拷贝实现redis异地数据中心同步”中，需要通过代码实现以上网络通信。
