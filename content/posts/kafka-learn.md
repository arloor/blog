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

文档搬运工，先看文档。用自己的语言把文档里的话重新组织，如有错漏，纯属我菜。

目标：看完[DESIGN](https://kafka.apache.org/documentation/#design)、[IMPLEMENTATION](https://kafka.apache.org/documentation/#implementation)、[OPERATIONS](https://kafka.apache.org/documentation/#operations)
<!--more-->

分片、拷贝 很多东西都是这样的，比如redis cluster、es、hbase。

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

为了解决太多bytes copying，producer、broker、consumer使用一样的二进制格式，避免在中间进行消息解码，从而利用操作系统在socket和pageCache之间直接双向传输的系统调用，在linux中，使用sendfile(socket,file,len)。(这一段就是说要使用0拷贝技术，下面将啥是0拷贝)

通常读文件，并写到socket有四次拷贝，两次系统调用：

1. The operating system reads data from the disk into pagecache in kernel space
2. The application reads the data from kernel space into a user-space buffer
3. The application writes the data back into kernel space into a socket buffer
4. The operating system copies the data from the socket buffer to the NIC buffer where it is sent over the network

使用0拷贝技术，则能变成：

1. The operating system reads data from the disk into pagecache in kernel space
2. 通过DMA模块直接将pagecache写到NIC buffer

这样就减少了bytes copying。

### 压缩

kakfa提供批量压缩的功能，将一组消息进行一次压缩，而不是将每个消息进行一次压缩——相同字符更多意味着更高的压缩率。kafka支持：GZIP, Snappy, LZ4 and ZStandard


## Producer

...



> TBD.





