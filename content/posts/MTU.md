---
title: "MTU详解"
date: 2025-10-22T14:05:02+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

MTU (Maximum Transmission Unit) 是网络通信中的一个关键参数。本文将通过实际案例，深入探讨 MTU 的工作机制、Path MTU Discovery (PMTUD) 协议，以及在 PPPoE 家庭网络环境下的实际应用。

<!--more-->

## 一、MTU 基础概念

### 1.1 什么是 MTU

MTU（Maximum Transmission Unit，最大传输单元）是**网络接口的配置参数**，定义了数据链路层（第 2 层）能够传输的最大数据包大小。需要注意的是，MTU **本身不在任何协议的包头中传递**，这是一个常见的误解。

**常见的 MTU 值：**

- 标准以太网：1500 字节
- PPPoE 连接：1492 字节（需要额外 8 字节 PPPoE 头部）
- Jumbo Frame：9000 字节

### 1.2 MTU 的实际含义

我们通常说的 MTU 是**指 IP 层的最大传输单元，不包括数据链路层的开销**。例如：

- IP 层 MTU：1500 字节
- 加上以太网帧头部：14 字节
- 加上帧校验序列（FCS）：4 字节
- **完整的以太网帧**：1518 字节

### 1.3 如何查看和测试 MTU

**Windows 系统查看 MTU：**

```powershell
# 方法 1：查看网络接口 MTU
netsh interface ipv4 show subinterfaces

# 方法 2：使用 PowerShell
Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceIndex, NlMtu
```

**使用 Ping 测试实际 MTU：**

```powershell
# 测试最大不分片包大小
ping -f -l 1464 www.baidu.com
```

参数说明：

