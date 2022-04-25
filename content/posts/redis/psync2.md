---
title: "Psync2——redis备份机制的发展【转载】"
date: 2019-09-05T21:20:30+08:00
draft: false
categories: [ "redis"]
tags: ["redis"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

今天的正题是想转发一篇关于[“异步拷贝”发展的博文](https://mp.weixin.qq.com/s/ROQofjE5WwdAltazQ5p0QQ)，写的真的好，忍不住想转发。看完不禁感叹redis的牛逼，有种兴叹汪洋的感觉。。
<!--more-->

> PS: 这篇博文疑似基于redis4.0.1版本的redis

## 正文

Redis4.0新特性psync2(partial resynchronization version2)部分重新同步(partial resync)增加版本；主要解决Redis运维管理过程中，从实例重启和主实例故障切换等场景带来的全量重新同步(full resync)问题。

## 1 什么是Redis部分重新同步-psync

redis部分重新同步：是指redis因某种原因引起复制中断后，从库重新同步时，只同步主实例的差异数据(写入指令），不进行bgsave复制整个RDB文件。

本文的名词规约：   
部分重新同步：后文简称**psync**    
全量重新同步：后文简称**fullsync**     
redis2.8第一版部分重新同步：后文简称**psync1** 
redis4.0第二版本部分重新同步：后文简称**psync2**   

在说明psync2功能前，先简单阐述redis2.8版本发布的psync1

### Redis2.8 psync1解决什么问题

在psync1功能出现前，redis复制秒级中断，就会触发从实例进行fullsync。  
每一次的fullsync，集群的性能和资源使用都可能带来抖动；如果redis所处的网络环境不稳定，那么fullsync的出步频率可能较高。为解决此问题，redis2.8引入psync1, 有效地解决这种复制闪断，带来的影响。redis的fullsync对业务而言，算是比较“重”的影响；对性能和可用性都有一定危险。

这里列举几个fullsync常见的影响：

- master需运行bgsave,出现fork()，可能造成master达到毫秒或秒级的卡顿(latest_fork_usec状态监控)；    
- redis进程fork导致Copy-On-Write内存使用消耗(后文简称COW)，最大能导致master进程内存使用量的消耗。(eg 日志中输出 RDB: 5213 MB of memory used by copy-on-write)   
- redis slave load RDB过程，会导致复制线程的client output buffer增长很大；增大Master进程内存消耗；    
- redis保存RDB(不考虑disless replication),导致服务器磁盘IO和CPU(压缩)资源消耗    
- 发送数GB的RDB文件,会导致服务器网络出口爆增,如果千兆网卡服务器，期间会影响业务正常请求响应时间(以及其他连锁影响)

### psync1的基本实现

因为psync2是在psync1基础上的增强实现，介绍psync2之前，简单分析psync1的实现。

redis2.8为支持psync1，引入了replication backlog buffer(后文称：复制积压缓冲区）；复制积压缓冲区是redis维护的固定长度缓冲队列(由参数repl-backlog-size设置，默认1MB)，master的写入命令在同步给slaves的同时，会在缓冲区中写入一份(master只有1个积压缓冲区，所有slaves共享）。

当redis复制中断后，slave会尝试采用psync, 上报原master runid + 当前已同步master的offset(复制偏移量，类似mysql的binlog file和position)；

如果runid与master的一致，且复制偏移量在master的复制积压缓冲区中还有(即offset >= min(backlog值)，master就认为部分重同步成功，不再进行全量同步。

```
部分重同步成功，master的日志显示如下：

30422:M 04 Aug 14:33:48.505 * Slave xxxxx:10005 asks for synchronization
30422:M 04 Aug 14:33:48.506 * Partial resynchronization request from xxx:10005 accepted. Sending 0 bytes of backlog starting from offset 6448313.
```

redis2.8的部分同步机制，有效解决了网络环境不稳定、redis执行高时间复杂度的命令引起的复制中断，从而导致全量同步。但在应对slave重启和Master故障切换的场景时，psync1还是需进行全量同步。

### psync1的不足

从上文可知，psync1需2个条件同时满足，才能成功psync: **master runid不变 和复制偏移量在master复制积缓冲区中**。
那么在redis slave重启,因master runid和复制偏移量都会丢失，需进行全量重同步；redis master发生故障切换，因master runid发生了变化；故障切换后，新的slave需进行全量重同步。而slave维护性重启、master故障切换都是redis运维常见场景，为redis的psync1是不能解决这两类场景的成功部分重同步问题。

因此redis4.0的加强版部分重同步功能-psync2，主要解决这两类场景的部分重新同步。

## 2 psync2的实现简述

在redis cluster的实际生产运营中，实例的维护性重启、主实例的故障切换（如cluster failover)操作都是比较常见的(如实例升级、rename command和释放实例内存碎片等）。而在redis4.0版本前，这类维护性的处理，redis都会发生全量重新同步，导到性能敏感的服务有少量受损。
如前文所述，psync2主要让redis在从实例重启和主实例故障切换场景下，也能使用部分重新同步。本节主要简述psync2在这两种场景的逻辑实现。

名词解释：

- master_replid : 复制ID1(后文简称：replid1)，一个长度为41个字节(40个随机串+’\0’)的字符串。redis实例都有，和runid没有直接关联，但和runid生成规则相同，都是由getRandomHexChars函数生成。当实例变为从实例后，自己的replid1会被主实例的replid1覆盖。
- master_replid2：复制ID2(后文简称:replid2),默认初始化为全0，用于存储上次主实例的replid1

实例的replid信息，可通过info replication进行查看； 示例如下：

```shell
127.0.0.1:6385> info replication
# Replication
role:slave
master_host:xxxx      // IP模糊处理
master_port:6382
master_link_status:up
slave_repl_offset:119750
master_replid:fe093add4ab71544ce6508d2e0bf1dd0b7d1c5b2  //这里是主实例的replid1相同
master_replid2:0000000000000000000000000000000000000000  //未发生切换，即主实例未发生过变化，所以是初始值全"0"master_repl_offset:119750
second_repl_offset:-1
```

## 3 Redis从实例重启的部分重新同步

在之前的版本，redis重启后，复制信息是完全丢失;所以从实例重启后，只能进行全量重新同步。

redis4.0为实现重启后，仍可进行部分重新同步，主要做以下3点：

1. redis关闭时，把复制信息作为辅助字段(AUX Fields)存储在RDB文件中；以实现同步信息持久化；

2. redis启动加载RDB文件时，会把复制信息赋给相关字段；

3. redis重新同步时，会上报repl-id和repl-offset同步信息，如果和主实例匹配，且offset还在主实例的复制积压缓冲区内，则只进行部分重新同步。

接下来，我们详细分析每步的简单实现

### redis关闭时，持久化复制信息到RDB

redis在关闭时，通过shutdown save,都会调用rdbSaveInfoAuxFields`函数，把当前实例的repl-id和repl-offset保存到RDB文件中。       
说明：当前的RDB存储的数据内容和复制信息是一致性的。熟悉MySQL的同学，可以认为MySQL中全量备份数和binlog信息是一致的。          
rdbSaveInfoAuxFields函数实现在rdb.c源文件中，省略后代码如下：

```c
/* Save a few default AUX fields with information about the RDB generated. */
int rdbSaveInfoAuxFields(rio *rdb, int flags, rdbSaveInfo *rsi) {

    /* Add a few fields about the state when the RDB was created. */
    if (rdbSaveAuxFieldStrStr(rdb,"redis-ver",REDIS_VERSION) == -1) return -1;

    //把实例的repl-id和repl-offset作为辅助字段，存储在RDB中
    if (rdbSaveAuxFieldStrStr(rdb,"repl-id",server.replid) == -1) return -1;
    if (rdbSaveAuxFieldStrInt(rdb,"repl-offset",server.master_repl_offset) == -1) return -1;
    return 1;
}
```

生成的RDB文件，可以通过redis自带的`redis-check-rdb`工具查看辅助字段信息。   
其中repl两字段信息和info中的相同；

```
$shell> /src/redis-check-rdb  dump.rdb      
[offset 0] Checking RDB file dump.rdb
[offset 26] AUX FIELD redis-ver = '4.0.1'[offset 133] AUX FIELD repl-id = '44873f839ae3a57572920cdaf70399672b842691'
[offset 148] AUX FIELD repl-offset = '0'[offset 167] \o/ RDB looks OK! \o/
[info] 1 keys read
[info] 0 expires
[info] 0 already expired
```

### redis启动读取RDB中复制信息

redis实例启动读取RDB文件，通过rdb.c文件中`rdbLoadRio()`函数实现。    
redis加载RDB文件，会专门处理文件中辅助字段(AUX fields）信息，把其中repl_id和repl_offset加载到实例中，分别赋给master_replid和master_repl_offset两个变量值。    
以下代码，是从RDB文件中读取两个辅助字段值。     

```c
int rdbLoadRio(rio *rdb, rdbSaveInfo *rsi) {
----------省略-----------

else if (!strcasecmp(auxkey->ptr,"repl-id")) {//读取的aux字段是repl-id
                if (rsi && sdslen(auxval->ptr) == CONFIG_RUN_ID_SIZE) {
                    memcpy(rsi->repl_id,auxval->ptr,CONFIG_RUN_ID_SIZE+1);
                    rsi->repl_id_is_set = 1;
                }
            } else if (!strcasecmp(auxkey->ptr,"repl-offset")) { 
                if (rsi) rsi->repl_offset = strtoll(auxval->ptr,NULL,10);
            } else {
                /* We ignore fields we don't understand, as by AUX field
                 * contract. */
                serverLog(LL_DEBUG,"Unrecognized RDB AUX field: '%s'",
                    (char*)auxkey->ptr);
            }
}
```

### redis从实例尝试部分重新同步

redis实例重启后，从RDB文件中加载(注：此处不讨论AOF和RDB加载优先权）master_replid和master_repl_offset；相当于实例的server.cached_master。当我们把它作为某个实例的从库时（包含如被动的cluster slave或主动执行slaveof指令)，实例向主实例上报master_replid和master_repl_offset+1；从实例同时满足以下两条件，就可以部分重新同步：

1. 从实例上报master_replid串，与主实例的master_replid1或replid2有一个相等
2. 从实例上报的master_repl_offset+1字节，还存在于主实例的复制积压缓冲区中

从实例尝试部分重新同步函数slaveTryPartialResynchronization;主实例判断能否进行部分重新同步函数masterTryPartialResynchronization。

### redis重启时，临时调整主实例的复制积压缓冲区大小

redis的复制积压缓冲区是通过参数repl-backlog-size设置，默认1MB；为确保从实例重启后，还能部分重新同步，需设置合理的repl-backlog-size值。    

**1 计算合理的repl-backlog-size值大小**

 通过主库每秒增量的master复制偏移量master_repl_offset(info replication指令获取)大小，
 如每秒offset增加是5MB,那么主实例复制积压缓冲区要保留最近60秒写入内容，backlog_size设置就得大于300MB(60*5)。而从实例重启加载RDB文件是较耗时的过程，如重启某个重实例需120秒(RDB大小和CPU配置相关），那么主实例backlog_size就得设置至少600MB.

```
计算公式：backlog_size = 重启从实例时长 * 主实例offset每秒写入量
```

**2 重启从实例前，调整主实例的动态调整repl-backlog-size的值。**

因为通过config set动态调整redis的repl-backlog-size时，redis会释放当前的积压缓冲区，重新分配一个指定大小的缓冲区。 所以我们必须在从实例重启前，调整主实例的repl-backlog-size。

调整backlog_size处理函数resizeReplicationBacklog，代码逻辑如下：

```c
void resizeReplicationBacklog(long long newsize) {
    if (newsize < CONFIG_REPL_BACKLOG_MIN_SIZE) //如果设置新值小于16KB,则修改为16KB
        newsize = CONFIG_REPL_BACKLOG_MIN_SIZE;
    if (server.repl_backlog_size == newsize) return; //如果新值与原值相同，则不作任何处理，直接返回。

    server.repl_backlog_size = newsize;  //修改backlog参数大小
    if (server.repl_backlog != NULL) { //当backlog内容非空时，释放当前backlog，并按新值分配一个新的backlog
        /* What we actually do is to flush the old buffer and realloc a new
         * empty one. It will refill with new data incrementally.
         * The reason is that copying a few gigabytes adds latency and even
         * worse often we need to alloc additional space before freeing the
         * old buffer. */
        zfree(server.repl_backlog);
        server.repl_backlog = zmalloc(server.repl_backlog_size);
        server.repl_backlog_histlen = 0;  //修改backlog内容长度和首字节offset都为0
        server.repl_backlog_idx = 0;
        /* Next byte we have is... the next since the buffer is empty. */
        server.repl_backlog_off = server.master_repl_offset+1;
    }
}
```

## 4 psync2实现Redis Cluster Failover部分全新同步

为解决主实例故障切换后，重新同步新主实例数据时使用psync，而分fullsync；

1. redis4.0使用两组replid、offset替换原来的master runid和offset.
2. redis slave默认开启复制积压缓冲区功能；以便slave故障切换变化master后，其他落后从可以从缓冲区中获取写入指令。

**第一组：master_replid和master_repl_offset**

 如果redis是主实例，则表示为自己的replid和复制偏移量； 如果redis是从实例，则表示为自己主实例的replid1和同步主实例的复制偏移量。

**第二组：master_replid2和second_repl_offset**

无论主从，都表示自己上次主实例repid1和复制偏移量；用于兄弟实例或级联复制，主库故障切换psync。   
初始化时, 前者是40个字符长度为0，后者是-1； 只有当主实例发生故障切换时，redis把自己replid1和master_repl_offset+1分别赋值给master_replid2和second_repl_offset。   
这个交换逻辑实现在函数shiftReplicationId中。   

```c
void shiftReplicationId(void) {
    memcpy(server.replid2,server.replid,sizeof(server.replid)); //replid赋值给replid2
    /* We set the second replid offset to the master offset + 1, since
     * the slave will ask for the first byte it has not yet received, so
     * we need to add one to the offset: for example if, as a slave, we are
     * sure we have the same history as the master for 50 bytes, after we
     * are turned into a master, we can accept a PSYNC request with offset
     * 51, since the slave asking has the same history up to the 50th
     * byte, and is asking for the new bytes starting at offset 51. */
    server.second_replid_offset = server.master_repl_offset+1; 
    changeReplicationId();
    serverLog(LL_WARNING,"Setting secondary replication ID to %s, valid up to offset: %lld. New replication ID is %s", server.replid2, server.second_replid_offset, server.replid);
}
```

这样发生主库故障切换，以下三种常见结构，都能进行psync:

1. 一主一从发生切换，A->B 切换变成 B->A ;
2. 一主多从发生切换，兄弟节点变成父子节点时；
3. 级别复制发生切换， A->B->C 切换变成 B->C->A

主实例判断能否进行psync的逻辑函数在`masterTryPartialResynchronization()`:

```c
int masterTryPartialResynchronization(client *c) {

    //如果slave提供的master_replid与master的replid不同，且与master的replid2不同，或同步速度快于master； 就必须进行fullsync.
    if (strcasecmp(master_replid, server.replid) &&
        (strcasecmp(master_replid, server.replid2) ||
         psync_offset > server.second_replid_offset))
    {
        /* Run id "?" is used by slaves that want to force a full resync. */
        if (master_replid[0] != '?') {
            if (strcasecmp(master_replid, server.replid) &&
                strcasecmp(master_replid, server.replid2))
            {
                serverLog(LL_NOTICE,"Partial resynchronization not accepted: "
                    "Replication ID mismatch (Slave asked for '%s', my "
                    "replication IDs are '%s' and '%s')",
                    master_replid, server.replid, server.replid2);
            } else {
                serverLog(LL_NOTICE,"Partial resynchronization not accepted: "
                    "Requested offset for second ID was %lld, but I can reply "
                    "up to %lld", psync_offset, server.second_replid_offset);
            }
        } else {
            serverLog(LL_NOTICE,"Full resync requested by slave %s",
                replicationGetSlaveName(c));
        }
        goto need_full_resync;
    }

    /* We still have the data our slave is asking for? */
    if (!server.repl_backlog ||
        psync_offset < server.repl_backlog_off ||
        psync_offset > (server.repl_backlog_off + server.repl_backlog_histlen))
    {
        serverLog(LL_NOTICE,
            "Unable to partial resync with slave %s for lack of backlog (Slave request was: %lld).", replicationGetSlaveName(c), psync_offset);
        if (psync_offset > server.master_repl_offset) {
            serverLog(LL_WARNING,
                "Warning: slave %s tried to PSYNC with an offset that is greater than the master replication offset.", replicationGetSlaveName(c));
        }
        goto need_full_resync;
    }
}
```