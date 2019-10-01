---
title: "阿里云轻量1c2g学生机一键网络安装centos8"
date: 2019-09-26T19:13:18+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

centos8在前几天发布了，但是云服务大厂们往往不会第一时间上架centos8镜像，这一篇博客就是如何在阿里云的机器上自力更生网络安装centos8。

<!--more-->

## 安装视频

<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/vCQVPBTfWb8" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>


## 脚本

执行以下命令，

```shell
wget -qO- http://arloor.com/centos8.sh|bash
```


## 结论——如何实现网络安装centos8

```
mkdir /boot/net8
cd /boot/net8
wget http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/vmlinuz -O vmlinuz
wget http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/initrd.img -O initrd.img
wget http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/images/install.img -O /squashfs.img

cat >> /boot/grub2/grub.cfg <<\EOF
menuentry "centos8-netboot-dhcp-localstage2" {
       set root=hd0,msdos1
       linux16 /boot/net8/vmlinuz ro ip=dhcp nameserver=223.6.6.6 inst.repo=http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/  inst.lang=zh_CN inst.keymap=us inst.stage2=hd:/dev/vda1:/boot/net8/squashfs.img
       initrd16 /boot/net8/initrd.img
}

menuentry "centos8-netboot-dhcp-localstage2" {
       set root=hd0,msdos1
       linux16 /boot/net8/vmlinuz ro ip=dhcp nameserver=223.6.6.6 inst.repo=http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/  inst.lang=zh_CN inst.keymap=us
       initrd16 /boot/net8/initrd.img
}


menuentry "centos8-netboot-dhcp-localstage2-bwg" {
       set root=hd0,msdos1
       linux16 /net8/vmlinuz ro ip=dhcp nameserver=223.6.6.6 inst.repo=http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/  inst.lang=zh_CN inst.keymap=us inst.stage2=hd:/dev/sda2:/squashfs.img
       initrd16 //net8/initrd.img
}
EOF
```

上述脚本所做：

1. 从阿里云镜像网站下载`vmlinuz`和`initrd.img`到`/boot/net8`文件夹
2. 编写grub2启动项


在做完之后，可以通过阿里云后台的VNC连接到服务器，然后重启服务器，，选择`centos8-netboot-dhcp`启动项进行启动，随后就会进入centos8安装过程。

以上便是整个过程。

## 注意事项

上一节的启动项并不适用于所有的云服务商的VPS。不同点有三处

1. `root`是`(hd0,msdos1)`还是`(hd0,1)`,这个需要自己去调整
2. `\boot`如果在单独的分区 则路径应为`/net8/{vmlinuz,initrd.img}`，同时`root`应该被`set`为`/boot`所在的`(hd0,x)`
3. 如果vps的网络配置不是`dhcp`，则`ip=`应该携带详细的ip地址、网关、子网掩码

如果看不懂上面三个是什么意思，那么请先搞懂再试图魔改该过程以实现在其他云服务商上实现安装centos8。

## 操作过程

**确定ip配置**

原系统为centos7，所以使用`network-scripts`来管理网络信息。   
首先使用如下命令，查看网卡配置：

```shell
cat /etc/sysconfig/network-scripts/ifcfg-eth0 
```

输出如下：

```
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
```

简单解释下什么意思：网卡`eth0`，使用`dhcp`来获取ip、子网掩码、网关、DNS服务器信息。   
这是进行网络安装时遇到的最简单的情况了，因为我们在这种情况下仅需要`ip=dhcp`就可以了。

在不使用dhcp的云服务vps上，其输出会像这样：

```
DEVICE=eth0
TYPE=Ethernet
BOOTPROTO=static
IPADDR=172.16.20.24
NETMASK=255.255.255.0
GATEWAY=172.16.20.1
DNS1=223.5.5.5
DNS2=114.114.114.114
ONBOO=yes
ZONE=public
```

