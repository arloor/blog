---
title: "Redhat8 Install"
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


## 参考文档

1. [红帽开发者网站-rhel下载](https://developers.redhat.com/products/rhel/download)
2. [使用 HTTP 或 HTTPS 创建安装源](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/creating-installation-sources-for-kickstart-installations_installing-rhel-as-an-experienced-user#creating-an-installation-source-on-http_creating-installation-sources-for-kickstart-installations)

## 创建镜像网站

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
print_info(){
    clear
    echo "#############################################################"
    echo "# reinstall Centos 8.                                       #"
    echo "# Usage: bash install.sh                                    #"
    echo "# Website:  http://www.arloor.com/                              #"
    echo "# Author: ARLOOR <admin@arloor.com>                         #"
    echo "# Github: https://github.com/arloor                         #"
    echo "#############################################################"
    echo
}

print_info
baseUrl="http://someme.me/rhel8-install/"


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
wget --no-check-certificate -qO '/boot/initrd.img' "${baseUrl}/BaseOS/x86_64/os/isolinux/initrd.img"
echo "vmlinuz downloading...."
wget --no-check-certificate -qO '/boot/vmlinuz' "${baseUrl}/BaseOS/x86_64/os/isolinux/vmlinuz"
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


# 展示最新的boot entry
rm -f /boot/loader/entries/temp.conf
 cd /boot/loader/entries/
 ls /boot/loader/entries/|tail -1|xargs cat > /var/temp.conf
 [[ -n "$(grep 'linux.*/\|kernel.*/' /var/temp.conf |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

 LinuxKernel="$(grep 'linux.*/\|kernel.*/' /var/temp.conf |awk '{print $1}' |head -n 1)";
[[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
LinuxIMG="$(grep 'initrd.*/' /var/temp.conf |awk '{print $1}' |tail -n 1)";
## 如果没有initrd 则增加initrd
[ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" /var/temp.conf && LinuxIMG='initrd';

## 分未Inboot和NoBoot修改加载kernel和initrd的
[[ "$Type" == 'InBoot' ]] && {
  sed -i "/$LinuxKernel.*\//c$LinuxKernel\\t\/boot\/vmlinuz" /var/temp.conf;
  sed -i "/$LinuxIMG.*\//c$LinuxIMG\\t\/boot\/initrd.img" /var/temp.conf;
}

[[ "$Type" == 'NoBoot' ]] && {
  sed -i "/$LinuxKernel.*\//c$LinuxKernel\\t\/vmlinuz" /var/temp.conf
  sed -i "/$LinuxIMG.*\//c$LinuxIMG\\t\/initrd.img" /var/temp.conf;
}

[[ "$AutoNet" -eq '1' ]] && sed -i "/options.*/coptions ip=dhcp inst.repo=http:\/\/someme.me\/rhel8-install\/BaseOS\/x86_64\/os\/ inst.lang=zh_CN inst.keymap=cn selinux=0 inst.stage2=http:\/\/someme.me\/rhel8-install\/BaseOS\/x86_64\/os\/" /var/temp.conf;
[[ "$AutoNet" -eq '0' ]] && sed -i "/options.*/coptions ip=$IPv4::$GATE:$MASK:my_hostname:eth0:none inst.repo=http:\/\/someme.me\/rhel8-install\/BaseOS\/x86_64\/os\/ inst.lang=zh_CN inst.keymap=cn selinux=0 inst.stage2=http:\/\/someme.me\/rhel8-install\/BaseOS\/x86_64\/os\/" /var/temp.conf;
sed -i "/title.*/ctitle reinstall-centos8" /var/temp.conf
sed -i "/id.*/cid reinstall-centos8" /var/temp.conf
sed -i "/version.*/cversion zthe-last" /var/temp.conf


rm -f /boot/loader/entries/temp.conf
cp /var/temp.conf /boot/loader/entries/


## 删除saved_entry ——即下次默认启动的
[[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;

echo -e "\n\033[36m# Due to reboot\033[0m"
echo -e "\n\033[33m\033[04mYour VPS will reboot to install Centos8.\nPlease enter the VNC!\nThen you can setup the system and start the installation!\n\033[0m\n"

echo  "Enter any key to reboot Or Ctrl+C to cancel:"&& read a
sleep 1 && reboot >/dev/null 2>&1
```