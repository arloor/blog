---
title: "从Centos7网络安装Centos8"
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

centos8在前几天发布了，但是云服务大厂们往往不会第一时间上架centos8镜像，这一篇博客就是如何在阿里云的机器上自力更生网络安装centos8。首先说明一点，以下脚本需要vps的内存至少有2G，这是Redhat8的要求，因为他的LiveOS比较大，小内存机器上请勿尝试。

<!--more-->



## 安装视频

[youtube](https://www.youtube.com/embed/R4PDWmtQ6Zw)


## 脚本

执行以下命令，

```shell
wget -qO install.sh http://www.arloor.com/install-centos8-from-centos7.sh && bash install.sh
```


上述脚本所做：

1. 从阿里云镜像网站下载`vmlinuz`和`initrd.img`到`/boot/net8`文件夹
2. 编写grub2启动项


在做完之后，可以通过阿里云后台的VNC连接到服务器，然后重启服务器，，选择`install centos8 [ ]`启动项进行启动，随后就会进入centos8安装过程。




## 一些问题

### vps内存过小导致的安装失败

如果内存小于2g会报如下错误：

```
/sbin/dmsquash-live-root: write error: No space left on device
```

原因在于：

At this point, the guest has successfully booted the kernel and is running in initramfs environment. The installer initramfs is loading a squashfs file, which would be located at <CentOS DVD root>/LiveOS/squashfs.img. In this case, I believe it might be loading it from http://kickstart.corp.example.com/install/LiveOS/squashfs.img - or it might even be loading it over the internet from the CentOS package repository servers.

(If the latter is true, you can add a boot option inst.stage2=http://kickstart.corp.example.com/install to the append line in /var/lib/tftpboot/pxelinux/pxelinux.cfg/default to enforce loading it from a local source.)

Since the root filesystem is not yet mounted, it would be loading it into a RAM disk. At this point the installer UI is not started yet, and the local disks haven't been touched at all, although the kernel has detected that /dev/vda is present.

On an old CentOS 7 ISO image I have at hand, the squashfs.img file is 352 MiB in size. An up-to-date version is likely to be a bit larger than that; the output of curl (the tool that is actually doing the downloading) encapsulated in the messages logged by dracut-initqueue suggests that your squashfs.img is 432 MiB in size, and the download gets aborted at about the 75% point because there is not enough space (in the ramdisk, I assume).

Since the squashfs.img download was incomplete, mounting it will fail, and then the RAM disk will still be 100% full, causing the No space left on device error message.

How much RAM does your guest VM have assigned to it? If the VM is tiny, you might be running out of memory.

### Ucloud安装失败

可能原因：Ucloud不支持pxeboot网卡安装


### 一串问题

```
[ok] Reached target Basic System
或者
[ok] starting dracut initqueue hook
或者
/dev/root does not exist
```

网上搜到的都是要设置inst.stage2=hd:/dev/sd*....

## 全自动kickstart安装centos8【自用】

所谓全自动的意思就是不需要使用VNC进行安装系统的配置，所有的网络配置、磁盘分区、软件包选择都通过kickstart进行。执行完脚本后，只需要等待若干分钟即可。以下脚本就是kickstart全自动安装的脚本，安装完毕后默认root密码为arloor.com。另外该脚本会设置公钥登录（当然是我自己的公钥了），所以在安装完毕之后，请清空`authorized_keys`。

该脚本目前仅自用，不保证可用。

```shell
wget -O kickstart.sh http://www.arloor.com/centos8-kickstart-from-centos7.sh && bash kickstart.sh -a
```

## 另外三种安装方式【备忘】

> 仅自己备忘

**grub2直接引导iso**

vps必须要有两块磁盘，因为一块硬盘会mount iso文件，无法用于安装新系统

```
wget http://mirrors.aliyun.com/centos/8/isos/x86_64/CentOS-8-x86_64-1905-boot.iso -O /boot/boot.iso


cat >> /boot/grub2/grub.cfg <<\EOF
menuentry 'centos8-iso-boot' --unrestricted {
    loopback loop0 (hd0,msdos1)/boot/boot.iso
    linux  (loop0)/isolinux/vmlinuz inst.repo=hd:/dev/vda1:/boot/boot.iso   inst.lang=zh_CN
    initrd (loop0)/isolinux/initrd.img
}
EOF

```

**设置本地stage2**

同样需要两块硬盘

```
wget http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/images/install.img -qO /boot/net8/squashfs.img
wget --no-check-certificate -qO '/boot/net8/initrd.img' "http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/initrd.img"
wget --no-check-certificate -qO '/boot/net8/vmlinuz' "http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/vmlinuz"
cat >> /boot/grub2/grub.cfg <<\EOF
menuentry "centos8-netboot-dhcp-localstage2" {
       set root=hd0,msdos1
       linux16 /boot/net8/vmlinuz ro ip=dhcp nameserver=223.6.6.6 inst.repo=http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/  inst.lang=zh_CN inst.keymap=us inst.stage2=hd:/dev/vda1:/boot/net8/squashfs.img
       initrd16 /boot/net8/initrd.img
}	
EOF
```

**memdisk引导ISO**

内存要够大。亲测可以在1g内存的机器上使用memdisk加载centos6的netinstall.iso，centos7、8不行。

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

## 安装后的设置


```
## 禁用firewalld
service firewalld stop
systemctl disable firewalld
## 关闭selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sestatus
## 开启bbr
uname -r  ##输出内核版本大于4.9
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p
lsmod |grep bbr
```
## 测试

```
wget -O kickstart.sh http://www.arloor.com/centos8-kickstart-from-centos7-stage2.sh && bash kickstart.sh -a
```

## 重新安装centos8

```
 # 手动重新安装
 curl https://www.arloor.com/centos8-reinstall.sh|bash
 # 全自动重新安装
 wget -O reinstall.sh https://www.arloor.com/centos8-kickstart-reinstall.sh && bash reinstall.sh -a
```