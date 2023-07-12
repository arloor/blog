---
title: "从centos8/9自动安装RHEL9.2，并制作dd镜像"
date: 2023-07-12T09:58:57+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 准备安装源

首先到[红帽开发者网站-rhel下载](https://developers.redhat.com/products/rhel/download)注册开发者账号，然后下载rhel8的DVD iso到一台提供http服务的公网vps上。

然后挂载该镜像到一个目录，然后启动httpd服务（文档:[使用 HTTP 或 HTTPS 创建安装源](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/creating-installation-sources-for-kickstart-installations_installing-rhel-as-an-experienced-user#creating-an-installation-source-on-http_creating-installation-sources-for-kickstart-installations)）

```shell
# 下面这个链接自己在下载页面复制
wget https://access.cdn.redhat.com/content/origin/files/sha256/30/30fd8dff2d29a384bd97886fa826fa5be872213c81e853eae3f9d9674f720ad0/rhel-8.3-x86_64-dvd.iso?_auth_=xxxxxxxxxxx -O redhat8.iso
lsof -i:80
yum install -y httpd
mkdir /var/www/html/rhel8-install/
mount -o loop,ro -t iso9660 ~/redhat8.iso /var/www/html/rhel8-install/
systemctl start httpd.service
# umount /var/www/html/rhel8-install/
```

## 准备kickstart自动安装配置

在上一步我们使用appache作为web服务器，我们就继续把ks.cfg放在`/var/www/html`下，下面是配置文件，可以按需修改。可能需要大家修改的点：

| 项目 | 说明 |
| :---: | :---: |
| root密码 | arloor，并且允许root通过ssh的密码登陆 |
| ssh密钥 | 为方便自己，设置了ssh公钥，大家自行删除 |
| 分区 | 为了制作镜像，这里的分区是最小分区： `/boot` 1G， `/` 3G的ext4类型的LVM。后面会涉及到扩容操作。如果不需要制作镜像，可以把reqpart到logvol都改为 `autopart --nohome`这一行|
| 其他 | 关闭了selinux和firewalld，并安装了httpd |

```shell
#version=RHEL9
ignoredisk --only-use="sda|hda|xda|vda|xvda|nvme0n1"
clearpart --all --initlabel
# autopart --nohome
reqpart
part /boot --fstype="xfs" --size=1024 
part pv.559 --fstype="lvmpv" --size=3072
volgroup rhel --pesize=4096 pv.559
logvol / --fstype="ext4" --size=3060 --name=root --vgname=
# Reboot after installation
reboot
# Use graphical install
graphical
keyboard --vckeymap=us --xlayouts='cn'
lang zh_CN.UTF-8

# Network information
network  --bootproto=dhcp  --ipv6=auto --activate --hostname=rhel9.arloor.com

# Root password
rootpw --plaintext --allow-ssh arloor
# SELinux configuration
selinux --disabled
firewall --disabled
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --enabled="chronyd"
sshkey --username=root "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQzKHfZLlFEdaRUjfSK4twhL0y7+v23Ko4EI1nl6E1/zYqloSZCH3WqQFLGA7gnFlqSAfEHgCdD/4Ubei5a49iG0KSPajS6uPkrB/eiirTaGbe8oRKv2ib4R7ndbwdlkcTBLYFxv8ScfFQv6zBVX3ywZtRCboTxDPSmmrNGb2nhPuFFwnbOX8McQO5N4IkeMVedUlC4w5//xxSU67i1i/7kZlpJxMTXywg8nLlTuysQrJHOSQvYHG9a6TbL/tOrh/zwVFbBS+kx7X1DIRoeC0jHlVJSSwSfw6ESrH9JW71cAvn6x6XjjpGdQZJZxpnR1NTiG4Q5Mog7lCNMJjPtwJ not@home"
# System timezone
timezone Asia/Shanghai --utc

%packages
@^minimal-environment
httpd

%end

%addon com_redhat_kdump --disable

%end
```

kickstart配置文件可以参考rhel9的文档：- [kickstart_references](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/performing_an_advanced_rhel_9_installation/index#kickstart_references)

## 从centos8/9自动安装RHEL9.2

需要在原来的centos8/9上做几件事：

1. 启用blscfg模块。从centos8开始才有
2. 下载kernel和initrd.img。
3. 指定kickstart自动安装的配置文件。
4. 使用grubby生成boot loader entry，并设置为默认启动项
5. 重启。

下面一键完成：

```shell
# 1. 启用blscfg模块
sed -i 's/GRUB_ENABLE_BLSCFG.*/GRUB_ENABLE_BLSCFG=true/g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
# 2. 下载网络安装的kernel
url="http://199.180.115.74"
ks_url="${url}/ks.cfg" #kickstart配置文件地址
base_url="${url}/rhel8-install"
## 可以从http://199.180.115.74/rhel8-install/.treeinfo确认地址
kernel_url="${base_url}/images/pxeboot/vmlinuz"
init_url="${base_url}/images/pxeboot/initrd.img"
curl -k  "${init_url}" -o '/boot/initrd.img'
curl -k  "${kernel_url}" -o '/boot/vmlinuz'
# 3. 使用grubby工具生成loader entry，这将由blscfg加载
machineId=`cat /etc/machine-id`
rm -rf /boot/loader/entries/${machineId}-vmlinuz*
grubby --add-kernel=/boot/vmlinuz  --make-default --initrd=/boot/initrd.img  --title="rhel9"  --args="ip=dhcp inst.repo=${base_url} inst.ks=${ks_url}" # --make-default 将设置成下次启动的内核
cat /boot/loader/entries/${machineId}-vmlinuz.conf

# [[ -f  /boot/grub2/grubenv ]] && sed -i 's/saved_entry.*/saved_entry='${machineId}'-vmlinuz/g' /boot/grub2/grubenv;
grep saved_entry /boot/grub2/grubenv
echo rebooting to install
sleep 1
reboot
```

grubby的 `--args` 是指定内核参数，可以参考rhel9官方文档：- [Boot options for RHEL Installer](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/boot_options_for_rhel_installer/index#installation-source-boot-options_kickstart-and-advanced-boot-options)或[anaconda boot options](https://github.com/rhinstaller/anaconda/blob/rhel-9/docs/boot-options.rst)。我们制定了三个参数，其含义是：

- ip=dhcp: 网络为dhcp
- inst.repo: 安装源
- inst.ks: 自动安装的配置文件

执行完毕后，可以到VNC上观看下运行情况，当然不看也无所谓，本身是无人值守运行的，过一段时间后会ssh即可使用密码arloor登陆机器了。

## 制作dd镜像

### 修复启动

确保/boot/grub2/grub.cfg中 `set root=` 不是使用UUID。如果是的话，请修改成 `'hd0,1'`

实测rhel9中是 `set root='hd0,msdos1'` 就不需要做修改了。

### /etc/fstab

~~将 `/boot` 前的UUID=，改为`/dev/vda1`~~ (搬瓦工的机器是/dev/sda1，会启动不了，所以还是在rc.local中mount)

将/boot使用的分区删掉

然后在rc.local或者其他能自启动的地方加上

```shell
sed -i "/.*\/boot.*/d" /etc/fstab
echo "mount /dev/vda1 /boot" >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
```

### 添加virtio驱动

```shell
cat >> /etc/dracut.conf <<EOF
add_drivers+=" virtio_console virtio_net virtio_scsi virtio_blk "
EOF
dracut -f
lsinitrd /boot/initramfs-$(uname -r).img | grep virtio
```


可以看到已经有virtio了：

```shell
-rw-r--r--   1 root     root        12196 Feb 15 00:45 usr/lib/modules/5.14.0-284.11.1.el9_2.x86_64/kernel/drivers/block/virtio_blk.ko.xz
-rw-r--r--   1 root     root        19152 Feb 15 00:45 usr/lib/modules/5.14.0-284.11.1.el9_2.x86_64/kernel/drivers/char/virtio_console.ko.xz
-rw-r--r--   1 root     root        45932 Feb 15 00:45 usr/lib/modules/5.14.0-284.11.1.el9_2.x86_64/kernel/drivers/net/virtio_net.ko.xz
-rw-r--r--   1 root     root        12336 Feb 15 00:45 usr/lib/modules/5.14.0-284.11.1.el9_2.x86_64/kernel/drivers/scsi/virtio_scsi.ko.xz
```

### 添加第二块磁盘

在腾讯云新建云硬盘，并挂载后，执行：

```shell
mkfs -t ext4 /dev/vdb
mkdir /dd
mount /dev/vdb /dd
df -TH
```
如果要自动挂载，可以加到 `/etc/fstab` 下，内容为：

```shell
/dev/vdb /dd   ext4 defaults     0   0
```
参考腾讯云的[云盘初始化文档](https://cloud.tencent.com/document/product/1207/81981#Steps)

### 开始dd

```shell
echo "" > .bash_history
fdisk -l -u /dev/vda
last=$(fdisk -l -u /dev/vda|tail -n 1 |awk '{print $3}') # 获取分区的末尾
echo $last
(dd   bs=512 count=$(expr ${last} + 1) if=/dev/vda | gzip -9 > /dd/9.img.gz &) ## dd到末尾+1
watch -n 5 pkill -USR1 ^dd$  # 每五秒输出一次进度
```

```shell
fdisk -l -u /dev/vda
Disk /dev/vda：120 GiB，128849018880 字节，251658240 个扇区
单元：扇区 / 1 * 512 = 512 字节
扇区大小(逻辑/物理)：512 字节 / 512 字节
I/O 大小(最小/最佳)：512 字节 / 512 字节
磁盘标签类型：dos
磁盘标识符：0x534b09a5

设备       启动    起点    末尾    扇区 大小 Id 类型
/dev/vda1  *       2048 2099199 2097152   1G 83 Linux
/dev/vda2       2099200 8390655 6291456   3G 8e Linux LVM

(dd   bs=512 count=[fdisk命令中最大的end数(这里是8390655)+1] if=/dev/vda | gzip -9 > /mnt/rhel8.img.gz &)
(dd   bs=512 count=8390656 if=/dev/vda | gzip -9 > /dd/9.img.gz &)
watch -n 5 pkill -USR1 ^dd$  # 每五秒输出一次进度
```

### 用web服务下载镜像

```shell
systemctl start httpd
ln -fs /dd/9.img.gz /var/www/html/9.img.gz
wget http://mi.arloor.com/9.img.gz -O 9.img.gz
```

## 在新机器上安装

### 安装dd镜像

centos8/9先关闭blscfg

```shell
sed -i "s/^GRUB_ENABLE_BLSCFG=.*/GRUB_ENABLE_BLSCFG=false/g" /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
rm -rf /boot/grub2/grub.cfg.bak
rm -rf /boot/grub2/grub.cfg.old
```

因为dd脚本需要使用debian的源，国内vps需要设置代理：

```shell
export http_proxy=xxx
export https_proxy=xxx
```

最后安装：

```shell
wget http://cdn.arloor.com/rhel/Core_Install_v3.1.sh -O install.sh&&bash install.sh -dd http://cdn.arloor.com/rhel/9.img.gz
```

### dd后磁盘扩容 

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
lvextend -l 99%FREE -r /dev/rhel/root  #将之前的逻辑卷扩展
lvdisplay   #查看扩展后的逻辑卷
# df -Th #查看系统磁盘使用情况，发现还是原来大小
# resize2fs /dev/rhel/root  #需要重设一下扩展后的逻辑卷
df -Th #这次再看的话，已经改过来了
```

### 注册到红帽

```shell
subscription-manager register
subscription-manager attach --auto
```
### sshd关闭密码登陆等

密码登陆可能有风险，而且我又使用了公钥登陆，就关闭密码登陆了

```shell
#关闭密码
grep "PasswordAuthentication yes " /etc/ssh/sshd_config
sed  -i  -e 's/\(#\)\?PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
#关闭GSSAPI认证登陆
sed -i "s/GSSAPIAuthentication yes/GSSAPIAuthentication no/g" /etc/ssh/sshd_config
#关闭UseDNS(解决ssh缓慢)
temp=$(cat /etc/ssh/sshd_config|grep "UseDNS"|grep -v "#");
if [ "$temp" != "" ];then
 sed -i "s/UseDNS.*/UseDNS no/g" /etc/ssh/sshd_config
else
 echo >> /etc/ssh/sshd_config
 echo UseDNS no >> /etc/ssh/sshd_config
fi
# 检查UseDNS确实被关闭
cat /etc/ssh/sshd_config|grep UseDNS
systemctl restart sshd
```