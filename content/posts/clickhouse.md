---
title: "Clickhouse文档学习"
date: 2020-08-14T14:37:51+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

ClickHouse是一个列式数据库管理系统，可用于联机分析（OLAP）。ClickHouse最常用的表引擎是MergeTree，下面主要围绕该种表引擎展开。
<!--more-->

## OLAP场景适合使用列式存储

### 列式存储的特点

- 同一列的数据存储在一起。
    - 局部性：。同一列的数据存储在一起，满足局部性，适合用于聚合操作。例如select sum(column) from table。
    - 同一列的数据是相同类型，可以选取适合的压缩算法，以得到较高的压缩率，从而减少磁盘的占用，以及内存缓存更多的数据。例如数值类型可以使用delta-of-delta压缩。
- 压缩意味着数据以块的形式存储。
    - 仅适合增加数据，更新不能原地更新，只能追加变更记录。
    - 适合使用LSM的数据结构

### OLAP的特点

- 绝大多数是读请求
- 数据以相当大的批次(> 1000行)更新，而不是单行更新;或者根本没有更新。
- 已添加到数据库的数据不能修改。
- 对于读取，从数据库中提取相当多的行，但只提取列的一小部分。
- 宽表，即每个表包含着大量的列
- 查询相对较少(通常每台服务器每秒查询数百次或更少)
- 对于简单查询，允许延迟大约50毫秒
- 列中的数据相对较小：数字和短字符串(例如，每个URL 60个字节)
- 处理单个查询时需要高吞吐量(每台服务器每秒可达数十亿行)
- 事务不是必须的
- 对数据一致性要求低
- 每个查询有一个大表。除了他以外，其他的都很小。
- 查询结果明显小于源数据。换句话说，数据经过过滤或聚合，因此结果适合于单个服务器的RAM中

## MergeTree

> 新数据插入到表中时，这些数据会存储为按**主键排序**的新**片段**（块）。插入后 10-15 分钟，同一分区的各个片段会**合并**为一整个片段。

- 以块的形式存储
- 主键有序
- 合并

### LSM Tree

MergeTree类似于LSM（Log-Structured-Merge-Tree）。

> 以下引用自[LSM树详解](https://zhuanlan.zhihu.com/p/181498475)

LSM树的核心特点是利用顺序写来提高写性能，但因为分层(此处分层是指的分为内存和文件两部分)的设计会稍微降低读性能，但是通过牺牲小部分读性能换来高性能写，使得LSM树成为非常流行的存储结构。

![](/img/LSM-tree.png)

如上图所示，LSM树有以下三个重要组成部分：

**1) MemTable**

MemTable是在内存中的数据结构，用于保存最近更新的数据，会按照Key有序地组织这些数据，LSM树对于具体如何组织有序地组织数据并没有明确的数据结构定义，例如Hbase使跳跃表来保证内存中key的有序。

因为数据暂时保存在内存中，内存并不是可靠存储，如果断电会丢失数据，因此通常会通过WAL(Write-ahead logging，预写式日志)的方式来保证数据的可靠性。

**2) Immutable MemTable**

当 MemTable达到一定大小后，会转化成Immutable MemTable。Immutable MemTable是将转MemTable变为SSTable的一种中间状态。写操作由新的MemTable处理，在转存过程中不阻塞数据更新操作。

**3) SSTable(Sorted String Table)**

![](/img/SSTable.png)

有序键值对集合，是LSM树组在磁盘中的数据结构。为了加快SSTable的读取，可以通过建立key的索引以及布隆过滤器来加快key的查找。

这里需要关注一个重点，LSM树(Log-Structured-Merge-Tree)正如它的名字一样，LSM树会将所有的数据插入、修改、删除等操作记录(注意是操作记录)保存在内存之中，当此类操作达到一定的数据量后，再批量地顺序写入到磁盘当中。这与B+树不同，B+树数据的更新会直接在原数据所在处修改对应的值，但是LSM数的数据更新是日志式的，当一条数据更新是直接append一条更新记录完成的。这样设计的目的就是为了顺序写，不断地将Immutable MemTable flush到持久化存储即可，而不用去修改之前的SSTable中的key，保证了顺序写。

因此当MemTable达到一定大小flush到持久化存储变成SSTable后，在不同的SSTable中，可能存在相同Key的记录，当然最新的那条记录才是准确的。这样设计的虽然大大提高了写性能，但同时也会带来一些问题：

>    1）冗余存储，对于某个key，实际上除了最新的那条记录外，其他的记录都是冗余无用的，但是仍然占用了存储空间。因此需要进行Compact操作(合并多个SSTable)来清除冗余的记录。     
 >   2）读取时需要从最新的倒着查询，直到找到某个key的记录。最坏情况需要查询完所有的SSTable，这里可以通过前面提到的索引/布隆过滤器来优化查找速度。

### MergeTree详解


 

 ## 向量引擎

 通过SIMD(Single Instruction Multiple Data)加速操作，ClickHouse使用SSE 4.2指令集。关于SIMD可见[向量化并行（vectorization）](https://zhuanlan.zhihu.com/p/337756824)