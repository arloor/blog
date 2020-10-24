---
title: "Kafka文档摘要"
date: 2020-10-17T11:35:15+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

**用自己的语言组织kafka文档，如有错漏，纯属我菜，造成损失，概不负责**

目标：看完[DESIGN](https://kafka.apache.org/documentation/#design)、[IMPLEMENTATION](https://kafka.apache.org/documentation/#implementation)、[OPERATIONS](https://kafka.apache.org/documentation/#operations)
<!--more-->

partition、replaction、failover 很多东西都是这样的，比如redis cluster、es、hbase。

## 持久化

### 不要害怕文件系统

kafka很依赖文件系统来存储和缓存消息。很多人有一个概念：硬盘很慢，然后大家就很怀疑，磁盘存储也能带来很高的性能。事实上，磁盘在某些用途下很慢，在某些用途上足够快了（并取决于怎么使用，例如顺序读写大于随机读写）。正确设计的磁盘存储结构可以和网络传输一样快（毕竟网络传输也有rtt的困扰）

磁盘性能很大取决于寻道时间（移动磁头到指定的此道的时间），因此一个7200转的机械硬盘（RAID-5阵列下）能提供600MB/s的顺序写速度，但只能提供100KB/s的随机写速度(差距6000倍以上)。

因为随机读写性能的低下，现代操作系统越来依赖内存作为磁盘的缓存。现代操作系统特别喜欢将所有空闲的内存作为磁盘缓存（当内存需要回收时，性能影响也不大）。因此所有的磁盘读写都会走一遍内存中的缓存。这个特性不容易关闭，除非直接进行direct I/O，所以即使进程在进程内保存一份数据，这些数据仍然会在操作系统控制的页缓存中保留一份，也就是保留了两份（他应该想说，只要用对磁盘，内存内缓存其实没必要）

另外kafka基于JVM，关于JVM使用有两点常识：

1. JVM存储一份data，会需要可能两倍data真实大小的空间
2. 当JVM的堆内存增加时，JVM的内存回收会给我们带来困扰。FullGC停顿几秒很难顶

基于以上，使用文件系统并依赖操作系统的pagecache优于在JVM进程内保存缓存。然后还有一些其他好处。。。
（这一段吹，就跟redis吹单线程一样。这些大佬咋就这么会呢）。总之就是依赖磁盘顺序读写和操作系统的pagecache，磁盘也能有很好的性能。

基于以上，有一种简单的设计思路：我们不需要在内存中保留尽可能多的缓存。而是所有的数据立即写到磁盘（不要强制flush到磁盘），这时会写到pagecache，我们使用这份数据时会用到pagecache。也就是在顺序读写下，操作系统帮我们做了缓存。——牛逼，顺序读写的场景下，我们不需要在内存中保留缓存，依赖文件系统就能很好的使用缓存。

## 效率

上一节消除了随机读写磁盘带来的效率问题，还有两种产生效率问题的原因：太多小的IO操作、太多bytes copying。

为了解决太多IO操作，kafka抽象出“message set”的概念，进行batch write和batch read，也就是一次行写多条消息，一次性读多条消息。另外一个好处是，减少网络传输rtt对qps、吞吐量的影响。

为了解决太多bytes copying，producer、broker、consumer使用一样的二进制格式，避免在中间进行消息解码，从而利用操作系统在socket和pageCache之间直接双向传输的系统调用，在linux中，使用sendfile(socket,file,len)。(这一段就是说要使用0拷贝技术)

通常读文件，并写到socket有四次拷贝，两次系统调用：

1. The operating system reads data from the disk into pagecache in kernel space
2. The application reads the data from kernel space into a user-space buffer
3. The application writes the data back into kernel space into a socket buffer
4. The operating system copies the data from the socket buffer to the NIC buffer where it is sent over the network

使用0拷贝技术，则能变成：

1. The operating system reads data from the disk into pagecache in kernel space
2. 通过DMA模块直接将pagecache写到NIC buffer

这样就减少了bytes copying。

参考文档：[深入剖析Linux IO原理和几种零拷贝机制的实现——含java实现](https://juejin.im/post/6844903949359644680)

### 压缩

kakfa提供批量压缩的功能，将一组消息进行一次压缩，而不是将每个消息进行一次压缩——相同字符更多意味着更高的压缩率。kafka支持：GZIP, Snappy, LZ4 and ZStandard


## Producer

### 负载均衡

producer直接向该partition的leader broker发送数据（中间没有任何路由层）。为了让producer能够直接找到对应的leader broker，所有的kafka节点都会回应对元数据的请求——想要知道哪些sever是活着的、当前分区的leader分别是谁。

插一句，rabbitMQ的架构中在producer和queue之前有个交换机的概念，exchange就是这里说的路由层

客户端控制自己将把消息发送给哪个partition。路由可以完全随机，也可以指定路由键控制相同的key发送到相同的分区，当然还可以override确定partition的方法。根据路由建指定分区能够很好地将逻辑上在一起的数据，控制在同一分区上，并且相应地由同一消费者消费。

### 异步发送

前面提到kafka通过batch操作，减少小的IO操作频率，减少rtt对吞吐量和qps的影响。kafka会在内存中积累多个消息，并且一次发送出去。producer可以设置成达到特定大小的buffer(64k)或固定的时间(10ms)进行一次batch send。


## Consumer

consumer的工作方式是向partition的leader发起“fetch”请求，指定开始的offset，从而拿到一大块数据。所以consumer控制着自己的消费，并且可以进行消息回溯（重新消费过去的数据）。相似的，redis cluster中slave同步master也是一样的，由消费者（slave）来发起“fetch”请求。

### 推和拉的模式

producer - broker - consumer

producer向broker发送消息时，使用的是push；consumer从broker获取数据使用的是pull——大多数消息系统都是这样。kafka称自己是pull-based，毕竟消费的部分才是重点。

推和拉都有优劣。推的模式下，下游很有可能被生产者压垮。拉的模式下，消费者可以控制消费速率，但是可能产生消息积压（很常见）。所以kakfa增加了一个broker，把所有问题都给broker来抗，简化producer和consumer这两个会出现在业务方代码里的东西。broker模式是一种常见的架构模式，通过borker可以增加可交互性（《软件架构》）

pull-based的另一个好处是拉的consumer可以控制batch。在push-based系统中，producer必须控制是立刻发送消息，还是积累到一定数量（却不知道这个数量会不会压垮下游）。

拉的方式不好的地方在于，如果broker没有数据，consumer还是会进行轮训(busy-waiting)。为了解决这个，consumer的fetch请求中会有参数控制，无数据时block到有数据到达，或者等到有足够多的bytes到达。

### consumer position

大多数消息系统在broker上保存关于consumer消费到哪里的元数据。也就是当broker交给consumer一份数据时，broker立刻记录或收到consumer的ack后记录。这种模式可能出现broker和consumer状态不一致的请款给，可能出现消息丢失或者重复消费。

kafka完全不一样。 我们的主题被分为多个有序的partition，每个partition固定地被消费组中的一个消费者消费。消费者自己确定当前的offset，不再需要broker和consumer之间同步消费的offset。

### 静态成员资格

kafka有rebalance-protocal：消费组协调者会将动态的id授予消费组的成员，当消费者重新启动时，会授予新的id——这导致消费会发生漂移（partition-consumer的对应关系变化）。如果不想发生消费漂移，则可以启用 static membership，加一个配置即可:

```
ConsumerConfig#GROUP_INSTANCE_ID_CONFIG
```

## 消息分发保证

基本上有三种消息分发保证：

- 最多一次（可能丢失） —Messages may be lost but are never redelivered.
- 最少一次（可能重复消费） —Messages are never lost but may be redelivered.
- 准确的一次 —this is what people actually want, each message is delivered once and only once.

这个保证可以分为两个问题：发的消息的持久化保证（produce后不会丢），保证会被消费（一定会consume）

kafka的保证是这样的，produce时，消息一旦被标记为“committed”，除非repicate leader的所有broker都挂了，该消息才会完全丢失。（这里涉及的replicate、failover下面会讲）。这又可能存在重复produce的问题：committed响应丢失了，于是producer再生产一条。

在0.11.0.0之后，kafka的producer增加了**幂等生产**和**跨分区原子写入**，并基于这两个功能，对kafka stream的read-process-write增加了**Exact-Once**支持。

**幂等生产**：producer可以修改配置，使重复produce变为幂等的（producer加id，消息增加序列号）。
**跨分区原子写入**：0.11.0.0之后，同样支持类似事物地将多个消息同时发送到多个partition，要么全部失败，要么全部成功，这用于确保准确地被“处理一次”。当然，producer可以控制是不是要等待committed，毕竟并不是所有场景都要求强持久化保证。

在Kafka stream中可以通过事务保证 准确地被消费一次。kafka stream可以认为是read-process-write：从一个topic消费数据，处理一下，再发送到另一个topic。在这个过程中的能被保证的“Exact-Once”是，我一定能准确地write一次到另一个topic——失败了我就退回consume的offset，直到成功一次。示例代码如下：

```
KafkaProducer producer = createKafkaProducer(
  "bootstrap.servers", "localhost:9092",
  "transactional.id", "my-transactional-id");

KafkaConsumer consumer = createKafkaConsumer(
  "bootstrap.servers", "localhost:9092",
  "group.id", "my-group-id",
  "isolation.level", "read_committed");

consumer.subscribe(singleton("inputTopic"));

producer.initTransactions();

while (true) {
  ConsumerRecords records = consumer.poll(Long.MAX_VALUE);
  // 开启事务
  producer.beginTransaction();
  for (ConsumerRecord record : records)
    producer.send(producerRecord(“outputTopic”, record));
  // 如果失败，退回consumer的offset，再试一次
  producer.sendOffsetsToTransaction(currentOffsets(consumer), group);  
  producer.commitTransaction();
}
```

## replication

分片是很多中间件为了高性能采取的措施，拷贝则是中间件为了可用性采取的措施。因为高可用，高性能基本上是中间件的基本需求，所以分片+拷贝这样的设计思路也很常见（比如redis）。拷贝这一设计是为了高可用，高可用最简单的一点就是，当master挂了的时候，slave能够顶上去，而有谁顶上去这件事又涉及到CAP中的另外两个要素，一致性和分区容错性。这一节其实就是围绕kafka分片的拷贝展开，然后介绍kafka如何解决一致性和分区容错性。

其他系统基于拷贝提供了一些额外功能，比如读写分离（master写，slave读），但是kakfa认为这些功能有一些坏处，所以拷贝仅仅是拷贝，不提供其他功能。

kafka以topic的分区为粒度进行repliacte，每个分区都有一个leader，以及0或多个follower。拷贝的总数（包含leader）被成为`replication factor`。大多数情况下，broker的数量远小于分区数——也就是一个broker可能承担多个partition的leader角色。

follower像consumer一样从leader消费数据（pull）(redis也是一样，由slave拉取master的拷贝)。

像很多分布式系统一样，kafka也要定义什么是“挂了”。在redis中，是“Subject Down”转变为“Object Down”，则认为机器挂了。在kafak中，node只有满足以下两点条件才被被认为存活：

1. 保持与kafka的会话，依赖于kafka的心跳机制——依赖zookeeper的很多中间件都会把这个作为一个条件（redis不依赖zookeeper，所以没这个）
2. 如果node是follower，则不能落后于leader太多。通过`replica.lag. time.max.ms`配置进行控制

kafka使用“in sync”来描述满足上述条件的node，而不是说“活着”。in sync是比较重要的一个概念，leader会在内存中保存in sync replications的信息（ISR）。如果一个follower不再满足上述两个条件，leader会将其从ISR中移除。

当所有的ISR都将一个消息追加到自己log的尾部时，kafka认为一个消息commited了（注意：仅仅是ISR中的node，不是全部follower）。而且只有committed的消息会被消费者消费。而且当leader挂掉时，只有ISR中的follower才会被提升为leader，所以消费者不用担心发生failover时原先有的消息丢失。而从生产者的视角看，可以设置是否等待committed的参数（取决于更看重持久化，还是延迟）。

kafka能保证一个committed的消息不会丢失，只要有至少一个ISR node活着。kafka在leader宕机后，经过故障迁移，仍然可以保证可用，但是不能保证分区容错性。kafka的拷贝是CA系统，不保证分区容错性。

### replicated Logs:合法票数，ISR，状态机

replicated log是leader和follower之间进行同步的依据，mysql的binlog，redis的resp协议格式的log。













> TBD.





