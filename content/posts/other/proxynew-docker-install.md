---
author: "刘港欢"
date: 2019-01-21
linktitle: 快速安装HttpProxy
title: 快速安装HttpProxy
categories: [ "代理"]
tags: ["program"]
weight: 10
showcomments: true
---

[HttpProxy](https://github.com/arloor/HttpProxy)是一个轻量、稳定、高性能的http代理，仅仅依赖netty和日志框架，实现http中间人代理和https隧道代理。google、youtube视频、满带宽下载、作为git的代理、作为shell的代理、作为docker的代理等场景都运行完美。

这一篇博客记录一下如何部署和使用这个代理
<!--more-->


# 说明

客户端：使用go语言编写，提供windows、linux、mac平台的编译好的客户端软件。

服务端：使用docker安装运行。项目地址[HttpProxy](https://github.com/arloor/HttpProxy)

暂不支持手机使用。


# 服务器端安装

首先需要有一台在墙外的服务器，个人使用的是搬瓦工 DC6 CN2 GIA 机房的vps。[购买链接](https://bwh88.net/aff.php?aff=11132&pid=87)

> 搬瓦工 DC6 CN2 GIA 机房，编号为 USCA_6，使用中国电信优先级最高的 CN2 GIA 线路，中国电信、中国联通、中国移动三网去程回程全部走 CN2 GIA，线路质量非常好，可以说是等级最高的国际出口。经过测试，去程和回程都使用中国电信提供的cn2 GIA线路，个人使用十分满意

下面以centos7为例，介绍服务器端的配置，配置过程可以分为三步：

1. 安装docker
2. 拉取镜像
3. 运行容器

其他linux发行版的不同只在于安装docker部分，不想使用centos7的同学可以自行搜索自己系统的docker安装教程。docker的入门可以参见[docker使用笔记](/posts/docker/docker-first-use/)

## 安装docker

```
# 安装相关依赖
yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
# 设置docker源
yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
# 安装docker 
yum install docker-ce
# 开机自启动docker服务
systemctl enable docker
```


## 拉取镜像并运行


```
# 运行docker
service docker start
# 拉取镜像（第一次运行时才需要运行此命令）
docker pull arloor/proxyserver:1.0
# 运行
docker run -d --name proxy -p 8080:8080 --restart always arloor/proxyserver:1.0
```

成功走通，则服务端启动成功，下面需要做的就是客户端的安装与设置


# linux系统客户端安装

windows系统的朋友不需要做这一小节说的东西哈

安装：

```bash
sudo su
mkdir /usr/local/proxy
cd /usr/local/proxy
wget --no-check-certificate -O proxy.json http://cdn.arloor.com/proxygo/proxy.json
wget --no-check-certificate -O pac.txt http://cdn.arloor.com/proxygo/pac.txt
wget --no-check-certificate -O proxygo http://cdn.arloor.com/proxygo/proxygo
chmod +x proxygo

cat > /lib/systemd/system/proxy.service <<EOF
[Unit]
Description=proxygo
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/local/proxy/proxygo 
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
service proxy start
exit
cd 
```

编辑/etc/hosts，增加一行 

```
xx.xx.xx.xx proxy
```

手动修改linux系统的代理设置为自动代理设置（pac模式），pac的URL地址：[http://127.0.0.1:9999/pac](http://127.0.0.1:9999/pac)

# windows 客户端安装

下载[proxygo.exe](http://cdn.arloor.com/proxygo/proxygo.exe)和[pac.txt](http://cdn.arloor.com/proxygo/pac.txt)和[proxy.json](http://cdn.arloor.com/proxygo/proxy.json)。（三个文件需要在同一文件夹）

编辑 `C:\Windows\System32\drivers\etc\hosts` ，会要求系统管理员权限，点击允许。如果那个文件不能直接编辑，则将他复制出来进行编辑，再移回原文件夹。

需要在这个文件夹中增加一行`xx.xx.xx.xx proxy`  注意把`xx.xx.xx.xx`换成自己服务器的ip。注意这一行前面不要加`#`哦。

之后双击proxygo.exe就成功运行了（只需要双击一次哦，不会有界面蹦出来的），重启浏览器就可以使用此代理了(也许要耐心等一会哦)。

# 问题排查

如果等了好久还没有用，作以下排查

1. ping proxy。看看通不通
2. 访问[http://127.0.0.1:9999/pac](http://127.0.0.1:9999/pac)。如果不能访问则说明客户端启动失败；如果看到“404 page not found”说明pac.txt与exe文件不在同一文件夹中
3. 查看系统代理设置，是否使用了本代理：是否是pac模式，pac地址 http://127.0.0.1:9999/pac
4. 查看浏览器的代理设置是否被插件修改，例如SwitchyOmega
5. 如果还是不行，请联系 admin@arloor.com

# 设置客户端开机启动

默认需要linux客户端的都是高玩，就不介绍如何linux如何加入开机自启动了。

而mac系统设置开机自启动我忘记了，不做介绍（大概需要创建一个快捷方式，然后把这个快捷方式加入到开机自启动列表。有mac的用户如果知道得话，欢迎在评论中分享一下）

下面是windows加入开机自启动的过程。

1. 创建proxygo.exe的快捷方式
2. 按`win+r`输入`shell:startup`，将上一步生成的快捷方式移动到打开的文件夹中(类似这个路径：

```
C:\Users\用户名\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
```

# 手机客户端

暂时基本不可能移植到手机上了，研究了shadowsocks安卓的实现，发现和这个tcp的代理不是一回事，详情可以看[安卓Vpn开发思路](/posts/other/android-vpnservice-and-vpn-dev/)

