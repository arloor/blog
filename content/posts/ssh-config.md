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
highlightjslanguages:
---

这篇把我最常用的 SSH 隧道能力整理成一份可直接复用的笔记，覆盖：

- 本地端口转发（`-L`）
- 远程端口转发（`-R`）
- 动态端口转发（`-D` / SOCKS5）
- `~/.ssh/config` 里长期可维护的写法

<!--more-->

## 三种端口转发速查

| 类型                      | 作用方向                | 常见场景             | 命令骨架                                                  |
| ------------------------- | ----------------------- | -------------------- | --------------------------------------------------------- |
| 本地转发（Local, `-L`）   | 本地端口 -> 远端目标    | 访问远程机器内网服务 | `ssh -L local_port:target_host:target_port user@ssh_host` |
| 远程转发（Remote, `-R`）  | 远端端口 -> 本地目标    | 让远端访问本机服务   | `ssh -R remote_port:local_host:local_port user@ssh_host`  |
| 动态转发（Dynamic, `-D`） | 本地端口 -> SOCKS5 代理 | 浏览器/命令行走代理  | `ssh -D local_port user@ssh_host`                         |

### 本地端口转发（`-L`）

场景：你要访问远程服务器上的 `127.0.0.1:8090`（比如 Prometheus、Grafana、内部管理面板）。

```bash
ssh -N -L 8090:127.0.0.1:8090 root@server.example.com
```

然后访问本地 `http://127.0.0.1:8090`，实际就是在访问远程 `127.0.0.1:8090`。

也可以写进 `~/.ssh/config`：

```bash
Host monitor
  HostName server.example.com
  User root
  LocalForward 8090 127.0.0.1:8090
```

连接时直接执行：

```bash
ssh monitor
```

### 远程端口转发（`-R`）

场景：你本机有一个服务（如本地代理 `127.0.0.1:7890`），想让远程服务器能用到。

```bash
ssh -N -R 7890:127.0.0.1:7890 root@server.example.com
```

对应 `~/.ssh/config`：

```bash
Host server
  HostName server.example.com
  User root
  RemoteForward 7890 127.0.0.1:7890
```

注意：默认只有远程服务器本机能访问这个 `7890` 端口。若要让远程其他机器也能访问，需要服务端 `sshd_config` 配置 `GatewayPorts`。

### 动态端口转发（`-D`）

场景：在本地创建一个 SOCKS5 代理，供浏览器、终端工具统一走 SSH 隧道。

```bash
ssh -N -D 1080 root@server.example.com
```

应用里配置 SOCKS5 代理为 `127.0.0.1:1080` 即可。

### 常用稳定性参数

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

## `ProxyCommand` 与 `ProxyJump`

两者都用于“到目标主机前先经过中间层”，但侧重点不同：

- `ProxyCommand`：最灵活。你可以指定任意命令（如 `socat`、`nc`）来建立到 `%h:%p` 的连接，适合接 HTTP/SOCKS 代理或特殊网络环境。
- `ProxyJump`：最省心。专门用于跳板机（bastion）场景，语义清晰、配置更短。

重要：`ProxyCommand` 与 `ProxyJump` 是互斥关系，不能同时生效。`ssh` 会采用“先命中、先生效”的规则：

- 如果先解析到 `ProxyJump`，后面的 `ProxyCommand` 会被忽略。
- 如果先解析到 `ProxyCommand`，后面的 `ProxyJump` 会被忽略。
- 这个规则同样适用于跨多个 `Host` 段的匹配结果，所以配置顺序很关键。

`ProxyCommand` 示例（经本地 HTTP 代理连接目标）：

```bash
Host through-http-proxy
  HostName server.example.com
  User root
  ProxyCommand /opt/homebrew/bin/socat - PROXY:localhost:%h:%p,proxyport=6152
```

这里 `%h` 和 `%p` 会自动替换成目标主机与端口。

`ProxyJump` 示例（先连跳板机，再进内网主机）：

```bash

Host app-internal
  HostName 10.0.1.23
  User ubuntu
  ProxyJump [user@]jump-host[:port]
```

连接时直接执行 `ssh app-internal`。如果是多级跳板，也可以写成 `ProxyJump jump1,jump2`。

## 我的 `~/.ssh/config` 示例

先看第一行：
`Host !pi.arloor.com *.arloor.* mac wsl`

这不是在定义一个主机名，而是在写一个“匹配规则列表”：

- `*.wildcard.*`、`mac`、`wsl` 命中时，应用下面的配置。
- `!pi.arloor.com` 是排除规则，即使它也匹配 `*.wildcard.*`，仍然不应用该段配置。
- `Host` 规则会影响它后面的配置项，直到下一个 `Host` 段开始。
- 同一主机命中多个 `Host` 段时，每个参数采用“第一次命中”的值；实践上应把更具体的规则放前面，把通用默认规则放后面。

```bash
# 对多数主机走本地 HTTP 代理（socat）
# 注意：某些工具会把 "proxyport=6152" 错改成 "proxyport 6152"
Host !pi.arloor.com *.wildcard.* mac wsl
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

# 需要特殊跳板登录的机器
Host wee.arloor.dev
    HostName wee.arloor.dev
    User root
    ProxyJump root@hk.arloor.dev:22

Host ix.arloor.com
	HostName ix.arloor.com
	ProxyJump root@ttl.arloor.com:22

Host hknat.arloor.dev
	HostName hknat.arloor.dev
	Port 10065
```

连接示例：

```bash
ssh mac
ssh wsl
ssh tt.arloor.com
```
