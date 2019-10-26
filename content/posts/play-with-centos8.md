---
title: "玩转Centos8"
date: 2019-09-26T23:52:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

上一篇在阿里云上安装了centos8，现在就开一篇centos8的踩坑记录，还是比较多的。。
<!--more-->

## 关闭firewalld

```shell
service firewalld stop
systemctl disable firewalld
```

## 关闭selinux

```
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sestatus
reboot
```

## 启用elrepo

```
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
yum install https://www.elrepo.org/elrepo-release-8.0-2.el8.elrepo.noarch.rpm
```

elrepo有四个频道，分别是：`elrepo`,`elrepo-extras`,`elrepo-testing`,`elrepo-kernel`    
我们可以用如下方式使用上面的四个频道（以更新内核为例）：

```
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
yum --enablerepo=elrepo-kernel install -y kernel-ml  #以后升级也是执行这句
```

参考文档:[elrepo.org](http://elrepo.org/tiki/tiki-index.php)

## 安装squid并设置高匿及密码

```shell
yum install -y squid

##设置密码
yum -y install httpd-tools
touch /etc/squid/passwd && chown squid /etc/squid/passwd
htpasswd -b /etc/squid/passwd arloor somepasswd

cat > /etc/squid/squid.conf<<EOF
#文件开头
# 选择的认证方式为basic，认证程序路径和密码文件路径。
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
# 认证程序的进程数
auth_param basic children 10
# 认证有效时间
auth_param basic credentialsttl 4 hours
# 不区分大小写
auth_param basic casesensitive off

#
# Recommended minimum configuration:
#

# Example rule allowing access from your local networks.
# Adapt to list your (internal) IP networks from where browsing
# should be allowed
acl localnet src 0.0.0.1-0.255.255.255 # RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8            # RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10         # RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16        # RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12         # RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16        # RFC 1918 local private network (LAN)
acl localnet src fc00::/7              # RFC 4193 local private network range
acl localnet src fe80::/10             # RFC 4291 link-local (directly plugged) machines
# 所有ipv4网段————————
acl allnet src 0.0.0.0/0

acl CONNECT method CONNECT

# acl的最后加上——————
#仅允许arloor用户连接
acl arloor proxy_auth REQUIRED
http_access deny !arloor


#修改允许全网 And finally deny all other access to this proxy
http_access allow allnet
http_access deny all

# 修改端口 Squid normally listens to port 3128
http_port 20000

.......

#在文件最后
#高匿
forwarded_for delete
via off
follow_x_forwarded_for deny all
request_header_access From deny all
request_header_access Server deny all
request_header_access WWW-Authenticate deny all
request_header_access Link deny all
request_header_access Cache-Control deny all
request_header_access Proxy-Connection deny all
request_header_access X-Cache deny all
request_header_access X-Cache-Lookup deny all
request_header_access Via deny all
request_header_access X-Forwarded-For deny all
request_header_access Pragma deny all
request_header_access Keep-Alive deny all
EOF
cat /etc/squid/squid.conf
squid -z
service squid start
systemctl enable squid
```

git config --global http.proxy http://proxyUsername:proxyPassword@proxy.server.com:port