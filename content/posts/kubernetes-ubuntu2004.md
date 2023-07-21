---
title: "在ubuntu2004上安装Kubernetes"
date: 2022-05-09T18:21:42+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 参考文档

[https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

## 关闭swap

```bash
swapoff -a
vim /etc/fstab
## 将swap的挂载点注释掉
```

## 确保br_netfilter内核模块被加载，并且让iptables看到网桥的流量

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

```bash
lsmod | grep br_netfilter
# 如果br_netfilter没有加载，手动执行以下
modprobe br_netfilter
```

## 安装docker作为容器运行时，并修改cgroup的driver为systemd

```bash
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
## 修改cgroup的driver为systemd
vim /etc/docker/daemon.json
{
"exec-opts": ["native.cgroupdriver=systemd"]
}
## 检查
docker info 2>/dev/null|grep "Cgroup Driver"
```

## 安装kubeadm、kubectl、kubelet

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl
# 需要科学上网
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# 配置源，安装完毕后可以删除该文件
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# 需要科学上网
apt-get update
apt-get install -y kubelet kubeadm kubectl
# 配置不更新这三个软件
apt-mark hold kubelet kubeadm kubectl
## 删除源
rm -rf /etc/apt/sources.list.d/kubernetes.list
```

此时就安装好了这个三个软件，此时kubelet的service会不断重启，因为没有配置好，这是正常的。

