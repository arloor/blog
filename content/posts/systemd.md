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

```shell
vim /usr/lib/systemd/system/bot.service
systemctl enable bot
```
使用上述命令编写bot服务的service文件，并设置开机自启动。service文件内容如下。

```shell
[Unit]
Description=草信官方助手

[Service]
WorkingDirectory=/root/caochatbot
ExecStart=/usr/bin/java -jar /root/caochatbot/caochatbot.jar
Restart=always

[Install]
WantedBy=multi-user.target
```

以上就是一个简单的服务文件了。好处很简单，重启、关闭等只需要使用sevice控制了，还是挺舒服的。晚些时候，会详细解释service文件各个字段的作用。