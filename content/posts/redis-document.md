---
title: "Redis文档摘要"
date: 2019-08-20T20:00:39+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

看了看redis的文档，觉得有些东西写的挺好的，就挑觉得有意义的记录一下。
<!--more-->

## pipelining—流水线

Redis使用TCP协议，网络通信需要包从客户端传递到服务器端，再从服务器端传回客户端，这段网络传输的时间被称为RTT(Round Trip Time)。RTT可以很短，比如在本地回环网卡（127.0.0.1）上传输，也可以很长，比如在中国和美国之间传输。

当RTT很长时，即使redis本身可以承受每秒数以万计的请求，但是实际上大量的时间消耗在RTT上，比如250ms的RTT，则每秒单TCP连接上最多处理4个请求（可以通过增加TCP连接数并将请求负载均衡到不同的TCP连接上增加实际能处理的请求数，但还是效率太低）。即使使用本地回环网卡，RTT仅需要约0.05ms，当写的数量十分大时，RTT的时间消耗仍然很大。

从这里就可以看到，RTT成为影响redis性能的重要因素（RTT同样影响其他网络程序）。Redis采用Pipelining的技术来减少RTT的影响。用一句话总结Pipelining就是“一次性讲很多句话”。如下所示：

```shell
#原来的redis请求-响应
Client: INCR X
Server: 1
Client: INCR X
Server: 2
Client: INCR X
Server: 3
Client: INCR X
Server: 4

#使用pipelining后的请求-响应
Client: INCR X  INCR X  INCR X  INCR X
Server: 1 2 3 4

# 【实例】使用nc向redis服务器一次性发送多个PING命令
# (printf "PING\r\nPING\r\nPING\r\n"; sleep 1) | nc 99.47.149.26 6433
+PONG
+PONG
+PONG

```
客户端一次性向服务器发送多个命令而不等待他们的响应，在最后一次读取所有的响应，这是在几十年前就产生的技术。

当使用pipeling时，redis会将响应暂存在内存中，等待所有的响应就绪再一次性地发送出去，这会占用内存。所以Pipelining一次执行的命令也不能太多，redis文档举例说10k个命令将是一个合理的数字。嗯，这个数字我觉得还是很大的。

上文我们由RTT引出Pipelining技术，实际上“一次讲很多话”解决的不仅仅是RTT带来的影响。网络传输涉及到系统调用`write()`和`read()`，需要在内核态与用户态之间转换，这涉及到上下文保存/切换等等，会消耗一定的时间。采用Pipelining可以减少这些系统调用，从而进一步节省时间。很多命令的bytes可以通过一次`read()`读取，而大量命令的响应可以通过一个`write()`写回。（这里说的很合理，很精细，很雅致。但是知道就好，自己写业务代码的时候如果想优化到这个地步，那得累死人，即使要有优化的意识）。在redis文档中，作者放出了一个图，使用Pipelining，最多可以获得10倍于不使用Pipelining的qps。

## 发布订阅系统

Redis is a fast and stable Publish/Subscribe messaging system!——很自信，所以我信了。

发布订阅系统不是senders 负责将消息发送给subscribers，而是将消息发送给Channel，senders 并不需要有哪些subscribers。同样，subscribers表示对某些Channel感兴趣，而不需要知道有哪些senders 。发送者和接受者的解耦让更大的可伸缩性和更弹性的网络拓扑成为可能。

一个Redis发布订阅的实例：

```shell
redis-cli -h 99.47.149.27 -p 6428
99.47.149.27:6428> subscribe one two
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "one"
3) (integer) 1
1) "subscribe"
2) "two"
3) (integer) 2
## 此时另一个redis-cli发送“publish one aaaaaaaaaaaa ”
1) "message"
2) "one"
3) "aaaaaaaaaaaa"
## 此时另一个redis-cli发送“publish two bbbbbbbbbbb”
1) "message"
2) "two"
3) "bbbbbbbbbbb"
```
redis大概是最易用的发布订阅系统了吧。关于其他使用redis发布订阅的细节，自己谷歌吧。

## 分布式锁

分布式锁——控制多个进程对一个资源的互斥访问。

redis文档提出了一个算法叫Redlock，他们认为比一般的实现更加安全，也希望社区能分析该算法，并提供反馈，同时以他为起点，实现更复杂的设计。[文档]([https://redis.io/topics/distlock](https://redis.io/topics/distlock)
)提及了各种语言对Redlock的实现。

分布式锁需要保证三个属性：

- 安全保证：互斥性——在同一时间只能有一个客户端持有锁
- 活跃度保证A：免于死锁——事实上很容易出现这种情况：持有锁的客户端宕机或发生分区，其他客户端仍在请求锁
- 活跃度保证B: 容错性——只要大部分节点正常运行，客户端就能正常获取和释放锁

> 基于Redis集群失效转移机制的分布式锁是不可靠的：

最简单的redis分布式锁实现是这样的——创建一个会超时删除的key，释放锁就删除该key。因为超时的特性，即使持有锁的客户端宕机，最终该锁还是会被释放。这样的问题是：会存在单点失效——redis节点宕机那么锁就不存在了。最自然的想法是创建redis集群，给主节点增加从节点，从节点去提供备用服务。但是这不能保证互斥性——因为redis集群的主从节点是异步拷贝的——主从之间的拷贝因为缺少确认机制导致拷贝可能会丢失部分写（这在[Redis集群扩容迁移](/posts/redis-slot-transpot/)也提到了）。这就导致下面的情况会发生：

1. Client A acquires the lock in the master.
2. The master crashes before the write to the key is transmitted to the slave.
3. The slave gets promoted to master.
4. Client B acquires the lock to the same resource A already holds a lock for. **SAFETY VIOLATION!**

这种实现适合当故障发生时，允许多个客户端持有锁的情况。但是更多情况下不推荐。

> 正确的单节点分布式锁：

使用以下命令获取锁：

```shell
SET key exclusive_random_value NX PX 30000
```

- NX——只有该key不存在时才会设置
- PX 30000——30秒的超时时间
- exclusive_random_value——每个客户端都有不同的随机值。用于安全地释放锁，在释放前可以检查这个值确认锁是否有自己持有。

> Redlock算法实现地锁
>
> To be continued..


