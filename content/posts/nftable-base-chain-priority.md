---
title: "Nftables基础链的优先级与默认策略"
subtitle:
tags:
  - undefined
date: 2025-04-24T14:58:23+08:00
lastmod: 2025-04-24T14:58:23+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
---

- [nftables wiki: Configuring chains](https://wiki.nftables.org/wiki-nftables/index.php/Configuring_chains#Base_chain_priority)
- [Netfilter 架构与 iptables/ebtables 入门](https://mp.weixin.qq.com/s/uzuRM9YHkKeyO6RC7XSdPQ)
- [iptables 与 netfilter](https://www.thebyte.com.cn/content/chapter1/netfilter.html#iptables)

<!--more-->

## iptables 四表五链

![alt text](/img/iptables-packet-routing.png)

### 四表

1. **filter 表** - 默认表，主要用于过滤数据包。控制允许或拒绝数据包通过。

   - 包含链：INPUT, FORWARD, OUTPUT

2. **nat 表** - 网络地址转换，修改数据包的源或目标地址。

   - 包含链：PREROUTING, POSTROUTING, OUTPUT
   - 主要用于实现 SNAT（源地址转换）和 DNAT（目标地址转换）

3. **mangle 表** - 专门用于修改数据包的 IP 头信息。

   - 包含链：PREROUTING, INPUT, FORWARD, OUTPUT, POSTROUTING
   - 可以修改 TTL, TOS 等 IP 头字段

4. **raw 表** - 主要用于配置免除连接跟踪机制。
   - 包含链：PREROUTING, OUTPUT
   - 优先级最高，数据包到达时首先被 raw 表处理

### 五链

1. **PREROUTING** - 数据包进入网络栈时立即触发此链

   - 存在于：nat 表、mangle 表、raw 表
   - 主要用于 DNAT 操作

2. **INPUT** - 处理流向本机的数据包

   - 存在于：filter 表、mangle 表
   - 主要用于保护本机服务

3. **FORWARD** - 处理经过本机转发的数据包

   - 存在于：filter 表、mangle 表
   - 主要用于路由器/防火墙功能

4. **OUTPUT** - 处理本机产生的出站数据包

   - 存在于：filter 表、nat 表、mangle 表、raw 表
   - 控制本机对外连接

5. **POSTROUTING** - 处理即将离开网络栈的数据包
   - 存在于：nat 表、mangle 表
   - 主要用于 SNAT 操作

### 数据包流向路径

1. **进入本机的数据包**：PREROUTING → INPUT → 本地进程
2. **转发的数据包**：PREROUTING → FORWARD → POSTROUTING → 其他主机
3. **本地产生的数据包**：本地进程 → OUTPUT → POSTROUTING → 发出

## nftables 中的表链设计

nftables 采用了更灵活的设计，没有严格遵循 iptables 的"四表五链"概念。

### nftables 的基本设计

1. **表(Table)** - 在 nftables 中，表只是命名空间，没有预定义的功能限制

   - 用户可以创建任意名称的表
   - 表必须指定家族(family)：ip, ip6, inet, arp, bridge, netdev 等

2. **链(Chain)** - nftables 中的链更加灵活

   - 基本链(Base chains)：类似于 iptables 的五链，但可以自定义。基础链的 `表 + 协议族 + hook点 + 优先级` 必须是唯一的
   - 常规链(Regular chains)：用户定义的链，可以从其他链跳转到这些链

3. **规则(Rules)** - 定义在链中的过滤或修改数据包的具体操作

### nftables 中的 Chain 的 type 属性

nftables 中的`type`是链的一个关键属性，定义了链的类型和挂载点，决定了链在网络栈中的位置和处理时机。

主要的链类型包括：

1. **filter** - 用于过滤数据包

   - 可用于所有协议家族
   - 类似于 iptables 的 filter 表功能

2. **route** - 用于在路由决策后但在发送前修改数据包

   - 仅适用于 ip 和 ip6 家族
   - 可以改变路由决策

3. **nat** - 用于网络地址转换

   - 分为`snat`和`dnat`两种变体
   - 类似于 iptables 的 nat 表功能

## hook 点

- `prerouting`：数据包进入时
- `input`：发往本机的数据包
- `forward`：转发的数据包
- `output`：本机发出的数据包
- `postrouting`：数据包离开前
- `ingress`：在网络设备驱动层处理进入的数据包(netdev 家族特有)

## accept/deny 策略

- accept：表示继续后续的判断（并不代表放行该 packet）
- deny： 表示立即拒绝，并且不再执行后续的判断

这意味着如果有两条 type、hook 相同的链，无论哪个链的优先级高，只要其中一个链中该 packet 被 accept（无论是 chain 的默认策略，还是命中某个 rule），但另一个链中该 packet 被 drop。这个 packet 依然会被 drop。

详见：[nftables wiki: Base_chain_priority](https://wiki.nftables.org/wiki-nftables/index.php/Configuring_chains#Base_chain_priority)
