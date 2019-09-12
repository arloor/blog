---
title: "Sentinel文档"
date: 2019-09-12T18:25:31+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

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

1. 首先 断开时间大于`(down-after-milliseconds * 10) + milliseconds_since_master_is_in_SDOWN_state`的从节点没有资格。
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









