---
title: "dd安装rhel8"
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

## dd安装

```shell
## 如果是国内vps会遇到连接deb.debian.org失败的问题，需要自己设置http代理
## 镜像的root密码是arloor.com
wget http://cdn.arloor.com/rhel/Core_Install_v3.1.sh -O install.sh&&bash install.sh -dd "http://cdn.arloor.com/rhel/rhel8.img.gz"
```

dd安装使用了www.cxthhhhh.com的脚本，详见[一键网络重装系统 - 魔改版](https://www.cxthhhhh.com/network-reinstall-system-modify)

## centos8因blscfg模块导致的dd安装失败问题

如果原linux发行版是centos8、rocky linux8等，会因为grub2的blscfg模块导致报错。

blscfg模块不在使用menuentry在grub.cfg中保存启动项，而是在`/boot/loader`中保存启动项。现在的网络安装脚本都不支持blscfg，所以需要禁用该模块

```
sed -i "s/^GRUB_ENABLE_BLSCFG=.*/GRUB_ENABLE_BLSCFG=false/g" /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
rm -rf /boot/grub2/grub.cfg.bak
rm -rf /boot/grub2/grub.cfg.old
```

## 安装后的操作

### 磁盘扩容

镜像本身只使用了3.2G空间，需要扩容以使用全部磁盘空间

```shell
fdisk -l      #查看磁盘
#对新添加的磁盘进行分区，此处使用整块盘
#并将格式化好的盘改成lvm（8e）格式
fdisk /dev/vda  
vgdisplay   #查看系统中的逻辑组
pvdisplay   #查看系统中的物理卷
pvcreate /dev/vda3   #将新分好区的磁盘做成逻辑卷
pvdisplay  #查看系统中的物理卷
lvdisplay   #查看系统中的逻辑卷
vgextend rhel /dev/vda3  #扩展已有逻辑组
vgdisplay  #查看扩展后的逻辑组
lvextend -L 45G /dev/rhel/root  #将之前的逻辑卷扩展到45G，不是扩展了45G 
lvdisplay   #查看扩展后的逻辑卷
df -Th #查看系统磁盘使用情况，发现还是原来大小
resize2fs /dev/rhel/root  #需要重设一下扩展后的逻辑卷
df -Th #这次再看的话，已经改过来了
```

### 注册vps到redhat以获取更新

未注册的vps是无法yum update的，这里需要先行注册红帽开发者计划

```shell
sudo subscription-manager remove --all
sudo subscription-manager unregister
sudo subscription-manager clean
sudo subscription-manager register
sudo subscription-manager refresh
sudo subscription-manager attach --auto
```

**红帽开发者计划续约：**红帽开发者计划有效期只有一年，一年后就需要重新注册，流程也比较简单，详见[红帽](https://developers.redhat.com/articles/renew-your-red-hat-developer-program-subscription?extIdCarryOver=true&sc_cid=701f2000001Css5AAC#how_to_re_register_for_your_red_hat_developer_subscription)

简单总结：需要你再次注册一年期的开发者订阅，而不提供“续约”，因为续约这种服务是需要付费的（资本主义操了

再次注册也很简单，用浏览器无痕模式打开[developers.redhat.com](http://developers.redhat.com/)，然后登陆，然后登出，最后关闭所有浏览器。过一会到[红帽订阅管理网站](http://access.redhat.com/management)就能看到新的开发者订阅。

之前的红帽服务器需要重新注册：


```shell
sudo subscription-manager remove --all
sudo subscription-manager unregister
sudo subscription-manager clean
sudo subscription-manager register
sudo subscription-manager refresh
sudo subscription-manager attach --auto
```

### 设置dnf代理

国内vps访问redhat的官方源比较慢，需要设置dnf的代理

```shell
vim /etc/dnf/dnf.conf
在[main]的最后面加上
proxy=<scheme>://<ip-or-hostname>[:port]
proxy_username=
proxy_password=
```

## 上述镜像是如何创建的

这部分是写给想自己创建rhel8镜像的同学看的。

### 参考文档

- [制作Linux的DD包](https://cosmiccat.net/2018/06/333/)
- [Linux格式化数据盘](https://www.alibabacloud.com/help/zh/doc-detail/25426.htm?spm=5176.2020520101disk.109.d25426.6c124df57ytrxv)
- [CentOS8修改网卡名称eth0](https://www.cnblogs.com/leoshi/p/12503088.html)
- [制作 Linux 镜像](https://cloud.tencent.com/document/product/213/17814)
- [Linux_LVM_磁盘扩容](https://www.cnblogs.com/hellojesson/p/4582908.html)

### 创建镜像

安装系统

```
wget http://blog.arloor.com/install-rhel8-form-centos7.sh -O a.sh&& bash a.sh
```

核心注意点：/boot单独分区为简单分区200M，根分区(/)使用lvm分区3.2G，格式ext4，软件选择最小安装

网卡配置选择为dhcp，dd到vps上之后可能需要改为静态ip

### 修改网卡

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

### 关闭防火墙和selinux

```shell
## 禁用firewalld
service firewalld stop
systemctl disable firewalld
## 关闭selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sestatus
```

### 修复启动

打开系统的引导文件

比如/boot/grub2/grub.cfg

确保set root行值不为UUID=XXXXXXXXXXXXXXXXXXXXXXXXXX

如果是的话请修改成hd0,1

### 最后修改/etc/fstab

将/boot使用的分区删掉

然后在rc.local或者其他能自启动的地方加上

```shell
mount /dev/vda1 /boot
```

```shell
chmod +x /etc/rc.d/rc.local
```

### 添加虚拟化所需的一些磁盘驱动

在/etc/dracut.conf里添加

```
add_drivers+="virtio_console virtio_net virtio_scsi virtio_blk"
```

然后

```
dracut -f 
```

```
lsinitrd /boot/initramfs-$(uname -r).img | grep virtio
```

可以看到已经有kvm所需的virtio驱动

```
-rw-r--r--   1 root     root         8992 Aug  4  2020 usr/lib/modules/4.18.0-240.10.1.el8_3.x86_64/kernel/drivers/block/virtio_blk.ko.xz
-rw-r--r--   1 root     root        15156 Aug  4  2020 usr/lib/modules/4.18.0-240.10.1.el8_3.x86_64/kernel/drivers/char/virtio_console.ko.xz
-rw-r--r--   1 root     root        24804 Aug  4  2020 usr/lib/modules/4.18.0-240.10.1.el8_3.x86_64/kernel/drivers/net/virtio_net.ko.xz
-rw-r--r--   1 root     root         8536 Aug  4  2020 usr/lib/modules/4.18.0-240.10.1.el8_3.x86_64/kernel/drivers/scsi/virtio_scsi.ko.xz
```

### 清空历史记录

```
echo "" > .bash_history
```

### dd

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