---
title: "使用Mac mini wakeonlan windows主机（微星主板）"
subtitle:
tags: 
- windows
date: 2024-12-16T22:16:38+08:00
lastmod: 2024-12-16T22:16:38+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

家里有台Mac mini是一直开机的，作为软路由使用，也作为跳板机连接到家里网络。今天试了下怎么用这个mac mini通过wake on lan唤醒windows主机。

## 参考文档

1. [[Motherboard] Wake on LAN Settings](https://www.msi.com/support/technical_details/MB_Wake_On_LAN)

## 主板BIOS设置

以微星主板为例，开机按DEL进入BIOS。然后进入Advanced页面，找到Wake Up Event Setup，然后打开 Resume by PCIE/Networking Device。按F10保存设置，这时可以看到一共有两个设置被改动，一个是我们设置的Resume by PCIE/Networking Device，另一个是Erp Ready选项被关闭，此时确认保存然后机器自动重启。至此BIOS的设置就好了。在电脑中，启用 ErP Ready 功能后，系统在关机状态下会减少待机功耗，例如关闭所有的待机设备电源，从而使整机的待机功耗降低到 1 瓦以下（通常这是 ErP 的最低要求）。开启ErP Ready的话，wakeonlan就无法工作了，因此微星的BIOS帮我一并设置了。

## windows设置

在设备管理器中，找到网卡，然后右键属性，找到电源管理，勾选“允许此设备唤醒计算机”。貌似有些网卡是不支持wol的，你们只能另寻他法。

{{<img device-manager-enable-wol-for-net-adapters.png 600>}}

然后关闭快速启动

{{<img turn-off-windows11-fast-boot.png 550>}}

## Mac mini上安装wakeonlan，并执行命令

```bash
brew install wakeonlan
wakeonlan -i 192.168.5.255 34:xx:xx:xx:xx:xx # -i 192.168.5.255是向我局域网的广播地址发送唤醒包，34:5a:60:07:25:ce是windows主机的mac地址
```

执行完就可以看到windows主机在启动了。

windows主机网卡的mac地址可以通过`ipconfig /all`查看，结果如下。

```bash
以太网适配器 以太网 6:

   连接特定的 DNS 后缀 . . . . . . . :
   描述. . . . . . . . . . . . . . . : Killer E5000B 5 Gigabit Ethernet Controller
   物理地址. . . . . . . . . . . . . : 34-xx-xx-xx-xx-xx <- 这个就是mac地址
   DHCP 已启用 . . . . . . . . . . . : 是
   自动配置已启用. . . . . . . . . . : 是
   本地链接 IPv6 地址. . . . . . . . : fe80::a8f:e4e9:148:6f47%2(首选)
   IPv4 地址 . . . . . . . . . . . . : 192.168.5.25(首选)
   子网掩码  . . . . . . . . . . . . : 255.255.255.0
   获得租约的时间  . . . . . . . . . : 2024年12月16日 22:14:51
   租约过期的时间  . . . . . . . . . : 2024年12月17日 22:14:50
   默认网关. . . . . . . . . . . . . : 192.168.5.1
   DHCP 服务器 . . . . . . . . . . . : 192.168.5.1
   DHCPv6 IAID . . . . . . . . . . . : 53762656
   DHCPv6 客户端 DUID  . . . . . . . : 00-01-00-01-2D-6E-88-D5-70-70-FC-04-B6-C1
   DNS 服务器  . . . . . . . . . . . : 119.29.29.29
                                       223.5.5.5
   TCPIP 上的 NetBIOS  . . . . . . . : 已启用
```