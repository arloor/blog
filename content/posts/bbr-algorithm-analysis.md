---
title: "BBR 算法的流量控制与拥塞控制"
subtitle:
tags:
  - undefined
date: 2025-11-06T13:45:23+08:00
lastmod: 2025-11-06T13:45:23+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
---

## 概述

BBR (Bottleneck Bandwidth and Round-trip propagation time) 是 Google 开发的拥塞控制算法，于 2016 年发布并集成到 Linux 内核 4.9 版本中。与传统的基于丢包的拥塞控制算法（如 Cubic）不同，BBR 采用了一种全新的思路：通过测量瓶颈带宽和往返时延来主动控制发送速率，从而达到高吞吐、低延迟的目标。

本文将结合 iperf3 测速时的 `ss -tmi sport = :5201` 命令输出，深入分析 BBR 算法的核心机制，包括带宽探测、pacing 控制、cwnd 控制以及各种限制因素。输出如下

```bash
ss -tmi sport = :5201
State                     Recv-Q                     Send-Q                                                     Local Address:Port                                                     Peer Address:Port
ESTAB                     0                          39475328                                          [::ffff:154.21.85.102]:5201                                           [::ffff:101.80.224.26]:60308
         skmem:(r0,rb16777216,t0,tb21133776,f3648,w40100288,o0,bl0,d0) bbr wscale:7,14 rto:324 rtt:123.217/0.23 ato:40 mss:1440 pmtu:1500 rcvmss:536 advmss:1448 cwnd:5944 ssthresh:2968 bytes_sent:72819104 bytes_acked:68704608 bytes_received:37 segs_out:50580 segs_in:36484 data_segs_out:50579 data_segs_in:1 bbr:(bw:270Mbps,mrtt:122.382,pacing_gain:1.25,cwnd_gain:2) send 556Mbps lastrcv:4724 pacing_rate 334Mbps delivery_rate 269Mbps delivered:47721 busy:4720ms rwnd_limited:884ms(18.7%) sndbuf_limited:1176ms(24.9%) unacked:2858 reordering:45 reord_seen:16585 rcv_space:14480 rcv_ssthresh:8387160 notsent:35360832 minrtt:122.382 snd_wnd:4153344 rcv_wnd:8388608
ESTAB                     0                          692928                                            [::ffff:154.21.85.102]:5201                                           [::ffff:101.80.224.26]:60292
         skmem:(r0,rb16777216,t0,tb871680,f3712,w713088,o0,bl0,d6) bbr wscale:7,14 rto:332 rtt:129.757/0.139 ato:40 mss:1440 pmtu:1500 rcvmss:536 advmss:1448 cwnd:6212 ssthresh:3006 bytes_sent:109227552 bytes_acked:108534624 bytes_received:37 segs_out:75869 segs_in:55700 data_segs_out:75867 data_segs_in:1 bbr:(bw:256Mbps,mrtt:129.155,pacing_gain:1.25,cwnd_gain:2) send 552Mbps lastsnd:12 lastrcv:4852 lastack:12 pacing_rate 317Mbps delivery_rate 48.5Mbps delivered:75376 busy:4720ms rwnd_limited:2840ms(60.2%) sndbuf_limited:288ms(6.1%) unacked:482 reordering:45 reord_seen:17744 rcv_space:14480 rcv_ssthresh:8387160 minrtt:129.155 snd_wnd:4149376 rcv_wnd:8388608
ESTAB                     0                          0                                                 [::ffff:154.21.85.102]:5201                                           [::ffff:101.80.224.26]:60256
         skmem:(r0,rb16777216,t0,tb16777216,f0,w0,o0,bl0,d0) bbr wscale:7,14 rto:376 rtt:137.071/26.943 ato:40 mss:1440 pmtu:1500 rcvmss:536 advmss:1448 cwnd:14 bytes_sent:4 bytes_acked:4 bytes_received:182 segs_out:7 segs_in:9 data_segs_out:4 data_segs_in:3 bbr:(bw:168kbps,mrtt:131.996,pacing_gain:2.88672,cwnd_gain:2.88672) send 1.18Mbps lastsnd:4724 lastrcv:5400 lastack:4588 pacing_rate 2.49Mbps delivery_rate 169kbps delivered:5 app_limited busy:440ms reordering:45 rcv_space:14480 rcv_ssthresh:8387160 minrtt:131.996 rcv_ooopack:1 snd_wnd:65408 rcv_wnd:8388608
ESTAB                     0                          671040                                            [::ffff:154.21.85.102]:5201                                           [::ffff:101.80.224.26]:60264
         skmem:(r0,rb16777216,t13440,tb946912,f2560,w714240,o0,bl0,d0) bbr wscale:7,14 rto:332 rtt:130.183/0.178 ato:40 mss:1440 pmtu:1500 rcvmss:536 advmss:1448 cwnd:1408 ssthresh:3008 bytes_sent:69475232 bytes_acked:69267872 bytes_received:37 segs_out:48261 segs_in:36223 data_segs_out:48260 data_segs_in:1 bbr:(bw:45.4Mbps,mrtt:129.609,pacing_gain:1.25,cwnd_gain:2) send 125Mbps lastrcv:5128 pacing_rate 56.2Mbps delivery_rate 42Mbps delivered:48117 busy:4724ms rwnd_limited:1208ms(25.6%) sndbuf_limited:1456ms(30.8%) unacked:144 reordering:45 reord_seen:18195 rcv_space:14480 rcv_ssthresh:8387160 notsent:463680 minrtt:129.609 snd_wnd:4150656 rcv_wnd:8388608
ESTAB                     0                          11829600                                          [::ffff:154.21.85.102]:5201                                           [::ffff:101.80.224.26]:60276
         skmem:(r0,rb16777216,t19200,tb6304320,f1312,w12131040,o0,bl0,d1) bbr wscale:7,14 rto:336 rtt:132.582/0.205 ato:40 mss:1440 pmtu:1500 rcvmss:536 advmss:1448 cwnd:1794 ssthresh:3004 bytes_sent:39048256 bytes_acked:37752256 bytes_received:37 segs_out:27132 segs_in:19000 data_segs_out:27130 data_segs_in:1 bbr:(bw:66Mbps,mrtt:132.071,pacing_gain:1.25,cwnd_gain:2) send 156Mbps lastrcv:4988 pacing_rate 81.7Mbps delivery_rate 66Mbps delivered:26221 busy:4724ms rwnd_limited:524ms(11.1%) sndbuf_limited:1692ms(35.8%) unacked:900 reordering:45 reord_seen:8808 rcv_space:14480 rcv_ssthresh:8387160 notsent:10533600 minrtt:132.071 snd_wnd:4145664 rcv_wnd:8388608
```

