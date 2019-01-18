---
title: "centos7配置使用"
author: "刘港欢"
date: 2019-01-18
categories: [ "linux"]
tags: ["linux"]
weight: 10
---

买了搬瓦工家的vps，相关配置记录一下。时隔两年又用回了搬瓦工，搬瓦工不是屌丝了，我也不是小白了。
<!--more-->

# 配置防火墙

据说centos7默认使firewalld作为防火墙，但是我装了两个centos7都是使用的iptables。iptables命令太复杂，直接编辑/etc/sysconfig/iptables。

```
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 27373 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
```

上面的27373是ssh的端口，发现好像ssh的端口好像要放在第一个。以后要增加某个端口只需要在ssh端口（27373）下面增加-A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT就行。最后service iptables restart，就生效了。

# 修改root用户密码

直接输入passwd命令即可。

# sshd服务配置

## 修改搬瓦工的默认ssh端口

```
#vi /etc/ssh/sshd_config
将Port 22前的注释删掉，或者增加

#重启服务
service sshd restart 
```
这个文件开头说，如果安装了selinux，需要执行semanage port -a -t 22 -p tcp。事实证明这台centos7没有selinux。 记得修改防火墙设置哦。

## 配置秘钥登录

将本地的~/.ssh/id_rsa.pub 添加到服务器的~/.ssh/authorized_keys文件中

# 安装apache

```
yum install httpd
systemctl enable httpd
```

# 安装jdk8

```
wget --no-check-certificate --no-cookie --header "Cookie: oraclelicense=accept- - securebackup-cookie;" https://download.oracle.com/otn-pub/java/jdk/8u201-b09/42970487e3af4f5aa5bca3f542482c60/jdk-8u201-linux-x64.rpm

yum install jdk-8u201-linux-x64.rpm
```