---
title: "Centos7备份/恢复与网卡配置"
date: 2019-05-10T15:51:28+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

这是我没搞过的东西，慢慢来，一点一点记录下。
<!--more-->

## 如何备份恢复系统

首要要注意，一切操作都是在使用liveCD的U盘启动的系统上进行操作，不要在备份/恢复的硬盘启动的系统上运行dd。（有硬盘读写的时候执行dd肯定不对啊）

首先就是创建liveCD的U盘启动盘，这个很简单，使用软碟通就好了，不多说。下面主要讲解dd命令

### 查看磁盘扇区占用情况

将liceCD启动u盘插到要备份的电脑上，选择u盘启动。执行fdisk查看要备份的系统盘的磁盘占用情况：

```
[root@DC6 ~]# fdisk -u -l /dev/sda

Disk /dev/sda: 10.7 GB, 10737418240 bytes, 20971520 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000929da

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048      821247      409600   83  Linux
/dev/sda2          821248    20969087    10073920   83  Linux
```

从这里可以看到，我们的目标磁盘`/dev/sda`(往往是一块固态)，所使用的最后一个扇区的扇区号是 20969087。记住这个数字，等会需要使用

### 使用dd命令创建磁盘映像ghost.img

```
dd   bs=512 count=[fdisk命令中最大的end数+1] if=/dev/sda of=/ghost.img
##在这里 count=20969088。
```

dd执行完毕后，ghost.img就在U盘中了。

### 将U盘中的ghost.img写到需要恢复系统的电脑磁盘上

将该liveCD启动u盘插到要恢复系统的电脑上，使用该U盘启动电脑。使用dd命令将ghost.img写进目标磁盘

```
dd if=/ghost.img of=/dev/sda
```

执行完毕之后，关机，选择硬盘启动，即可发现系统恢复成功。

## 使用压缩，减小ghost.img

使用以下命令——使用gzip压缩/解压缩
```
dd   bs=512 count=[fdisk命令中最大的end数+1] if=/dev/sda | gzip -6 > /ghost.img.gz
gzip -dc /ghost.img.gz | dd of=/dev/sda
```

### 查看dd进度

```
watch -n 5 pkill -USR1 ^dd$  #每五秒输出一次进度
```

```
13185281+0 records in
13185281+0 records out
6750863872 bytes (6.8 GB) copied, 252.002 s, 26.8 MB/s
13708065+0 records in
13708065+0 records out
7018529280 bytes (7.0 GB) copied, 257.014 s, 27.3 MB/s
14320025+0 records in
14320025+0 records out
```

## 恢复系统后的网卡问题

> 引用：如果你把镜像恢复到另一台计算机上，你可能会发现你的网卡是eth1，而不是eth0。这是因为/etc/udev/rules.d/70-persistent-net.rules文件把你做镜像的计算机的网卡作为eth0登记了。

>如果你的网络脚本对eth0进行了处理，而没有对eth1进行处理，那么不修改网络脚本，你可能无法上网了。

>也许你会希望在做镜像之前，先删除 /etc/udev/rules.d/70-persistent-net.rules 文件。这样你恢复镜像时，网卡的名字是eth0。   不会造成你在恢复后的计算机上无法上网的问题了。


可能会存在，系统启动后无法上网，使用ifconfig命令只能看到lo这一个网卡，无eth0网卡。这是因为恢复系统时将老系统上存留的网卡配置也带了过来，但是与新机器信息不对导致的。因此需要更正这一部分的配置。eth0的配置在：

```
/etc/sysconfig/network-scripts/ifcfg-eth0
```

先来看看几种`ifcfg-eth0`的内容吧

```
cat /etc/sysconfig/network-scripts/ifcfg-eth0
==================================
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
==================================
DEVICE=eth0
TYPE=Ethernet
BOOTPROTO=dhcp
ONBOOT=yes
DEFROUTE=yes
==================================
DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.2.31
GATEWAY=192.168.2.1
NETMASK=255.255.255.0
==================================
DEVICE=eth0
HWADDR=52:54:00:A3:5A:FB
IPADDR=10.23.238.233
NETMASK=255.255.0.0
GATEWAY=10.23.0.1
BOOTPROTO=none
PEERDNS=yes
USERCTL=no
NM_CONTROLLED=no
ONBOOT=yes
MTU=1454
DNS1=10.23.255.1
DNS2=10.23.255.2
DNS3=114.114.114.114
==================================
```

现在来看看这些都是什么意思，从CSDN上找到一篇[Linux网络接口配置文件ifcfg-eth0解析](https://blog.csdn.net/jmyue/article/details/17288467)

1 TYPE：

- 配置文件接口类型。在/etc/sysconfig/network-scripts/目录有多种网络配置文件，有Ethernet 、IPsec等类型，网络接口类型为Ethernet。

2 DEVICE:

- 网络接口名称

3 BOOTPROTO

- 系统启动地址协议
- none：不使用启动地址协议; 
- bootp：BOOTP协议;
- dhcp：DHCP动态地址协议;
- static：静态地址协议

4 ONBOOT

- 系统启动时是否激活
- yes：系统启动时激活该网络接口; 
- no：系统启动时不激活该网络接口;

5 IPADDR

- IP地址

6 NETMASK

- 子网掩码

7 GATEWAY

- 网关地址

8 BROADCAST

- 广播地址

9 HWADDR/MACADDR

- MAC地址。只需设置其中一个，同时设置时不能相互冲突。

10 PEERDNS

- 是否在这里定义网卡的DNS
- yes：如果DNS{1、2}设置，则写入/etc/resolv.conf，作为系统DNS;
- no：即使DNS{1、2}设置，也不写入/etc/resolv.conf
- BOOTPROTO为dhcp时，dhcp会自动设置DNS服务器，不需要设置PEERDNS

11 DNS{1, 2}

- DNS地址。当PEERDNS为yes时会被写入/etc/resolv.conf中。

12 NM_CONTROLLED

- 是否由Network Manager控制该网络接口。修改保存后立即生效，无需重启。被其坑过几次，建议一般设为no。
- yes：由Network Manager控制；
- no：不由Network Manager控制；

13 USERCTL

- 用户权限控制 
- yes：非root用户允许控制该网络接口；
- no：非root用户不运行控制该网络接口；

14 IPV6INIT 

- 是否执行IPv6 yes/no

15 IPV6ADDR 

- IPv6地址/前缀长度


知道这些参数的含义，应该就能模仿以上的`ifcfg-eth0`写出自己的网卡配置了。使用dhcp的最为简单，需要自己配置静态ip的需要做的就比较多了，要填写子网掩码、网关，这些信息在某些云服务商那里还是挺难获取的呀。