## BBR 核心原理

### 带宽-延迟乘积 (BDP)

BBR 的核心思想基于网络的 BDP (Bandwidth-Delay Product)，即：

```
BDP = 瓶颈带宽 (Bottleneck Bandwidth) × 往返时延 (RTT)
```

BDP 表示网络管道的容量，也就是在理想情况下，为了充分利用带宽，网络中应该保持的在途数据量。BBR 通过测量这两个参数，计算出最优的发送窗口和发送速率。

从我们的 ss 输出中可以看到：

```
bbr:(bw:270Mbps,mrtt:122.382,pacing_gain:1.25,cwnd_gain:2)
```

这里：

- `bw:270Mbps` 是测得的瓶颈带宽
- `mrtt:122.382` 是最小 RTT（单位：ms）
- 理论 BDP = 270Mbps × 122.382ms ≈ 4.12 MB ≈ 28,785 字节

## 带宽探测机制

BBR 采用周期性的带宽探测策略，通过在不同状态之间切换来持续优化网络使用：

### Startup（启动阶段）

连接初期，BBR 会激进地探测带宽。从第三个连接可以看到：

```
bbr:(bw:168kbps,mrtt:131.996,pacing_gain:2.88672,cwnd_gain:2.88672)
```

在这个阶段，`pacing_gain` 和 `cwnd_gain` 都被设置为 2.88672（约等于 2/ln(2)），这使得发送速率呈指数增长，快速填充网络管道。

