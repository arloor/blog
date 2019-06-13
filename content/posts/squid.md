---
title: "Centos7安装Squid"
date: 2019-06-13T23:59:56+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

Squid是一个开源http代理。在这里介绍一下怎么使用
<!--more-->

```shell
yum install squid
vim /etc/squid/squid.conf
# 写入以下内容
# http_access allow localnet
# http_access allow localhost
# http_access deny all
# http_port 8888
squid -z
systemctl enable squid
systemctl start squid
```

这样就在8888端口运行了一个只允许本地连接的http代理。