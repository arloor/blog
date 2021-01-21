---
title: "Centos8没了，那就用rhel8"
date: 2021-01-21T11:36:10+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

2020年12月8日，红帽宣布将从2021年12月31日起停止维护centos系统，转而将精力投向centos stream。2021年1月20日，红帽又宣布rhel系统的开发者订阅可以用于小型生产环境，允许授权16台主机获得红帽的更新。原文链接[新年，新的Red Hat Enterprise Linux程序：访问RHEL的更简便方法](https://www.redhat.com/en/blog/new-year-new-red-hat-enterprise-linux-programs-easier-ways-access-rhel)。

但是想要在云服务器上安装rhel系统在当前并不是一件简单的事情，这篇博客就是通过一种方式来安装redhat8系统

## 参考文档

1. [红帽开发者网站-rhel下载](https://developers.redhat.com/products/rhel/download)
2. [使用 HTTP 或 HTTPS 创建安装源](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/creating-installation-sources-for-kickstart-installations_installing-rhel-as-an-experienced-user#creating-an-installation-source-on-http_creating-installation-sources-for-kickstart-installations)

## 过程简述

1. 搭建redhat8的安装源，类似阿里云腾讯云的centos镜像网站
2. 下载redhat8的isolinux的内核和init程序的img文件
3. 编写grub2启动的menuentry，填写相关内核参数，以使用上述的内核文件和init程序启动redhat8安装程序。
4. 安装redhat系统
5. 【进阶】使用kickstart文件控制安装过程自动进行

全部的参考文档都在[执行高级 RHEL 安装](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/index)

## 1. 创建镜像网站

首先到[红帽开发者网站-rhel下载](https://developers.redhat.com/products/rhel/download)注册开发者账号，然后下载rhel8的DVD iso到一台提供http服务的公网vps上。

然后挂载该镜像到一个目录，然后启动httpd服务

```shell
# 下面这个链接自己在下载页面复制
wget https://access.cdn.redhat.com/content/origin/files/sha256/30/30fd8dff2d29a384bd97886fa826fa5be872213c81e853eae3f9d9674f720ad0/rhel-8.3-x86_64-dvd.iso?_auth_=xxxxxxxxxxx -O redhat8.iso
lsof -i:80
yum install httpd
mkdir /mnt/rhel8-install/
mount -o loop,ro -t iso9660 ~/redhat8.iso
mount -o loop,ro -t iso9660 ~/redhat8.iso /mnt/rhel8-install/
cp -r /mnt/rhel8-install/ /var/www/html/
systemctl start httpd.service
```

现在可以访问`http://exmaple.com/rhel8-install/`来查看镜像网站 http://someme.me/rhel8-install/

```
wget -O install.sh https://blog.arloor.com/install-rhel8-form-centos7.sh && bash install.sh
```

## 2. 下载内核文件和initd程序文件

安装redhat系统也需要一个系统，而系统的启动本身就需要一个linux内核和initd程序（pid=1的程序），这一步所做的就是下载这两个文件到boot分区上的文件夹中。

我们使用第一步搭建好的镜像网站来下载内核和initd文件：

```
baseUrl="http://someme.me/rhel8-install/"
## 下载kernel和initrd
echo "initrd.img downloading...."
wget --no-check-certificate -qO '/boot/initrd.img' "${baseUrl}/isolinux/initrd.img"
echo "vmlinuz downloading...."
wget --no-check-certificate -qO '/boot/vmlinuz' "${baseUrl}/isolinux/vmlinuz"
echo "done"
```

下载好的内核和initd文件都在`/boot`路径下。在linux系统上，无论哪种分区,`/boot`都在启动分区上。

## 3. 编写grub2启动项的内核参数

先给下一个实际的menuentry例子：

```shell
menuentry 'Install Centos8 [ ]' --class debian --class gnu-linux --class gnu --class os {
        load_video
        set gfxpayload=keep
        insmod gzio
        insmod part_msdos
        insmod ext2
        set root='hd0,msdos1'
        if [ x$feature_platform_search_hint = xy ]; then
          search --no-floppy --fs-uuid --set=root --hint='hd0,msdos1'  4b499d76-769a-40a0-93dc-4a31a59add28
        else
          search --no-floppy --fs-uuid --set=root 4b499d76-769a-40a0-93dc-4a31a59add28
        fi
        linux16 /boot/vmlinuz  ip=dhcp inst.repo=http://someme.me/rhel8-install/BaseOS/ inst.lang=zh_CN inst.keymap=cn selinux=0 inst.stage2=http://someme.me/rhel8-install/
        initrd16        /boot/initrd.img
}
```

值得关注的是`linux16`和`initrd16`开头的行，其他的行都是从系统启动项的其他menuentry里抄过来的，以保证grub2能正常地引导linux内核。

**linux16**

这是内核启动参数，这些参数就是控制如何启动安装系统的系统。一般安装系统的时候我们使用的是linux发行版提供的DVD iso或者boot iso。DVD iso是一个大而全的东西，boot iso也提供了足够用于安装系统的东西。我们这种方式比较特别，启动安装过程的东西只有内核和initd程序，这是不够的。这些内核启动参数就是告诉内核，哪里能找到安装所需的软件。

关于这些参数的更多解释：[Anaconda Boot Options](https://github.com/rhinstaller/anaconda/blob/rhel-8.0/docs/boot-options.rst)或者查看[rhel7这部分的文档](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html/installation_guide/chap-anaconda-boot-options)（rhel8这部分文档不全）

这里简单讲下我们用到的参数：

1. ip=dhcp 指定本机连接网络的方式，这台机器是dhcp的。对于非dhcp的机器，需要

```
ip=<ip>::<gateway>:<netmask>:<hostname>:<interface>:none
例如：
ip=$IPv4::$GATE:$MASK:my_hostname:eth0:none
```

其中IPv4,GATE,MASK这些需要从当前系统获取。

2. inst.repo= 安装源，这里就是上面的镜像网站。
3. inst.stage2= 安装器运行的镜像，也被称为liveOS。不指定的话，会与inst.repo相同。这个选项需要包含有效 .treeinfo 文件的目录路径；如果发现这个文件，则会从这个文件中读取运行时映象位置。如果 .treeinfo 文件不可用，Anaconda 会尝试从 LiveOS/squashfs.img 中载入该映象。[http://someme.me/rhel8-install/.treeinfo](http://someme.me/rhel8-install/.treeinfo)下的stage2标签
4. selinux=0 关闭selinux

**initrd16**

指定initd文件的位置

## 4 安装redhat系统

![](/img/redhat8-install-0.jpg)
![](/img/redhat8-install-1.jpg)
![](/img/redhat8-install-2.jpg)
![](/img/redhat8-install-3.jpg)

## 5 kickstart文件

把ks.cfg上传到镜像网站上，然后在linux16后增加`inst.ks=http://someme.me/rhel8-install/ks.cfg`即可激活下面的kickstart配置

kickstart配置文件文档:[CHAPTER 4. CREATING KICKSTART FILES](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/creating-kickstart-files_installing-rhel-as-an-experienced-user)

[在线生成kickstart](https://access.redhat.com/labsinfo/kickstartconfig)

例子：

```
#version=RHEL8
autopart --type=plain --nohome --noboot
# Partition clearing information
clearpart --all --initlabel
# Use graphical install
graphical


%packages
@^minimal-environment

%end

# Keyboard layouts
keyboard --vckeymap=cn --xlayouts='cn'
# System language
lang zh_CN.UTF-8

# Network information
network  --hostname=rhel8.localdomain
# 用于非dhcp的机器，即使用静态IP的机器，相关变量需要替换
# network --bootproto=static --ip=$IPv4 --netmask=$MASK --gateway=$GATE --device=ens3 --nameserver=223.6.6.6 --ipv6=auto --activate

# Use network installation
url --url="http://someme.me/rhel8-install/BaseOS/"

# SELinux configuration
selinux --disabled
firewall --disabled

# Run the Setup Agent on first boot
firstboot --enable

# Intended system purpose
syspurpose --sla="Self-Support"

# System timezone
timezone Asia/Shanghai --isUtc

# Root password
rootpw --plaintext arloor.com
services --enabled="chronyd"
sshkey --username=root "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQzKHfZLlFEdaRUjfSK4twhL0y7+v23Ko4EI1nl6E1/zYqloSZCH3WqQFLGA7gnFlqSAfEHgCdD/4Ubei5a49iG0KSPajS6uPkrB/eiirTaGbe8oRKv2ib4R7ndbwdlkcTBLYFxv8ScfFQv6zBVX3ywZtRCboTxDPSmmrNGb2nhPuFFwnbOX8McQO5N4IkeMVedUlC4w5//xxSU67i1i/7kZlpJxMTXywg8nLlTuysQrJHOSQvYHG9a6TbL/tOrh/zwVFbBS+kx7X1DIRoeC0jHlVJSSwSfw6ESrH9JW71cAvn6x6XjjpGdQZJZxpnR1NTiG4Q5Mog7lCNMJjPtwJ not@home"

%addon com_redhat_kdump --disable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
```

## 6 终极放送

```
wget -O install.sh https://blog.arloor.com/install-rhel8-form-centos7.sh && bash install.sh
```

里面有很多在上面的过程中没有提及的细节，可以直接完成安装

## 红帽订阅管理

[https://access.redhat.com/management](https://access.redhat.com/management)