### Drain（排空阶段）

当探测到带宽增长停滞时，BBR 进入排空阶段，降低发送速率以排空之前过度填充的队列。

### ProbeBW（带宽探测阶段）

这是 BBR 的稳态运行阶段。大多数连接都处于这个状态：

```
bbr:(bw:270Mbps,mrtt:122.382,pacing_gain:1.25,cwnd_gain:2)
bbr:(bw:256Mbps,mrtt:129.155,pacing_gain:1.25,cwnd_gain:2)
```

在 ProbeBW 阶段，BBR 会在 8 个 RTT 的周期内循环使用不同的 `pacing_gain` 值：

- 1 个 RTT 使用 5/4 (1.25)：轻微增加发送速率以探测是否有更多带宽可用
- 1 个 RTT 使用 3/4 (0.75)：减少发送速率以排空可能产生的队列
- 6 个 RTT 使用 1.0：以测得的带宽速率发送

这种周期性的探测机制确保 BBR 能够适应网络条件的变化，同时保持较低的队列延迟。

### ProbeRTT（RTT 探测阶段）

每隔约 10 秒，BBR 会进入 ProbeRTT 状态，将 cwnd 降至 4 个 MSS，持续至少 200ms。这样做是为了清空所有中间队列，获得准确的最小 RTT 测量值。

## Pacing 控制

Pacing（速率控制）是 BBR 的核心机制之一。与传统 TCP 依赖 ACK 时钟不同，BBR 主动控制数据包的发送速率。

### Pacing Rate 计算

```
pacing_rate = pacing_gain × BDP / RTT = pacing_gain × bandwidth
```

从输出中可以看到：

```
pacing_rate 334Mbps delivery_rate 269Mbps
bw:270Mbps, pacing_gain:1.25
```

计算验证：270Mbps × 1.25 = 337.5Mbps ≈ 334Mbps

这个 pacing_rate 决定了 TCP 发送数据包的速率。Linux 内核使用高精度定时器来精确控制每个数据包的发送时间间隔，而不是像传统 TCP 那样尽快发送数据包。

### Pacing 的优势

1. **平滑发送**：避免突发流量造成的瞬时队列累积
2. **降低延迟**：通过控制发送速率，减少中间路由器的排队时间
3. **公平性**：在多流竞争时能更公平地共享带宽

从实际数据看：

```
pacing_rate 334Mbps delivery_rate 269Mbps
```

pacing_rate 高于 delivery_rate 是因为 `pacing_gain=1.25`，正在探测是否有更多可用带宽。

## CWND 控制

在 BBR 中，cwnd (拥塞窗口) 的角色与传统 TCP 有所不同。它不再是发送速率的主要控制者，而是作为 pacing 的辅助，用于限制在途数据量的上限。

### CWND 计算

```
cwnd = cwnd_gain × BDP
```

从输出中：

```
cwnd:5944
bbr:(bw:270Mbps,mrtt:122.382,pacing_gain:1.25,cwnd_gain:2)
```

计算验证：

```
BDP = 270Mbps × 122.382ms / 8 / 1440 bytes (MSS) ≈ 2,858 packets
cwnd = 2 × 2,858 ≈ 5,716 packets
```

实际 cwnd=5944，略高于理论值，这是因为算法会根据实际情况进行微调。

### 为什么 cwnd_gain 在平稳期是 2

这是一个非常关键的设计决策。在 ProbeBW 稳态下，`cwnd_gain` 固定为 2，原因包括：

#### 容忍重排序

网络中的数据包可能乱序到达。如果 cwnd 太小，可能会误判重排序为丢包，触发不必要的重传。从输出中可以看到：

