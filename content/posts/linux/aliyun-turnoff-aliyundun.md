---
title: "阿里云vps关闭阿里云盾"
date: 2019-03-21T16:46:54+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
---

阿里云 ECS 默认自动安装了阿里云盾（安骑士）的 WAF 防火墙，这个云盾基本是没有用的，唯一的用处就是记录一些所谓的漏洞、扫描/注入攻击以便在阿里云后台提示用户购买使用收费版“安骑士”服务。可以说这玩意儿除了是阿里云营销“套路”调用获取数据外基本没有什么用的，摆设的感觉非常强烈。删！
<!--more-->



# 阿里云ECS关闭删除安骑士

Linux 服务器运维人员，都有一定程度的“洁癖”，既然是没有卵用的东西，自然就要关停掉，作为一个常驻后台的进程始终给人的感觉怪怪的。

其实已经注意这货很久了，以前是担心会对阿里云服务有影响，后来发现仅仅是个摆设而已，所以就度娘、谷哥一番关闭这货。

不搜索不知道，竟然有那么多站长们都已经关闭和清除阿里云盾（安骑士）了，并且好像方法还有好多种呢。

## 方法1：卸载云盾监控屏蔽 IP

阿里云云盾管理页面：https://yundun.console.aliyun.com/?p=aqs#/aqs/settings/setInstall

阿里云官网手动卸载：https://help.aliyun.com/document_detail/31777.html

1、卸载阿里云盾监控

```
wget http://update.aegis.aliyun.com/download/uninstall.sh
sh uninstall.sh
wget http://update.aegis.aliyun.com/download/quartz_uninstall.sh
sh quartz_uninstall.sh
```

2、删除残留

```
pkill aliyun-service
rm -rf /etc/init.d/agentwatch /usr/sbin/aliyun-service
rm -rf /usr/local/aegis*
```

3、屏蔽云盾 IP​

```
iptables -I INPUT -s 140.205.201.0/28 -j DROP
iptables -I INPUT -s 140.205.201.16/29 -j DROP
iptables -I INPUT -s 140.205.201.32/28 -j DROP
iptables -I INPUT -s 140.205.225.192/29 -j DROP
iptables -I INPUT -s 140.205.225.200/30 -j DROP
iptables -I INPUT -s 140.205.225.184/29 -j DROP
iptables -I INPUT -s 140.205.225.183/32 -j DROP
iptables -I INPUT -s 140.205.225.206/32 -j DROP
iptables -I INPUT -s 140.205.225.205/32 -j DROP
iptables -I INPUT -s 140.205.225.195/32 -j DROP
iptables -I INPUT -s 140.205.225.204/32 -j DROP
```

## 方法2：CentOS 关闭 AliYunDun

使用 chkconfig --list 查看开机启动里面这个软件的服务名是什么，然后 off 掉 aegis 执行就可以了。

```
# chkconfig --list
aegis           0:off   1:off   2:on    3:on    4:on    5:on    6:off
agentwatch      0:off   1:off   2:on    3:on    4:on    5:on    6:off
cloudmonitor    0:off   1:off   2:on    3:on    4:on    5:on    6:off
mysql           0:off   1:off   2:off   3:off   4:off   5:off   6:off
netconsole      0:off   1:off   2:off   3:off   4:off   5:off   6:off
network         0:off   1:off   2:on    3:on    4:on    5:on    6:off
```

如果想开机不启动的话，chkconfig --del aegis 这个 aegis 就是你找出来的 aliyundun 的后台服务。

```
service aegis stop  # 停止服务
chkconfig --del aegis  # 删除服务
```
 
## 方法3：阿里云服务器关闭云盾

阿里云服务器查杀关闭云盾进程

查杀关闭云盾进程处理过程如下：

```
# ps -ef | grep -v grep | grep -i aliyundun
root     18779     1  0 12:33 ?        00:00:00 /usr/local/aegis/aegis_update/AliYunDunUpdate
root     18832     1  0 12:33 ?        00:00:01 /usr/local/aegis/aegis_client/aegis_10_39/AliYunDun
# ps -ef | grep -v grep | grep -i aliyundun | awk '{print $2}'
18779
18832
# ps -ef | grep -v grep | grep -i aliyundun | awk '{print $2}' | xargs kill -9
```


## 方法4：别的公司用的uninstall.sh 适用centos7

```
#!/bin/bash

#check linux Gentoo os 
var=`lsb_release -a | grep Gentoo`
if [ -z "${var}" ]; then 
 var=`cat /etc/issue | grep Gentoo`
fi

if [ -d "/etc/runlevels/default" -a -n "${var}" ]; then
 LINUX_RELEASE="GENTOO"
else
 LINUX_RELEASE="OTHER"
fi

stop_aegis(){
 killall -9 aegis_cli >/dev/null 2>&1
 killall -9 aegis_update >/dev/null 2>&1
 killall -9 aegis_cli >/dev/null 2>&1
 killall -9 AliYunDun >/dev/null 2>&1
 killall -9 AliHids >/dev/null 2>&1
 killall -9 AliYunDunUpdate >/dev/null 2>&1
    printf "%-40s %40s\n" "Stopping aegis" "[  OK  ]"
}

remove_aegis(){
if [ -d /usr/local/aegis ];then
    rm -rf /usr/local/aegis/aegis_client
    rm -rf /usr/local/aegis/aegis_update
 rm -rf /usr/local/aegis/alihids
fi
}

uninstall_service() {
   
   if [ -f "/etc/init.d/aegis" ]; then
  /etc/init.d/aegis stop  >/dev/null 2>&1
  rm -f /etc/init.d/aegis 
   fi

 if [ $LINUX_RELEASE = "GENTOO" ]; then
  rc-update del aegis default 2>/dev/null
  if [ -f "/etc/runlevels/default/aegis" ]; then
   rm -f "/etc/runlevels/default/aegis" >/dev/null 2>&1;
  fi
    elif [ -f /etc/init.d/aegis ]; then
         /etc/init.d/aegis  uninstall
     for ((var=2; var<=5; var++)) do
   if [ -d "/etc/rc${var}.d/" ];then
     rm -f "/etc/rc${var}.d/S80aegis"
      elif [ -d "/etc/rc.d/rc${var}.d" ];then
    rm -f "/etc/rc.d/rc${var}.d/S80aegis"
   fi
  done
    fi

}

stop_aegis
uninstall_service
remove_aegis
umount /usr/local/aegis/aegis_debug


printf "%-40s %40s\n" "Uninstalling aegis"  "[  OK  ]"
```

# 删除阿里云登录界面欢迎信息

```
Welcome to Ubuntu 17.04 (GNU/Linux 4.10.0-19-generic x86_64)
* Documentation: https://help.ubuntu.com
* Management: https://landscape.canonical.com
* Support: https://ubuntu.com/advantage
Welcome to Alibaba Cloud Elastic Compute Service !
Last login from
```

就莫名的不爽，于是查了一下 vim /etc/motd

就可以编辑/删除倒数第二行的 Welcome to Alibaba Cloud Elastic Compute Service ! 欢迎信息了。