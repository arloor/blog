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

centos8在前几天发布了，但是云服务大厂们往往不会第一时间上架centos8镜像，这一篇博客就是如何在阿里云的机器上自力更生网络安装centos8。首先说明一点，以下脚本需要vps的内存至少有2G，这是Redhat8的要求，因为他的LiveOS比较大，小内存机器上请勿尝试。

<!--more-->

## 测试——kickstart

```shell
wget -O install.sh http://arloor.com/install-centos8-aliyun-kickstart.sh && bash install.sh -a
```

## 安装视频

<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/R4PDWmtQ6Zw" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>


## 脚本

执行以下命令，

```shell
cat /etc/redhat-release
wget -qO install.sh http://arloor.com/install-centos8-from-centos7.sh&& bash install.sh
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



## 源码

脚本代码如下，在很大的程度上参考了[萌咖大佬的CentosNetInstall](https://moeclub.org/2018/03/26/597/?spm=26.8)（仅支持centos8）

```c
print_info(){
    clear
    echo "#############################################################"
    echo "# Install Centos8 on a centos7 VPS.                         #"
    echo "# Usage: bash install.sh                                    #"
    echo "# Website:  http://arloor.com/                              #"
    echo "# Author: ARLOOR <admin@arloor.com>                         #"
    echo "# Github: https://github.com/arloor                         #"
    echo "#############################################################"
    echo
}

print_info