```
reordering:45 reord_seen:16585
```

这个连接观察到了大量的重排序（16585 次），最大重排序距离为 45 个包。较大的 cwnd 能够容忍这种重排序而不触发快速重传。

#### 应对延迟 ACK

接收端可能延迟发送 ACK，或者 ACK 本身也有传输延迟。cwnd=2×BDP 确保即使部分 ACK 延迟，发送窗口也不会被耗尽，能够持续发送数据。

#### 缓冲变化的 RTT

实际网络中 RTT 会波动。从不同连接可以看到：

```
rtt:123.217/0.23  (连接1)
rtt:129.757/0.139 (连接2)
rtt:130.183/0.178 (连接3)
```

RTT 存在变化，cwnd=2×BDP 提供了安全边际，避免因 RTT 短暂增加导致管道未充分利用。

#### 带宽探测的需要

在 ProbeBW 阶段，`pacing_gain` 会在 [0.75, 1.0, 1.25] 之间切换。当 `pacing_gain=1.25` 时，发送速率增加到 1.25×BW，此时需要 cwnd 足够大以支持这个更高的速率：

```
cwnd ≥ pacing_gain × BDP = 1.25 × BDP
```

设置 `cwnd_gain=2` 确保 cwnd 不会成为限制因素。从输出可以印证：

```
cwnd:5944  (约 2×BDP)
unacked:2858  (约 1×BDP)
```

在途数据量 (unacked) 远小于 cwnd，说明 cwnd 没有成为瓶颈，pacing 在发挥主要作用。

## 限制因素分析

BBR 的发送速率可能受到多种因素的限制，了解这些限制对于性能调优至关重要。

### RWND Limited（接收窗口受限）

接收端通告的接收窗口限制了发送端能发送的数据量。

```
rwnd_limited:884ms(18.7%)
rwnd_limited:2840ms(60.2%)
rwnd_limited:1208ms(25.6%)
```

第二个连接有 60.2% 的时间受到 rwnd 限制，这说明：

- 接收端处理速度较慢，或
- 接收缓冲区设置过小

从输出看接收窗口：

```
snd_wnd:4153344 rcv_wnd:8388608  (连接1，约8MB)
snd_wnd:4149376 rcv_wnd:8388608  (连接2，约8MB)
```

发送窗口 (snd_wnd) 是对端通告的接收窗口。当 `snd_wnd < cwnd × MSS` 时，就会出现 rwnd_limited。

对于连接 2：

```
cwnd=6212 packets × 1440 bytes = 8,945,280 bytes
snd_wnd=4,149,376 bytes
```

发送窗口明显小于 cwnd，这就是 rwnd_limited 的原因。

**优化建议**：

- 增大接收端的 TCP 接收缓冲区：`net.ipv4.tcp_rmem`
- 确保接收端应用及时读取数据

### SNDBUF Limited（发送缓冲区受限）

发送缓冲区不足也会限制发送速率。

```
sndbuf_limited:1176ms(24.9%)
sndbuf_limited:288ms(6.1%)
sndbuf_limited:1456ms(30.8%)
sndbuf_limited:1692ms(35.8%)
```

从 skmem 可以看到发送缓冲区状态：

```
skmem:(r0,rb16777216,t0,tb21133776,f3648,w40100288,o0,bl0,d0)
```

其中：

- `rb`: 接收缓冲区总大小
- `tb`: 发送缓冲区总大小 (21,133,776 bytes ≈ 20MB)
- `w`: 当前发送缓冲区已用 (40,100,288 bytes ≈ 38MB)

等等，`w` 怎么大于 `tb`？实际上 `w` 包括了所有待发送和已发送未确认的数据，可能超过缓冲区限制。

第五个连接：

```
tb6304320 (约6MB), notsent:10533600 (约10MB)
```

这里 notsent (尚未发送的数据) 大于缓冲区，说明应用写入速度很快，但发送速率受限。

**优化建议**：

