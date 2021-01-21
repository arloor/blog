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
wget -O install.sh https://blog.arloor.com/test.sh|bash && bash install.sh
```
