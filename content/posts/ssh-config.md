---
title: "SSH 配置与端口转发"
date: 2023-11-16T20:20:22+08:00
draft: false
categories: ["software"]
tags: ["software", "ssh", "network"]
weight: 10
subtitle: ""
description: "一篇搞懂 SSH 本地转发、远程转发、动态代理和 ~/.ssh/config 常用写法。"
keywords:
  - 刘港欢 arloor moontell
---

这篇把我最常用的 SSH 隧道能力整理成一份可直接复用的笔记，覆盖：

- 本地端口转发（`-L`）
- 远程端口转发（`-R`）
- 动态端口转发（`-D` / SOCKS5）
- `~/.ssh/config` 里长期可维护的写法

<!--more-->

## 三种端口转发速查

| 类型 | 作用方向 | 常见场景 | 命令骨架 |
| --- | --- | --- | --- |
| 本地转发（Local, `-L`） | 本地端口 -> 远端目标 | 访问远程机器内网服务 | `ssh -L local_port:target_host:target_port user@ssh_host` |
| 远程转发（Remote, `-R`） | 远端端口 -> 本地目标 | 让远端访问本机服务 | `ssh -R remote_port:local_host:local_port user@ssh_host` |
| 动态转发（Dynamic, `-D`） | 本地端口 -> SOCKS5 代理 | 浏览器/命令行走代理 | `ssh -D local_port user@ssh_host` |

## 本地端口转发（`-L`）

场景：你要访问远程服务器上的 `127.0.0.1:8090`（比如 Prometheus、Grafana、内部管理面板）。

```bash
ssh -N -L 8090:127.0.0.1:8090 root@server.example.com
```

然后访问本地 `http://127.0.0.1:8090`，实际就是在访问远程 `127.0.0.1:8090`。

也可以写进 `~/.ssh/config`：

```sshconfig
Host monitor
  HostName server.example.com
  User root
  LocalForward 8090 127.0.0.1:8090
```

连接时直接执行：

```bash
ssh monitor
```

## 远程端口转发（`-R`）

场景：你本机有一个服务（如本地代理 `127.0.0.1:7890`），想让远程服务器能用到。

```bash
ssh -N -R 7890:127.0.0.1:7890 root@server.example.com
```

对应 `~/.ssh/config`：

```sshconfig
Host server
  HostName server.example.com
  User root
  RemoteForward 7890 127.0.0.1:7890
```

注意：默认只有远程服务器本机能访问这个 `7890` 端口。若要让远程其他机器也能访问，需要服务端 `sshd_config` 配置 `GatewayPorts`。

## 动态端口转发（`-D`）

场景：在本地创建一个 SOCKS5 代理，供浏览器、终端工具统一走 SSH 隧道。

```bash
ssh -N -D 1080 root@server.example.com
```

应用里配置 SOCKS5 代理为 `127.0.0.1:1080` 即可。

## 常用稳定性参数

```bash
ssh -fN \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -L 8090:127.0.0.1:8090 \
  root@server.example.com
```

- `-N`：只建隧道，不执行远程命令。
- `-f`：放到后台执行（常和 `-N` 搭配）。
- `ExitOnForwardFailure=yes`：端口转发失败就立即退出，避免“看起来连上了但其实没生效”。
- `ServerAliveInterval` + `ServerAliveCountMax`：减少 NAT/防火墙导致的静默断连。

## 我的 `~/.ssh/config` 示例

先看第一行：
`Host !pi.arloor.com *.arloor.* mac wsl`

这不是在定义一个主机名，而是在写一个“匹配规则列表”：

- `*.arloor.*`、`mac`、`wsl` 命中时，应用下面的配置。
- `!pi.arloor.com` 是排除规则，即使它也匹配 `*.arloor.*`，仍然不应用该段配置。
- `Host` 规则会影响它后面的配置项，直到下一个 `Host` 段开始。
- 同一主机命中多个 `Host` 段时，每个参数采用“第一次命中”的值；实践上应把更具体的规则放前面，把通用默认规则放后面。

```sshconfig
# 对多数主机走本地 HTTP 代理（socat）
# 注意：某些工具会把 "proxyport=6152" 错改成 "proxyport 6152"
Host !pi.arloor.com *.arloor.* mac wsl
  ProxyCommand /opt/homebrew/bin/socat - PROXY:localhost:%h:%p,proxyport=6152

# 家里的 mac mini
Host mac
  HostName 192.168.5.244
  User arloor

Host wsl
  HostName 192.168.5.127
  Port 222
  User root

Host tt.arloor.com
  HostName tt.arloor.com
  User root
```

连接示例：

```bash
ssh mac
ssh wsl
ssh tt.arloor.com
```