- 增大发送缓冲区：`net.ipv4.tcp_wmem`
- 调整应用的写入策略，避免过度缓冲

### 无限制状态

第一个连接的时间分配：

```
busy:4720ms rwnd_limited:884ms(18.7%) sndbuf_limited:1176ms(24.9%)
```

计算：884 + 1176 = 2060ms，占 43.6%

这意味着有约 56.4% 的时间既不受 rwnd 限制也不受 sndbuf 限制，此时 BBR 的 pacing 机制在发挥作用，按照计算的 pacing_rate 控制发送速率。

## 重排序处理

TCP 需要处理网络中的包重排序，BBR 通过多种机制来应对。

```
reordering:45 reord_seen:16585
```

- `reordering:45`：当前估计的最大重排序程度，表示数据包可能乱序到达最多 45 个包的距离
- `reord_seen:16585`：观察到的重排序事件总数

这些重排序可能来自：

1. 多路径路由
2. 数据包在中间节点的调度差异
3. 网络接口卡的并行处理

BBR 通过 `cwnd_gain=2` 来容忍重排序。如果 cwnd 太小（比如只有 1×BDP），当出现重排序时，可能会误判为丢包并触发重传。较大的 cwnd 允许更多的数据包在途，降低了重排序导致误判的概率。

从输出看：

```
cwnd:5944 unacked:2858
```

实际在途数据 (unacked) 约为 cwnd 的一半，这为重排序提供了足够的缓冲空间。

## 重传机制

重传是 TCP 可靠性的保证，BBR 也需要处理丢包情况。

### RTO (Retransmission Timeout)

```
rto:324 rtt:123.217/0.23
rto:332 rtt:129.757/0.139
rto:336 rtt:132.582/0.205
```

RTO 是重传超时时间，通常计算为：

```
RTO = SRTT + 4 × RTTVAR
```

其中 SRTT 是平滑的 RTT，RTTVAR 是 RTT 变化量。

从第一个连接：

```
rtt:123.217/0.23
```

这里 123.217 是当前平滑 RTT，0.23 是 RTT 变化量。

计算 RTO：

```
RTO ≈ 123.217 + 4 × 0.23 ≈ 124.1ms
```

但实际 `rto:324`，这是因为 Linux 使用了更保守的 RTO 计算，最小 RTO 通常设置为 200ms。

### 丢包处理

BBR 对丢包的处理与传统 TCP 有所不同：

1. **不降低带宽估计**：BBR 认为偶尔的丢包可能是由于浅缓冲或偶发事件，不应立即降低带宽估计
2. **降低 inflight**：通过 `ssthresh` 来限制在途数据量

```
cwnd:5944 ssthresh:2968
```

ssthresh (慢启动阈值) 被设置为约 cwnd 的一半，这表明可能经历了丢包事件。BBR 会将 cwnd 限制在 `max(cwnd_gain × BDP, ssthresh)` 和 ssthresh 之间。

## 性能指标解读

### 发送与接收统计

```
bytes_sent:72819104 bytes_acked:68704608
segs_out:50580 segs_in:36484
data_segs_out:50579 data_segs_in:1
```

- 已发送约 69 MB 数据，已确认约 65 MB
- 发送了 50580 个段，接收了 36484 个段（包括 ACK）
- 只收到 1 个数据段（因为这是发送端）

### 实时速率

```
send 556Mbps pacing_rate 334Mbps delivery_rate 269Mbps
```

- `send`：基于 cwnd 、MSS 和 RTT 计算的**理论**发送速率。`cwnd × MSS / RTT`
- `pacing_rate`：BBR **控制**的发送速率
- `delivery_rate`：最近测量的**实际**数据送达速率

可以看到：

- send > pacing_rate：cwnd 不是瓶颈，pacing 在控制速率
- pacing_rate > delivery_rate：正在以 1.25 倍速率探测带宽

### 延迟指标

```
minrtt:122.382 rtt:123.217/0.23
```

