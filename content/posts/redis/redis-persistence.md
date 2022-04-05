---
title: "Redis持久化机制-aof.c与rdb.c"
date: 2019-09-11T20:17:11+08:00
draft: false
categories: [ "redis"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

redis提供aof和rdb两种持久化机制，本文分析一下这两种持久化机制

## 两种持久化机制的优劣

以下先摘录一下redis文档关于rdb、aof持久化的优势和劣势

redis提供两种持久化方式：RDB和AOF

- RDB以一定的时间间隔提供redis数据集的实时快照
- AOF则记录redis的每一次写操作。在redis重启时，会重新执行这些操作。这些操作以redis网络通信协议的格式记录。采用追加写的方式。如果AOF文件太大，redis可以在后台重写这些日志（啥叫rewrite？）
- 如果愿意，可以完全禁用数据持久化，如果没有持久化的需求
- RDB和AOF能够同时存在，当两者都存在时，会使用AOF进行恢复，因为AOF会更加完整

**RDB的优势**

- RDB以一个紧凑的单一文件备份redis的实时数据。RDB文件非常适合备份。比如你希望每个小时备份一下RDB文件，从而存储不同版本的数据以应对可能出现的灾难
- RDB很适合用于灾难恢复，因为单一的紧凑的文件很容易迁移到另一个较远的数据中心
- RDB最大化了redis的性能，因为redis父进程仅需要fork一个子进程去完成剩余的工作，而不需要处理IO等会产生阻塞的事件。
- RDB恢复的启动时间小于AOF恢复

**RDB的劣势**

- RDB会丢失部分数据，因为他是定时地进行备份。如果Redis没有经历正常的关闭过程（断电等），则会丢失上一次RDB到异常关闭这段时间的写。
- RDB需要fork子进程来进行持久化。如果数据集太大，fork系统调用可能消耗较多时间，甚至导致redis暂停服务（ n ms-1s）。AOF也需要fork，但是你可以在不影响持久性的前提下控制多久重写一次日志

**AOF的优势**

- 使用AOF的话，redis具有更高的持久性。你可以选择不同的fsync（将磁盘写缓冲区的数据冲刷到磁盘-真正写到磁盘）策略：不做fsync，每秒做一次fsync，每次查询做一次fsync。在默认策略-每秒执行一次fsync时，性能仍然很客观，而只会丢失一秒的写。
- AOF是一个尾部追加写的文件，不会做任何的seek操作（定位到文件的中间位置再进行写）。所以即使发生断电，也不会造成AOF文件的污染。如果断电时仅仅成功地写了一半的命令，也可以通过redis-check-aof工具进行修正。
- redis可以在后台重写AOF当日志文件变得很大。重写是完全安全的。当新日志文件创建并准备就绪后，新的追加会立即切换到新日志文件。
- AOF记录了写的操作顺序。如果想要撤销某个操作例如flushall，仅需要删除AOF文件中的flushalll的命令，并重启redis即可。

**AOF的劣势**

- AOF文件通常会比同数据集的RDB文件大
- AOF在特定的fsync策略下会影响性能。总体来说，在每秒一次fsync时，性能仍然很高；当关闭fsync时，会和RDB有差不多一样的性能。另外在高负载时，RDB的最大延迟比AOF低。
- AOF曾经有一些bug。【技术人真严谨，讲了好几条

## 主从架构下主节点是否应该开启持久化

先说结论：如果主节点没有开启持久化，那么主节点的进程千万不能有崩溃后自动重启机制。崩溃后自动重启可以通过systemd的restart=always等方式进行配置。考虑如下场景：

1. A是主节点，B、C是他的从节点，从A获取异步拷贝。A没有开启持久化，并且A节点通过systemd配置了崩溃后自动重启
2. A崩溃后立即自动重启，因为没有持久化所有数据被清空，因为崩溃的时间间隔短，sentinel或cluster来不及提升其他从节点，A重启后仍然为主节点。
3. B、C仍然从A获取拷贝，他们也清空了自己的数据。

该场景下，导致数据最终丢失。

所以主从架构下，主节点要么开启持久化，要么不能有自动重启机制。

## rdb实现机制简析

rdb简单地理解就是将内存数据快照一下，redis提供SAVE和BGSAVE两种命令，其中SAVE会暂停redis服务，BGSAVE则是在后台进行。

将内存数据快照这件事，很容易想到JVM进行full GC前stop the world获取内存快照进行可达性分析，这样不难理解为什么redis的SAVE会暂停redis服务。

而BGSAVE则使用fork()系统调用创建子进程来进行内存快照，从而实现不暂停服务进行快照。redis文档用一句话总结为什么新开进程，而不是新开线程：利用copy-on-write机制。

在这里展开来讲一下。如果我们开新的线程，进行快照是要对整块内存数据加锁的，开新线程并不能并行地备份+提供服务。而fork机制新建的子进程，在一开始与父进程共享内存空间，只有当父子进程的内存出现不一致时，父子才使用不同的内存空间去承载这不同的部分——这就是copyonwirte机制，可以理解为一种“懒”的机制。fork出的子进程拥有父进程（redis主进程）的全部内存数据，子进程将自己的内存数据快照，即将本节点当时的内存快照下来，而redis主进程继续向客户端提供服务。利用fork机制，可以实现不暂停服务进行快照。——这可能是为数不多的进程优于线程的情况。

在进行BGSAVE时，redis会产生一条日志：`RDB: %zu MB of memory used by copy-on-write`，记录在rdb过程中，父子进程产生了多少内存的差异。redis对统计`/proc/self/smaps`文件下的`Private_dirty`的总和来计算copy-on-write内存。可以使用一下命令自己看看Private_dirty的情况：`cat /proc/self/smaps | grep Private_Dirty`。linux的哲学是一切皆文件，/proc目录就是一个虚拟文件，用于保存系统运行时的状态。而/proc/self文件夹下永远呈现查看该目录内容的进程的情况——rdb子进程看到的是自己的情况，我们cat /proc/self/smaps则看到的是cat进程的信息。

> PS:因为copyonwrite机制，在进行rdb时，redis的内存占用会出现膨胀的状况。例如原来只占用8GB，进行rdb时可能会膨胀到10GB。。。

> PS:如果内存膨胀超过机器内存，此时rdb会失败。

> 考虑从节点要获取全量同步的情况，如果主节点因内存不足导致rdb失败，从节点会重试请求全量同步，主节点仍然会rdb失败。这会循环。。

**rdbSaveRio**

rdb的核心实现是rdbSaveRio。其函数声明如下：

```
int rdbSaveRio(rio *rdb, int *error, int flags, rdbSaveInfo *rsi)
```

其中rio指针类型的rdb参数是redisIO模型对linux文件描述符的一个封装，rio既可以是磁盘文件描述符也可以是socket描述符。第二个参数记录write系统调用的errno，通过指针的方式进行“透传”，执行完毕后仍能查看看error的值。

rdbSaveRio会做下面这些事：

1. 写入魔数“REDIS”以及RDB_VERSION
2. 保存AUX字段（可以认为是redis的状态元数据）
3. 遍历数据库，执行4、5
4. 写入“RDB_OPCODE_SELECTDB 数据库号”和“RDB_OPCODE_RESIZEDB 数据库大小 设置expire的key-value的大小”
5. 遍历数据库的dict中的key-value，写入`[EXPIRETIME time] type key value`
6. 写入RDB_OPCODE_EOF ——EOF标志
7. 写入checksum

rdb的核心实现就是以上。另外，redis在主从拷贝中可以直接传输rdb到socket连接而不使用磁盘存储（diskless），redis定义了rdbSaveRioWithEOFMark和rdbSaveToSlavesSockets两个函数来实现以上功能。依赖于rio封装linux文件描述符（磁盘/socket）的设计，这两个函数最终还是使用rdbSaveRio。


## rdbLoad-加载rdb文件

rdbLoad函数是rdbSave的逆过程，实现感觉没有必要细说。rdb加载通常发生在redis启动时，redis不允许管理员在运行时加载rdb文件，实际上这是可以的，仅仅是redis没有暴露相关的接口。

在这里简单记录一下如何实现这个功能，以备不时之需。因为篇幅和内容相关性的原因，这里仅给出链接，不列原文。[redis运行时加载rdb](/posts/redis/redis-online-load-rdb/)。

## AOF实现

AOF会记录write请求，将其写入aof文件。从redis接受一个请求到写入AOF的函数调用路径为：

1. processCommand @server.c
    1. call @server.c 
        1. propagate @server.c
            1. feedAppendOnlyFile @aof.c
            2. replicationFeedSlaves @replicate.c

从该路径可以清晰地看到server处理命令后最终走到了aof功能和replicate功能的代码。


**将命令追加到aof_buf**

feedAppendOnlyFile会对expire类型的命令进行翻译，将过期时翻译为绝对的过期时间戳，伪代码表示：

```
void feedAppendOnlyFile(struct redisCommand *cmd, int dictid, robj **argv, int argc) {
    如果databaseID不等于上次使用的databaseID{
        追加select命令
    }

    如果命令为EXPIRE/PEXPIRE/EXPIREAT{
        翻译为PEXPIREAT，然后追加
    }

    如果命令为SETEX/PSETEX{
        翻译为SET+PEXPIREAT两条命令，然后追加
    }

    如果命令为SET [EX seconds][PX milliseconds]{
        翻译为SET+PEXPIREAT两条命令，然后追加
    }

    其他情况{
        直接追加命令
    }
}
```

feedAppendOnlyFile并不直接将命令追加到aof文件，而是追加到server.aof_buf这个缓存，之后再通过其他途径写入磁盘。如果有后台rewriting正在执行，则同时将这些命令写入aofRewrite缓冲区（aof_rewrite_buf_blocks）。

**将aof_buf真正写入aof文件**

真正将buf写到磁盘的函数是flushAppendOnlyFile。该函数会调用一次write，将aof_buf写入aof的文件描述符。同时，会根据appendfsync配置（always、everysec、no）的值和当前是否有后台线程执行fsync，决定现在执行fsync还是延迟fsync。

write系统调用并不会立即将数据落到磁盘，落盘由操作系统调度，fsync则是强制操作系统进行落盘。

**加载AOF文件**

由函数loadAppendOnlyFile实现。

读取AOF中的命令tcp报文再执行，修改redis的database中数据，这是加载AOF文件的流程。因为redis的实现中，每一个命令的执行都需要一个struct client实例,同样执行AOF中的命令也需要一个这样的client。所以redis伪造了一个client来执行这些命令——通过createFakeClient函数。

在读取/加载AOF文件过程中，会首先判断是否AOF文件是否已“REDIS”开头，如果是，则认为这个文件是rdb+aof。则先读取该文件的rdb部分，再读取尾部的aof部分。从aof中读取到命令后，将命令参数设置到fakeclient中，然后将fakeClient作为参数传递给命令对应的cmd函数，这就完成了该条命令的执行。


**重写AOF文件实现**

AOF文件使用追加的方式记录redis的写命令历史，也就意味着AOF文件会不断增大，“重写”就是当AOF文件过大时，创建新的AOF文件，以减小单个AOF文件的大小。

其实实现在rewriteAppendOnlyFileBackground。redis会fork出一个子进程。子进程创建名为“temp-rewriteaof-bg-{child_pid}.aof”的临时文件。随后调用rewriteAppendOnlyFile(tempfile)。


rewrite的整体过程是：先将当前redis的快照保存到新AOF文件中，然后将aof_rewrite_buf_blocks中的缓冲写到新的AOF文件中

rewriteAppendOnlyFile会根据server.aof_use_rdb_preamble是否设定，决定rewirte是否使用rdb作当前redis的快照。其关键代码为：

```c
    if (server.aof_use_rdb_preamble) {
        int error;
        if (rdbSaveRio(&aof,&error,RDB_SAVE_AOF_PREAMBLE,NULL) == C_ERR) {
            errno = error;
            goto werr;
        }
    } else {
        if (rewriteAppendOnlyFileRio(&aof) == C_ERR) goto werr;
    }
```

rewriteAppendOnlyFileRio保存当前redis快照的方式是遍历所有database，将所有key-value用set命令的形式追加到新的AOF文件中（超时的key不追加，超时时间使用PEXPIREAT记录）。

serverCron函数会检测AOF重写子进程的退出，其实现是通过wait系统调用——linux中子进程退出，父进程要wait其退出，否则该子进程会成为僵尸进程。

如果serverCron中wait得到的进程id与AOF重写子进程相同，则说明AOF重写完成，此时通过`backgroundRewriteDoneHandler`函数执行重写完毕后的操作。关键代码如下：

```
        if ((pid = wait3(&statloc,WNOHANG,NULL)) != 0) {
            ...
            if (pid == -1) {
                ...
            } else if (pid == server.rdb_child_pid) {
                ...
            } else if (pid == server.aof_child_pid) {
                backgroundRewriteDoneHandler(exitcode,bysignal);
                if (!bysignal && exitcode == 0) receiveChildInfo();
            } else {
                ...
            }
            ...
        }
```

backgroundRewriteDoneHandler关键代码如下：

```
void backgroundRewriteDoneHandler(int exitcode, int bysignal) {
    if (!bysignal && exitcode == 0) {
        snprintf(tmpfile,256,"temp-rewriteaof-bg-%d.aof",
            (int)server.aof_child_pid);
        newfd = open(tmpfile,O_WRONLY|O_APPEND);
        if (aofRewriteBufferWrite(newfd) == -1) {
            ……//将重写缓冲区的数据写入到重写AOF文件
        }
        if (rename(tmpfile,server.aof_filename) == -1) {
            ……//覆盖旧的AOF文件
        }
        ……
    } 
}
```

他会将重写期间暂时存放在aof_rewrite_buf_blocks中的写请求追加到新的AOF文件，随后覆盖就得AOF文件。

