---
title: "Systemd服务文件编写-centos7下"
date: 2019-06-07T19:25:03+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

以前的博客中有如何使用shell脚本重启应用的教程，也有解决tty的最大打开文件数量限制的方法。其实这些都可以用systemd服务的方式解决。今天就来一个简单的service文件，记录下怎么使用。

使用如下命令即可编写sogo服务的service文件，并设置开机自启动。
<!--more-->

```shell
vim /usr/lib/systemd/system/sogo.service
systemctl enable sogo
```

service文件内容如下。

```shell
[Unit]
Description=一个socks5代理
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/root/socks5
ExecStart=/usr/bin/java -jar /root/socks5/sogo.jar -c /root/socks5/sogo.json
LimitNOFILE=100000
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

以上就是一个简单的服务文件了。好处很简单，重启、关闭等只需要使用sevice控制了，还是挺舒服的。

```shell
After=network-online.target    #等待网络—ip、dns等
Wants=network-online.target    #等待网络—ip、dns等

LimitNOFILE=100000             #最大打开文件数，对于web服务还是很重要的
Restart=always                 #进程退出时自动重启
RestartSec=2                   #重启延迟
```