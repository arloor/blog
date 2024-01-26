---
title: "使用Surge Mac版作为旁路由网关"
date: 2023-01-07T20:55:01+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


## Surge配置文件

```ini
[General]
loglevel = notify
allow-wifi-access = false
proxy-test-url = http://connectivitycheck.gstatic.com/generate_204
internet-test-url = http://baidu.com/
test-timeout = 5
http-api-web-dashboard = true
http-api = xxxxx@0.0.0.0:9090
# encrypted-dns-server = https://1.12.12.12/dns-query,https://120.53.53.53/dns-query
hijack-dns = *:53

[Proxy]
日本 = https, xxxxxxxx, 444, username=xxx, password=xxxx, skip-cert-verify=true, always-use-connect=true
美国 = https, xxxxxxxx, 444, username=xxx, password=xxxx, skip-cert-verify=true, always-use-connect=true

[Proxy Group]
通用 = select, 美国, 日本
奈飞 = select, 美国, 日本
电报 = select, 美国, 日本
openai = select, 美国, 日本
codespaces = select, 美国, 日本
推特 = select, 美国, 日本


[Rule]
PROTOCOL,QUIC,REJECT-NO-DROP
PROTOCOL,UDP,DIRECT
DOMAIN-SET,http://xxxxxxxx/mine.yaml,DIRECT,extended-matching
DOMAIN-SET,http://xxxxxxxx/apple.yaml,DIRECT,extended-matching
DOMAIN-SET,http://xxxxxxxx/twitter.yaml,推特,extended-matching
DOMAIN-SET,http://xxxxxxxx/netflix.yaml,奈飞,extended-matching
DOMAIN-SET,http://xxxxxxxx/openai.yaml,openai,extended-matching
DOMAIN-SET,http://xxxxxxxx/copilot.yaml,copilot,extended-matching
DOMAIN-SET,http://xxxxxxxx/codespaces.yaml,codespaces,extended-matching
DOMAIN-SET,https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/proxy.txt,通用,extended-matching
DOMAIN-SET,https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/gfw.txt,通用,extended-matching
RULE-SET,http://xxxxxxxx/telegram.yaml,电报,no-resolve
RULE-SET,LAN,DIRECT,no-resolve
GEOIP,CN,DIRECT
FINAL,通用
```

核心有：

1. `hijack-dns = *:53` ：用于拦截所有53端口的dns请求
2. RULE-SET后面的 `,no-resolve` ：对于IP-CIDR和GEOIP类型的规则，不进行dns解析，直接使用ip匹配。这样可以避免dns解析失败导致的无法访问问题。
3. DOMAIN-SET或RULE-SET后面的 `,extended-matching` ：识别TLS SNI，根据SNI进行匹配路由规则，这样一定程度上可以避免dns劫持导致分流失败的问题。
4. `PROTOCOL,QUIC,REJECT-NO-DROP` 禁用QUIC协议的流量。Surge开发者提到**Since most proxy protocols are not suitable for forwarding QUIC traffic, Surge will now automatically block QUIC traffic to make it fallback to HTTPS/TCP protocol, ensuring performance. For QUIC traffic that hits the MITM hostname, it will also be automatically rejected.**

> 2和3的选项在 `Version 5.4.1 (Build 2495)` 中才有，所以请务必升级到最新版。

## Mac配置

需要禁止Mac的睡眠，否则Mac mini进入睡眠Surge就代理不了其他设备了。

{{< imgx src="/img/mac-mini-surge-no-sleep.png" alt="" width="700px" style="max-width: 100%;">}}

## 路由器关闭RA（Ipv6路由器通告的DNS下发或全部关闭）

我之前就因为这个问题导致DNS劫持失败，进而导致分流失败，所以记录下！

参考[Surge网关模式的建议](https://community.nssurge.com/d/1847-surge)：

1. 请勿在开启 Surge Mac 网关模式接管的情况下，再在客户端上开启 Surge iOS 或 Surge Mac，可能导致冲突问题。这种场景下使用网关模式接管和设备上单独运行 Surge 的性能几乎不会有差异，可根据需求自行选择其一。
2. 请勿使用 Surge Mac 网关模式接管 P2P/BT 下载软件，由于 Surge 工作在 Layer 4，所以在处理巨量请求数时消耗的资源会比较高，可能导致 Surge 被 macOS 终止。
3. 如果该网络支持 IPv6，请配置 RA 使其不广播 DNS 服务器，以避免 Surge 的 DNS 接管失效，如果路由不支持配置，请关闭整个 IPv6 支持。
4. Surge Mac 网关模式支持 Jumbo MTU，但是依然很可能遇到各种兼容性问题，Jumbo MTU 带来的性能提升有限，不建议开启。

{{< imgx src="/img/router-ipv6-ra-close.png" alt="" width="700px" style="max-width: 100%;">}}

## 其他设备的设置

| 项目 | 设置 |
| --- | --- |
| 网关 | Mac mini的ip地址 |
| DNS | **198.18.0.2**（重点） |
| 子网掩码 | 255.255.255.0 |
| IP | 与其他设备不同的IP即可 |