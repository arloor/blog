---
title: "K8s Kubeadm"
date: 2023-07-19T19:48:26+08:00
draft: true
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

- [install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [create-cluster-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [containerd get started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
- [kubernetes新版本使用kubeadm init的超全问题解决和建议](https://blog.csdn.net/weixin_52156647/article/details/129765134)


## kubeadm安装控制面

### 关闭swap

```shell
swapoff -a # 临时关闭
sed -i '/.*swap.*/d' /etc/fstab # 永久关闭，下次开机生效
```

### 安装containerd

当前版本为1.7.2

```shell
wget  https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz -O containerd.tar.gz
tar -zxvf containerd.tar.gz -C /usr/local
containerd -v # 1.7.2
## systemd服务
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
## runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 -O /tmp/runc.amd64
install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc
## cni
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz -O /tmp/cni-plugins-linux-amd64-v1.3.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin /tmp/cni-plugins-linux-amd64-v1.3.0.tgz
## 生成containerd配置文件
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
## 使用Systemd作为cggroup驱动
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/'  /etc/containerd/config.toml
## 从/etc/containerd/config.toml的disabled_plugins中去掉cri
systemctl restart containerd
```
### 安装kubtelet kubeadm kubectl

```shell
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

## 关闭selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet # 启动kubelet服务，但是会一直重启，这是正常的
kubelet --version # Kubernetes v1.27.3
kubectl version --short # Client Version: v1.27.3
```

### 初始化控制面节点

控制面节点是控制面组件运行的地方，包括etcd和api server。是kubectl打交道的地方.

```shell
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
# echo $(ip addr|grep "inet " |awk -F "[ /]+" '{print $3}'|grep -v "127.0.0.1") $(hostname) >> /etc/hosts
echo 127.0.0.1 $(hostname) >> /etc/hosts


kubeadm config print init-defaults > /etc/kubernetes/init-default.yaml
sed -i 's/imageRepository: registry.k8s.io/imageRepository: registry.aliyuncs.com\/google_containers/' /etc/kubernetes/init-default.yaml
kubeadm config images pull --image-repository=registry.aliyuncs.com/google_containers
kubeadm reset -y
kubeadm init --pod-network-cidr=192.168.0.0/16 --image-repository=registry.aliyuncs.com/google_containers --v=5 --apiserver-advertise-address=10.0.4.17

# kubeadm reset
```

