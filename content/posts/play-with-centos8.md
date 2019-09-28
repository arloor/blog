---
title: "玩转centos8"
date: 2019-09-26T23:52:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

上一篇在阿里云上安装了centos8，现在就开一篇centos8的踩坑记录。
<!--more-->

## 关闭firewalld

```shell
service firewalld stop
systemctl disable firewalld
```

## 关闭selinux

```
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sestatus
reboot
```

## 启用elrepo

```
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
yum install https://www.elrepo.org/elrepo-release-8.0-2.el8.elrepo.noarch.rpm
```

elrepo有四个频道，分别是：`elrepo`,`elrepo-extras`,`elrepo-testing`,`elrepo-kernel`    
我们可以用如下方式使用上面的四个频道（以更新内核为例）：

```
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
yum --enablerepo=elrepo-kernel install -y kernel-ml  #以后升级也是执行这句
```

参考文档:[elrepo.org](http://elrepo.org/tiki/tiki-index.php)

## 关于yum和dnf

centos8上的yum仅仅是dnf的一个别名

```
[root@localhost ~]# ls -l /usr/bin/yum
lrwxrwxrwx. 1 root root 5 5月  14 03:34 /usr/bin/yum -> dnf-3
```

同时fastestmirror这个yum插件也不再提供，所以最好手动设置源了。

## 解压initrd.img

```
mkdir /root/test
wget http://mirrors.aliyun.com/centos/8-stream/BaseOS/x86_64/os/isolinux/initrd.img -O /root/test/initrd.img
cd /root/test
xz --decompress < initrd.img | cpio --extract --verbose --make-directories --no-absolute-fil
enames 
ls 
# bin  dev  etc  init  initrd.img  lib  lib64  proc  root  run  sbin  shutdown  sys  sysroot  tmp  usr  var

```

## 截取grub.cfg一个完整的menu

```
READGRUB='/tmp/grub.read'
  cat /etc/grub2.cfg |sed -n '1h;1!H;$g;s/\n/+++/g;$p' |grep -oPm 1 'menuentry\ .*\{.*\}\+\+\+' |sed 's/\+\+\+/\n/g' >$READGRUB
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
  cat /tmp/grub.new
```