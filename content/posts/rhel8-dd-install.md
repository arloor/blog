---
title: "Rhel8 Dd Install"
date: 2021-02-17T14:27:20+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

## 参考文档

- [制作Linux的DD包](https://cosmiccat.net/2018/06/333/)
- [Linux格式化数据盘](https://www.alibabacloud.com/help/zh/doc-detail/25426.htm?spm=5176.2020520101disk.109.d25426.6c124df57ytrxv)
- [CentOS8修改网卡名称eth0](https://www.cnblogs.com/leoshi/p/12503088.html)
- [制作 Linux 镜像](https://cloud.tencent.com/document/product/213/17814)
- [Linux_LVM_磁盘扩容](https://www.cnblogs.com/hellojesson/p/4582908.html)

## 创建镜像

安装系统

```
wget http://blog.arloor.com/install-rhel8-form-centos7.sh -O a.sh&& bash a.sh
```

核心注意点：/boot单独分区为简单分区200M，根分区(/)使用lvm分区3.2G，软件选择最小安装

网卡配置选择为dhcp，dd到vps上之后可能需要改为静态ip

## 修改网卡

查看当前网卡

```shell
dmesg | grep eth
[    4.829146] vmxnet3 0000:03:00.0 eth0: NIC Link is Up 10000 Mbps
[    5.671853] vmxnet3 0000:03:00.0 ens3: renamed from eth0
```

我们需要将ens3变更为eth0

查看当前连接信息

```shell
# nmcli connection show
NAME    UUID                                  TYPE      DEVICE
ens3  46f3176f-23ac-4af8-b9fe-08d3c668ba81  ethernet  ens3
```

新增eth0连接

```shell
# nmcli connection add type ethernet con-name eth0 ifname ens3
# nmcli connection show
NAME    UUID                                  TYPE      DEVICE
ens3  46f3176f-23ac-4af8-b9fe-08d3c668ba81  ethernet  ens3
eth0    55e201dc-0f9e-44c7-b6ae-da09370e3718  ethernet  --
```

删除ens3连接

```shell
# nmcli connection delete ens3
# nmcli connection show
NAME  UUID                                  TYPE      DEVICE
eth0  55e201dc-0f9e-44c7-b6ae-da09370e3718  ethernet  ens3
```

修改物理网卡名称

```shell
# 查看配置文件
# ls /etc/sysconfig/network-scripts/
ifcfg-eth0
# 修改物理网卡名称
# sed -i 's/ens3/eth0/' /etc/sysconfig/network-scripts/ifcfg-eth0
```

修改grub启动配置

```shell
vim /etc/default/grub
#在GRUB_CMDLINE_LINUX_DEFAULT行后边添加
net.ifnames=0 biosdevname=0

grub2-mkconfig -o /boot/grub2/grub.cfg
```

检查/etc/udev/rules.d/70-persistent-net.rules是否存在，如果存在则删除

## 关闭防火墙和selinux

```shell
## 禁用firewalld
service firewalld stop
systemctl disable firewalld
## 关闭selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sestatus
```

## 修复启动

打开系统的引导文件

比如/boot/grub2/grub.cfg

确保set root行值不为UUID=XXXXXXXXXXXXXXXXXXXXXXXXXX

如果是的话请修改成hd0,1

## 最后修改/etc/fstab

将/boot使用的分区删掉

然后在rc.local或者其他能自启动的地方加上

```shell
mount /dev/vda1 /boot
```

```shell
chmod +x /etc/rc.d/rc.local
```

## 添加虚拟化所需的一些磁盘驱动

这边rhel8不需要这一步

## 清空历史记录

```
echo "" > .bash_history
```

## dd

```
mount /dev/vdb1 /mnt
```

```
fdisk -l -u /dev/vda
Disk /dev/vda：20 GiB，21474836480 字节，41943040 个扇区
单元：扇区 / 1 * 512 = 512 字节
扇区大小(逻辑/物理)：512 字节 / 512 字节
I/O 大小(最小/最佳)：512 字节 / 512 字节
磁盘标签类型：dos
磁盘标识符：0x000bde00

设备       启动   起点    末尾    扇区  大小 Id 类型
/dev/vda1  *      2048  411647  409600  200M 83 Linux
/dev/vda2       411648 7145471 6733824  3.2G 8e Linux LVM
```

```
(dd   bs=512 count=[fdisk命令中最大的end数+1] if=/dev/vda | gzip -9 > /mnt/rhel8.img.gz &)
```

## dd安装

wget http://blog.arloor.com/sh/InstallNET.sh -O InstallNET.sh&& bash  InstallNET.sh -dd http://someme.me/rhel8-install/rhel8.img.gz

## 磁盘扩容

```shell
   64  fdisk -l      查看磁盘
   65  fdisk /dev/vda  对新添加的磁盘进行分区，此处使用整块盘
   66  mkfs.ext4 /dev/vda3   对新分的区进行格式化
   67  fdisk /dev/vda  将格式化好的盘改成lvm（8e）格式
   68  fdisk -l  查看格式化好的盘是否是lvm格式
   69  vgdisplay   查看系统中的逻辑组
   70  pvdisplay   查看系统中的物理卷
   71  pvcreate /dev/vda3   将新分好区的磁盘做成逻辑卷
   72  pvdisplay  查看系统中的物理卷
   73  lvdisplay   查看系统中的逻辑卷
   74  vgextend rhel /dev/vda3  扩展已有逻辑组
   75  vgdisplay  查看扩展后的逻辑组
   76  lvextend -L 45G /dev/rhel/root  将之前的逻辑卷扩展到328.6G，不是扩展了328.6G 
   77  lvdisplay   查看扩展后的逻辑卷
   78  df -Th 查看系统磁盘使用情况，发现还是原来大小
   79  resize2fs /dev/rhel/root  需要重设一下扩展后的逻辑卷
   80  df -Th 这次再看的话，已经改过来了
   ```