[[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1;

## 检查依赖
function CheckDependence(){
FullDependence='0';
for BIN_DEP in `echo "$1" |sed 's/,/\n/g'`
  do
    if [[ -n "$BIN_DEP" ]]; then
      Founded='0';
      for BIN_PATH in `echo "$PATH" |sed 's/:/\n/g'`
        do
          ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
          if [ $? == '0' ]; then
            Founded='1';
            break;
          fi
        done
      if [ "$Founded" == '1' ]; then
        echo -en "$BIN_DEP\t\t[\033[32mok\033[0m]\n";
      else
        FullDependence='1';
        echo -en "$BIN_DEP\t\t[\033[31mfail\033[0m]\n";
      fi
    fi
  done
if [ "$FullDependence" == '1' ]; then
  exit 1;
fi
}

echo -e "\n\033[36m# Check Dependence\033[0m\n"
CheckDependence wget,awk,xz,openssl,grep,dirname,file,cut,cat,cpio,gzip
echo "Dependence Check done"


## 寻找grub.cfg
[[ -f '/boot/grub/grub.cfg' ]] && GRUBOLD='0' && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg';
[[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub2/grub.cfg' ]] && GRUBOLD='0' && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg';
[[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub/grub.conf' ]] && GRUBOLD='1' && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf';
[ -z "$GRUBDIR" -o -z "$GRUBFILE" ] && echo -ne "Error! \nNot Found grub path.\n" && exit 1;
## 为了简单起见，不支持grub1
[ "x$GRUBOLD" = "x1" ] && echo "Error! \ngrub1 not supported, please use centos7 as Base OS. since centos7 use grub2" && exit1


echo -e "\n\033[36m# Install\033[0m\n"
## 下载kernel和initrd
echo "initrd.img downloading...."
wget --no-check-certificate -qO '/boot/initrd.img' "http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/initrd.img"
echo "vmlinuz downloading...."
wget --no-check-certificate -qO '/boot/vmlinuz' "http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/vmlinuz"
echo "done"

## 查看网络信息 ip、网关、掩码
  DEFAULTNET="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
  [[ -n "$DEFAULTNET" ]] && IPSUB="$(ip addr |grep ''${DEFAULTNET}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";
  ###ip地址
  IPv4="$(echo -n "$IPSUB" |cut -d'/' -f1)";
  ### /16 /24等子网掩码
  NETSUB="$(echo -n "$IPSUB" |grep -o '/[0-9]\{1,2\}')";
  ### 网关
  GATE="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
  ### MASK 255.255.0.0
  [[ -n "$NETSUB" ]] && MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${NETSUB}'' |cut -d'/' -f1)";

[[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
echo "Not found \`ip command\`, Exit！please use centos7 as Base os." && exit 1
}


##检查/etc/sysconfig/network-scripts
[[ ! -d '/etc/sysconfig/network-scripts' ]] && echo "/etc/sysconfig/network-scripts not exit. please use centos7 as base os.exit." && exit 1
## 检查本机是不是dhcp的 最终设置AutoNet 1-dhcp 0-static
[[ -d '/etc/sysconfig/network-scripts' ]] && {
  ICFGN="$(find /etc/sysconfig/network-scripts -name 'ifcfg-*' |grep -v 'lo'|wc -l)" || ICFGN='0';
  [[ "$ICFGN" -ne '0' ]] && {
    for NetCFG in `ls -1 /etc/sysconfig/network-scripts/ifcfg-* |grep -v 'lo$' |grep -v ':[0-9]\{1,\}'`
      do 
      ## 打印 BOOTPROTO=dhcp 如果有的话，并且设置AutoNet=1 意为启动时使用dhcp
        [[ -n "$(cat $NetCFG | sed -n '/BOOTPROTO.*[dD][hH][cC][pP]/p')" ]] && AutoNet='1' || {
          ## AutoNet=0 同时从network-scripts中加载NETMASK，GATEWAY
          AutoNet='0' && . $NetCFG;
          [[ -n $NETMASK ]] && MASK="$NETMASK";
          [[ -n $GATEWAY ]] && GATE="$GATEWAY";
        }
        [[ "$AutoNet" -eq '0' ]] && break;
      done
  }
}

echo -e "\n\033[36m# Network Infomation\033[0m"
[[ "$AutoNet" -eq '1' ]]&&{
  echo DHCP:  enable
}||{
  echo DHCP:  disable
}
echo IPV4： $IPv4
echo GATEWAY：  $GATE  
echo MASK：  $MASK $NETSUB


### 备份grub文件
[[ ! -f $GRUBDIR/$GRUBFILE ]] && echo "Error! Not Found $GRUBFILE. " && exit 1;

[[ ! -f $GRUBDIR/$GRUBFILE.old ]] && [[ -f $GRUBDIR/$GRUBFILE.bak ]] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old;
mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak;
[[ -f $GRUBDIR/$GRUBFILE.old ]] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE;

## 截取原grub中的第一个menuentry到/tmp/grub.new
[[ "$GRUBOLD" == '0' ]] && {
  READGRUB='/tmp/grub.read'
  cat $GRUBDIR/$GRUBFILE |sed -n '1h;1!H;$g;s/\n/+++/g;$p' |grep -oPm 1 'menuentry\ .*\{.*\}\+\+\+' |sed 's/\+\+\+/\n/g' >$READGRUB
  LoadNum="$(cat $READGRUB |grep -c 'menuentry ')"
  if [[ "$LoadNum" -eq '1' ]]; then
    cat $READGRUB |sed '/^$/d' >/tmp/grub.new;
  elif [[ "$LoadNum" -gt '1' ]]; then
    CFG0="$(awk '/menuentry /{print NR}' $READGRUB|head -n 1)";
    CFG2="$(awk '/menuentry /{print NR}' $READGRUB|head -n 2 |tail -n 1)";
    CFG1="";
    for tmpCFG in `awk '/}/{print NR}' $READGRUB`
      do
        [ "$tmpCFG" -gt "$CFG0" -a "$tmpCFG" -lt "$CFG2" ] && CFG1="$tmpCFG";
      done
    [[ -z "$CFG1" ]] && {
      echo "Error! read $GRUBFILE. ";
      exit 1;
    }

    sed -n "$CFG0,$CFG1"p $READGRUB >/tmp/grub.new;
    [[ -f /tmp/grub.new ]] && [[ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ]] || {
      echo -ne "\033[31mError! \033[0mNot configure $GRUBFILE. \n";
      exit 1;
    }
  fi
  [ ! -f /tmp/grub.new ] && echo "Error! $GRUBFILE. " && exit 1;
  ## 修改标头
  sed -i "/menuentry.*/c\menuentry\ \'Install Centos8 \[$DIST\ $VER\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" /tmp/grub.new
  sed -i "/echo.*Loading/d" /tmp/grub.new;
  ## 找到在哪插入新的menuentry
  INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
}


## 从已有menuentry判断/boot是否为单独分区
[[ -n "$(grep 'linux.*/\|kernel.*/' /tmp/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

LinuxKernel="$(grep 'linux.*/\|kernel.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)";
[[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
LinuxIMG="$(grep 'initrd.*/' /tmp/grub.new |awk '{print $1}' |tail -n 1)";
## 如果没有initrd 则增加initrd
[ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" /tmp/grub.new && LinuxIMG='initrd';



## 分未Inboot和NoBoot修改加载kernel和initrd的
[[ "$Type" == 'InBoot' ]] && {
  [[ "$AutoNet" -eq '1' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz  ip=dhcp inst.repo=http:\/\/mirrors.aliyun.com\/centos\/8-stream\/BaseOS\/x86_64\/os\/ inst.lang=zh_CN inst.keymap=cn selinux=0" /tmp/grub.new;
  [[ "$AutoNet" -eq '0' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz  ip=$IPv4::$GATE:$MASK:my_hostname:eth0:none inst.repo=http:\/\/mirrors.aliyun.com\/centos\/8-stream\/BaseOS\/x86_64\/os\/ inst.lang=zh_CN inst.keymap=cn selinux=0" /tmp/grub.new;
  sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrd.img" /tmp/grub.new;
}

[[ "$Type" == 'NoBoot' ]] && {
  [[ "$AutoNet" -eq '1' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz  ip=dhcp inst.repo=http:\/\/mirrors.aliyun.com\/centos\/8-stream\/BaseOS\/x86_64\/os\/ inst.lang=zh_CN inst.keymap=us selinux=0" /tmp/grub.new;
  [[ "$AutoNet" -eq '0' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz  ip=$IPv4::$GATE:$MASK:my_hostname:eth0:none inst.repo=http:\/\/mirrors.aliyun.com\/centos\/8-stream\/BaseOS\/x86_64\/os\/ inst.lang=zh_CN inst.keymap=cn selinux=0" /tmp/grub.new;
  sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrd.img" /tmp/grub.new;
}

## 增加空行
sed -i '$a\\n' /tmp/grub.new;

## 根据是否-a，决定将新的条目查到第一个还是尾部
[ "$1" = "-a" ]&&{
  ## 将新的menuentry插入到grub，作为第一个menuentry
  sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
  sed -i ''${INSERTGRUB}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE;
}||{
  ##  插入到grub尾部，并作为最后一个menuentry；同时设置超时时间为100s，以给与充分时间连接VNC
  sed -i ''${INSERTGRUB}'i\set timeout=100\n' $GRUBDIR/$GRUBFILE;
  sed -i '$i\\n' $GRUBDIR/$GRUBFILE
  sed -i '$r /tmp/grub.new' $GRUBDIR/$GRUBFILE
}

## 删除saved_entry ——即下次默认启动的
[[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;

echo -e "\n\033[36m# Due to reboot\033[0m"
echo -e "\n\033[33m\033[04mYour VPS will reboot to install Centos8.\nPlease enter the VNC in 100 seconds!\nThen you can setup the system and start the installation!\n\033[0m\n"

echo  "Enter any key to reboot Or Ctrl+C to cancel:"&& read a
sleep 1 && reboot >/dev/null 2>&1
```


## 另外三种

> 尽自己备忘

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
       set root=hd0,msdos1	       set root=hd0,msdos1
       linux16 /boot/net8/vmlinuz ro ip=dhcp nameserver=223.6.6.6 inst.repo=http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/ inst.lang=zh_CN inst.keymap=us	       linux16 /boot/net8/vmlinuz ro ip=dhcp nameserver=223.6.6.6 inst.repo=http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/  inst.lang=zh_CN inst.keymap=us inst.stage2=hd:/dev/vda1:/boot/net8/squashfs.img
       initrd16 /boot/net8/initrd.img	       initrd16 /boot/net8/initrd.img
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


