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

# 一键安装shadowsocks-libev

在研究了安卓VPN的实现之后，发现我的[HttpProxy](http://github.com/arloor/HttpProxy)跟安卓VPN根本不是一回事，基本不可能有安卓客户端了。而shadowsocks安卓所采用的tun2socks+shadowsocks-libev这种模式很现代。所以给自己的centos也装上shadowsocks了。

shadowsocks有很多版本，我选择shadowsocks-libev，全功能且内存占用真的少，C语言省内存啊。

参见[秋水逸冰](https://teddysun.com/357.html)

```
wget --no-check-certificate -O shadowsocks-libev.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev.sh
chmod +x shadowsocks-libev.sh
./shadowsocks-libev.sh 2>&1 | tee shadowsocks-libev.log
```

安装完成后，可以使用`service shadowsocks status`查看状态，ss的配置文件在`/etc/shadowsocks-libev/config.json`

卸载如下：
```
./shadowsocks-libev.sh uninstall
```



# 配置防火墙

据说centos7默认使firewalld作为防火墙，但是我装了两个centos7都是使用的iptables。

```
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  #开启tcp 22端口的读
iptables -A INPUT -p tcp --dport 80 -j ACCEPT  #开启tcp 80端口的读
iptables -A INPUT -p tcp --dport 8099 -j ACCEPT #开启tcp 8099端口的读
iptables -A INPUT -p udp --dport 8099 -j ACCEPT #开启udp 8099端口的读
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT # 允许所以已建立连接
iptables --policy INPUT DROP #除了以上允许的,设置默认阻止所有读，这个最后再做哦
#或者最后增加这个
# iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited #最后做啊
```

最后service iptables restart，就生效了。可以执行`service iptables save`

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

## 禁用密码登陆

编辑远程服务器上的sshd_config文件：
```
vim /etc/ssh/sshd_config
```

找到如下选项并修改(通常情况下，前两项默认为no，地三项如果与此处不符，以此处为准)：
```
#PasswordAuthentication yes 改为
PasswordAuthentication no
```

编辑保存完成后，重启ssh服务使得新配置生效，然后就无法使用口令来登录ssh了
```
systemctl restart sshd.service
```

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
# 设置时区

```
# 查看事件设置信息
timedatectl status
#Local time: 四 2014-12-25 10:52:10 CST
#Universal time: 四 2014-12-25 02:52:10 UTC
#RTC time: 四 2014-12-25 02:52:10
#Timezone: Asia/Shanghai (CST, +0800)
#NTP enabled: yes
#NTP synchronized: yes
#RTC in local TZ: no
#DST active: n/a
```

```
timedatectl list-timezones # 列出所有时区
timedatectl set-local-rtc 1 # 将硬件时钟调整为与本地时钟一致, 0 为设置为 UTC 时间
timedatectl set-timezone Asia/Shanghai # 设置系统时区为上海
```