- `-f`：设置 DF (Don't Fragment) 标志，不允许分片
- `-l 1464`：指定数据包大小

**包大小计算：**

- ICMP 数据：1464 字节
- IP 头部：20 字节
- ICMP 头部：8 字节
- **总 MTU**：1492 字节

这就是为什么家庭 PPPoE 宽带的实际 MTU 是 1492 字节，而不是网卡配置的 1500 字节。

## 二、MTU 在网络协议栈中的位置

### 2.1 MTU 不在协议包头中传递

MTU 本身不作为字段存在于任何协议的包头中，但以下字段与 MTU 机制相关：

#### IP 层相关字段

**IPv4：**

- **Total Length 字段**（16 位）：指示整个 IP 数据包的长度
- **Don't Fragment (DF) 标志位**：当设置时，路由器不能分片该数据包
- **Fragment Offset 字段**：用于 IP 分片重组

**IPv6：**

- **Payload Length 字段**（16 位）：指示 IPv6 载荷长度
- **注意**：IPv6 不支持路由器分片，必须在源端处理

#### ICMP 协议

**Path MTU Discovery 通过 ICMP 消息实现：**

当路由器因数据包超过 MTU 且设置了 DF 标志而丢弃数据包时：

1. 路由器发送 **ICMP Type 3 Code 4**（目标不可达 - 需要分片但设置了 DF）消息
2. 该 ICMP 消息的 **Next-Hop MTU 字段**（16 位）携带链路的 MTU 值

这是 **Path MTU Discovery** 机制的核心部分。

#### TCP 层

**MSS (Maximum Segment Size) 选项：**

- 在 TCP 三次握手的 SYN 包中传递
- 出现在 TCP Options 字段中
- 格式：Kind=2，Length=4，后跟 16 位 MSS 值
- 计算公式：**MSS = MTU - IP 头部 (20) - TCP 头部 (20)**
- 典型值：1460 字节（基于 1500 字节 MTU）

### 2.2 MTU 的工作流程

```
发送端：
1. 查询本地接口 MTU（如 1500 字节）
2. 计算 TCP MSS = 1500 - 20(IP) - 20(TCP) = 1460
3. 在 SYN 包的 TCP 选项中发送 MSS=1460

中间路由器：
1. 接收到大于链路 MTU 的数据包
2. 若 DF=1，丢弃并发送 ICMP（包含该链路的 MTU）
3. 若 DF=0，进行 IP 分片转发

接收端：
1. 从对方 SYN 包中读取 MSS
2. 使用 min(本地 MSS, 对端 MSS) 作为发送大小
```

## 三、TCP 的 MSS 协商机制

### 3.1 MSS 在 TCP 握手中的传递

MSS 选项**只在 SYN 包中传递**，不在纯 ACK 包中携带。

**TCP 三次握手示意：**

```
客户端                                服务器
   |                                    |
   |------ SYN (MSS=1460) ----------->|
   |                                    |
   |<----- SYN-ACK (MSS=1460) --------|
   |                                    |
   |------ ACK (无 MSS) ------------->|
   |                                    |
```

**详细说明：**

1. **第一次握手（SYN）**

   - 客户端发送 SYN 包
   - TCP Options 中包含 MSS 选项
   - 告知服务器："我能接收的最大段大小是 1460 字节"

2. **第二次握手（SYN-ACK）**

   - 服务器回复 SYN-ACK 包
   - **SYN 标志位仍然为 1**，所以可以携带 MSS 选项
   - 告知客户端服务器的 MSS 值

3. **第三次握手（纯 ACK）**
   - 客户端发送 ACK 包
   - **SYN 标志位为 0**
   - **不携带 MSS 选项**
   - MSS 协商已完成

### 3.2 为什么 ACK 不携带 MSS

**协议规定：**
根据 RFC 793 和 RFC 879：

- MSS 选项**仅在 SYN 包中有效**（SYN=1）
- 普通 ACK 包（SYN=0）中的 MSS 选项会被忽略

**技术原因：**

1. **单向声明**：MSS 是发送方告知对方"你发给我的数据最大能有多大"
2. **握手期间协商**：双方在建立连接时各自声明一次即可
3. **连接期间固定**：MSS 在连接建立后不会改变

### 3.3 TCP Options 在不同包中的使用

| TCP 选项                | SYN | SYN-ACK | ACK | 数据包 |
| ----------------------- | --- | ------- | --- | ------ |
| MSS (Kind=2)            | ✓   | ✓       | ✗   | ✗      |
| Window Scale (Kind=3)   | ✓   | ✓       | ✗   | ✗      |
| SACK Permitted (Kind=4) | ✓   | ✓       | ✗   | ✗      |
| SACK (Kind=5)           | ✗   | ✗       | ✓   | ✓      |
| Timestamp (Kind=8)      | ✓   | ✓       | ✓   | ✓      |

## 四、PPPoE 环境下的 MTU 问题

### 4.1 问题场景

典型的家庭网络拓扑：

```
内网设备(MTU=1500) --> 路由器 LAN 口(MTU=1500)
                   --> 路由器 WAN 口(MTU=1492) --> ISP
```

**问题：** 当内网设备发送 1500 字节的 IP 包时，到达路由器 WAN 口（PPPoE MTU=1492）会发生什么？

### 4.2 两种处理情况

#### 情况 1：DF 标志未设置（DF=0）

路由器会进行 **IP 分片**：

- 第一个分片：1492 字节（包含原始 IP 头）
- 第二个分片：8 字节剩余数据 + 20 字节新 IP 头 = 28 字节
- **性能影响**：增加路由器 CPU 负担，降低吞吐量 10-30%

#### 情况 2：DF 标志已设置（DF=1）

这是现代 TCP 连接的常见情况：

1. 路由器**丢弃数据包**
2. 发送 **ICMP Type 3 Code 4** 消息回内网设备
3. ICMP 消息告知："需要分片但设置了 DF，下一跳 MTU=1492"
4. 内网设备收到后，降低发送包大小至 1492 或更小
5. 这就是 **Path MTU Discovery (PMTUD)** 机制

### 4.3 TCP 连接的自动适应

**通常不会有严重问题**，因为存在以下机制：

#### 1. MSS 协商自动调整

```
内网设备计算 MSS：
- 如果路由器正确配置 MSS Clamping
- TCP SYN 包的 MSS 会被路由器改写
- MSS = 1492(PPPoE MTU) - 20(IP 头) - 20(TCP 头) = 1452
```

#### 2. PMTUD 发现

- 即使初始包过大，通过 ICMP 反馈快速调整
- 现代操作系统都支持 PMTUD

#### 3. 路由器 MSS Clamping

- 大多数路由器默认启用此功能
- 自动修改通过的 TCP SYN 包的 MSS 值

### 4.4 UDP 和 ICMP 的潜在问题

这些协议**没有 MSS 协商机制**：

- 应用层直接发送大包可能超过 PPPoE MTU
- 如果 DF=0：被路由器分片，性能下降
- 如果 DF=1：被丢弃，应用层需要处理

### 4.5 解决方案

#### 方案 1：修改内网设备 MTU（最彻底）

```bash
# Linux
ip link set eth0 mtu 1492

# Windows
netsh interface ipv4 set subinterface "以太网" mtu=1492

# macOS
sudo ifconfig en0 mtu 1492
```

**优点**：彻底避免分片
**缺点**：需要配置每台设备

#### 方案 2：路由器启用 MSS Clamping（推荐）

```bash
# 使用 iptables
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
  -j TCPMSS --clamp-mss-to-pmtu

# 或直接指定 MSS 值
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
  -j TCPMSS --set-mss 1452
```

**优点**：对内网设备透明，自动处理 TCP 连接
**缺点**：只对 TCP 有效，UDP 仍可能有问题

#### 方案 3：启用 PMTUD 并确保 ICMP 畅通

确保：

- 路由器不阻止 ICMP Type 3 Code 4 消息
- 内网设备防火墙允许 ICMP
- 内网设备操作系统启用 PMTUD（一般默认启用）

### 4.6 测试和验证

#### 测试是否存在分片问题

```bash
# Linux/macOS
ping -M do -s 1464 8.8.8.8  # 1464+20(IP)+8(ICMP)=1492，应该成功
ping -M do -s 1472 8.8.8.8  # 1472+20+8=1500，可能失败

# Windows
ping -f -l 1464 8.8.8.8
ping -f -l 1472 8.8.8.8
```

#### 查看路由缓存中的 PMTU

```bash
# Linux
ip route get 8.8.8.8
# 输出示例：
# 8.8.8.8 via 192.168.1.1 dev eth0 src 192.168.1.100
#     cache expires 597sec mtu 1492
```

#### 检查 MSS Clamping 是否生效

```bash
# 在内网设备抓包查看 SYN 包的 MSS
tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0' -vv
# 查看 MSS 值是否被改写为 1452
```

## 五、Path MTU Discovery (PMTUD) 深度解析

### 5.1 PMTUD 是跨层协作机制

PMTUD 确实是通过 ICMP 实现的，但它**完全可以作用到 TCP**。这是一个**跨层协作机制**：

```
应用层 (HTTP/FTP 等)
    ↓
传输层 (TCP) ← 接收 PMTUD 结果，调整发送大小
    ↓
网络层 (IP) ← 设置 DF 标志，处理 ICMP 反馈
    ↓
ICMP ← 传递 MTU 信息
```

### 5.2 PMTUD 的完整工作流程

#### 步骤 1：TCP 发送数据包

```
内网设备 TCP 层：
1. 根据本地 MSS (1460) 构造 TCP 段
2. 交给 IP 层封装
3. IP 层添加 20 字节头部，总共 1480 字节
4. IP 层设置 DF=1 标志（Don't Fragment）
```

#### 步骤 2：路由器发现 MTU 不足

```
路由器 WAN 口 (MTU=1492)：
1. 收到 1500 字节的 IP 包
2. 检查：包大小(1500) > MTU(1492) 且 DF=1
3. 无法分片，丢弃数据包
4. 生成 ICMP 消息返回
```

#### 步骤 3：ICMP 消息内容

```
ICMP 包结构：
- Type: 3 (Destination Unreachable)
- Code: 4 (Fragmentation Needed and DF Set)
- Next-Hop MTU: 1492 (关键信息)
- 原始 IP 包的头部 + 前 8 字节数据（用于识别连接）
```

#### 步骤 4：TCP 层接收并处理

```
内网设备收到 ICMP：
1. 操作系统内核的 IP 层处理 ICMP 消息
2. 提取 Next-Hop MTU = 1492
3. 更新路由缓存中该目的地的 PMTU 值
4. 通知 TCP 层：到该目的地的路径 MTU 是 1492
5. TCP 层调整发送窗口，后续 TCP 段不超过：
   1492 - 20(IP 头) - 20(TCP 头) = 1452 字节
```

### 5.3 TCP 如何感知 ICMP

**内核层面的关联机制：**

ICMP 消息携带**原始 IP 包的前 28 字节**：

- 20 字节 IP 头（包含源/目的 IP）
- 8 字节 TCP 头（包含源/目的端口）

操作系统通过这些信息找到对应的 TCP 连接（**四元组匹配**：源 IP、源端口、目的 IP、目的端口）。

**内核简化逻辑（伪代码）：**

```c
void icmp_unreach(struct icmp_hdr *icmp) {
    if (icmp->code == ICMP_FRAG_NEEDED) {
        u32 new_mtu = icmp->un.frag.mtu;

        // 从 ICMP 载荷中提取原始 IP 头
        struct iphdr *orig_ip = (struct iphdr *)icmp->data;

        // 找到对应的 TCP 连接
        struct sock *sk = find_socket(orig_ip);

        // 更新该连接的 PMTU
        if (sk && sk->sk_protocol == IPPROTO_TCP) {
            tcp_update_mtu(sk, new_mtu);
        }
    }
}
```

### 5.4 实际抓包验证

**典型抓包输出：**

```
1. 12:00:00.100 IP 192.168.1.100.45678 > 93.184.216.34.443:
   Flags [.], seq 1:1461, ack 1, win 65535, length 1460
   # TCP 发送 1460 字节数据段

2. 12:00:00.105 IP 路由器WAN_IP > 192.168.1.100:
   ICMP 93.184.216.34 unreachable - need to frag (mtu 1492)
   # 路由器返回 ICMP

3. 12:00:00.106 IP 192.168.1.100.45678 > 93.184.216.34.443:
   Flags [.], seq 1:1453, ack 1, win 65535, length 1452
   # TCP 重传，大小已调整为 1452
```

### 5.5 MSS 协商的局限性

MSS 只解决**端到端的声明**，无法发现**路径中间的瓶颈**：

```
客户端 --- 路由器A(MTU=1500) --- 路由器B(MTU=1492) --- 服务器

1. 三次握手时：
   客户端 <--> 服务器 协商 MSS=1460
   此时双方都不知道中间有 MTU=1492 的瓶颈

2. 传输数据时：
   客户端发送 1500 字节 IP 包 → 到达路由器 B 时超限
   必须通过 ICMP 反馈才能发现路径 MTU
```

### 5.6 现代改进：PLPMTUD

TCP 还支持 **Packetization Layer PMTUD (RFC 4821)**：

- 不依赖 ICMP（某些网络会过滤 ICMP）
- 通过主动发送不同大小的包并观察 ACK 来探测 MTU
- TCP 层直接实现，更可靠

### 5.7 PPPoE 场景下的 PMTUD 实际效果

```
第一个 TCP 连接建立时：
1. SYN 包协商 MSS=1460（假设没有 MSS Clamping）
2. TCP 发送 1500 字节 IP 包
3. 路由器 WAN 口返回 ICMP (mtu=1492)
4. 内核更新路由缓存：到该目的地 PMTU=1492
5. 该 TCP 连接后续段大小 ≤ 1452 字节
6. 其他新连接也会使用缓存的 PMTU=1492

路由缓存：
- 存储时间：通常 10 分钟（可配置）
- 定期探测是否 MTU 变化
```

### 5.8 PMTUD 对不同协议的作用

| 协议       | DF 标志       | PMTUD 是否有效 | 备注             |
| ---------- | ------------- | -------------- | ---------------- |
| TCP        | 通常设置 DF=1 | **有效**       | 内核自动处理     |
| UDP        | 应用决定      | 部分有效       | 需应用层配合     |
| ICMP       | ping 可设置   | 有效           | 测试用           |
| QUIC/HTTP3 | 在 UDP 上实现 | 有效           | 协议层实现 PMTUD |

## 六、UDP 协议与 MTU

### 6.1 UDP 的 DF 标志不是固定的

UDP 协议的 IP 包 DF 标志**取决于多个因素**，不是固定为 1 或 0。

#### 因素 1：操作系统默认行为

```
Linux (较新版本):
- IPv4 UDP: 默认 DF=0（允许分片）
- IPv6 UDP: 不支持路由器分片，源端必须处理

Windows:
- 默认 DF=0
- 某些版本会根据数据包大小动态设置

macOS/BSD:
- 默认 DF=0
- 可通过 setsockopt 配置
```

#### 因素 2：应用层控制

应用程序可以通过 socket 选项控制 DF 标志：

```c
// Linux
int val = IP_PMTUDISC_DO;  // 强制设置 DF=1
setsockopt(sock, IPPROTO_IP, IP_MTU_DISCOVER, &val, sizeof(val));

// 可选值
IP_PMTUDISC_DONT  // DF=0，允许分片
IP_PMTUDISC_WANT  // 尽量设置 DF=1，但不强制
IP_PMTUDISC_DO    // 强制 DF=1
IP_PMTUDISC_PROBE // 用于 MTU 探测

// Windows
DWORD val = IP_PMTUDISC_DO;
setsockopt(sock, IPPROTO_IP, IP_DONTFRAGMENT, (char*)&val, sizeof(val));
```

#### 因素 3：具体协议实现

| 协议/应用                   | DF 标志   | 原因                           |
| --------------------------- | --------- | ------------------------------ |
| **DNS 查询**                | DF=0      | 允许分片，确保可达性           |
| **QUIC/HTTP3**              | DF=1      | 自己实现 PMTUD，不依赖 IP 分片 |
| **VPN (OpenVPN/WireGuard)** | DF=1      | 避免双重分片，性能优化         |
| **RTP/实时音视频**          | DF=0 或 1 | 取决于实现                     |
| **DHCP**                    | DF=0      | 必须保证可达                   |
| **NTP**                     | DF=0      | 通常使用小包，允许分片         |
| **游戏协议**                | 多数 DF=0 | 小包为主，避免 PMTUD 延迟      |

### 6.2 PPPoE 场景中的 UDP 行为

```
场景 1：UDP 包 ≤ 1472 字节，DF=0
- 1472 + 20(IP 头) = 1492，正好通过
- 如果 1473-1500 字节，路由器会分片

场景 2：UDP 包 > 1472 字节，DF=0
- 路由器进行 IP 分片
- 第一片：1472 字节数据 + 20 字节 IP 头 = 1492
- 第二片：剩余数据 + 20 字节新 IP 头
- 性能下降，可能导致丢包

场景 3：UDP 包 > 1472 字节，DF=1
- 路由器丢弃包
- 发送 ICMP (Type 3 Code 4, MTU=1492)
- 但 UDP 应用层不会自动处理 ICMP
- 应用层需要自己实现重传和调整包大小
```

### 6.3 UDP 与 TCP 在 PMTUD 上的关键区别

#### TCP (有状态连接)

```
内核维护连接状态：
- 收到 ICMP 后自动调整后续段大小
- 重传被丢弃的段
- 应用层无感知
```

#### UDP (无状态)

```
内核只更新路由缓存：
- 收到 ICMP 后更新 PMTU
- 但不会通知应用层
- 不会重传丢失的包
- 应用层需要：
  1. 主动查询路径 MTU
  2. 自己处理包大小
  3. 自己实现重传
```

### 6.4 UDP 应用如何处理 PMTUD

#### 方法 1：查询路径 MTU（需要 DF=1）

```c
int sock = socket(AF_INET, SOCK_DGRAM, 0);

// 启用 PMTUD
int val = IP_PMTUDISC_DO;
setsockopt(sock, IPPROTO_IP, IP_MTU_DISCOVER, &val, sizeof(val));

// 发送数据
sendto(sock, data, len, 0, ...);

// 如果 sendto 返回 EMSGSIZE 错误，查询 MTU
int mtu;
socklen_t mtu_len = sizeof(mtu);
getsockopt(sock, IPPROTO_IP, IP_MTU, &mtu, &mtu_len);

// 根据 mtu 调整包大小
int udp_payload = mtu - 20(IP) - 8(UDP);
```

#### 方法 2：保守策略（避免分片）

```c
// 直接使用安全的包大小
#define SAFE_UDP_PAYLOAD 1200  // 适用于绝大多数网络

// 或使用最小 MTU
#define MIN_MTU_PAYLOAD (576 - 20 - 8)  // IPv4 最小 MTU
```

#### 方法 3：QUIC 的做法（推荐）

```
QUIC 协议在 UDP 上实现了完整的 PMTUD：
1. 初始使用 1200 字节包（保守）
2. 主动发送 Padding 帧探测更大 MTU
3. 如果丢包或收到 ICMP，降低包大小
4. 定期重新探测，适应路径变化
```

### 6.5 常见误区

#### 误区 1："UDP 的 DF 总是 0，所以不怕 MTU 问题"

- **错误**：IP 分片会降低性能，增加丢包率
- 分片包任何一片丢失，整个包都要重传
- 某些防火墙会丢弃分片包

#### 误区 2："UDP 不支持 PMTUD"

- **部分正确**：内核会更新路由 PMTU
- 但需要应用层主动配合使用

#### 误区 3："设置 DF=1 就能自动适应 MTU"

- **错误**：对 UDP 来说，只是让内核拒绝发送过大的包
- 应用层必须自己处理 EMSGSIZE 错误

### 6.6 实际建议

#### 对于 PPPoE 环境

**应用开发者：**

```c
// 推荐做法
#define MAX_UDP_PAYLOAD 1400  // 留足够余量
// 1400 + 8(UDP) + 20(IP) = 1428 < 1492，安全
```

**网络管理员：**

- UDP 应用通常自己控制包大小
- 路由器会对 DF=0 的包进行分片
- 监控是否有大量 IP 分片（性能指标）

**诊断命令：**

```bash
# 查看 IP 分片统计
netstat -s | grep -i frag

# Linux
cat /proc/net/snmp | grep Ip:

# 监控分片包
tcpdump -i eth0 'ip[6:2] & 0x3fff != 0' -nn
```

## 七、总结与最佳实践

### 7.1 核心要点

1. **MTU 是配置参数**，不在协议包头中传递
2. **MSS 在 TCP 选项中协商**（只在 SYN 包中）
3. **Path MTU 通过 ICMP 消息动态发现**
4. **PMTUD 是跨层协作机制**，可以作用到 TCP
5. **UDP 需要应用层主动处理 PMTUD**

### 7.2 PPPoE 环境最佳实践

#### TCP 连接

1. **启用路由器 MSS Clamping**（推荐）
2. 确保 ICMP 消息畅通（PMTUD 依赖）
3. 如果需要，统一内网 MTU 为 1492

#### UDP 应用

1. **限制 UDP 载荷 ≤ 1400 字节**（最安全）
2. 应用层实现 PMTUD（如 QUIC）
3. 监控 IP 分片统计，及时发现问题

### 7.3 诊断和验证

```bash
# 测试实际 MTU
ping -f -l 1464 8.8.8.8  # Windows
ping -M do -s 1464 8.8.8.8  # Linux/macOS

# 查看路由缓存中的 PMTU
ip route get 8.8.8.8

# 检查 MSS Clamping
tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0' -vv

# 监控 IP 分片
netstat -s | grep -i frag
```

### 7.4 性能影响量化

假设每秒传输 100MB 数据：

| 场景       | CPU 使用率增加 | 吞吐量下降 | 延迟增加 |
| ---------- | -------------- | ---------- | -------- |
| 无分片     | 0%             | 0%         | 0ms      |
| IP 分片    | 20-40%         | 10-30%     | 5-20ms   |
| PMTUD 优化 | <5%            | <5%        | <2ms     |

### 7.5 参考资源

- **RFC 793**：TCP 协议
- **RFC 879**：TCP MSS 选项
- **RFC 1191**：Path MTU Discovery (IPv4)
- **RFC 8201**：Path MTU Discovery (IPv6)
- **RFC 4821**：Packetization Layer PMTUD

---

## 附录：常用命令速查

### Windows

```powershell
# 查看 MTU
netsh interface ipv4 show subinterfaces
Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceIndex, NlMtu

# 设置 MTU
netsh interface ipv4 set subinterface "以太网" mtu=1492

# 测试 MTU
ping -f -l 1464 www.baidu.com
```

### Linux

```bash
# 查看 MTU
ip link show
ip addr show

# 设置 MTU
ip link set eth0 mtu 1492

# 测试 MTU
ping -M do -s 1464 8.8.8.8

# 查看路由 PMTU
ip route get 8.8.8.8

# 查看分片统计
cat /proc/net/snmp | grep Ip:
netstat -s | grep -i frag

# 抓包分析
tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0' -vv
tcpdump -i eth0 'icmp' -vv
tcpdump -i eth0 'ip[6:2] & 0x3fff != 0' -nn  # 分片包
```

### macOS

```bash
# 查看 MTU
ifconfig

# 设置 MTU
sudo ifconfig en0 mtu 1492

# 测试 MTU
ping -D -s 1464 8.8.8.8
```

---

本文通过理论与实践相结合的方式，深入探讨了 MTU 的工作原理和实际应用。希望能帮助读者更好地理解和解决网络通信中的 MTU 相关问题。
