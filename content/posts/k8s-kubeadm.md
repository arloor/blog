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

- [install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [create-cluster-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [containerd get started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
- [kubernetes新版本使用kubeadm init的超全问题解决和建议](https://blog.csdn.net/weixin_52156647/article/details/129765134)


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
wget  https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz -O containerd.tar.gz
tar -zxvf containerd.tar.gz -C /usr/local
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
cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
sed -i 's/sandbox_image.*/sandbox_image = "registry.aliyuncs.com\/google_containers\/pause:3.9"/' /etc/containerd/config.toml
## 从/etc/containerd/config.toml的disabled_plugins中去掉cri
## systemd服务
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service
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

sudo systemctl enable --now kubelet # 启动kubelet服务，但是会一直重启，这是正常的
kubelet --version # Kubernetes v1.27.3
kubectl version --short # Client Version: v1.27.3
```

### 初始化控制面节点

控制面节点是控制面组件运行的地方，包括etcd和api server。是kubectl打交道的地方.

```shell
# echo $(ip addr|grep "inet " |awk -F "[ /]+" '{print $3}'|grep -v "127.0.0.1") $(hostname) >> /etc/hosts
# echo 127.0.0.1 $(hostname) >> /etc/hosts


kubeadm config print init-defaults --component-configs KubeletConfiguration> /etc/kubernetes/init-default.yaml
sed -i 's/imageRepository: registry.k8s.io/imageRepository: registry.aliyuncs.com\/google_containers/' /etc/kubernetes/init-default.yaml
# 将criSocket改成 unix:///run/containerd/containerd.sock containerd的
# 将cgroupDriver改成systemd
# 将advertiseAddress改成实际地址
kubeadm config images pull --config /etc/kubernetes/init-default.yaml
kubeadm init --config /etc/kubernetes/init-default.yaml

# 如果执行有问题，就kubeadm reset重新进行kubeadm init
```

```shell
[init] Using Kubernetes version: v1.27.0
[preflight] Running pre-flight checks
        [WARNING Hostname]: hostname "node" could not be reached
        [WARNING Hostname]: hostname "node": lookup node on 183.60.83.19:53: no such host
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local node] and IPs [10.96.0.1 10.0.4.17]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost node] and IPs [10.0.4.17 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost node] and IPs [10.0.4.17 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 6.504062 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node node as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node node as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: abcdef.0123456789abcdef
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.4.17:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:53732d5e7da9dc9b64050765e20475aa0e695b43279fe874da614c6bd1f39ea6
```

