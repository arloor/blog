---
author: "刘港欢"
date: 2019-01-21
linktitle: proxynew一键安装
title: proxynew一键安装
categories: [ "代理"]
tags: ["program"]
weight: 10
showcomments: true
---

为了方便其他同学在自己的服务器上安装proxynew，搞了一个简单的部署方式。不得不说docker很香

# 使用说明

系统需要是centos 7

# 开始安装

这个部署使用了docker镜像，高玩可以研究一下，普通玩家可以直接复制运行应该就可以了。

首先需要安装docker，然后再拉取docker镜像，最后运行，下面开始

## 安装docker

安装相关依赖

```
yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
  ```

  设置docker源

  ```
  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
```

安装docker

```
    yum install docker-ce
 ```


## 拉取镜像并运行

```
# 运行docker
service docker start
# 拉取镜像（第一次运行时才需要运行此命令）
docker pull arloor/proxyserver:1.0
# 运行
docker run -d -p 8080:8080 arloor/proxyserver:1.0
```

如果成功走到这里，服务端就成功启动了。另外需要做的就是下载客户端和配置host了，详见[release页面](https://github.com/arloor/proxynew/releases/tag/v1.4)

如果上面的走不通，可以联系admin@arloor.com