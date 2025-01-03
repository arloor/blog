---
title: "Clash Tun模式和透明代理"
date: 2023-07-23T10:39:36+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

大概前几年就玩过软路由，当时用openwrt作为主路由使用，一是折腾起来太麻烦，二是对家庭网络侵入性太大，三是当时用的机器风扇声音太大。用上M2的Macbook PRO、Mac MINI后，我才发现，原来低功耗的无风扇的被动散热的体验是真的安静。所以，这次软路由的搭建核心诉求是三个：1. 旁路由而不是主路由；2. 用Clash而不是openwrt；3. 用被动散热的机器，主打一个安静。最终的话，这次整了一台畅网N100先锋版，把附送给内存和硬盘散热的风扇拆了，走纯被动散热。最终成品如下，特点是小小的，稳稳的，烫烫的。

![Alt text](/img/8aafce027a7a038b8c86497537075571_0.jpg)

下面的内容是介绍下如何使用Clash tun模式搭建旁路由。
<!--more-->

## 准备工作

1. 畅网N100先锋版
2. 英睿达4800频率的DDR5笔记本内存
3. 致态TiPlus5000 PCIE3.0 固态
4. RedHat 9系统，内核版本5.14，其他linux系统也都行。

> 注意，很多Intel N100 CPU的机器只支持PCIE3.0的固态。

> 另外有人反馈Redhat8/Centos8的内核版本4.18开启不了clash tun的auto-route功能

