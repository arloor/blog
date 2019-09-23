---
title: "Redis Cluster实现"
date: 2019-09-23T23:13:50+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

# 文档

redis cluster使用P2P的拓扑结构，集群中每个节点到其他节点都有两个TCP连接，一条接收消息，一条发送消息——这两条tcp连接是单向（单工）的，集群通过这些tcp连接进行信息交换。

首先要确定两点：

1. 我说的都是我知道的（我内存中的状态和信息）
2. 我知道的都是别人告诉我的（别人通过tcp通信告诉我的）

所以，向集群某节点发送`CLUSTER NODE`所拿到的`nodeID`、`ip:port`、`flags`、`config-epoch`、`slots`等信息，都是该节点从内存中拿出来的信息，也就是该节点自己对集群的认知。

而集群信息的传播，则是gossip协议和cluster bus所做的事情。

## slot划分、ASK/MOVED重定向

这些部分不再涉及，以前说到过。

## 节点flag种类

flag是节点状态的表述，有如下几种。flag的实现是一个整数，整数不同位上0或1，表示是否具有该flag。

- **myself**: 该节点我自己，跟别人交互前首先不能忘记哪一个是自己
- **master**: 该节点是主节点
- **slave**: 该节点是从节点，一份拷贝
- **fail?**: 该节点处于PFAIL状态——我认为他可能宕机
- **fail**: 该节点处于FAIL状态——集群大部分节点也告诉我这个节点宕机了
- **handshake**: 别人刚刚告诉我存在该节点，需要我通过PING/PONG去确认
- **noaddr**: 该节点没有IP、PORT信息
- **noflags**: No flags at all.

## 节点间传输的消息类型

1、**MEET消息**：当发送者接收到客户端发送的cluster meet命令时，发送者会向接收者发送meet消息，请求接收加入到发送者所在的集群里。

2、**PING消息**：集群里用来检测相应节点是否在线的消息，每个节点默认每隔一秒从节点列表随机选5个节点，然后对最长时间没有收到PONG回复的节点发送PING消息。此外，如果上次收到某个节点的PONG消息回复的时间，距离当前时间超过了cluster-node-time选项设置的一半，那么会对此节点发送PING消息，这样可以防止节点长期没被随机到，而导致长期没有发送PING检测是否存活。

3、**PONG消息**：当接收者收到发送者发来的meet消息或者ping消息时，为了向发送者确认这条meet消息或ping消息已到达，接收者向发送者返回一条pong消息。另外，一个节点也可以通过向集群广播自己的pong消息来让集群中的其他节点立即刷新关于这个节点的认识、。

4、**FAIL消息**：当一个主节点a判断另外一个主节点b已经进入fail状态时，节点a向集群广播一条关于节点b的fail消息，所有收到这条消息的节点都会立即将节点b标记为已下线。

5、**PUBLISH消息**：当节点接收到一个PUBLISH命令时，节点会执行这个命令，并向集群广播一条PUBLISH消息，所有接收到PUBLISH消息的节点都会执行相同的PUBLISH命令。

6、**FAILOVER_AUTH_REQUEST消息**：当slave的master进入fail状态，slave向集群中的所有的节点发送消息，但是只有master才能给自己投票failover自己的maser。

7、**FAILOVER_AUTH_ACK消息**：当master接收到FAILOVER_AUTH_REQUEST消息，如果发送者满足投票条件且自己在当前纪元未投票就给它投票，返回FAILOVER_AUTH_ACK消息.。

8、**UPDATE消息**：当接收到ping、pong或meet消息时，检测到自己与发送者slots不一致，且发送的slots的纪元过时， 就发送slots中纪元大于发送者的节点信息作为update消息的内容给发送者。

9、**MFSTART消息**：当发送者接收到客户端发送的cluster failover命令时，发送者会向自己的master发送MFSTART消息，进行手动failover。

### 这些消息的struct定义

struct clusterMsg就是消息的定义。struct clusterMsg包含union clusterMsgData。

union clusterMsgData这个共享空间用于存放上述9钟消息对应的struct。

下面解释一下clusterMsg的各个字段：