- `minrtt`：观察到的最小 RTT，用于 BDP 计算
- `rtt`：当前平滑的 RTT 及其变化量

RTT 接近 minrtt 说明网络队列延迟很低，这正是 BBR 的优势所在。

## 优化建议

基于上述分析，针对不同的瓶颈可以采取相应的优化措施：

### 缓冲区调优

```bash
# 增加 TCP 接收缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 131072 16777216"

# 增加 TCP 发送缓冲区
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 增加最大缓冲区限制
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
```

### 应用层优化

对于 rwnd_limited 严重的情况：

- 确保接收端应用及时读取数据
- 使用更大的接收缓冲区（SO_RCVBUF）
- 考虑使用异步 I/O 减少处理延迟

对于 sndbuf_limited 严重的情况：

- 调整发送缓冲区大小
- 控制应用写入速率，避免过度缓冲
- 考虑使用流控机制

### 网络层优化

- 启用 TCP timestamps：`net.ipv4.tcp_timestamps=1`
- 启用 SACK：`net.ipv4.tcp_sack=1`
- 调整初始拥塞窗口：`net.ipv4.tcp_initial_cwnd=10`

## 总结

BBR 算法通过测量瓶颈带宽和最小 RTT，结合 pacing 控制和 cwnd 辅助，实现了高吞吐、低延迟的目标。其核心特点包括：

1. **主动测量**：持续测量网络参数，而不是被动等待丢包信号
2. **Pacing 控制**：主动控制发送速率，避免突发流量
3. **智能探测**：通过周期性的 pacing_gain 调整，在稳定性和探索性之间取得平衡
4. **容错设计**：cwnd_gain=2 提供了应对重排序、延迟 ACK 和 RTT 波动的能力

理解这些机制和指标，能够帮助我们更好地诊断网络性能问题，进行针对性的优化。通过 `ss -tmi` 这样的工具，我们可以实时观察 BBR 的运行状态，识别瓶颈所在，从而做出正确的调优决策。

BBR 的成功之处在于它改变了 TCP 拥塞控制的范式，从"反应式"转向"主动式"，从"以丢包为信号"转向"以测量为基础"。这种思路的转变，为高速网络环境下的传输优化开辟了新的道路。

## 一份 tcp 参数调优的例子

