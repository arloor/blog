---
title: "Centos7安装ss5"
date: 2019-06-15T23:07:52+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

减少造轮子，使用已有socks5代理。
<!--more-->

## 编译安装、配置

```shell
yum install -y gcc openldap-devel pam-devel openssl-devel
wget http://jaist.dl.sourceforge.net/project/ss5/ss5/3.8.9-8/ss5-3.8.9-8.tar.gz
tar -vzx -f ss5-3.8.9-8.tar.gz
cd ss5-3.8.9/
./configure
make
make install
chmod a+x /etc/init.d/ss5
service ss5 start
# 修改配置文件
cat >> /etc/opt/ss5/ss5.conf <<EOF
auth    0.0.0.0/0               -               u
permit u       0.0.0.0/0       -       0.0.0.0/0       -       -       -       -       -
EOF
# 增加用户
cat >> /etc/opt/ss5/ss5.passwd <<EOF
aaaa bbbb
EOF
service ss5 restart
```

这样就在1080端口启动了socks5代理，允许uname/passwd认证的用户使用该socks5代理。

## 只允许本地使用该代理

这个大多数人是不需要做的。

```shell
iptables -I  INPUT 1 -p tcp  --dport 1080 -j DROP
iptables -I  INPUT 1 -p udp  --dport 1080 -j DROP
iptables -I  INPUT 1 -i lo -j ACCEPT
```