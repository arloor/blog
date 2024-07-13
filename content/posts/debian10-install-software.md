---
title: "Debian10相关软件安装"
date: 2024-06-21T14:12:12+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

字节的工作机是debian10的系统，比较老了，记录下一些软件的安装。
<!--more-->

## 安装clang相关

参考[https://apt.llvm.org/](http://apt.llvm.org/buster/)

```bash
wget https://apt.llvm.org/llvm-snapshot.gpg.key
apt-key add llvm-snapshot.gpg.key
apt install -y software-properties-common
add-apt-repository "deb http://apt.llvm.org/buster/ llvm-toolchain-$(lsb_release -sc)-16 main"
apt update
apt install clang-format-16 clang-16
```

## 安装docker

参考[How To Install and Use Docker on Debian 10](https://www.notion.so/arloor/11f0ad24f77c4b43ad16db7bf31b38eb?pvs=4#e6ba02afe7b9475ca5afd9f6e6a10bc7)

```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common　
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
sudo systemctl status docker
sudo usermod -aG docker ${USER}
su - ${USER}
id -nG
```

给docker配置代理，以加速docker hub的访问

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo touch /etc/systemd/system/docker.service.d/http-proxy.conf

if ! grep HTTP_PROXY /etc/systemd/system/docker.service.d/http-proxy.conf;
then
cat >> /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:3128/" "HTTPS_PROXY=http://127.0.0.1:3128/" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF
fi

# Flush changes:
sudo systemctl daemon-reload
#Restart Docker:
sudo systemctl restart docker
#Verify that the configuration has been loaded:
sudo systemctl show --property=Environment docker
# 像这样：Environment=HTTP_PROXY=http://127.0.0.1:8081/ NO_PROXY=localhost,127.0.0.1,docker-registry.so
```