---
title: "Cockpit控制台使用"
date: 2023-07-25T21:27:05+08:00
draft: false
categories: [ "undefined"]
tags: ["tools"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

```bash
yum install -y cockpit cockpit-podman
echo "" > /etc/cockpit/disallowed-users # 允许root登陆
# vim /etc/cockpit/ws-certs.d/a.cert #可选，自定义证书，格式是先fullchain.cer，再privkey.pem。文件后缀一定要是.cert
systemctl mask packagekit # 屏蔽这个服务，是用于自动更新软件的，太消耗内存了，而且还会锁住yum的锁
systemctl enable cockpit.socket --now
passwd # 修改root密码为强密码
```