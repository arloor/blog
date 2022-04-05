---
title: "Redis Cluster实现"
date: 2019-09-23T23:13:50+08:00
draft: false
categories: [ "redis"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## redis cluster简介

在我的理解里，redis集群和数据库分库差不多——自动地将key分配到16384个槽（slot），而集群中的每个redis节点存储一部分槽。

为什么是16384个槽？因为redis集群会计算key的CRC16然后取模16384，得到的值即为槽点编号。

redis集群通过这个分片（reshrad）和主从备份机制，实现了较高的可用性、较高的写安全性（或称为写不会丢失、一致性）。

### 可用性

举例3主3从的redis集群，当网络分区发生时，连接到小分区的客户端肯定不能获得正常服务；连接到大分区的客户端，如果大分区中有大部分的主节点，并且缺失的主节点都有相应的从节点在大分区中，则该客户端能获得正常服务——需要等待NODE_TIMEOUT，从节点被选举为主节点或原来的主节点恢复。

集群的设计目标是当少部分节点发生故障时能够继续运行。但是不能解决发生大规模网络分区的情况。

### 写安全性/写不丢失/一致性

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

### ASK/MOVED重定向

我们之前提到，redis cluster会将所有key分散到16384个槽，cluster中每个节点分别承载一部分槽。而客户端可以连接到cluster中的每一个节点，当客户端读写的key不在该连接所指的节点上时，cluster的节点不会代理该读写请求，而是返回重定向响应（IP和端口），由客户端根据该响应去请求正确地址上的节点。在redis中，重定向响应就是ASK和MOVED。

```c
get {n}111
(error) MOVED 3432 99.47.149.25:6419

get {n}222
(error) ASK 3432 99.47.149.26:6425
```

以上就是ASK/MOVED响应真实的长相。MOVED表示，集群的当前状态表明——3432槽点在99.47.149.25:6419的节点上。而ASK响应则只在迁移过程（下一节解释迁移过程）中出现，其语义为——槽点3432正在迁移，你要的{n}222现在不在我这，你去问问（ask）99.47.149.26:6425的节点。一个正确的客户端在遇到ASK重定向时，会先向新节点发送ASKING，然后发送查询。

## 实现

以上是对redis cluster大体上的一个认识，下面开始探究一下redis cluster内部的实现，从黑盒到白盒。

### 宏观介绍

redis cluster是一种P2P的拓扑结构，以一个N个节点的集群为例，每个节点都有N-1条到其他节点的发送（outgoing）tcp连接和N-1条接收（incoming）tcp连接。我们知道tcp连接是全双工通信的，可以在同一时间双向传播消息，但是在redis cluster中，集群内部通信中的每条tcp连接都是单工的。

这些用于集群内部通信的tcp连接共同组成redis cluster bus。虽然官方称他为总线，但他不是总线型地拓扑而是P2P的。这条总线用于传播共计9种类型的消息（下文介绍），用于传播状态，进行协作等。redis称这种通信方式为gossip（闲言碎语），因为确实这种分布式的P2P架构下的通信确实有些混乱和不那么完整。但是通过“版本”来决定丢弃过时消息、认可最新消息，这些闲言碎语最终能让集群达成一致的状态。

### P2P拓扑结构的建立

> N头独狼形成一个狼群

当集群刚刚建立或者有新的节点加入集群时，节点是孤立的，没有到其他节点的连接。我们需要一种“识别”的机制来让集群认可新的节点，创建新的tcp连接用于交换信息。

redis cluster使用两个途径确保让集群中的老节点“认识”新的节点。

**CLUSTER MEET ip port**

`CLUSTER MEET`强制redis节点向指定的地址发送MEET消息，作用相当于：你好，我的nodeName是xxx，我在某IP某端口。

目标节点收到该MEET消息后，两者就会建立通信的连接。

**Gossip传播**

不需要向所有节点发送MEET消息，仅仅需要发送若干个MEET消息。redis cluster bus会自己通过gossip将该新发现的节点信息发送给其他节点。这样其他节点就得知该新节点的存在，从而建立tcp连接，最终形成完整的P2P拓扑结构。

这里是时候简单介绍下什么是gossip了。

gossip是八卦、闲言碎语的意思。聊天和通信只有涉及聊天双方之外的第三人的信息才能称为闲话、八卦。在redis cluster中，gossip的含义就是A向B发送消息时，会告诉B他知道的C、D的情况。这些情况具体包含哪些字段，下文再介绍。

总之，通过手动MEET和自动Gossip传播，新节点信息最终传播给了集群每个节点。当然Gossip传播会在更多场景下发挥作用，例如主节点宕机检测等。

这里预先额外说明一点，大家都在八卦地发送gossip，那么怎么确定谁说的是“真的”？这是通过“版本”来实现的，在redis中用epoch（纪元）表示。大家形成一个共识：新epoch的消息是正确的，接收新纪元消息，拒绝旧纪元消息。

### 消息格式

> 狼群内部的语言

上一节中redis节点之间成功建立了tcp连接，这一节将继续介绍建立连接后，他们会交换什么信息以完成协作。这一节使用了很长篇幅介绍各种消息，可能会很烦人。但是我觉得还是有必要的，毕竟分布式协作的本身就是消息传来传去。看这一节不需要看懂并记住，可以先大略看一下就往后。后面需要的时候再回头。

首先介绍六种通过redis cluster bus传播的消息类型（这不是全部）。他们的c语言定义由clusterMsg（struct）、clusterMsgData、clusterMsgDataGossip等组合而成。具体字段如下：

**clusterMsg**

|字段|含义|
|-----| -----|
|char sig[4]|消息的签名，固定为”RCmb“（redis cluster message bus）|
|uint32_t totlen;|消息的长度|
|uint16_t ver; |协议版本，当前固定为1|
|uint16_t port;|sender的端口号|
|uint16_t type; |消息类型：PING、PONG、MEET等|
|uint16_t count;|包含的gossip信息的数量，PING、PONG、MEET消息含有该字段|
| uint64_t currentEpoch; |sender所知道的集群当前epoch|
|uint64_t configEpoch;|sender（或其最后所知的其主节点）的configEpoch|
|uint64_t offset;|异步拷贝的offset|
|char sender[CLUSTER_NAMELEN];|sender的节点NODEID|
|unsigned char myslots[CLUSTER_SLOTS/8];|sender（或其主节点）所持有的slots信息，使用16384bit的bitmap表示|
|char slaveof[CLUSTER_NAMELEN];|sender的主节点的NODEID|
|char myip[NET_IP_STR_LEN]; |sender的IP，或全为0|
|uint16_t cport;|cluster bus的端口，比上面的port大10000|
|uint16_t flags|sender状态标志|
|unsigned char state; | sender视角认为的集群状态：down/ok|
|unsigned char mflags[3]; |Message flags: CLUSTERMSG_FLAG[012]_... |
|union clusterMsgData data;|9种消息类型的载体|

clusterMsg的前17个字段是所有类型消息都有的字段，最后一个字段`data`的类型是`union clusterMsgData`。

**union clusterMsgData**

union是共享空间的意思，多种不同的struct存放在相同的内存空间。`clusterMsgData`的定义如下：

```c
union clusterMsgData {
    /* PING, MEET and PONG */
    struct {
        /* Array of N clusterMsgDataGossip structures */
        clusterMsgDataGossip gossip[1];  //c语言的数组是无界的，这里长度写1，但后面使用可以自由越界到N。
    } ping;

    /* FAIL */
    struct {
        clusterMsgDataFail about;
    } fail;

    /* PUBLISH */
    struct {
        clusterMsgDataPublish msg;
    } publish;

    /* UPDATE */
    struct {
        clusterMsgDataUpdate nodecfg;
    } update;
};
```

可以看到该共享空间可以存放9种不同类型的data，对应于`clusterMsg`中的`type`字段。

**clusterMsgDataGossip**

这是PING、PONG、MEET类型消息中的data，也是所谓的八卦和闲话，是sender所知的其他节点的信息。其定义如下：

```c
typedef struct {
    char nodename[CLUSTER_NAMELEN];
    uint32_t ping_sent;
    uint32_t pong_received;
    char ip[NET_IP_STR_LEN];  /* IP address last time it was seen */
    uint16_t port;              /* base port last time it was seen */
    uint16_t cport;             /* cluster port last time it was seen */
    uint16_t flags;             /* node->flags copy */
    uint32_t notused1;
} clusterMsgDataGossip;
```

可以gossip看到包含的信息有：nodename、心跳信息(ping、pong)、地址、flags。

PING、PONG两种类型的消息被称为心跳，会用于判断tcp连接是否需要重连和节点是否宕机。MEET消息除了类型外其实和PING、PONG一模一样，但是他多了“使接受新节点”的语义，上一节有叙。

**clusterMsgDataFail**

我们刚刚提到PING、PONG心跳可用于判断节点是否宕机。如果节点A判断节点B宕机（FAIL），则其会向所有节点发送FAIL消息。收到FAIL消息的所有节点都会将B标记为宕机（FAIL）

```c
typedef struct {
    char nodename[CLUSTER_NAMELEN];
} clusterMsgDataFail;
```

**clusterMsgDataPublish**

redis也是一个稳定可靠的发布订阅系统。PUBLISH类型的消息就是用于在cluster中传播发布订阅的消息，使每个节点都能发布相同的消息。

```c
typedef struct {
    uint32_t channel_len;
    uint32_t message_len;
    /* We can't reclare bulk_data as bulk_data[] since this structure is
     * nested. The 8 bytes are removed from the count during the message
     * length computation. */
    unsigned char bulk_data[8];
} clusterMsgDataPublish;
```

**clusterMsgDataUpdate**

当A收到B发来的消息并发现消息中的版本（configEpoch）小于自己目前所知的，则说明B的状态过时了，此时回向B发送UPDATE消息，携带A所知的版本（configEpoch）和slots位图，要求B更新自己的状态。

```c
typedef struct {
    uint64_t configEpoch; /* Config epoch of the specified instance. */
    char nodename[CLUSTER_NAMELEN]; /* Name of the slots owner. */
    unsigned char slots[CLUSTER_SLOTS/8]; /* Slots bitmap. */
} clusterMsgDataUpdate;
```

### 心跳机制

PING、PONG消息实现了redis cluster中的心跳机制。cluster中的心跳机制主要用于判断节点是否宕机以决定是否需要fail over（故障迁移）。当然PING、PONG包中的gossip内容用以传播节点状态也是PING、PONG不可忽略的作用。

心跳发送PING包和检测PONG响应时间都在`clusterCron`中，下面结合源码介绍其中机制：

**随机选取节点，发送PING**

一般情况下一个节点每秒向随机的固定数量的节点发送PING（也收到固定数量节点的PONG），所以不管集群有多少节点，单个节点每秒的PING包数量是固定的。

```c
    /* Ping some random node 1 time every 10 iterations, so that we usually ping
     * one random node every second. */
    if (!(iteration % 10)) {
        int j;

        /* Check a few random nodes and ping the one with the oldest
         * pong_received time. */
        for (j = 0; j < 5; j++) {
            de = dictGetRandomKey(server.cluster->nodes);
            clusterNode *this = dictGetVal(de);

            /* Don't ping nodes disconnected or with a ping currently active. */
            if (this->link == NULL || this->ping_sent != 0) continue;
            if (this->flags & (CLUSTER_NODE_MYSELF|CLUSTER_NODE_HANDSHAKE))
                continue;
            if (min_pong_node == NULL || min_pong > this->pong_received) {
                min_pong_node = this;
                min_pong = this->pong_received;
            }
        }
        if (min_pong_node) {
            serverLog(LL_DEBUG,"Pinging node %.40s", min_pong_node->name);
            clusterSendPing(min_pong_node->link, CLUSTERMSG_TYPE_PING);
        }
    }
```

**查漏补缺，PING长时间没有PING过的节点**

如果超过NODE_TIMEOUT/2时长没有向一个节点发送PING，会强制向其发送PING  

```c
       //在node的遍历中
        /* If we have currently no active ping in this instance, and the
         * received PONG is older than half the cluster timeout, send
         * a new ping now, to ensure all the nodes are pinged without
         * a too big delay. */
        if (node->link &&
            node->ping_sent == 0 &&
            (now - node->pong_received) > server.cluster_node_timeout/2)
        {
            clusterSendPing(node->link, CLUSTERMSG_TYPE_PING);
            continue;
        }
```

**长时间没有收到PONG，怀疑tcp连接断开，重建连接**

长时间没有收到PONG，要么tcp连接出现问题，要么目标节点宕机导致无法响应心跳。首先怀疑tcp连接出现问题，进行重建。

如果一个超过NODE_TIMEOUT/2时长一个节点没有返回PONG，则认为到该节点的tcp连接出现问题，释放该tcp连接，在下一`clusterCron`会自动重建。

```c
       //在node的遍历中
        /* If we are waiting for the PONG more than half the cluster
         * timeout, reconnect the link: maybe there is a connection
         * issue even if the node is alive. */
        if (node->link && /* is connected */
            now - node->link->ctime >
            server.cluster_node_timeout && /* was not already reconnected */
            node->ping_sent && /* we already sent a ping */
            node->pong_received < node->ping_sent && /* still waiting pong */
            /* and we are waiting for the pong more than timeout/2 */
            now - node->ping_sent > server.cluster_node_timeout/2)
        {
            /* Disconnect the link, it will be reconnected automatically. */
            //此处断开连接，下个clusterCron会自动重建
            freeClusterLink(node->link);
        }
```

### 主节点宕机检测

原主节点宕机，从节点可以接替原主节点工作，这是redis可用性的实现机制。这首先要及时检测到主节点宕机检测。

在cluster中标记节点宕机状态的flag有PFAIL和FAIL，这和sentinel中的sdown和odown很像——PFAIL：我认为该节点挂了，那就可能挂了；FAIL：大家都告诉我他挂了，那他确实挂了。sentinel和cluster确实有些像，例如宕机检测、选举、epoch等。

**何时设置PFAIL**

如果sender向其他节点发送PING后，超过NODE_TIMEOUT仍没有收到pong，则设置该节点为PFAIL。主节点和从节点都能将另一个节点设置成PFAIL。

```c
        if (delay > server.cluster_node_timeout) {
            /* Timeout reached. Set the node as possibly failing if it is
             * not already in this state. */
            if (!(node->flags & (CLUSTER_NODE_PFAIL|CLUSTER_NODE_FAIL))) {
                serverLog(LL_DEBUG,"*** NODE %.40s possibly failing",
                    node->name);
                node->flags |= CLUSTER_NODE_PFAIL;
                update_state = 1;
            }
        }
```

上一节，我们提到如果NODE_TIMEOUT/2的时间没有收到PONG，则首先重建到目标节点的outgoing连接，这能再一定程度避免因网络问题导致的PFAIL误判。

**何时设置FAIL**

正如上文所说的，PING/PONG包中含有N个其他节点的gossip信息，包含PING/PONG
时间、flags等信息。其中flags就包含PFAIL、FAIL，通过这种gossip的传播，节点就能向集群其他节点传播自己知道的信息。

如果节点A在NODE_TIMEOUT*2的时间内收到大部分节点将节点B置为PFAIL或FAIL状态，则节点A将节点B置为FAIL，同时向所有可到达的节点发送FAIL消息（FAIL消息格式见上文）。所有收到FAIL消息的节点都会将该节点设置为FAIL。

```c
void clusterProcessGossipSection(clusterMsg *hdr, clusterLink *link) {
   ...
        if (node) {
            //根据消息中的clusterMsgDataGossip更新节点状态
            if (sender && nodeIsMaster(sender) && node != myself) {
                if (flags & (CLUSTER_NODE_FAIL|CLUSTER_NODE_PFAIL)) {
                    if (clusterNodeAddFailureReport(node,sender)) {//在这个节点的fail_reports里加入sender
                    }
                    markNodeAsFailingIfNeeded(node);//判断在这个节点的fail_reports，将节点标记为fail
                } else {
                    if (clusterNodeDelFailureReport(node,sender)) {//在这个节点的fail_reports里删除sender
                    }
                }
            }
            ……
        } else {//节点不存在，开始handshake(主要是接收到meet消息，与gossip中的节点进行handshake)
            if (sender &&!(flags & CLUSTER_NODE_NOADDR) &&!clusterBlacklistExists(g->nodename))
            {   
                clusterStartHandshake(g->ip,ntohs(g->port),ntohs(g->cport));
            }
        }
...
}

void markNodeAsFailingIfNeeded(clusterNode *node) {
    int failures;
    int needed_quorum = (server.cluster->size / 2) + 1;

    if (!nodeTimedOut(node)) return; /* We can reach it. */
    if (nodeFailed(node)) return; /* Already FAILing. */

    failures = clusterNodeFailureReportsCount(node);
    /* Also count myself as a voter if I'm a master. */
    if (nodeIsMaster(myself)) failures++;
    if (failures < needed_quorum) return; /* No weak agreement from masters. */

    serverLog(LL_NOTICE,
        "Marking node %.40s as failing (quorum reached).", node->name);

    /* Mark the node as failing. */
    node->flags &= ~CLUSTER_NODE_PFAIL;
    node->flags |= CLUSTER_NODE_FAIL;
    node->fail_time = mstime();

    /* Broadcast the failing node name to everybody, forcing all the other
     * reachable nodes to flag the node as FAIL. */
    if (nodeIsMaster(myself)) clusterSendFail(node->name);
    clusterDoBeforeSleep(CLUSTER_TODO_UPDATE_STATE|CLUSTER_TODO_SAVE_CONFIG);
}
```

**何情况下，消除FAIL标志**

- 节点可达，且他是从节点。因为从节点不需要被failover
- 节点可达，且他是没有负责slots的主节点。在这种情况下，该主节点没有真正参与集群，且在等待配置以加入集群工作
- 节点可达并且是主节点，但超过N*NODE_TIMEOUT没有进行failover。这时最好将该主节点重新加入集群。

相关代码：

```c
/* This function is called only if a node is marked as FAIL, but we are able
 * to reach it again. It checks if there are the conditions to undo the FAIL
 * state. */
void clearNodeFailureIfNeeded(clusterNode *node) {
    mstime_t now = mstime();

    serverAssert(nodeFailed(node));

    /* For slaves we always clear the FAIL flag if we can contact the
     * node again. */
    if (nodeIsSlave(node) || node->numslots == 0) {
        serverLog(LL_NOTICE,
            "Clear FAIL state for node %.40s: %s is reachable again.",
                node->name,
                nodeIsSlave(node) ? "slave" : "master without slots");
        node->flags &= ~CLUSTER_NODE_FAIL;
        clusterDoBeforeSleep(CLUSTER_TODO_UPDATE_STATE|CLUSTER_TODO_SAVE_CONFIG);
    }

    /* If it is a master and...
     * 1) The FAIL state is old enough.
     * 2) It is yet serving slots from our point of view (not failed over).
     * Apparently no one is going to fix these slots, clear the FAIL flag. */
    if (nodeIsMaster(node) && node->numslots > 0 &&
        (now - node->fail_time) >
        (server.cluster_node_timeout * CLUSTER_FAIL_UNDO_TIME_MULT))
    {
        serverLog(LL_NOTICE,
            "Clear FAIL state for node %.40s: is reachable again and nobody is serving its slots after some time.",
                node->name);
        node->flags &= ~CLUSTER_NODE_FAIL;
        clusterDoBeforeSleep(CLUSTER_TODO_UPDATE_STATE|CLUSTER_TODO_SAVE_CONFIG);
    }
}
```

## 配置处理、传播和Failover

### currentEpoch

redis cluster使用epoch（纪元）的来递增地标记配置信息的版本——类似raft算法中的term。当多个节点提供不同epoch的配置信息时，其他节点知道更大epoch的配置信息是更新的。

`currentEpoch` 是一个64位无符号整数。在节点创建伊始，currentEpoch被设置为0
。随后当收到其他节点发来的包时，当检测到sender的epoch大于自己的，curentEpoch将会被设置为sender的epoch。通过这些机制，最终集群的所有节点都会有统一的最大的epoch。

这种一致性用于当集群状态发生变化，一个节点需要征得其他节点同意来执行一些操作的时候（当前仅执行FAILOVER）

### configEpoch

每个主节点在PING、PONG包中都会携带configEpoch和slots分布的bitmap。

在新节点被创建时，configEpoch会被设置为0。   
新的configEpoch在从节点选举时会被创建。试图代替主节点的从节点会增加自己的configEpoch然后尝试从大部分主节点获取认可。当一个从节点被认可时，一个新的独一无二的configEpoch被创建，并在该从节点成为主节点，使用该configEpoch。

使用configEpoch可以解决节点由网络分区和节点短暂宕机后恢复造成的不同配置信息的冲突——configEpoch大的胜利。

从节点也会在PING、PONG包中携带configEpoch字段，但是从节点的configEpoch字段代表上次他的主节点的configEpoch（主从最后一次通信告知的）。   如果其他主节点发现从节点的configEpoch较旧，则不会把票投给该从节点。

每次configEpoch改变被传播到其他节点时，该配置都会被持久化到node.conf文件。

### 从节点选举和晋升

当从节点将自己的主节点状态置为FAIL，并且自己满足成为主节点的条件时就会发起一次选举，请求执行failover，成为主节点。

发起选举的条件如下：

1. 从节点的主节点为FAIL
2. 主节点负责N个slots，而不是0个slots
3. 从节点到主节点连接的断开时间小于某一值。该值由用户配置，用于确保从节点的数据较新

为了被选举，slave的第一步是增加自己的currentEpoch，并且请求其他主节点的投票。

从节点会向所有主节点发送FAILOVER_AUTH_REQUEST 消息来请求投票，然后他会等待2*NODE_TIMEOUT的时间来获取主节点们的回复。

一旦一个主节点投票给一个从节点（回复FAILOVER_AUTH_ACK），在2*NODE_TIMEOUT的时间内k，他不能再投票给其他从节点。从节点会丢弃任何epoch小于currentEpoch的AUTH_ACK回复。这确保了从节点不会计算之前的投票。

一旦从节点从大多数主节点获得投票，他赢得选举。否则这次选举退出，一个新的选举在4*NODE_TIMEOUT后会开始。

相关代码在`clusterHandleSlaveFailover`，太长不贴。

### Slave rank

当主节点在FAIL状态，从节点会等待一小段时间而后开始选举。该段时间的长度计算方式如下：

```
DELAY = 500 milliseconds + random delay between 0 and 500 milliseconds +
        SLAVE_RANK * 1000 milliseconds.
```

**固定delay**：等待FAIL状态传播到所有其他主节点，否则其他主节点不会进行投票
**随机delay**：防止不同的从节点同时发起选举
**SLAVE_RANK**：根据异步拷贝的偏移量决定的排名，有更新的偏移量则排名越高（值越小）

根据这三个参数计算出来的选举延迟会让每个试图发起选举的从节点在不同的时间发起选举。

一旦一个从节点赢得选举，他获得一个新的独一无二的configEpoch。他会通过PING、PONG向其他节点宣告自己是主节点，并携带configEpoch和自己携带的slots。为了更快的更新其他节点的配置信息，该新主节点会立刻向其他节点发送PONG包。当前不可达的节点在网络恢复后会最终更新自己的配置，因为当他向其他节点发送更旧得配置信息时，会收到UPDATE消息。

相关代码：

```c
int clusterGetSlaveRank(void) {
    long long myoffset;
    int j, rank = 0;
    clusterNode *master;

    serverAssert(nodeIsSlave(myself));
    master = myself->slaveof;
    if (master == NULL) return 0; /* Never called by slaves without master. */

    myoffset = replicationGetSlaveOffset();
    for (j = 0; j < master->numslaves; j++)
        if (master->slaves[j] != myself &&
            master->slaves[j]->repl_offset > myoffset) rank++;
    return rank;
}
```

## 主节点投票

以上是从节点的表现，该节描述主节点如何投票给从节点

主节点收到从节点发来的FAILOVER_AUTH_REQUEST 后，需要满足如下几个条件：

1. 主节点在一个currentEpoch只会投票一次，只有从节点携带的currentEpoch大于lastVoteEpoch 才会投票——这和Sentinel中一致
2. 只有请求投票的从节点的主节点为FAIL才会投票
3. 从节点投票请求携带的currentEpoch小于其主节点的currentEpoch的不会被投票

其实现在`clusterSendFailoverAuthIfNeeded`

## clusterCron()总结

仍然从serverCron进入clusterCron执行的部分。

clusterCron按顺序做如下几件事情：

1. 如果有通过`CONFIG SET`命令设置`cluster_announce_ip`，则将该IP设置到`myself->ip`
2. 遍历`server.cluster->nodes`中的节点
    1. 如果节点的flag包含PFAIL，stats_pfail_nodes加一
    2. 如果节点在HANDESHAKE状态，且握手已经超时，则使用`clusterDelNode`删除内存中该节点的信息
    3. 如果自己到该节点的tcp连接为null，则创建tcp连接。
        1. 并设置该连接的“readable”可读事件回调为`clusterReadHandler`。
        2. 如果该节点flag包含`CLUSTER_NODE_MEET`，则发送一次MEET报文，随后消除`CLUSTER_NODE_MEET`flag。
        3. 如果该节点不包含`CLUSTER_NODE_MEET`flag，则发送一次PING报文。
3. 随机挑选一个连接状态正常、不在HANDESHAKE状态、不在等待pong响应报文的节点，向其发送PING报文
4. 再次遍历`server.cluster->nodes`中的节点
    1. 跳过自己、没有地址信息的、在HANDSHAKE状态的节点
    2. 如果自己是从节点、目标节点为主节点且状态正常，
        1. 则统计该节点的正常slave的数量（okslaves）
        2. 如果okslaves为0，且承载的slots数量不为0，且包含`CLUSTER_NODE_MIGRATE_TO`flag，那么orphaned_masters（孤儿主节点、没有有效slave的节点）计数加一。
        3. 检查并设置max_slaves（主节点最大slaves数量）、this_slaves（自己的主节点的slave数量）计数
    3. 判断如果等待PONG响应过长时间，则主动断开连接，将在下一clusterCron重连——应用层心跳机制
    4. 如果过长时间没有发送PING，则发送PING，随后`continue;`开始操作下一节点
    5. 如果在等待PONG响应，则继续执行以下操作，否则`continue;`操作下一节点
        1. 如果等待PONG响应的时间超过超时时间，则设置该节点`CLUSTER_NODE_PFAIL`flag。同时设置需要更新cluster状态（update_state = 1）
5. 如果自己是从节点，且主节点重新上线，则调用`replicationSetMaster`，设置主节点的IP和PORT。——在`replicationCron()`中，将会主动连接该地址，进行拷贝操作。
6. 如果manual failover超时，则退出该次failover
7. 如果自己为从节点
    1. 处理手动failover clusterHandleManualFailover()
    2. 自动failover clusterHandleSlaveFailover()
    3. 如果自己的主节点的从节点数量最多，同时集群中有孤儿主节点，则尝试把自己迁移为该孤儿主节点的从节点。
8. 如果cluster状态需要更新，则进行更新。if (update_state || server.cluster->state == CLUSTER_FAIL)...


以上步骤，没有stepinto执行细节，是在阅读clusterCron代码和注释后总结的。

### clusterSendPing

```
void clusterSendPing(clusterLink *link, int type) 
```

向指定node的连接发送PING、PONG消息，包含足够的gossip信息。


gossip信息会包含若干个自己知道的其他节点的信息，gossip信息包含的字段见文末附录

## 处理收到的消息

前面我们提到，重建到其他redis节点的连接后，会设置可读事件的回调为`clusterProcessPacket`。该函数最终会调用clusterProcessPacket消费读取到的消息。下面来看下redis收到各种消息后，会做出什么处理。

**First Step**

1. 首先做一些消息格式的验证
2. 判断消息长度是否符合预期
3. 如果消息发送者已经存在自己的内存中，则做
    1. 如果消息中的currentEpoch大于内存中的，则更新内存中的currentEpoch（cluster的属性）
    2. 如果消息中的发送者的configEpoch大于内存中，则更新内存中发送者的configEpoch（node的属性）
    3. 更新sender的repl_offset和repl_offset_time，这是异步拷贝的offset
    4. 如果我是sender的slave，且正在执行manual failover，此时sender发送来的offset将被存入`server.cluster->mf_master_offset`

**Second Step——初步处理PING和MEET**

针对PING和MEET做以下：

1. 如果是MEET，则从该连接的socket文件描述符得出连接的本地IP，将其设置为我的IP，而不是硬编码配置IP信息
2. 如果是MEET且内存中没有改发送者的信息，则调用`createClusterNode`和`clusterAddNode`，增加该节点信息
3. 如果是MEET且内存中没有该发送者的信息，还是调用`clusterProcessGossipSection`处理Gossip部分的消息（sender所知道的关于其他节点的信息）
4. 回复PONG

**Third Step——处理PING、PONG、MEET中的配置信息**

1. 如果sender信息在内存中存在
    1. 如果sender在HANDSHAKE状态，则检查IP、端口是否需要更新，同时更新sender的节点名;删除节点，返回0；标志HANDSHAKE完成。
    2. 如果没有匹配的IP和端口，设置`CLUSTER_NODE_NOADDR`flag
2. 更新sender地址信息
3. 更新sender的主从角色，如果主变从则删除slots信息；如果从变主则更新其flag为master；如果主节点发生变更，更新主节点信息
4. 检查并更新sender的slots分布，如果内存中的sender的configEpoch大于sender发送的，且slot分布不同，则向sender发送update报文。
5. 如果我和sender都是主节点，且configEpoch相同，则处理这种冲突
6. 从消息的gossip部分获取信息

**Fourth Step——处理FAIL消息**

更新sender所说的node状态为fail

**Fifth Step——处理PUBLISH消息**

发布该PUB/SUB消息

**Sixth Step——处理UPDATE消息**

更新主从角色，更新slots分布

### 处理gossip部分消息

clusterProcessGossipSection负责处理PING和PONG消息中的gossip信息

Gossip部分包含如下字段：

```c
    char nodename[CLUSTER_NAMELEN];
    uint32_t ping_sent;
    uint32_t pong_received;
    char ip[NET_IP_STR_LEN];  /* IP address last time it was seen */
    uint16_t port;              /* base port last time it was seen */
    uint16_t cport;             /* cluster port last time it was seen */
    uint16_t flags;             /* node->flags copy */
    uint32_t notused1;
```

源码+解析

```c
void clusterProcessGossipSection(clusterMsg *hdr, clusterLink *link) {
    uint16_t count = ntohs(hdr->count);
    clusterMsgDataGossip *g = (clusterMsgDataGossip*) hdr->data.ping.gossip;
    clusterNode *sender = link->node ? link->node : clusterLookupNode(hdr->sender);
    while(count--) {
        ……      
        node = clusterLookupNode(g->nodename);
        if (node) {
            //根据消息中的clusterMsgDataGossip更新节点状态
            if (sender && nodeIsMaster(sender) && node != myself) {
                if (flags & (CLUSTER_NODE_FAIL|CLUSTER_NODE_PFAIL)) {
                    if (clusterNodeAddFailureReport(node,sender)) {//在这个节点的fail_reports里加入sender
                    }
                    markNodeAsFailingIfNeeded(node);//判断在这个节点的fail_reports，将节点标记为fail
                } else {
                    if (clusterNodeDelFailureReport(node,sender)) {//在这个节点的fail_reports里删除sender
                    }
                }
            }
            ……
        } else {//节点不存在，开始handshake(主要是接收到meet消息，与gossip中的节点进行handshake)
            if (sender &&!(flags & CLUSTER_NODE_NOADDR) &&!clusterBlacklistExists(g->nodename))
            {   
                clusterStartHandshake(g->ip,ntohs(g->port),ntohs(g->cport));
            }
        }
        g++;
    }
}
```

