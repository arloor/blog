---
title: "Dd Centos9 Stream"
date: 2023-05-27T20:51:35+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```shell
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 centos9.qcow2
fdisk -l /dev/nbd0
sudo mount /dev/nbd0p4 /mnt
chroot /mnt /bin/bash
vim /etc/shadow
删除root后的密码
exit
sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0
sudo modprobe -r nbd
qemu-img convert -f qcow2 -O raw centos9.qcow2 centos9.img 
gzip centos9.img
```

```shell
wget http://cdn.arloor.com/rhel/Core_Install_v3.1.sh -O install.sh&&bash install.sh -dd "http://dc6.arloor.dev/centos9.img.gz"
```