这些字段的具体含义可以看[此链接](/posts/linux/dd-backup/#恢复系统后的网卡问题)。  
在这种情况，按照[centos8安装指南]()或者[centos7安装指南（差不多）](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html/installation_guide/chap-anaconda-boot-options#sect-boot-options-installer)上的说明，应该使用

```
ip=ip::gateway:netmask:hostname:interface:none
```

**确定磁盘分区**

首先确定`/boot`是不是单独分区：

```
# 执行 blkid -o list
device                   fs_type    label       mount point                  UUID
------------------------------------------------------------------------------------------------------------------
/dev/mapper/centos-root  xfs                    /                            a7ddaec6-e806-4d48-b080-68925dc7b11e
/dev/vda2                LVM2_member            (in use)                     Tk0rP5-0N8W-XLXy-jjSd-9uF0-a0oc-l9CyB8/dev/vda1                xfs                    /boot                        c4c7c569-0c1e-4ad5-949f-d7eb3f1ba88d
/dev/mapper/centos-swap  swap                   <swap>                       69a9267b-41b4-4f71-9e3c-5aeac964b0ff
```

这种情况下看到`/boot`是一个单独的挂载点，所以路径应该为`/net8/{vmlinuz,initrd.img}`。
而阿里云只有一个`/`挂载点，所以路径就是`/boot//net8/{vmlinuz,initrd.img}`

其次`(hd0,xxx)`

这个可以到`/boot/grub2/grub.cfg`中寻找线索。  
另一种方法是在VNC中按c进入grub的命令提示，输入如下：

```
grub> echo $root
hd0,msdos1
```

这个输出的意思就是grub会使用`(hd0,msdos1)`作为root（根地址），我们相应地`set root=(hd0,msdos1)`

进一步可以在grub的cmd中输入：

```
grub> ls ($root)/
dev/ lost+found/ usr/ opt/ ....
```

能看到这些输出。

### 阿里云上的表现

这一节确认一下阿里云上的这些需要注意的点是什么样的

```
cat /etc/sysconfig/network-scripts/ifcfg-eth0
blkid -o list
cat /boot/grub2/grub.cfg |grep "set root="  
```

输出如下： 

```
[root@qing ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth0 
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
[root@qing ~]# blkid -o list
device     fs_type label    mount point    UUID
------------------------------------------------------------------------------
/dev/vda1  ext4             /              59d9ca7b-4f39-4c0c-9334-c56c182076b5
[root@qing ~]# cat /boot/grub2/grub.cfg |grep "set root="
 set root='hd0,msdos1'
 set root='hd0,msdos1'
 set root='hd0,msdos1'
 set root='hd0,msdos1'
 set root='hd0,msdos1'
 set root='hd0,msdos1'
```

结合上文，应该能帮助理解三个注意点吧。

## 一些问题

During the installation I face a problem /sbin/dmsquash-live-root: write error: No space left on device and after this some "timeout scripts" are started with the following fail of the installation.

At this point, the guest has successfully booted the kernel and is running in initramfs environment. The installer initramfs is loading a squashfs file, which would be located at <CentOS DVD root>/LiveOS/squashfs.img. In this case, I believe it might be loading it from http://kickstart.corp.example.com/install/LiveOS/squashfs.img - or it might even be loading it over the internet from the CentOS package repository servers.

(If the latter is true, you can add a boot option inst.stage2=http://kickstart.corp.example.com/install to the append line in /var/lib/tftpboot/pxelinux/pxelinux.cfg/default to enforce loading it from a local source.)

Since the root filesystem is not yet mounted, it would be loading it into a RAM disk. At this point the installer UI is not started yet, and the local disks haven't been touched at all, although the kernel has detected that /dev/vda is present.

On an old CentOS 7 ISO image I have at hand, the squashfs.img file is 352 MiB in size. An up-to-date version is likely to be a bit larger than that; the output of curl (the tool that is actually doing the downloading) encapsulated in the messages logged by dracut-initqueue suggests that your squashfs.img is 432 MiB in size, and the download gets aborted at about the 75% point because there is not enough space (in the ramdisk, I assume).

Since the squashfs.img download was incomplete, mounting it will fail, and then the RAM disk will still be 100% full, causing the No space left on device error message.

How much RAM does your guest VM have assigned to it? If the VM is tiny, you might be running out of memory.

## 另外两种

**grub2直接引导iso**

vps必须要有两块磁盘

```
wget http://mirrors.aliyun.com/centos/8/isos/x86_64/CentOS-8-x86_64-1905-boot.iso -O /boot/boot.iso

cat >> /boot/grub2/grub.cfg <<\EOF
menuentry 'centos8-iso-boot' --unrestricted {
    loopback loop0 (hd0,msdos1)/boot/boot.iso
    linux  (loop0)/isolinux/vmlinuz inst.repo=hd:/dev/vda1:/boot/boot.iso   inst.lang=zh_CN
    initrd (loop0)/isolinux/initrd.img
}
EOF

reboot
```

**memdisk引导ISO**

内存要够大。亲测可以在1g内存的机器上使用memdisk加载centos6的netinstall.iso，centos7、8不行，

```
wget http://mirrors.aliyun.com/centos/6.10/isos/x86_64/CentOS-6.10-x86_64-netinstall.iso -O /boot/boot.iso
wget http://mirrors.aliyun.com/centos/8.0.1905/isos/x86_64/CentOS-8-x86_64-1905-boot.iso  -O /boot/boot.iso
yum install syslinux -y 
# apt-get install syslinux -y
cp -f /usr/share/syslinux/memdisk /boot/memdisk

cat >> /boot/grub2/grub.cfg <<\EOF
menuentry 'Memdisk-centos6.10' {
    # 从其他menuentry抄
    linux16 /boot/memdisk raw iso
    initrd16 /boot/boot.iso
    echo 'Booting ISO ...'
}
EOF
```
