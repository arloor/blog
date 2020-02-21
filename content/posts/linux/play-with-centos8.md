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

## tar操作

**查看tar压缩包的内容**

```
tar -tvf a.tar
```

v可以省略

**压缩某目录下的某文件（或子目录）**

```
tar -zcvf a.tar.gz  -C ~/test somedir
```

这样就可以压缩`~/test`目录下的`somedir`子目录到`a.tar.gz`中

**小技巧：** 你可以先输入`tar -zcvf a.tar.gz  -C ~/test/somedir`，然后把`/somedir`的反斜杠改为空格以形成上面的命令（这样可以使用tab的自动补全）

**注意：** `somedir`在这种模式下是不能用通配符的

**压缩时排除指定文件**

```
cd ~/test
tar  -zcf  public.tar.gz --exclude=public.tar.gz *
```

这样也能实现压缩目录下的所有文件

**解压缩**

```
tar -zxvf a.tar.gz -C targetDir
```

解压到目标文件夹

## 安装squid并设置高匿及密码

```shell
# squid4.4
yum install -y squid

##设置密码
yum -y install httpd-tools
touch /etc/squid/passwd && chown squid /etc/squid/passwd
htpasswd -b /etc/squid/passwd arloor somepasswd

vim /etc/squid/squid.conf  #内容见下面
squid -z
service squid start
systemctl enable squid
```

squid.conf内容，[直接使用的conf](/squid.conf)

```
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
acl localnet src 0.0.0.1-0.255.255.255	# RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8		# RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10		# RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16 	# RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12		# RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16		# RFC 1918 local private network (LAN)
acl localnet src fc00::/7       	# RFC 4193 local private network range
acl localnet src fe80::/10      	# RFC 4291 link-local (directly plugged) machines
# 所有网段
acl allnet src all

acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
acl CONNECT method CONNECT
# 只允许arloor用户
acl arloor proxy_auth REQUIRED
http_access deny !arloor

#
# Recommended minimum Access Permission configuration:
#
# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Only allow cachemgr access from localhost
http_access allow localhost manager
http_access deny manager

# We strongly recommend the following be uncommented to protect innocent
# web applications running on the proxy server who think the only
# one who can access services on "localhost" is a local user
#http_access deny to_localhost

#
# INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS
#

# Example rule allowing access from your local networks.
# Adapt localnet in the ACL section to list your (internal) IP networks
# from where browsing should be allowed
http_access allow localnet
http_access allow localhost

# 允许所有网段
http_access allow allnet
# And finally deny all other access to this proxy
http_access deny all

# Squid normally listens to port 3128
http_port 20000

# Uncomment and adjust the following to add a disk cache directory.
#cache_dir ufs /var/spool/squid 100 16 256

# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid

#
# Add any of your own refresh_pattern entries above these.
#
refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern ^gopher:	1440	0%	1440
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320

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
```

这样git就可以使用这个代理了。

```
git config --global http.proxy "http://user:passwd@host:20000"
git config --global https.proxy "http://user:passed@host:20000"
```

上面的设置已经对该http_proxy进行了密码认证。但是网络上有一堆扫代理的机器，很有可能有人暴力破解这个代理，然后用于访问非法网站。。。

如果用途只是用于代理github，那么建议增加两个配置项：

```
## 在acl部分
acl github dstdomain .github.com

## 在http_access部分
http_access deny !github
```

这样squid仅仅允许访问github.com了。

[squid的一些命令](https://my.oschina.net/u/125259/blog/310289)

## 安装ss-libev

```shell
# 安装依赖
yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel -y
# 安装libsodium
libsodium_file="libsodium-1.0.17"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.17/libsodium-1.0.17.tar.gz"
wget -O "${libsodium_file}.tar.gz" "${libsodium_url}"
tar zxf ${libsodium_file}.tar.gz
cd ${libsodium_file}
./configure --prefix=/usr && make && make install
# 安装mbedtls
mbedtls_file="mbedtls-2.16.0"
mbedtls_url="https://tls.mbed.org/download/mbedtls-2.16.0-gpl.tgz"
wget -O "${mbedtls_file}-gpl.tgz" "${mbedtls_url}"
tar xf ${mbedtls_file}-gpl.tgz
cd ${mbedtls_file}
make SHARED=1 CFLAGS=-fPIC
make DESTDIR=/usr install
# 安装ss-libev
wget -O shadowsocks-libev-3.3.4.tar.gz https://github.com/shadowsocks/shadowsocks-libev/releases/download/v3.3.4/shadowsocks-libev-3.3.4.tar.gz
tar zxf shadowsocks-libev-3.3.4.tar.gz
cd shadowsocks-libev-3.3.4
./configure --disable-documentation
make && make install
# 配置动态库链接地址
sed -n '/^\/usr\/local\/lib/'p /etc/ld.so.conf.d/local.conf | grep -q "/usr/local/lib"
if [ $? -ne 0 ]; then
    echo -e "/usr/local/lib" >> /etc/ld.so.conf.d/local.conf && ldconfig
fi
# 配置
mkdir /etc/shadowsocks-libev
cat > /etc/shadowsocks-libev/config.json <<EOF
{
    "server":"0.0.0.0",
    "server_port":10000,
    "password":"passwd",
    "timeout":300,
    "user":"nobody",
    "method":"aes-256-gcm",
    "fast_open":false,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF

cat > /lib/systemd/system/ss.service <<EOF
[Unit]
Description=ss-server
Documentation=man:shadowsocks-libev(8)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks-libev/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ss
systemctl daemon-reload
systemctl start ss
```