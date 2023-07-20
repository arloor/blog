---
title: "K8s Kubeadm"
date: 2023-07-19T19:48:26+08:00
draft: false
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 参考文档

- [install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [create-cluster-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [containerd get started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
- [kubernetes新版本使用kubeadm init的超全问题解决和建议](https://blog.csdn.net/weixin_52156647/article/details/129765134)
- [calico quick start](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)
- [containerd设置代理](https://blog.51cto.com/u_15343792/5142108)
- [工作负载pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [工作负载deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

## kubeadm安装控制面

### 机器配置

```shell
# 关闭swap
swapoff -a # 临时关闭
sed -i '/.*swap.*/d' /etc/fstab # 永久关闭，下次开机生效

# 加载内核模块
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
```

### 安装containerd

当前版本为1.7.2

```shell
wget  https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz -O /tmp/containerd.tar.gz
tar -zxvf /tmp/containerd.tar.gz -C /usr/local
containerd -v # 1.7.2
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
## 使用阿里云镜像的sandbox，和下面的kubeadm init --image-repository镜像保持一致，否则kubeadm init时控制面启动失败
sed -i 's/sandbox_image.*/sandbox_image = "registry.aliyuncs.com\/google_containers\/pause:3.9"/' /etc/containerd/config.toml
## 从/etc/containerd/config.toml的disabled_plugins中去掉cri
## systemd服务
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service
```

修改containerd.service的代理配置，否则镜像都拉不下来，calico网络插件也装不了

```shell
# 在[Service]块中增加代理配置
# NO_PROXY中
#  10.96.0.0/16是kubeadm init --service-cidr的默认地址
#  192.168.0.0/16是kubeadmin init --pod-network-cidr我们填入的地址，也是calico网络插件工作的地址
Environment="HTTP_PROXY=http://127.0.0.1:3128/"
Environment="HTTPS_PROXY=http://127.0.0.1:3128/"
Environment="NO_PROXY =10.96.0.0/16,127.0.0.1,192.168.0.0/16,localhost"
```

启动containerd服务

```shell
systemctl daemon-reload
systemctl enable --now containerd
```

### 安装crictl

```shell
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.0/crictl-v1.27.0-linux-amd64.tar.gz
tar -zxvf crictl-v1.27.0-linux-amd64.tar.gz
install -m 755 crictl /usr/local/bin/crictl
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock  version
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
# 在/etc/dnf/dnf.conf的[main]块中增加 exclude=kubelet kubeadm kubectl
echo "exclude=kubelet kubeadm kubectl" >> /etc/dnf/dnf.conf

sudo systemctl enable --now kubelet # 启动kubelet服务，但是会一直重启，这是正常的
kubelet --version # Kubernetes v1.27.3
kubectl version --short # Client Version: v1.27.3
```

### 初始化控制面节点

控制面节点是控制面组件运行的地方，包括etcd和api server。是kubectl打交道的地方.

```shell
# echo $(ip addr|grep "inet " |awk -F "[ /]+" '{print $3}'|grep -v "127.0.0.1") $(hostname) >> /etc/hosts
# echo 127.0.0.1 $(hostname) >> /etc/hosts


# kubeadm config print init-defaults --component-configs KubeletConfiguration > /etc/kubernetes/init-default.yaml
# sed -i 's/imageRepository: registry.k8s.io/imageRepository: registry.aliyuncs.com\/google_containers/' /etc/kubernetes/init-default.yaml
# sed -i 's/criSocket: .*/criSocket: unix:\/\/\/run\/containerd\/containerd.sock/' /etc/kubernetes/init-default.yaml
# sed -i 's/cgroupDriver: .*/cgroupDriver: systemd/' /etc/kubernetes/init-default.yaml

# # 将advertiseAddress改成实际地址
# kubeadm config images pull --config /etc/kubernetes/init-default.yaml
# kubeadm init --config /etc/kubernetes/init-default.yaml

echo $(ip addr|grep "inet " |awk -F "[ /]+" '{print $3}'|grep -v "127.0.0.1") $(hostname) >> /etc/hosts
kubeadm config images pull --image-repository registry.aliyuncs.com/google_containers
kubeadm init --pod-network-cidr=192.168.0.0/16 --image-repository registry.aliyuncs.com/google_containers --cri-socket unix:///run/containerd/containerd.sock
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock ps -a
# 如果执行有问题，就kubeadm reset重新进行kubeadm init
```

设置kube config

```shell
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
. unpass
kubectl get cs # 使用kubectl与集群交互
```

### 解决network plugin未安装导致的node not ready

```shell
$ kubectl get nodes
NAME   STATUS     ROLES           AGE   VERSION
node   NotReady   control-plane   49m   v1.27.3
$ kubectl describe nodes node|grep KubeletNotReady
  Ready            False   Wed, 19 Jul 2023 22:52:58 +0800   Wed, 19 Jul 2023 22:06:46 +0800   KubeletNotReady              container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
```

下面安装Calico网络插件，前提是 `--pod-network-cidr=192.168.0.0/16`，并且containerd正确设置了代理，否则下载不了Calico

```shell
# 创建tigera operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
# 创建Calico网络插件
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
watch kubectl get pods -n calico-system # 两秒刷新一次，直到所有Calico的pod变成running
```

### 让控制面节点也能调度pod 

```shell
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-
```

### 在控制面节点上跑一个nginx的pod

```shell
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml
kubectl get pods -o wide # 显示nginx的pod正Running在192.168.254.8上
curl 192.168.254.8
kubectl delete pod nginx # 删除这个pod
```