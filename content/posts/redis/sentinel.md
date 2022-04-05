---
title: "Redis哨兵实现-sentinel.c"
date: 2019-09-12T18:25:31+08:00
draft: false
categories: [ "redis"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

这一篇记录一下sentinel的文档和实现。真的是好长的一篇文章😂
<!--more-->

# 官方文档

sentinel是redis官方高可用方案，从宏观角度看，sentinel提供以下能力。

- **监控**： 持续检测主从节点是否正常工作
- **通知**： sentinel可以通过调用notification_script向系统管理员报告事件
- **自动故障转移**： 如果主节点不能正常工作，sentinel会提升其他从节点为主节点，并通知客户端新主节点的地址。
- **配置提供**：告知客户端主节点的地址

reids Sentinel以集群、分布式的方式运行。这样的好处：

1. 只有多个sentinel认为主节点主观下线，该主节点才会被判定客观下线——降低了误判几率
2. 当单个sentinel故障时，其他sentinel节点仍能正常进行故障迁移——故障迁移控制系统本身面临单点问题是很傻的。

启动sentinel必须要提供配置文件，该配置文件会被sentinel进程重写，所以要提供写权限。至少需要三台sentinel实例才能保证健壮性(redis提供了几种推荐的部署方式)。配置文件仅需要指定自己监控的master（们），而不需要指定相关的slaves。sentinel会自动地获取slave信息。这份配置文件会在从节点成为主节点或新的sentinel被发现时被sentinel修改。

## sentinel工作流程

1. sentinel启动，指定`sentinel monitor <master-group-name> <ip> <port> <quorum>`——quorum是一个数字
2. 当一个sentinel得知有大于等于quorum个sentinel认为该主节点掉线时，该节点会尝试进行故障转移（提升从节点）
3. sentinel需要被大多数sentinel选举为leader后才有权进行故障迁移——网络分区时，小分区的sentinel不可能执行故障迁移/如果大多数sentinel不能通信，则不可能发生故障迁移

## 模拟sentinel故障迁移过程

使用`redis-cli -p 6379 DEBUG sleep 30`模拟主节点宕机三十秒。会出现以下过程

1. 每个sentinel都判定该主节点为+sdown（主观宕机）
2. 最终该主观宕机被确认为+odown（客观宕机）——多个sentinel判定其为主观宕机
3. 一个sentinel被大部分sentinel投票来执行故障迁移
4. 改sentinel执行故障迁移

## SDOWN事件和ODOWN事件

SDOWN是主观宕机，即sentinel自己认为某master宕机。   
ODWON是客观宕机，即大于等于quorum个sentinel都认为该master宕机——此时才可故障。

在sentinel向master发送PING后，超过`is-master-down-after-milliseconds`毫秒仍未收到有效的响应（+PONG、-LOADING、-MASTERDOWN），则sentinel记录master的状态为SDOWN。

从SDOWN到ODOWN状态的转换没有使用强一致性协议，而是一种gossip（流言蜚语）协议——只要一个sentinel被足够数量的sentinel告知master处于SDOWN，则该sentinel标记其为ODOWN，并开始选举从而执行故障迁移。

ODOWN只适用于master，而slave和sentinel节点还有SDOWN状态。**被标记为SDOWN的从节点不会被选举为主节点。**

## sentinel和salve自动发现机制

首先，sentinel仅需要配置监测的master而不需要配置slaves，sentinel会自动的向master查询slave信息。

其次，sentinel会利用redis的发布订阅功能来实现自动发现。所有的sentinel都会连接到所有master和slave的` __sentinel__:hello`频道，每两分钟发布一条带有ip、port、runid的消息。所有sentinel都会收到这个消息，这个消息携带主节点的配置信息，如果自身保存的master配置信息旧于收到的，则立即更新。如果收到的sentinel hello消息携带的runid或地址信息已经存在，则删除自身保存的旧的sentinel，替换为新的这个。

注意：sentinel不会主动删除（forget）自身保存的其他sentinel或slave信息，需要手动以30秒间隔的方式对每个sentinel执行`sentinel reset <maste rname>`，详情请见redis文档。

## sentinel主动重新配置被监控redis节点

主动重新配置的主要目的是纠正redis从节点的错误配置。具体如下：

1. 认为自己是主节点的从节点（发生故障转移，被降级为从节点）将会被重配置为拷贝正确的主节点（成为他的从节点）
2. 拷贝旧主节点的从节点，将会被重新配置为拷贝新主节点。

为了防止sentinel过期的知识错误地配置从节点，在真正进行重配置前，会等待一段时间看看其他sentinel会不会传播新的配置信息，以确保本sentinel本身信息足够新。

这种重配置保证了主从架构在网络分区前后的健壮性：

1. 被故障迁移降为从节点的旧主节点会重新配置为从节点
2. 从节点在网络分区恢复后，会被重新配置为拷贝新的主节点

## 从节点选举及其优先级

当sentinel确认master为ODOWN状态，且获得大多数sentinel授权来执行故障迁移时，就会挑选合适的从节点成为主节点。sentinel会从以下几个维度挑选：（英文更利于理解）

1. Disconnection time from the master.
2. Slave priority.
3. Replication offset processed. ——异步拷贝接收的数据量
4. Run ID. （当主节点挂了，从节点的Run id已经变为自己的，而不是与主节点相同）

这些信息都可以对slave节点执行`info replication`进行查看。

1. 首先 断开时间大于特定时长的从节点没有资格。
2. 其次检查slave priority，数字小的优先。为0则不会被选择
3. 再其次，replication offset大的优先。
4. 如果以上都相同，则选择runid小的从节点——这样安排比随机选择一个更加有秩序。

## 配置纪元（epochs）

当一个sentinel被授权进行故障迁移时，他会获得一个**configuration epoch**，用于标记配置信息的版本。——每一次故障迁移所使用的配置信息都对应一个配置纪元。

故障迁移具有这样一个规则：其他sentinel会等待被授权的sentinel failover-timeout的时间进行故障迁移，之后自己才会尝试failover。这保证同一时间只有一个sentinel在进行故障迁移。

## 配置信息传播

sentinel会在__sentinel__:hello 频道中传播自己持有的配置信息和配置纪元，前文提到，所有sentinel都会连接到主从节点的__sentinel__:hello。更新的配置信息有更新的配置纪元，当sentinel收到更新的配置纪元时，会更新自己的配置信息。——这确保了sentinel们只认可一份配置信息，也就是只认可一个主节点。

**sentinel的配置信息会携带配置纪元一同进行持久化**，所以重启不会丢失状态

## TILT模式

sentinel重度依赖计算机时间，因为他会记录各种时间，依赖超时机制进行决策。如果计算机时间异常改变、计算机过忙或者进程被block一段时间，sentinel可能会出现异常的表现。

TITL就是在发生上述情况时的一种保护状态。sentinel会进行周期中断，每十秒进行一次，因此两次中断的间隔大约为100ms，如果这个时间差为负，或者太大（>=2秒），就会进入TILT模式。

在TILT模式中，sentinel仍然进行监控，但不会进行操作。因为时间变得不可信，所以sentinel依赖时间的状态监控也不再可信。如果恢复正常超过30s，TITL模式退出。



# 实现

如果redis实例为sentinel模式，则serverCron函数会执行sentinelTimer函数。sentinelTimer函数周期性执行，做以下几件事情：

1. sentinelCheckTiltCondition()：判断系统时间是否出现异常，决定是否进入TILT模式
2. sentinelHandleDictOfRedisInstances(sentinel.masters)：
    1. 遍历所有节点，handle每个节点，分为monitoring和acting两部分工作——如果在TILT模式，则不做acting工作；
    2. 如果当前在TILT模式，且系统时间回复正常则退出TILT模式；
    3. 如果某个主节点的failover_state为SENTINEL_FAILOVER_STATE_UPDATE_CONFIG，则执行+switch-master事件。

## TILT模式实现

TILT模式就像一个自动开关，根据系统时间是否正常决定是否执行主观下线、客观下线、failover这些acting。

**进入TILT模式**

判断是否进入TILT模式在sentinelTimer函数开头的sentinelCheckTiltCondition();

```
    //delta为当前时间与上次时间之差
    if (delta < 0 || delta > SENTINEL_TILT_TRIGGER) {
        sentinel.tilt = 1;
        sentinel.tilt_start_time = mstime();
        sentinelEvent(LL_WARNING,"+tilt",NULL,"#tilt mode entered");
    }
```

如果delta为负，或者过大，说明在两次sentinelTimer的执行间隔中，系统时间被异常地修改，时间不再可信，进入TILT模式，只做监控，不做acting

**退出TILT模式**

在handle每个节点的acting部分的开始，都会检查是否在TILT模式中，如果在则判断能否退出。

```c
    if (sentinel.tilt) {
        if (mstime()-sentinel.tilt_start_time < SENTINEL_TILT_PERIOD) return;
        sentinel.tilt = 0;
        sentinelEvent(LL_WARNING,"-tilt",NULL,"#tilt mode exited");
    }
```

如果在这里能够退出TILT模式，则继续执行对给节点的acting部分。


## Sentinel通知实现

Sentinel通知主要通过发布订阅和notification_scripts实现。其实现在

```
void sentinelEvent(int level, char *type, sentinelRedisInstance *ri,
                   const char *fmt, ...)
```

这很像一个log函数的声明，level有LL_DEBUG、LL_NOTICE、LL_WARNING等。LL_WARNING等级的事件会调用notification_scripts进行通知；非DEBUG等级的事件会通过名为type参数的发布订阅频道进行通知。

## Sentinel监控实现


Sentinel的监控实现在`sentinelHandleRedisInstance`函数（handle单个redis实例）的monitoring部分。

一个sentinel实例到其他每个节点（master、slave、sentinel）都有两条tcp连接——命令传输连接和发布订阅连接。monitoring部分首先会修复该两条连接，如果断开则重建该两条连接。

监控的实现主要依赖INFO、PING命令和发布hello消息到`__sentinel__:hello`频道。INFO、PING命令通过命令传输连接，hello消息通过发布订阅连接。所有这些命令都是通过异步回调的方式执行的。redis保持一个pending_commands变量来计算已发出但未收到响应的命令数量。如果该数量太大，则不再发送新的监控命令

**PING及其回调**

PING会发送给所有redis实例（master、slave、sentinel），其通过`sentinelSendPing`函数实现。他会更新last_ping_time为当前时间；同时，如果act_ping_time为0（意味着收到了上一次ping的pong），则也更新act_ping_time为当前时间。执行ping，pending_commands会累加一。

PING命令收到响应的回调函数为`sentinelPingReplyCallback`。其会对pending_commands减一，同时更新last_pong_time为当前时间。如果响应为PONG、LOADING、MASTERDOWN，则更新last_avail_time为当前时间，act_ping_time为0。如果响应为BUSY，则有可能是其在执行脚本，sentinel会向其发送`SCRIPT KILL`命令。

上面我们涉及 act_ping_time、last_ping_time、last_pong_time、last_avail_time这些变量。而monitoring部分发送PING命令就在last_ping_time和last_pong_time过老的时候：

```
    if ((now - ri->link->last_pong_time) > ping_period &&
               (now - ri->link->last_ping_time) > ping_period/2) {
        /* Send PING to all the three kinds of instances. */
        sentinelSendPing(ri);
    }
```

**INFO及其回调**

INFO命令会发送给master和slave节点。

它的回调函数是sentinelInfoReplyCallback，其会解析INFO的响应，并通过sentinelRefreshInstanceInfo，更新INFO命令目标节点在sentinel内存中的状态，包括以下信息：

- run_id——如果runid与之前记录的不同，则记录一次+reboot事件（LL_NOTICE）
- slave0、slave1....——如果某slave是新发现的，则加入监听列表，并记录+slave事件（LL_NOTICE）
- master_link_down_since_seconds
- role:(master/slave)
    - 如果是slave则继续读取`master_host`、`master_port`、master_link_status、slave_priority、slave_repl_offset

该回调函数还会在目标节点role发生变化时产生+/-role-change的事件（仅记录到日志）。

如果当前不在TILT模式，还会继续执行以下：

1. 如果之前记录该节点为slave，而该INFO响应报告其为master。且他的主节点的SRI_FAILOVER_IN_PROGRESS flag被设置且failover_state为SENTINEL_FAILOVER_STATE_WAIT_PROMOTION，则说明该从节点成功地被提升为主节点。此事将failover_state置为SENTINEL_FAILOVER_STATE_RECONF_SLAVES。同时记录+promoted-slave和——这一段的作用将在下文状态机部分解释。
2. 如果该slave异常地报告自己是主节点（没有sentinel进行failover提升他）或报告自己拷贝的主节点不同于sentinel记录的，则修正该从节点的状态。
3. 处理SRI_RECONF_SENT->SRI_RECONF_INPROG->SRI_RECONF_DONE的状态转换

**hello消息的发布与消费**

hello消息会发送给所有节点的`__sentinel__:hello`频道。消息格式为：

```
sentinel_ip,sentinel_port,sentinel_runid,current_epoch,
master_name,master_ip,master_port,master_config_epoch
```

发布hello消息的回调函数为sentinelPublishReplyCallback。其仅仅递减pending_commands，和更新last_pub_time为当前时间（如果发布成功）。

hello消息的消费是通过sentinelReceiveHelloMessages函数，该函数是SUBSCRIBE命令的回调函数。该函数在解析hello消息的8个字段后，会做如下：

1. 增加新发现的sentinel或更新已有sentinel的地址。（决定更新还是增加是判断runID是否有记录过）
2. 如果hello消息中sentinel的current_epoch大于本地current_epoch,则更新本地的为hello消息中的current_epoch
3. 如果hello消息中master_config_epoch大于本地的记录，则更新本地的master地址和master_config_epoch。产生+config-update-from事件和+switch-master事件。
4. 更新last_hello_time为当前时间

消费hello消息的过程就是配置传播的过程。


## 自动故障迁移实现

自动failover的实现在sentinelHandleRedisInstance的acting部分，包含：

- 主观下线
- 客观下线
- 选举leader
- 执行failover

```c
    /* ============== ACTING HALF ============= */
    /* Every kind of instance */
    sentinelCheckSubjectivelyDown(ri);

    /* Masters and slaves */
    if (ri->flags & (SRI_MASTER|SRI_SLAVE)) {
        /* Nothing so far. */
    }

    /* Only masters */
    if (ri->flags & SRI_MASTER) {
        //主观下线状态更新
        sentinelCheckObjectivelyDown(ri);
        if (sentinelStartFailoverIfNeeded(ri))
            //询问其他sentinel该master是否为sdown，并可能伴随选举leader
            sentinelAskMasterStateToOtherSentinels(ri,SENTINEL_ASK_FORCED);
        sentinelFailoverStateMachine(ri);
        sentinelAskMasterStateToOtherSentinels(ri,SENTINEL_NO_FLAGS);
    }
```

**主观下线状态判断与更新**

主观下线状态判断与更新会对master、slave和sentinel进行。

主观下线状态的检测就是检测几个时间变量有没有超出阈值，因为是“主观”的变动，所以不需要与其他sentinel协商。会产生+sdown事件和-sdown事件（离开主观下线状态）

**客观下线状态判断与更新**

sentinel会遍历自己内存中所有sentinel的SRI_MASTER_DOWN标记，如果该flag为1，则计数+1，如果计数大于quorum则设置为主观下线状态。会产生+odown事件和-odown事件（离开客观下线状态）。

**检测并开始failover**

检测部分包括三项工作：

1. Master must be in ODOWN condition.
2. No failover already in progress.
3. No failover already attempted recently.

如果满足三项条件则执行sentinelStartFailover，该函数会做如下：

1. 设置flag：SRI_FAILOVER_IN_PROGRESS；
2. master->failover_epoch = ++sentinel.current_epoch; ——更新两个epoch，该epoch比当前集群稳定的epoch大
3. 同时设置failover_state为SENTINEL_FAILOVER_STATE_WAIT_START。该failover_state随后进入一个状态机进行状态转换（真正的failover过程）。
4. 产生+new-epoch和+try-failover事件

**与其他sentinel协商**

sentinelAskMasterStateToOtherSentinels向其他所有sentinel发送IS-MASTER-DOWN-BY-ADDR。其请求和响应格式如下：

```
请求：SENTINEL is-master-down-by-addr master_ip master_port sentinel_current_epoch sentinel_myid/*
响应：down state, leader, vote epoch.
```

该命令的作用其实有两部分：

- 目标sentinel是否认为该master为sdown
- 如果源sentinel开始了failover，则最后一个参数不为“*”，此时会进行failover的leader选举——这是从命名中看不出来的。

我们看`sentinelCommand`中处理`is-master-down-by-addr`命令的激发选举leader的代码；

```
        /* Vote for the master (or fetch the previous vote) if the request
         * includes a runid, otherwise the sender is not seeking for a vote. */
        if (ri && ri->flags & SRI_MASTER && strcasecmp(c->argv[5]->ptr,"*")) {
            leader = sentinelVoteLeader(ri,(uint64_t)req_epoch,
                                            c->argv[5]->ptr,
                                            &leader_epoch);
        }
```

可以看到判断第6个参数是不是“*”，已决定是否进行`sentinelVoteLeader`。我们先将sentinelVoteLeader视为一个黑盒，仅需要知道他会返回leader信息。

现在来看收到响应的回调函数`sentinelReceiveIsMasterDownReply`。他会做两件事：

1. 更新内存中该sentinel对目标master的sdown状态标记
2. 更新内存中该sentinel的选举信息：leader以及leader_epoch


**sentinelFailoverStateMachine-执行failover的状态机**

该状态机真正调用一些函数来执行failover过程，状态转换如下：

```c
    switch(ri->failover_state) {
        case SENTINEL_FAILOVER_STATE_WAIT_START:
            sentinelFailoverWaitStart(ri);
            break;
        case SENTINEL_FAILOVER_STATE_SELECT_SLAVE:
            sentinelFailoverSelectSlave(ri);
            break;
        case SENTINEL_FAILOVER_STATE_SEND_SLAVEOF_NOONE:
            sentinelFailoverSendSlaveOfNoOne(ri);
            break;
        case SENTINEL_FAILOVER_STATE_WAIT_PROMOTION:
            sentinelFailoverWaitPromotion(ri);
            break;
        case SENTINEL_FAILOVER_STATE_RECONF_SLAVES:
            sentinelFailoverReconfNextSlave(ri);
            break;
    }
```

sentinelStartFailover函数将failover_state置为SENTINEL_FAILOVER_STATE_WAIT_START，随后进行状态机。

sentinelFailoverWaitStart会统计其他sentinel的投票信息，判断自己是否为leader，如果是则置failover_state为SENTINEL_FAILOVER_STATE_SELECT_SLAVE，进入状态机下一步状态。

sentinelFailoverSelectSlave会选举出一个slave，选举规则上文有陈述。

sentinelFailoverSendSlaveOfNoOne会对该slave发送“SLAVEOF NO ONE”命令，让其成为一个主节点。

sentinelFailoverWaitPromotion单纯为一个超时判断函数，SENTINEL_FAILOVER_STATE_WAIT_PROMOTION->SENTINEL_FAILOVER_STATE_RECONF_SLAVES的状态转换在INFO命令的回调函数中执行，上文有陈述。

sentinelFailoverReconfNextSlave则是向其他slave发送“SLAVEOF new_master”。

**以上过程的顺序——值得关注一下**

sentinel在判断是否odown时使用自己内存中所保存的其他sentinel的信息。实现中在一个周期中，是先判断odown，而后发送`is-master-down-by-addr`要求更新其他sentinel的信息。也就是说判断时，使用的是陈旧的信息。为什么这样设计？

首先我们注意到，is-master-down-by-addr是异步的，也就是不是发送后阻塞地等待更新。所以先发送`is-master-down-by-addr`,而后立即判断odown，其使用的仍然是陈旧的信息。

其次，因为这是定时的任务，我们询问更新之后，会等待一个时间间隔，而后开始一次新的odown判断，因为这个时间间隔的存在，是有可能使用新的状态信息的。

最后，`is-master-down-by-addr`依赖是否为odown决定是否需要进行leader选举，这是一个硬性的依赖。

以上三点决定了这个顺序。

**failover的leader选举**

这是最后一个部分啦。

请求成为leader的sentinel将自己的epoch+1，然后携带自己的runid和epoch向其他sentinel发送`is-master-down-by-addr`。

其他sentinel会拿着该runid和epoch决定是否把票投给他。其实现在sentinelVoteLeader。

```c
char *sentinelVoteLeader(sentinelRedisInstance *master, uint64_t req_epoch, char *req_runid, uint64_t *leader_epoch) {
    if (req_epoch > sentinel.current_epoch) {
        sentinel.current_epoch = req_epoch;
        sentinelFlushConfig();
        sentinelEvent(LL_WARNING,"+new-epoch",master,"%llu",
            (unsigned long long) sentinel.current_epoch);
    }
    //决定是否投给他
    if (master->leader_epoch < req_epoch && sentinel.current_epoch <= req_epoch)
    {
        sdsfree(master->leader);
        master->leader = sdsnew(req_runid);
        master->leader_epoch = sentinel.current_epoch;
        sentinelFlushConfig();
        sentinelEvent(LL_WARNING,"+vote-for-leader",master,"%s %llu",
            master->leader, (unsigned long long) master->leader_epoch);
        /* If we did not voted for ourselves, set the master failover start
         * time to now, in order to force a delay before we can start a
         * failover for the same master. */
        if (strcasecmp(master->leader,sentinel.myid))
            master->failover_start_time = mstime()+rand()%SENTINEL_MAX_DESYNC;
    }

    *leader_epoch = master->leader_epoch;
    return master->leader ? sdsnew(master->leader) : NULL;
}
```

先来先得票，投票给第一个epoch大于自己的sentinel。






