---
title: "Rhel8 Install"
date: 2019-09-14T10:55:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```

wget  -O rhel8dvd.iso "https://access.cdn.redhat.com/content/origin/files/sha256/00/005d4f88fff6d63b0fc01a10822380ef52570edd8834321de7be63002cc6cc43/rhel-8.0-x86_64-dvd.iso?user=&_auth_=1568433002_1a04311ebe15ca4e234f0ab41898f188"

mkdir /rhel
mount -t iso9660 rhel8dvd.iso /rhel/ -o loop,ro

cd /usr/share/nginx/html/
mkdir rhel
cp -r /rhel/* rhel/
service nginx restart

menuentry "RHEL8-Install"{
	set root=UUID=ef0ca717-b580-42e8-b609-e929b5234713
	linux16 /isolinux/vmlinuz ro ip=38.121.20.13::38.121.20.13:255.255.255.0:my_hostname:eth0:none nameserver=1.1.1.1 inst.repo=http://106.75.223.90/rhel/ inst.vnc inst.vncpassword=MyPassword
	initrd16 /isolinux/initrd.img
}

set timeout=60
menuentry 'RHEL 8' {
  linuxefi images/RHEL-8.0/vmlinuz ip=dhcp inst.repo=http://10.32.5.1/RHEL-8.0/x86_64/iso-contents-root/
  initrdefi images/RHEL-8.0/initrd.img
}


DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
IPADDR=38.121.20.13
NETMASK=255.255.255.0
GATEWAY=38.121.20.1

http://117.28.246.36:18100/rhel/
http://106.75.223.90/rhel/isolinux/splash.png
```


研究一下怎么网络安装rhel8.

## 相关术语

**Anaconda**：Fedora，RHEL和centos等使用的操作系统安装器。     
**Automated install**：全自动安装，使用Kickstart技术驱动Anaconda自动地设置安装参数，从而实现系统安装。

## KickStart全自动安装流程

1. 创建kickstart文件。可以手写、从安装成功的系统中复制、或者使用在线工具配置
2. 让Anaconda可以使用kickstart，kickstart可以在U盘、本地磁盘、或者网络上，但一定要告诉Anaconda地址
3. 


Network location: Copy the Binary DVD ISO image or the installation tree (extracted contents of the Binary DVD ISO image) to a network location and perform the installation over the network using the following protocols:

NFS: The Binary DVD ISO image is in a Network File System (NFS) share.
HTTPS, HTTP or FTP: The installation tree is on a network location that is accessible over HTTP, HTTPS or FTP.

