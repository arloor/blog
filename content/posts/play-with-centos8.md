---
title: "玩转Centos8"
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

上一篇在阿里云上安装了centos8，现在就开一篇centos8的踩坑记录，还是比较多的。。
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