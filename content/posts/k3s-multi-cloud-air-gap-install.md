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
3. 可以轻松的支持多云环境，对我这种有多个云厂商vps的玩家很友好
4. 资源消耗较少。虽然节点增加后，控制面的内存压力也不小
5. 文档[docs.k3s.io](https://docs.k3s.io/)很清晰。PS：不要看中文版的文档，也不要看rancher中国的文档，垃圾

<!--more-->

## 环境说明

- linux发型版： RHEL9.2
- 关闭firewalld
- 关闭selinux
- 安装v1.27.3+k3s1版本k3s
- 安装v2.7.0版本kubernetes-dashboard

## 离线安装

步骤说明：

1. 下载离线安装包
2. 下载k3s可执行文件
3. 下载install.sh安装脚本
4. 进行安装

Tips：

1. 关于离线安装，参考：[Manually Deploy Images Method](https://docs.k3s.io/installation/airgap#manually-deploy-images-method)。下面的脚本通过wget和mv命令展示了如何准备各项资源来做离线安装
2. 关于多云部署，参考[Distributed hybrid or multicloud cluster](https://docs.k3s.io/installation/network-options#distributed-hybrid-or-multicloud-cluster)。
3. 多云部署需要预先安装wireguard的内核模块，RHEL9的5.14内核已经内置，老的发行版需要参考[WireGuard Install Guide](https://www.wireguard.com/install/)(k3s agent节点也需要安装wireguard内核模块)
4. 执行安装脚本时，默认会把当前的http_proxy环境变量传递给kubectl、kubelet、containerd。我通过 `CONTAINERD_`开头的环境变量配置了仅供containerd使用的而不影响kubectl、kubelet的本地clash代理，用于加速镜像拉取。不过这不是必须的，因为docker hub没有被墙。代理传递参考：[Configuring an HTTP proxy](https://docs.k3s.io/advanced#configuring-an-http-proxy)。
5. `--node-external-ip=<SERVER_EXTERNAL_IP> --flannel-backend=wireguard-native --flannel-external-ip` 来设置server的使用外网ip，以实现多云集群
6. `--node-external-ip=<AGENT_EXTERNAL_IP>` 来实现Agent使用外网ip，以实现多云集群。
7. 多云集群下，k3s的监管流量走外网的websocket，cluster流量走wireguard的VPN。我的集群是国内和国外机器都有，wireguard流量特征明显，不知道gfw会不会干扰wireguard流量
8. 禁用traefik ingress controller。我觉得它用起来太烦了，而且还占用了80、443端口，不如直接用LoadBalancer
9. 集群节点越多，对控制面节点的CPU、内存压力越大，参见[requirements#cpu-and-memory](https://docs.k3s.io/installation/requirements#cpu-and-memory)

### 创建控制面Server节点

```bash
wget "https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s-airgap-images-amd64.tar" -O k3s-airgap-images-amd64.tar
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo mv -f ./k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/

wget "https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s" -O k3s 
mv -f k3s /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
wget "https://get.k3s.io/" -O install.sh
chmod +x install.sh
. unpass #取消我的http_proxy环境变量
CONTAINERD_HTTP_PROXY=http://127.0.0.1:3128 \
CONTAINERD_HTTPS_PROXY=http://127.0.0.1:3128 \
CONTAINERD_NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
K3S_TOKEN=12345 \
INSTALL_K3S_SKIP_DOWNLOAD=true \
./install.sh \
--node-external-ip="`curl https://bwg.arloor.dev:444/ip -k`" \
--flannel-backend=wireguard-native \
--flannel-external-ip \
--disable=traefik # 禁用traefik ingress controller
watch kubectl get pod -A
```

安装好server后，在server node上执行以下命令来得到agent加入集群的token：

```bash
cat /var/lib/rancher/k3s/server/token
```


### Agent节点加入集群


```bash
. unpass
wget "http://cdn.arloor.com/k3s/k3s-airgap-images-amd64.tar" -O k3s-airgap-images-amd64.tar # https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s-airgap-images-amd64.tar
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo mv -f ./k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/

wget "http://cdn.arloor.com/k3s/k3s" -O k3s #https://github.com/k3s-io/k3s/releases/download/v1.27.3%2Bk3s1/k3s
mv -f k3s /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
wget "http://cdn.arloor.com/k3s/install.sh" -O install.sh #https://get.k3s.io/
chmod +x install.sh

# server上 cat /var/lib/rancher/k3s/server/token  的到token
K3S_TOKEN=K10098693af78777497406169383c59586da0916a6fc63bd293d9881f48b4789e0f::server:12345 \
INSTALL_K3S_SKIP_DOWNLOAD=true \
K3S_URL=https://118.25.142.222:6443  \
bash install.sh \
--node-external-ip="`curl https://bwg.arloor.dev:444/ip -k`"
```

如果Agent节点能自由访问Internet，也可以用下面的命令：

```bash
wget https://get.k3s.io/ -O install.sh \
&& chmod +x install.sh
INSTALL_K3S_VERSION=v1.27.3+k3s1 \
K3S_TOKEN=K10098693af78777497406169383c59586da0916a6fc63bd293d9881f48b4789e0f::server:12345 \
K3S_URL=https://118.25.142.222:6443  \
./install.sh \
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

先介绍两种安装方式，首先是通过manifest yaml文件安装，另一种是通过helm chart安装。再介绍token生成，以及使用token登陆kubernetes-dashboard。

### 使用manifest安装

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

### 使用helm安装

安装helm：

```bash
wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -O /tmp/helm-v3.12.0-linux-amd64.tar.gz
tar -zxvf /tmp/helm-v3.12.0-linux-amd64.tar.gz -C /tmp
mv /tmp/linux-amd64/helm  /usr/local/bin/
```

安装dashboard的helm chart

> 需要先参考[访问集群](#访问集群)设置kubeconfig，从而让helm与集群交互

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm search repo kubernetes-dashboard -l #找到 app version 2.7.0对应的version为6.0.8
helm show values kubernetes-dashboard/kubernetes-dashboard --version 6.0.8 > /tmp/values.yaml 
# 修改values.yaml
cat > /tmp/values.yaml <<EOF
service:
  type: LoadBalancer
  # Dashboard service port
  externalPort: 8443
metricsScraper:
  ## Wether to enable dashboard-metrics-scraper
  enabled: true
metrics-server:
  enabled: false # k3s自带了metrics-server所以这里为false
  args:
  - --kubelet-insecure-tls # 必要
  - --cert-dir=/tmp
  - --secure-port=4443
  - --kubelet-preferred-address-types=ExternalIP,InternalIP,Hostname
  - --kubelet-use-node-status-port
  - --metric-resolution=15s
EOF
kubectl create namespace kubernetes-dashboard
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard  --version 6.0.8  \
-n kubernetes-dashboard \
-f /tmp/values.yaml
watch kubectl get pod -n kubernetes-dashboard

# 卸载
# helm delete kubernetes-dashboard --namespace kubernetes-dashboard 
```

### 生成访问token

生成ServiceRole和ClusterRoleBinding，并生成token。之后执行 `token` 命令，即可得到dashboard的token

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: default

---

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
  namespace: default
EOF

cat > /usr/local/bin/token <<\EOF
kubectl -n kubernetes-dashboard create token admin-user --duration 24000h
EOF
chmod +x /usr/local/bin/token
```

```bash
token # 有效期100天
```

鉴权相关的可以看[access-control/README.md#login-view](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md#login-view)。我是用的文档中的Authorization header配合modHeader插件和上面的100天的token，使用dashboard就很方便了。

k8s的RBAC鉴权机制可以参考[Kubernetes（k8s）权限管理RBAC详解](https://juejin.cn/post/7116104973644988446)。简单说就是Role Based Access Control ，Role定义了访问一系列资源的权限。Subject有User、Group、ServiceAccount等几种。每个NameSpace都有一个默认ServiceAccount，名为"default"。Role和Subject（主体）通过RoleBinding绑定，绑定后Subject就有了Role定义的权限。ClusterRole有集群所有命名空间的权限，Role只有指定命名空间的权限。

也可以参考[创建长期存在的token](/posts/k8s-rbac-prometheus-sd-relabel-config/#创建长期存在的token)，生成永不过期的token。

![](/img/k3s-two-nodes.png)

## 访问集群

kubeconfig保存在 /etc/rancher/k3s/k3s.yaml。如果你安装了上游k8s的命令行工具，例如kubectl、helm，你需要给他们配置正确的kubeconfig位置。可以通过配置KUBECONFIG环境变量，或增加 --kubeconfig 参数来实现。细节请参考下面的例子：

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
或者

```bash
cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

### Mac上管理该k3s集群：

```bash
mkdir ~/.kube
scp root@mi.arloor.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config
curl -LO "https://dl.k8s.io/release/v1.27.3/bin/darwin/arm64/kubectl"
chmod +x kubectl
mv kubectl /data/bin/
sudo echo "118.25.142.222 mi" > /etc/hosts
sed -i "" 's/127.0.0.1/mi/' ~/.kube/config
kubectl get nodes
```

其中，Mac上安装kubectl参考[install-kubectl-binary-with-curl-on-macos](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/#install-kubectl-binary-with-curl-on-macos)。注意kubectl和集群版本要保持一致，否则有些api可能不兼容。

另外，使用sed命令是要注意： Mac 和 Linux 在 sed 命令的 -i 参数上存在一些不同。在 Linux 上，-i 参数后面可以直接跟着文件名，但在 macOS 上，-i 需要后跟一个扩展名。这个扩展名用于创建一个备份文件。如果你不想创建备份文件，你可以使用空字符串（""）作为扩展名。
