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
wget -qO install.sh http://arloor.com/install-centos8-from-centos7.sh&& bash install.sh
```


上述脚本所做：

1. 从阿里云镜像网站下载`vmlinuz`和`initrd.img`到`/boot/net8`文件夹
2. 编写grub2启动项


在做完之后，可以通过阿里云后台的VNC连接到服务器，然后重启服务器，，选择`install centos8 [ ]`启动项进行启动，随后就会进入centos8安装过程。

以上便是整个过程。


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
