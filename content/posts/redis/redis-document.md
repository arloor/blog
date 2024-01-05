---
title: "Redis文档摘要"
date: 2019-08-20T20:00:39+08:00
draft: false
categories: [ "redis"]
tags: ["redis"]
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

```bash
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

```bash
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

```bash
SET key exclusive_random_value NX PX 30000
```

- NX——只有该key不存在时才会设置
- PX 30000——30秒的超时时间
- exclusive_random_value——每个客户端都有不同的随机值。用于安全地释放锁，在释放前可以检查这个值确认锁是否有自己持有。

> Redlock算法

在Redis的分布式环境中，我们假设有N个Redis master。这些节点完全互相独立，不存在主从复制或者其他集群协调机制。我们确保将在N个实例上使用与在Redis单实例下相同方法获取和释放锁。现在我们假设有5个Redis master节点，同时我们需要在5台服务器上面运行这些Redis实例，这样保证他们不会同时都宕掉。

为了取到锁，客户端应该执行以下操作:

1. 获取当前Unix时间，以毫秒为单位。

2. 依次尝试从5个实例，使用相同的key和具有唯一性的value（例如UUID）获取锁。当向Redis请求获取锁时，客户端应该设置一个网络连接和响应超时时间，这个超时时间应该小于锁的失效时间。例如你的锁自动失效时间为10秒，则超时时间应该在5-50毫秒之间。这样可以避免服务器端Redis已经挂掉的情况下，客户端还在死死地等待响应结果。如果服务器端没有在规定时间内响应，客户端应该尽快尝试去另外一个Redis实例请求获取锁。

3. 客户端使用当前时间减去开始获取锁时间（步骤1记录的时间）就得到获取锁使用的时间。当且仅当从大多数（N/2+1，这里是3个节点）的Redis节点都取到锁，并且使用的时间小于锁失效时间时，锁才算获取成功。

4. 如果取到了锁，key的真正有效时间等于有效时间减去获取锁所使用的时间（步骤3计算的结果）。

5. 如果因为某些原因，获取锁失败（没有在至少N/2+1个Redis实例取到锁或者取锁时间已经超过了有效时间），客户端应该在所有的Redis实例上进行解锁（即便某些Redis实例根本就没有加锁成功，防止某些节点获取到锁但是客户端没有得到响应而导致接下来的一段时间不能被重新获取锁）。

> java使用Redlock

```
<dependency>
 <groupId>org.redisson</groupId>
 <artifactId>redisson</artifactId>
 <version>3.3.2</version>
</dependency>
```

```
Config config = new Config();
config.useSentinelServers().addSentinelAddress("127.0.0.1:6369","127.0.0.1:6379", "127.0.0.1:6389")
   .setMasterName("masterName")
   .setPassword("password").setDatabase(0);
RedissonClient redissonClient = Redisson.create(config);
// 还可以getFairLock(), getReadWriteLock()
RLock redLock = redissonClient.getLock("REDLOCK_KEY");
boolean isLock;
try {
   isLock = redLock.tryLock();
   // 500ms拿不到锁, 就认为获取锁失败。10000ms即10s是锁失效时间。
   isLock = redLock.tryLock(500, 10000, TimeUnit.MILLISECONDS);
   if (isLock) {
     //TODO if get lock success, do something;
   }
} catch (Exception e) {
} finally {
 // 无论如何, 最后都要解锁
 redLock.unlock();
}
```


## Redis持久化

redis提供两种持久化方式：RDB和AOF

- RDB以一定的时间间隔提供redis数据集的实时快照
- AOF则记录redis的每一次写操作。在redis重启时，会重新执行这些操作。这些操作以redis网络通信协议的格式记录。采用追加写的方式。如果AOF文件太大，redis可以在后台重写这些日志（啥叫rewrite？）
- 如果愿意，可以完全禁用数据持久化，如果没有持久化的需求
- RDB和AOF能够同时存在，当两者都存在时，会使用AOF进行恢复，因为AOF会更加完整

### RDB的优势

- RDB以一个紧凑的单一文件备份redis的实时数据。RDB文件非常适合备份。比如你希望每个小时备份一下RDB文件，从而存储不同版本的数据以应对可能出现的灾难
- RDB很适合用于灾难恢复，因为单一的紧凑的文件很容易迁移到另一个较远的数据中心
- RDB最大化了redis的性能，因为redis父进程仅需要fork一个子进程去完成剩余的工作，而不需要处理IO等会产生阻塞的事件。
- RDB恢复的启动时间小于AOF恢复

### RDB的劣势

- RDB会丢失部分数据，因为他是定时地进行备份。如果Redis没有经历正常的关闭过程（断电等），则会丢失上一次RDB到异常关闭这段时间的写。
- RDB需要fork子进程来进行持久化。如果数据集太大，fork系统调用可能消耗较多时间，甚至导致redis暂停服务（ n ms-1s）。AOF也需要fork，但是你可以在不影响持久性的前提下控制多久重写一次日志

### AOF的优势

- 使用AOF的话，redis具有更高的持久性。你可以选择不同的fsync（将磁盘写缓冲区的数据冲刷到磁盘-真正写到磁盘）策略：不做fsync，每秒做一次fsync，每次查询做一次fsync。在默认策略-每秒执行一次fsync时，性能仍然很客观，而只会丢失一秒的写。
- AOF是一个尾部追加写的文件，不会做任何的seek操作（定位到文件的中间位置再进行写）。所以即使发生断电，也不会造成AOF文件的污染。如果断电时仅仅成功地写了一半的命令，也可以通过redis-check-aof工具进行修正。
- redis可以在后台重写AOF当日志文件变得很大。重写是完全安全的。当新日志文件创建并准备就绪后，新的追加会立即切换到新日志文件。
- AOF记录了写的操作顺序。如果想要撤销某个操作例如flushall，仅需要删除AOF文件中的flushalll的命令，并重启redis即可。

### AOF的劣势

- AOF文件通常会比同数据集的RDB文件大
- AOF在特定的fsync策略下会影响性能。总体来说，在每秒一次fsync时，性能仍然很高；当关闭fsync时，会和RDB有差不多一样的性能。另外在高负载时，RDB的最大延迟比AOF低。
- AOF曾经有一些bug。【技术人真严谨，讲了好几条