```bash
# ============================================================================
# 网络核心参数配置
# ============================================================================

# 默认队列规则（Queueing Discipline）
# fq (Fair Queue) 是一种公平队列算法，为每个数据流提供独立队列
# 配合 BBR 拥塞控制算法使用效果最佳，能有效减少缓冲区膨胀
net.core.default_qdisc = fq

# 接收缓冲区最大值（字节）
# 67108848 字节 ≈ 64MB
# 控制单个 socket 接收缓冲区的最大大小
# 高带宽网络环境下建议设置较大值以提升接收性能
net.core.rmem_max = 67108848

# 发送缓冲区最大值（字节）
# 67108848 字节 ≈ 64MB
# 控制单个 socket 发送缓冲区的最大大小
# 高带宽网络环境下建议设置较大值以提升发送性能
net.core.wmem_max = 67108848

# socket 监听队列的最大长度
# 4096 表示可以同时处理 4096 个待完成的连接请求
# 高并发服务器（如 Web 服务器、代理服务器）建议设置较大值
# 防止在高负载时出现连接拒绝的情况
net.core.somaxconn = 4096

# ============================================================================
# TCP/IPv4 协议栈参数配置
# ============================================================================

# TCP SYN 队列的最大长度(半连接队列)
# 4096 表示可以容纳 4096 个处于 SYN_RECV 状态的连接
# 用于防御 SYN Flood 攻击，同时支持高并发连接建立
# 应该与 net.core.somaxconn 保持一致或略大
net.ipv4.tcp_max_syn_backlog = 4096

# TCP 拥塞控制算法
# bbr (Bottleneck Bandwidth and RTT) 是 Google 开发的新一代拥塞控制算法
# 相比传统的 cubic 算法，BBR 能够：
#   - 更充分利用带宽
#   - 降低延迟
#   - 在丢包环境下表现更好
# 特别适合高延迟、高带宽的网络环境
net.ipv4.tcp_congestion_control = bbr

# TCP 接收缓冲区大小配置（字节）
# 格式：最小值 默认值 最大值
# 16384 (16KB)      - 最小值，每个 TCP 连接保证的最小接收缓冲区
# 16777216 (16MB)   - 默认值，新建连接的初始接收缓冲区大小
# 536870912 (512MB) - 最大值，单个连接可以使用的最大接收缓冲区
# 内核会根据网络状况自动调整，在最小值和最大值之间动态分配
# 大缓冲区配合高带宽长距离网络（如跨国传输）能显著提升吞吐量
net.ipv4.tcp_rmem = 16384 16777216 536870912

# TCP 发送缓冲区大小配置（字节）
# 格式：最小值 默认值 最大值
# 16384 (16KB)      - 最小值，每个 TCP 连接保证的最小发送缓冲区
# 16777216 (16MB)   - 默认值，新建连接的初始发送缓冲区大小
# 536870912 (512MB) - 最大值，单个连接可以使用的最大发送缓冲区
# 内核会根据网络状况自动调整，在最小值和最大值之间动态分配
# 大缓冲区能够存储更多待发送数据，提高高带宽网络的利用率
net.ipv4.tcp_wmem = 16384 16777216 536870912

# TCP 接收缓冲区的应用层可用空间比例控制（计算TCP接受窗口的大小）
# 这个参数实际上控制的是：接收缓冲区中有多少空间分配给应用层数据，
# 有多少空间预留给内核的 TCP/IP 协议栈开销（如 sk_buff 结构等）
# -2 表示应用层可用的接收窗口为实际 TCP 窗口的 1/4
# 计算公式：应用可用空间 = tcp_rmem / (2^(-tcp_adv_win_scale))
# 设置为负值可以为内核预留更多空间用于 socket 缓冲区管理
# 在超大缓冲区配置下（如本配置的 512MB），建议设置为 -2
# 这样可以避免应用层占用过多内存，同时保证内核有足够空间处理数据
net.ipv4.tcp_adv_win_scale = -2

# 启用 TCP 选择性确认（Selective Acknowledgment）
# 1 = 启用，0 = 禁用
# SACK 允许接收方告知发送方哪些数据包已收到，哪些丢失
# 在丢包环境下能显著提升性能，避免重传整个窗口的数据
# 现代网络环境强烈建议启用
net.ipv4.tcp_sack = 1

# 启用 TCP 时间戳选项
# 1 = 启用，0 = 禁用
# TCP 时间戳用于：
#   - 更精确的往返时间（RTT）测量
#   - 防止序列号回绕（PAWS，在高速网络中很重要）
#   - 支持更大的 TCP 窗口（配合窗口缩放选项）
# 现代网络环境强烈建议启用
# 注意：会在每个 TCP 数据包中增加 12 字节的开销（导致MSS减小12字节）
net.ipv4.tcp_timestamps = 1

# ============================================================================
# 配置说明
# ============================================================================
# 本配置适用场景：
# - 大BDP场景（带宽和延迟乘积大的情况下，需要增大缓冲区）：高带宽服务器（1Gbps 以上） / 长距离高延迟网络传输（跨国、跨洲数据传输）
# - 高并发应用（Web 服务器、反向代理、CDN 节点等）
# - 需要优化大文件传输的场景
#
# 应用配置后执行：
# sudo sysctl -p
#
# 验证配置：
# sysctl net.core.default_qdisc
# sysctl net.ipv4.tcp_congestion_control
#
# 注意事项：
# - 大缓冲区会占用更多内存，请确保服务器有足够的 RAM
# - BBR 需要 Linux 内核 4.9 或更高版本
# - 修改后建议进行性能测试验证效果
# ============================================================================
```
