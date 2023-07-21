---
title: "Redis集群slot迁移"
date: 2019-08-10T14:01:47+08:00
draft: false
categories: [ "redis"]
tags: ["redis"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

本文记录了redis集群扩容时会发生的slot迁移过程，同时记录了在迁移过程中查询key集群会如何响应。在文章开头，附带了一些redis集群技术的简单介绍（大部分摘自redis官方文档），帮助了解迁移过程。
<!--more-->

## redis集群简介（非codis方案）

在我的理解里，redis集群和数据库分库差不多——自动地将key分配到16384个槽（slot），而集群中的每个redis节点存储一部分槽。

为什么是16384个槽？因为redis集群会计算key的CRC16然后取模16384，得到的值即为槽点编号。

redis集群通过这个分片（reshrad）和主从备份机制，实现了较高的可用性、较高的写安全性（或称为写不会丢失、一致性）。

### 可用性

举例3主3从的redis集群，当网络分区发生时，连接到小分区的客户端肯定不能获得正常服务；连接到大分区的客户端，如果大分区中有大部分的主节点，并且缺失的主节点都有相应的从节点在大分区中，则该客户端能获得正常服务——需要等待NODE_TIMEOUT，从节点被选举为主节点或原来的主节点恢复。

集群的设计目标是当少部分节点发生故障时能够继续运行。但是不能解决发生大规模网络分区的情况。

### 写安全性、写不丢失、一致性

主从节点之间使用异步拷贝。即：

1. 客户端向主节点写。
2. 主节点通知客户端写成功
3. 主节点通知从节点拷贝

第二、三步的顺序决定，如果在2执行完毕后，发生网络分区或主节点故障，则这一部分拷贝就不会顺利传递到从节点，当主节点不能及时恢复时，则从节点成为主节点，导致丢失的这一部分拷贝彻底丢失。

使用异步拷贝，是一致性和性能之间的一种妥协和权衡。

### 由分片来的其他特性

分片意味着每个redis节点上只有一部分key。这导致了redis集群的一些特性和“做不到”。

1. 支持所有的单key操作，但只支持涉及的key都在同一节点的多key操作。【可以使用hash flag强制一些key在同一slot/节点，通过{}包裹被计算hash的部分】
2. 当客户端向节点请求不在该节点的key时，节点会返回重定向（-ASK/-MOVED），而不是代理该请求，向持有key的节点请求。
3. 读写集群中节点的key耗时和单节点差不多，所以有N个节点的集群，差不多可带来N倍的性能提升——前提是key比较分散（这肯定需要的）

## ASK/MOVED重定向

在介绍迁移前，先说下什么是ASK/MOVED重定向。前面说到节点不会代理客户端对其他节点的查询，而是返回重定向，告诉客户端目标key在哪个节点上——这是基于性能的考虑。

```bash
get {n}111
(error) MOVED 3432 99.47.149.25:6419

get {n}222
(error) ASK 3432 99.47.149.26:6425
```

以上就是ASK/MOVED响应真实的长相。MOVED表示，集群的当前状态表明——3432槽点在99.47.149.25:6419的节点上。而ASK响应则只在迁移过程（下一节解释迁移过程）中出现，其语义为——槽点3432正在迁移，你要的{n}222现在不在我这，你去问问（ask）99.47.149.26:6425的节点。一个正确的客户端在遇到ASK重定向时，会先向新节点发送ASKING，然后发送查询。

## 迁移

上一节说到，redis集群将节点分成了16384个分片。而“迁移”就是动态增加/减少集群的节点时，根据节点增减移动这些分片，以保证16384个槽都有节点存储，并较为平均。

### 迁移原理讲解

在实际迁移中，我们使用redis-4.0.1包中src下的redis-trib.rb脚本中的reshrad方法。reshrad方法迁移原理如下（以迁移3432槽点为例）：

1. 在目标节点执行： CLUSTER SETSLOT 3432(slot编号) IMPORTING 原节点ID ——标记目标节点为importing状态
2. 在源节点执行： CLUSTER SETSLOT 3432 MIGRATING 目标节点ID           ——标记源节点为migrating状态
3. 在源节点上执行： CLUSTER GETKEYSINSLOT 3432 10 获取10个还在源节点上的key
4. 对3返回的每个key，在源节点上执行MIGRATE指令，将其移动至目标节点 migrate 99.47.149.26 6425 "" 0 10000 keys {n}2600
5. 重复3-4直到源节点上没有剩余待迁移的key。向目标节点和原节点清除importing和migrating标记 cluster setslot 3432 node 目标节点ID

注意点和迁移3432槽点时集群的反应：
 
- 要先在目标节点标记importing，再在源节点标记migrating——otherwise a client may be redirected to the target node that does not yet know it is importing this slot.
- 执行完2后，向源节点请求3432槽点上的key时，会收到ASK重定向（或者说执行完2，集群就认为自己开始了槽点3432的迁移）。

### 迁移实际操作

先放迁移操作的命令：

```bash
./redis-trib.rb reshard  --from   004c9d0adad075161658c3a2f972591a265ec83c(A) --to  7efc5feb4a1ddb095e9253d918d1d3137599d381(B)   --slots 10 --yes --timeout 10000  --yes --pipeline 20 99.47.149.25:6419
```

把节点A中的前10个slot迁移到节点B，每次迁移20个key。详细的参数解释可以自己通过`./redis-trib.rb help`看，我要讲如何安装这个脚本执行所需的依赖。

```bash
    #安装ruby
    yum -y install zlib-devel
    tar xvf ruby-2.2.7.tar.gz
    cd ruby-2.2.7/
    yum install -y gcc
    ./configure -prefix=/usr/local/ruby2
    make
    make install
    cd /usr/local/ruby2
    yum remove -y ruby#删除预装的老版本的ruby，测试环境下是1.8版本的
    ln -fs /usr/local/ruby2/bin/ruby /bin/ruby
    ln -fs /usr/local/ruby2/bin/gem /bin/gem
    #安装redis-3.3.3.gem——高版本的redis.gem被证明不能正常使用
    gem install -l redis-3.3.3.gem
    #进入redis-4.0.1/src,执行redis-trib.rb
    chmod +x redis-trib.rb
    ./redis-trib.rb help
    cp ./redis-trib.rb /bin/  #加入path（可选）
    #至此，就可以使用redis-trib了。
```

### 迁移计时

我们只需要关注单个slot迁移的耗时，而不需要关注迁移N个slot所有的耗时。

在我的测试环境下：

- 迁移一个空slot耗时0.003秒，基本可以认为只是函数调用时间
- 迁移一个含有一万个100字节的slot（1MB大小）耗时0.897秒
- 迁移一个含有八万个100字节的slot（8MB大小）耗时4.293秒
- 迁移一个含有34万个100字节的slot（34MB大小）耗时15.194秒

迁移耗时肯定会和服务器性能、集群中的网络状况有关联——以上耗时仅供参考，根据本文有缘人完全可以自己来一遍迁移计时【推荐】

上一个计算毫秒级时间差的shell函数：

```bash
function timediff() {

# time format:date +"%s.%N", such as 1502758855.907197692
    start_time=$1
    end_time=$2
    
    start_s=${start_time%.*}
    start_nanos=${start_time#*.}
    end_s=${end_time%.*}
    end_nanos=${end_time#*.}
    
    # end_nanos > start_nanos? 
    # Another way, the time part may start with 0, which means
    # it will be regarded as oct format, use "10#" to ensure
    # calculateing with decimal
    if [ "$end_nanos" -lt "$start_nanos" ];then
        end_s=$(( 10#$end_s - 1 ))
        end_nanos=$(( 10#$end_nanos + 10**9 ))
    fi
    
# get timediff
    time=$(( 10#$end_s - 10#$start_s )).`printf "%03d\n" $(( (10#$end_nanos - 10#$start_nanos)/10**6 ))`
    echo $time
}

start=$(date +"%s.%N")
####一些命令
end=$(date +"%s.%N")
timediff $start $end
```

### 当目标节点maxmemory内存不足时

如果目标节点设置的最大内存不足以存放迁移来的所有key时，如果`maxmemory_policy`规则为`allkeys-lru`则redis-trib不会报错，而是根据allkeys-lru的规则丢弃存放不下的key。`maxmemory_policy`可以使用info命令查看。

### 迁移过程中和迁移结束后，读取key集群的不同表现

迁移结束后，对源节点发起针对slot的请求，源节点会返回 `MOVED 3432 目标节点地址`。一个机智的redis-cluster-client此时会更新自己的slots-node映射（这是redis文档中的原话）。

slot迁移过程中，对源节点发起针对该slot的请求，集群的表现比较复杂。——通过redis-trib难以查看到这些表现，我是通过手动执行`CLUSTER GETKEYSINSLOT 3432 10`和`migrate`等指令，模拟redis-trib的执行中的状态，从而查看中间状态。集群的表现分为以下三种。

1. 请求源节点时，直接返回key的值。——最简单，不需要处理。
2. 源节点返回ASK，proxy asking再get时，得到key的值。——也符合redis的文档，是在执行`migrate`该key之后出现的状态。
3. 源节点返回ASK，proxy asking再get时，得不到key的值，返回nil。——这真实并普遍存在，，需要想想应对策略。


## 本文的意义

前文已经说到，redis集群中的节点不会代理客户端的请求，而是返回重定向。在redis集群的文档中说到，一个聪明的客户端会保存node-slots的映射关系，访问对的节点，减少重定向的出现。

本文整理了redis集群的相关知识，以及在集群迁移中的表现，摸清楚了一个“聪明的客户端”应该具有的业务逻辑：

1. 使用cluster nodes或cluster slots命令获取node-slots映射。
2. 需要查询key时，计算key的slot号（需要妥善处理hash tag）。
3. 遇到moved重定向时，说明集群发生了一次slot迁移，此时更新node-slots映射
4. 遇到ask重定向时，说明该slot正在迁移中，先执行ASK，再执行查询。

以上“聪明的客户端”需要在自己的内存中保存一份node-slots映射，每一个聪明的客户端都要保存一份。不难想到可以在client和redis集群之间添加一个代理，由代理保存node-slots映射，由代理去代理请求而不返回重定向，让客户端透明的调用redis服务，而不用知道后面是redis集群，而非单节点redis。

添加redis代理后，如果只有一个代理，会有单点问题（该redis代理挂了，整个redis服务就挂了）。这很好解决，启动多个redis代理，将他们注册到etcd或者zookeeper，客户端从etcd或zookeeper获取redis代理信息并选择一个使用。


## 附录——仅备忘，防止重复工作


快速执行redis-trib的脚本

```bash
#! /bin/bash
# 用于快速迁移一个槽点
#一般还是不能直接用的，需要保证需要迁移的slot迁移前后都在节点slots的最前面；并自己修改一些a和b中的一些参数
a="redis-trib.rb reshard --yes --from   34a5f5f4f6f2cf0da57ef51d2902feb3103c161b  --to  004c9d0adad075161658c3a2f972591a265ec83c   --slots 1  --timeout 10000   --pipeline 50 99.47.149.25:6419"
b="redis-trib.rb reshard --yes  --from   004c9d0adad075161658c3a2f972591a265ec83c --to   34a5f5f4f6f2cf0da57ef51d2902feb3103c161b  --slots 1  --timeout 10000   --pipeline 50 99.47.149.25:6419"

#flag 文件中的内容为1或者2
flag=$(cat ./flag)
echo $flag

if [ $flag == 1 ];then
 echo "执行b"
 ($b)
 if [ $? == 0 ];then
  echo 2 > flag
 fi
else
 echo "执行a"
 ($a)
 if [ $? == 0 ];then
  echo 1 > flag
 fi
fi
```



