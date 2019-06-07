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

使用如下命令即可编写bot服务的service文件，并设置开机自启动。
<!--more-->

```shell
vim /usr/lib/systemd/system/bot.service
systemctl enable bot
```

service文件内容如下。

```shell
[Unit]
Description=某应用

[Service]
WorkingDirectory=/root/caochatbot
Restart=always
ExecStart=/usr/bin/java -jar /root/caochatbot/caochatbot.jar

[Install]
WantedBy=multi-user.target
```

以上就是一个简单的服务文件了。好处很简单，重启、关闭等只需要使用sevice控制了，还是挺舒服的。晚些时候，会详细解释service文件各个字段的作用。