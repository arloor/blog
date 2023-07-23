---
title: "K3S多云环境下的离线部署"
date: 2023-07-23T11:01:10+08:00
draft: false
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

这几天把k8s折腾了个遍，个人觉得k3s更适合我，主要有五个优势

1. 类似springboot的“约定优于配置”，就是默认给你一个开箱即用的东西，如果需要，再进行修改。而不是k8s那样样样要你配置
2. 内置[LoadBalancer实现](https://docs.k3s.io/networking#service-load-balancer)，而不是像k8s那样没有LoadBalancer实现，导致裸机安装情况下得用NodePort、HostPort、HostNetwork来暴露服务，或者安装Metallb。
3. 可以轻松的支持多云环境，对我这种有多个vps的玩家很友好
4. 资源消耗较少。虽然节点增加后，控制面的内存压力也不小
5. 文档[docs.k3s.io](https://docs.k3s.io/)很清晰。PS：不要看中文版的文档，也不要看rancher中国的文档，垃圾

<!--more-->

## 环境说明

- linux发型版： RHEL9.2
- firewalld关闭
- selinux关闭

## 离线安装

步骤说明：

1. 下载离线安装包
2. 下载k3s可执行文件
3. 下载install.sh安装脚本
4. 进行安装

Tips：

1. 关于离线安装，参考：[Manually Deploy Images Method](https://docs.k3s.io/installation/airgap#manually-deploy-images-method)
2. 关于多云部署，参考[Distributed hybrid or multicloud cluster](https://docs.k3s.io/installation/network-options#distributed-hybrid-or-multicloud-cluster)。
3. 多云部署需要预先安装wireguard的内核模块，RHEL9的5.14内核已经内置，老的发行版需要参考[WireGuard Install Guide](https://www.wireguard.com/install/)(k3s agent节点也需要安装wireguard内核模块)
4. 执行安装脚本时，会把当前的http_proxy环境变量传递给kubectl、kubelet、containerd。因为我当前的shell代理是127.0.0.1，集群内的kubelet和containerd根本不通，所以有个 `. unpass`来取消当前代理。后面会在集群内部用pod的方式起个clash代理。代理传递参考：[Configuring an HTTP proxy](https://docs.k3s.io/advanced#configuring-an-http-proxy)。
5. 每一个wget后面都跟着注释标明原始的资源url是什么。
6. 安装好server后，可以在server node上 `cat /var/lib/rancher/k3s/server/token` 查看agent加入集群的token。
7. `--node-external-ip=<SERVER_EXTERNAL_IP> --flannel-backend=wireguard-native --flannel-external-ip` 来设置server的使用外网ip，以实现多云集群
8. `--node-external-ip=<AGENT_EXTERNAL_IP>` 来实现Agent使用外网ip，以实现多云集群。
9. 多云集群下，k3s的监管流量走外网的websocket，cluster流量走wireguard的VPN
10. 禁用traefik ingress controller。我觉得它用起来太烦了，而且还占用了80、443端口，不如直接用LoadBalancer
11. 集群节点越多，对控制面节点的CPU、内存压力越大，参见[requirements#cpu-and-memory](https://docs.k3s.io/installation/requirements#cpu-and-memory)

### 创建控制面Server节点

```bash
. pass # 设置代理
wget "http://cdn.arloor.com/k3s/k3s-airgap-images-amd64.tar" -O k3s-airgap-images-amd64.tar # https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s-airgap-images-amd64.tar
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo mv -f ./k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/

wget "http://cdn.arloor.com/k3s/k3s" -O k3s #https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s
mv -f k3s /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
wget "http://cdn.arloor.com/k3s/install.sh" -O install.sh #https://get.k3s.io/
chmod +x install.sh
. unpass #取消设置代理
K3S_TOKEN=12345 INSTALL_K3S_SKIP_DOWNLOAD=true   ./install.sh \
	--node-external-ip="`curl https://bwg.arloor.dev:444/ip -k`" \
    --flannel-backend=wireguard-native \
    --flannel-external-ip \
	--disable=traefik # 禁用traefik ingress controller
watch kubectl get pod -A
```

### Agent节点加入集群


```bash
. pass # 设置代理
wget "http://cdn.arloor.com/k3s/k3s-airgap-images-amd64.tar" -O k3s-airgap-images-amd64.tar # https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s-airgap-images-amd64.tar
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo mv -f ./k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/

wget "http://cdn.arloor.com/k3s/k3s" -O k3s #https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s
mv -f k3s /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
wget "http://cdn.arloor.com/k3s/install.sh" -O install.sh #https://get.k3s.io/
chmod +x install.sh

# server上 cat /var/lib/rancher/k3s/server/token  的到token
K3S_TOKEN=K10dc4730767f0ca319862ffc29159ecc96ac84cfdebb36edf6380b959d143fd97a::server:12345 \
INSTALL_K3S_SKIP_DOWNLOAD=true \
K3S_URL=https://118.25.142.222:6443  \
bash install.sh \
--node-external-ip="`curl https://bwg.arloor.dev:444/ip -k`"
```

### 卸载Server和Agent

```bash
/usr/local/bin/k3s-uninstall.sh
/usr/local/bin/k3s-agent-uninstall.sh
```

### 另一个选择：使用Rancher的中国加速镜像安装

```bash
. unpass
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh -o install.sh
chmod +x install.sh
INSTALL_K3S_MIRROR=cn  INSTALL_K3S_VERSION=v1.27.3+k3s1 K3S_TOKEN=12345 ./install.sh \
		--node-external-ip="`curl https://bwg.arloor.dev:444/ip -k`" \
    --flannel-backend=wireguard-native \
    --flannel-external-ip \
		--disable=traefik
watch kubectl get pod -A
```

虽然rancher中国的文档不咋样，但是这个加速镜像还是要点赞的， `INSTALL_K3S_MIRROR=cn` 环境变量就是来使用加速镜像的。此方式也不需要使用代理。我是在[Rancher中国的安装选项介绍](https://docs.rancher.cn/docs/k3s/installation/install-options/_index/#%E4%BD%BF%E7%94%A8%E8%84%9A%E6%9C%AC%E5%AE%89%E8%A3%85%E7%9A%84%E9%80%89%E9%A1%B9)找到这个镜像的。建议配合 `INSTALL_K3S_VERSION=v1.27.3+k3s1`环境变量指定k3s版本为v1.27.3+k3s1(我离线安装的版本)



## kubernetes dashboard安装

> 这里还是使用v2.7.0版本，因为v3.0.0版本需要ingress-nginx-controller，而我不想用ingress-controller。

下载k8s dashboard的manifest，并预先下载镜像

```bash
. pass
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml -O recommended.yaml
. unpass
crictl pull docker.io/kubernetesui/dashboard:v2.7.0
crictl pull docker.io/kubernetesui/metrics-scraper:v1.0.8
```

修改Service/kubernetes-dashboard，将type设置成LoadBalancer，修改port为8443，修改后的样子：

```yaml
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 8443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  type: LoadBalancer
```

创建工作负载

```bash
. unpass
kubectl apply -f recommended.yaml
watch kubectl get pod -n kubernetes-dashboard
```

生成ServiceRole和ClusterRoleBinding，并生成token。之后执行 `token` 命令，即可得到dashboard的token

```bash
cat > sa.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
kubectl apply -f sa.yaml

cat > roleBind.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
kubectl apply -f roleBind.yaml

cat > /usr/local/bin/token <<\EOF
kubectl -n kubernetes-dashboard create token admin-user
EOF
chmod +x /usr/local/bin/token
```

```bash
token
```

![](/img/k3s-two-nodes.png)

## 访问集群

The kubeconfig file stored at /etc/rancher/k3s/k3s.yaml is used to configure access to the Kubernetes cluster. If you have installed upstream Kubernetes command line tools such as kubectl or helm you will need to configure them with the correct kubeconfig path. This can be done by either exporting the KUBECONFIG environment variable or by invoking the --kubeconfig command line flag. Refer to the examples below for details.

Leverage the KUBECONFIG environment variable:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods --all-namespaces
helm ls --all-namespaces
```

Or specify the location of the kubeconfig file in the command:

```bash
kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get pods --all-namespaces
helm --kubeconfig /etc/rancher/k3s/k3s.yaml ls --all-namespaces
```

