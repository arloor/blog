---
title: "Centos7安装ss5、squid"
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

减少造轮子，安装已有socks5、http代理。这里的ss5和squid是不能达到FQ的目的的，要实现这个目的，请查看之前的其他文章。
<!--more-->

## 编译ss5——socks5代理

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
cat > /etc/opt/ss5/ss5.passwd <<EOF
aaaa bbbb
EOF
service ss5 restart
```

这样就在1080端口启动了socks5代理，允许uname/passwd认证的用户使用该socks5代理。

## 安装squid——http代理

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

## 只允许本地使用这两个代理

这个大多数人是不需要做的。

```shell
iptables -I  INPUT 1 -p tcp  --dport 1080 -j DROP 
iptables -I  INPUT 1 -p udp  --dport 1080 -j DROP
iptables -I  INPUT 1 -p tcp  --dport 8888 -j DROP
iptables -I  INPUT 1 -i lo -j ACCEPT   #允许本地访问
```


