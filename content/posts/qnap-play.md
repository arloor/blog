---
title: "威联通NAS折腾"
date: 2022-09-17T14:55:19+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

入手了一台威联通TS-564，当作给自己的奖励。
<!--more-->

## 容器

1. 在appcentor安装Container Station
2. 搜索centos8-stream的LXD镜像，并创建容器
3. 修改容器的网络为Bridge，这样就和局域网里其他的机器网络共通了
4. 开启nas的ssh功能
5. ssh到nas上，执行`lxc exec ${容器名} -- /bin/bash`

> ssh到某机器并且一键登入容器可以:`ssh xxx@xxx.com -t 'lxc exec ${容器名} -- /bin/bash'`

lxd的容器完全可以当成富容器来用，除了不能ssh，也是有systemd的，可以运行daemon程序，这点很重要。

## 关闭sshd密码登陆

威联通的默认设置无法关闭sshd密码登陆，导致nas一直会被爆破，手动更改sshd的配置也会被qnap覆盖掉，所以需要自定义crontab来不断检查配置

```shell
# vim /share/CACHEDEV1_DATA/repo/disable_sshd_passwd.sh 
#! /bin/bash
echo $(date)
if grep -E "^PasswordAuthentication no$" /etc/config/ssh/sshd_config; then
  echo "passwd is disabled;do nothing"
else
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/g' /etc/config/ssh/sshd_config
  if grep -E "^PasswordAuthentication no$" /etc/config/ssh/sshd_config; then
    echo "passwd is disabled"
  else
    echo "append passwd disable to sshd_config"
    echo "PasswordAuthentication no" >>/etc/config/ssh/sshd_config
  fi
  sshd_pid=$(ps -ef | grep "/usr/sbin/sshd -f /etc/config/ssh/sshd_config -p 22" | grep -v "grep" | awk '{print $1}')
  echo $sshd_pid
  [ "$sshd_pid" = "" ] && {
    echo "not running"
  } || {
    echo "kill sshd"
    kill -15 $sshd_pid
  }
  /usr/sbin/sshd -f /etc/config/ssh/sshd_config -p 22
  echo "start sshd"
fi
```

```shell
## crontab -e
* * * * * /bin/bash /share/CACHEDEV1_DATA/repo/disable_sshd_passwd.sh > /share/CACHEDEV1_DATA/repo/sshd_disable_passwd.log
```

为什么放在没有放在比较常规的路径下，因为看到说威联通重启是会删除一些系统外增加的脚本