|字段|含义|
|---|---|
|char sig[4]|消息的签名，固定为”RCmb“（redis cluster message bus）|
|uint32_t totlen;|消息的长度|
|uint16_t ver; |协议版本，当前固定为1|
|uint16_t port;|sender的端口号|
|uint16_t type; |消息类型：PING、PONG、MEET等|
|uint16_t count;|包含的gossip信息的数量，PING、PONG、MEET消息含有该字段|
| uint64_t currentEpoch; |sender所知道的集群当前epoch|
|uint64_t configEpoch;|sender（或其主节点最后所知）的configEpoch|
|uint64_t offset;|异步拷贝的offset|
|char sender[CLUSTER_NAMELEN];|sender的节点NODEID|
|unsigned char myslots[CLUSTER_SLOTS/8];|sender（或其主节点）所持有的slots信息，使用16384bit的bitmap表示|
|char slaveof[CLUSTER_NAMELEN];|sender的主节点的NODEID|
| char myip[NET_IP_STR_LEN]; |sender的IP，或全为0|
| uint16_t cport;|cluster bus的端口，比上面的port大10000|
|uint16_t flags|sender状态标志|
|unsigned char state; | sender视角认为的集群状态：down/ok|
| unsigned char mflags[3]; |Message flags: CLUSTERMSG_FLAG[012]_... |
| union clusterMsgData data;|9种消息类型的载体|

其中union clusterMsgData这个共享空间是9种消息类型的载体。union这个数据结构可以存放不同数据类型，他们共享相同的内存空间。这里的clusterMsgData定义如下：

```
union clusterMsgData {
    /* PING, MEET and PONG */
    struct {
        /* N个clusterMsgDataGossip 的数组，这里设置长度为1，但其实c的数组是可以越界的，所以后面可以用下标N */
        clusterMsgDataGossip gossip[1];
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

该union中包含的各种数据结构的定义如下：   
这里不详细解释，但是看完基本就懂各种消息包含哪些字段了，所以还是很有必要看一下的。

```
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

typedef struct {
    char nodename[CLUSTER_NAMELEN];
} clusterMsgDataFail;

typedef struct {
    uint32_t channel_len;
    uint32_t message_len;
    /* We can't reclare bulk_data as bulk_data[] since this structure is
     * nested. The 8 bytes are removed from the count during the message
     * length computation. */
    unsigned char bulk_data[8];
} clusterMsgDataPublish;

typedef struct {
    uint64_t configEpoch; /* Config epoch of the specified instance. */
    char nodename[CLUSTER_NAMELEN]; /* Name of the slots owner. */
    unsigned char slots[CLUSTER_SLOTS/8]; /* Slots bitmap. */
} clusterMsgDataUpdate;
```

## 心跳(PING/PONG)和gossip消息

redis节点会持续地交换PING和PONG包。这两种消息有相同的结构，仅仅是type字段不同。称PING和PONG为心跳包。

一般情况下发送PING，对方会响应PONG。但也可以直接发送PONG来传播重要的配置，而不要求对方响应。

1.一般情况下一个节点每秒向随机的固定数量的节点发送PING（也收到固定数量节点的PONG），所以不管集群有多少节点，单个节点每秒的PING包数量是固定的。
2. 此外，如果超过NODE_TIMEOUT/2时长没有向一个节点发送PING，会强制向其发送PING  
3. 如果一个超过NODE_TIMEOUT/2时长一个节点没有返回PONG，则认为到该节点的tcp连接出现问题，释放该tcp连接，在下一周期会自动重建。

因为上述原因，如果集群的节点数很大，并且NODE_TIMEOUT被设置得太小，那么PING/PONG的数量将会很大。

PING、PONG包中的gossip信息的格式请看上文clusterMsgDataGossip的定义，他包含sender所知的一些其他节点的基本信息（IP、端口、flags、PING/PONG时间）。

### 对应源码 all in clusterCron()

**1对应的代码片段**

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

**2对应的代码片段**

```c
       //在一个迭代器的遍历中
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

**3对应的代码片段**

```c
       //在一个迭代器的遍历中
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
            freeClusterLink(node->link);
        }
```


## 异常检测：PFAIL和FAIL

**PFAIL**

如果sender向其他节点发送PING后，超过NODE_TIMEOUT仍没有收到pong，则设置该节点为PFAIL。主节点和从节点都能将另一个节点设置成PFAIL。

对应代码片段：

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

为了防止因网络问题发生PFAIL误判——因为网络问题，PING/PONG无法正常传输，cluster会重建等待pong时间超过NODE_TIMEOUT/2的连接——上一节步骤3有说到。

**FAIL**

正如上文所说的，PING/PONG包中含有N个其他节点的gossip信息，包含PING/PONG
时间、flags等信息。其中flags就包含PFAIL、FAIL，通过这种gossip的传播，节点就能向集群其他节点传播自己知道的信息。

如果节点A在NODE_TIMEOUT*2的时间内收到大部分节点将节点B置为PFAIL或FAIL状态，则节点A将节点B置为FAIL，同时向所有可到达的节点发送FAIL消息（FAIL消息格式见上文）。所有收到FAIL消息的节点都会将该节点设置为FAIL。


相关代码：

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

在如下几种情况下，可以消除FAIL标志

- 节点可达，且他是从节点。因为从节点不需要做故障迁移
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
3.  从节点投票请求携带的currentEpoch小于其主节点的currentEpoch的不会被投票

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