> 还看到一些关于畅网N100的负面消息，这里贴一下[畅网N100 四网精英版 踩雷了【软路由吧】_百度贴吧](https://tieba.baidu.com/p/8518096633?share=9105&fr=sharewise&see_lz=0&share_from=post&sfc=copy&client_type=2&client_version=12.45.7.0&st=1692451415&is_video=false&unique=C11CFEB8D10A93F3B2A32491CD528A31)

## 下载Clash premium内核

> 2023-12-25更新：Clash core项目已经删除，有大佬fork了Release文件，保存在了MEGA网盘，地址：[https://mega.nz/folder/orkzRYbR#bHhSjy9r_9AJayIgqtZTag](https://mega.nz/folder/orkzRYbR#bHhSjy9r_9AJayIgqtZTag)，请自行下载，自行备份。


下载链接[https://github.com/Dreamacro/clash/releases/tag/premium](https://github.com/Dreamacro/clash/releases/tag/premium)，到页面下方选择clash-linux-amd64开头的文件下载。也可以选择clash-linux-amd64-v3的版本，有一些性能提升，但是老机器上可能有兼容性问题。

写此文时clash premium版本是clash-linux-amd64-2023.07.22，我的下载命令如下。大家可以自行修改version字段为最新版本。

```bash
version="2023.07.22" # 自行修改为当前的最新版本
curl -Lf "https://github.com/Dreamacro/clash/releases/download/premium/clash-linux-amd64-${version}".gz | gzip -d > /tmp/clash
install -m 777 /tmp/clash /usr/local/bin/clash
```

## 下载Clash dashboard的UI

```bash
mkdir -p /data/clash
git clone -b gh-pages https://github.com/haishanh/yacd.git /data/clash/ui
```

PS: 为了使用上面的UI，需要在clash的配置文件中加上：


```yaml
external-controller: 0.0.0.0:9090
external-ui: /data/clash/ui
```

这样就能访问软路由的9090端口通过ui操纵clash的配置了。

![Alt text](/img/clash-yacd-ui.png)

## Clash配置文件

> 为了“以Systemd服务运行”成功，配置文件请放置在 /data/clash/config.yaml

> 这里是Clash tun旁路由的关键，包括tun配置、dns劫持、dns fallback等配置，想了解这些可以参考：
> - [configuration-reference](https://dreamacro.github.io/clash/configuration/configuration-reference.html)
> - [Feature: tun-device](https://dreamacro.github.io/clash/premium/tun-device.html)

在你原有的clash配置文件中增加以下内容：

```yaml
experimental:
  sniff-tls-sni: true

tun:
  enable: true
  stack: system
  dns-hijack:
    - 8.8.8.8:53
    - tcp://8.8.8.8:53
    - any:53
    - tcp://any:53
  auto-route: true 
  auto-detect-interface: true 

dns:
  enable: true
  listen: 0.0.0.0:53
  default-nameserver:
    - 119.29.29.29
    - 223.5.5.5
  fake-ip-range: 198.18.0.1/16 # Fake IP addresses pool CIDR
  fake-ip-filter:
    - '*.lan'
    - localhost.ptlogin2.qq.com
  nameserver:
      - 119.29.29.29
      - 114.114.114.114
      - 223.5.5.5
  fallback:
      - https://doh.pub/dns-query
      - https://cloudflare-dns.com/dns-query
      - https://1.12.12.12/dns-query
      - https://120.53.53.53/dns-query
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4
    domain:
      - '+.google.com'
      - '+.facebook.com'
      - '+.youtube.com'
```

## 预先下载Country.mmdb

Clash会使用Country.mmdb文件识别ip地址所属的国家，GEOIP的规则会用到这个文件。在clash启动时，如果运行目录下没有这个文件会自动下载，由于国内网络的问题，通常会耗时很久，所以我们自行到[maxmind-geoip releases](https://github.com/Dreamacro/maxmind-geoip/releases)下载，并ftp/scp到软路由的 `/data/clash` 目录下。

## 以Systemd服务运行

> 如果53端口被占用，请自行关闭相关进程

```bash
cat > /lib/systemd/system/clash.service <<\EOF
[Unit]
Description=rust_http_proxy
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/data/clash
ExecStartPre=/bin/sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
ExecStart=/usr/local/bin/clash -d /data/clash -f /data/clash/config.yaml
LimitNOFILE=100000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now clash #启动clash并设置开机自启动
```

其中ExecStartPre部分定义了在服务启动前，开启内核的ip转发特性，这也是Clash作为旁路由比较关键的一步。

## 手机等设备使用Clash软路由作为网关

在手机等设备的网络设置页面设置网关为Clash软路由的ip地址即可。得益于Clash的dns劫持功能，手机设备的dns服务器并不需要设置，这让Clash软路由的搭建方便了很多。

![Alt text](/img/macos-gateway-setting.png)

## 主机温度监控

用被动散热还是挺担心温度的，所以用lm_sensors测了下，室温30度时，cpu温度在40-45度，没毛病。被动散热下，铝合金的外壳温度是暖暖的，冬天肯定很吸猫。

```bash
$ yum install -y lm_sensors
$ sensors
acpitz-acpi-0
Adapter: ACPI interface
temp1:        +27.8°C  (crit = +110.0°C)

coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +40.0°C  (high = +105.0°C, crit = +105.0°C)
Core 0:        +40.0°C  (high = +105.0°C, crit = +105.0°C)
Core 1:        +40.0°C  (high = +105.0°C, crit = +105.0°C)
Core 2:        +40.0°C  (high = +105.0°C, crit = +105.0°C)
Core 3:        +40.0°C  (high = +105.0°C, crit = +105.0°C)
```

## 网速测试

跑满了我200M的电信宽带，N100处理器处理这点带宽真是轻轻松松。

![Alt text](/img/dmit-lax-pro-speedtest.png)

## 一些拓展

### 屏蔽quic流量

chrome浏览器和youtube应用等默认开启了quic，国内udp qos的问题会导致quic网速较差，一般情况下都建议关闭quic。在chrome浏览器里，可以访问 `chrome://flags`，将 `Experimental QUIC protocol` 的特性关闭。但是在手机youtube应用里就没办法关闭了，所以研究了下clash屏蔽quic的方案，就是在配置文件里增加：

```yaml
script:
  shortcuts:
    quic: network == 'udp' and dst_port == 443

rules:
- SCRIPT,quic,REJECT,no-resolve
```

### 避免暴露DNS服务

```yaml
dns:
  enable: true
  #listen: 0.0.0.0:53
```

这样，DNS服务就会监听 `198.18.0.1:53` 而不是 `0.0.0.0:53` ，也就不会暴露。不过为了让DNS劫持生效，设备的DNS不能设置为局域网地址，需要是公网地址或者`198.18.0.1`，详见官方的描述：

> Since `tun.auto-route` does not intercept LAN traffic, if your system DNS is set to servers in private subnets, DNS hijack will not work. You can either:
> - Use a non-private DNS server as your system DNS like `1.1.1.1`
> - Or manually set up your system DNS to the Clash DNS (by default, `198.18.0.1`)