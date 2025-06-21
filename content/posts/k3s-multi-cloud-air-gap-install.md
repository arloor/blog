---
title: "K3S多云环境下的离线部署"
date: 2023-07-23T11:01:10+08:00
draft: false
categories: ["undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
---

这几天把 k8s 折腾了个遍，个人觉得 k3s 更适合我，主要有五个优势

1. 类似 springboot 的“约定优于配置”，就是默认给你一个开箱即用的东西，如果需要，再进行修改。而不是 k8s 那样样样要你配置
2. 内置[LoadBalancer 实现](https://docs.k3s.io/networking#service-load-balancer)，而不是像 k8s 那样没有 LoadBalancer 实现，导致裸机安装情况下得用 NodePort、HostPort、HostNetwork 来暴露服务，或者安装 Metallb。
3. 可以轻松的支持多云环境，对我这种有多个云厂商 vps 的玩家很友好
4. 资源消耗较少。虽然节点增加后，控制面的内存压力也不小
5. 文档[docs.k3s.io](https://docs.k3s.io/)很清晰。PS：不要看中文版的文档，也不要看 rancher 中国的文档，垃圾

<!--more-->

## 环境说明

- linux 发型版： RHEL9.2
- 关闭 firewalld
- 关闭 selinux
- 安装 v1.27.3+k3s1 版本 k3s
- 安装 v2.7.0 版本 kubernetes-dashboard

## 离线安装

步骤说明：

1. 下载离线安装包
2. 下载 k3s 可执行文件
3. 下载 install.sh 安装脚本
4. 进行安装

Tips：

1. 关于离线安装，参考：[Manually Deploy Images Method](https://docs.k3s.io/installation/airgap#manually-deploy-images-method)。下面的脚本通过 wget 和 mv 命令展示了如何准备各项资源来做离线安装
2. 关于多云部署，参考[Distributed hybrid or multicloud cluster](https://docs.k3s.io/installation/network-options#distributed-hybrid-or-multicloud-cluster)。
3. 多云部署需要预先安装 wireguard 的内核模块，RHEL9 的 5.14 内核已经内置，老的发行版需要参考[WireGuard Install Guide](https://www.wireguard.com/install/)(k3s agent 节点也需要安装 wireguard 内核模块)
4. 执行安装脚本时，默认会把当前的 http*proxy 环境变量传递给 kubectl、kubelet、containerd。我通过 `CONTAINERD*`开头的环境变量配置了仅供 containerd 使用的而不影响 kubectl、kubelet 的本地 clash 代理，用于加速镜像拉取。不过这不是必须的，因为 docker hub 没有被墙。代理传递参考：[Configuring an HTTP proxy](https://docs.k3s.io/advanced#configuring-an-http-proxy)。
5. `--node-external-ip=<SERVER_EXTERNAL_IP> --flannel-backend=wireguard-native --flannel-external-ip` 来设置 server 的使用外网 ip，以实现多云集群
6. `--node-external-ip=<AGENT_EXTERNAL_IP>` 来实现 Agent 使用外网 ip，以实现多云集群。
7. 多云集群下，k3s 的监管流量走外网的 websocket，cluster 流量走 wireguard 的 VPN。我的集群是国内和国外机器都有，wireguard 流量特征明显，不知道 gfw 会不会干扰 wireguard 流量
8. 禁用 traefik ingress controller。我觉得它用起来太烦了，而且还占用了 80、443 端口，不如直接用 LoadBalancer
9. 集群节点越多，对控制面节点的 CPU、内存压力越大，参见[requirements#cpu-and-memory](https://docs.k3s.io/installation/requirements#cpu-and-memory)

### 创建控制面 Server 节点

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

安装好 server 后，在 server node 上执行以下命令来得到 agent 加入集群的 token：

```bash
cat /var/lib/rancher/k3s/server/token
```

### Agent 节点加入集群

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

如果 Agent 节点能自由访问 Internet，也可以用下面的命令：

```bash
wget https://get.k3s.io/ -O install.sh \
&& chmod +x install.sh
INSTALL_K3S_VERSION=v1.27.3+k3s1 \
K3S_TOKEN=K10098693af78777497406169383c59586da0916a6fc63bd293d9881f48b4789e0f::server:12345 \
K3S_URL=https://118.25.142.222:6443  \
./install.sh \
--node-external-ip="`curl https://bwg.arloor.dev:444/ip -k`"
```

### 卸载 Server 和 Agent

```bash
/usr/local/bin/k3s-uninstall.sh
/usr/local/bin/k3s-agent-uninstall.sh
```

### 另一个选择：使用 Rancher 的中国加速镜像安装

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

虽然 rancher 中国的文档不咋样，但是这个加速镜像还是要点赞的， `INSTALL_K3S_MIRROR=cn` 环境变量就是来使用加速镜像的。此方式也不需要使用代理。我是在[Rancher 中国的安装选项介绍](https://docs.rancher.cn/docs/k3s/installation/install-options/_index/#%E4%BD%BF%E7%94%A8%E8%84%9A%E6%9C%AC%E5%AE%89%E8%A3%85%E7%9A%84%E9%80%89%E9%A1%B9)找到这个镜像的。建议配合 `INSTALL_K3S_VERSION=v1.27.3+k3s1`环境变量指定 k3s 版本为 v1.27.3+k3s1(我离线安装的版本)

## 测试 dns 正常工作

```bash
kubectl run curl --image=redhat/ubi9-minimal --attach --command --rm --restart=Never -- \
sh -c 'curl https://kubernetes.default:443 -k -v; echo $?'
```

| 参数              | 说明                            |
| ----------------- | ------------------------------- |
| `--attach`        | 附加到 pod 中                   |
| `--command`       | `--` 后的表示命令，而不是参数   |
| `--rm`            | 运行完成后删除 pod              |
| `--restart=Never` | 不设置的话，会是 backoff 的状态 |

## kubernetes dashboard 安装

先介绍两种安装方式，首先是通过 manifest yaml 文件安装，另一种是通过 helm chart 安装。再介绍 token 生成，以及使用 token 登陆 kubernetes-dashboard。

### 使用 manifest 安装

> 这里还是使用 v2.7.0 版本，因为 v3.0.0 版本需要 ingress-nginx-controller，而我不想用 ingress-controller。

下载 k8s dashboard 的 manifest，并预先下载镜像

```bash
. pass
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml -O recommended.yaml
. unpass
crictl pull docker.io/kubernetesui/dashboard:v2.7.0
crictl pull docker.io/kubernetesui/metrics-scraper:v1.0.8
```

修改 Service/kubernetes-dashboard，将 type 设置成 LoadBalancer，修改 port 为 8443，修改后的样子：

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

### 使用 helm 安装

安装 helm：

```bash
wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -O /tmp/helm-v3.12.0-linux-amd64.tar.gz
tar -zxvf /tmp/helm-v3.12.0-linux-amd64.tar.gz -C /tmp
mv /tmp/linux-amd64/helm  /usr/local/bin/
```

安装 dashboard 的 helm chart

> 需要先参考[访问集群](#访问集群)设置 kubeconfig，从而让 helm 与集群交互

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

### 生成访问 token

kubernetes-dashboard 使用 RBAC 的权限控制，需要我们生成 ServiceRole 和 ClusterRoleBinding，并生成 token。可以生成永不过期的 token，也可以生成带过期时间的 token

#### 永不过期的 token

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: arloor
  namespace: default

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: arloor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: arloor
  namespace: default

---

apiVersion: v1
kind: Secret
metadata:
  name: arloor-secret
  namespace: default
  annotations:
    kubernetes.io/service-account.name: arloor
type: kubernetes.io/service-account-token
EOF

kubectl get secret/arloor-secret -o yaml #查看token字段，base64格式的
kubectl describe secret/arloor-secret # 查看token字段，原始的
```

其中 kubectl get 得到的是 Base64 编码过的，需要 base64 解码才能使用：

```bash
base64 -d - <<EOF
xxxxxxx token
EOF
```

#### 带过期时间的 token

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: arloor
  namespace: default

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: arloor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: arloor
  namespace: default
EOF

cat > /usr/local/bin/token <<\EOF
kubectl create token arloor --duration 24000h
EOF
chmod +x /usr/local/bin/token
```

```bash
token # 有效期100天
```

使用 token 登陆 dashboard 后可以看到类似下面的界面

![](/img/k3s-two-nodes.png)

kubernetes-dashboard 的鉴权机制可以看[access-control](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md#login-view)。我是用的文档中的 Authorization header 配合 chrome 的 modHeader 插件来使用上面的 token 进行鉴权，这样使用 dashboard 就很方便了。

k8s 的 RBAC 鉴权机制可以参考[Kubernetes（k8s）权限管理 RBAC 详解](https://juejin.cn/post/7116104973644988446)。简单说就是 Role Based Access Control ，Role 定义了访问一系列资源的权限。Subject 有 User、Group、ServiceAccount 等几种。每个 NameSpace 都有一个默认 ServiceAccount，名为"default"。Role 和 Subject（主体）通过 RoleBinding 绑定，绑定后 Subject 就有了 Role 定义的权限。ClusterRole 有集群所有命名空间的权限，Role 只有指定命名空间的权限。

## 访问集群

kubeconfig 保存在 /etc/rancher/k3s/k3s.yaml。如果你安装了上游 k8s 的命令行工具，例如 kubectl、helm，你需要给他们配置正确的 kubeconfig 位置。有三种方式，推荐方式三。

1. 配置 KUBECONFIG 环境变量

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods --all-namespaces
helm ls --all-namespaces
```

2. 增加 `--kubeconfig` 参数

```bash
kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get pods --all-namespaces
helm --kubeconfig /etc/rancher/k3s/k3s.yaml ls --all-namespaces
```

3. 复制到默认 kubeconfig 的位置

```bash
cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

### Mac 上管理该 k3s 集群：

```bash
mkdir ~/.kube
scp root@mi.arloor.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config
curl -LO "https://dl.k8s.io/release/v1.27.3/bin/darwin/arm64/kubectl"
chmod +x kubectl
mv kubectl /data/bin/
sed -i "" 's/127.0.0.1/118.25.142.222/' ~/.kube/config
kubectl get nodes
```

其中，Mac 上安装 kubectl 参考[install-kubectl-binary-with-curl-on-macos](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/#install-kubectl-binary-with-curl-on-macos)。注意 kubectl 和集群版本要保持一致，否则有些 api 可能不兼容。

另外，使用 sed 命令是要注意： Mac 和 Linux 在 sed 命令的 -i 参数上存在一些不同。在 Linux 上，-i 参数后面可以直接跟着文件名，但在 macOS 上，-i 需要后跟一个扩展名。这个扩展名用于创建一个备份文件。如果你不想创建备份文件，你可以使用空字符串（""）作为扩展名。

## Server 或 Agent IP 改变时的操作

下面以 ServerIP 变更为例：

**Server**

1. 修改 `/etc/systemd/system/k3s.service` 中的 `--node-external-ip` 参数
2. 重启 k3s 服务

```bash
systemctl daemon-reload
systemctl restart k3s
```

**Agent**

```bash
sed -i 's/K3S_URL.*/K3S_URL="https:\/\/154.xx.xx.xx:6443"/'  /etc/systemd/system/k3s-agent.service.env
systemctl restart k3s-agent.service
```

## 2025 重新折腾

在家用小主机上使用

## 安装k3s

```bash
version=$(curl -s https://api.github.com/repos/k3s-io/k3s/releases/latest | jq -r '.tag_name')
version_url_encoded=$(echo $version | sed 's/+/%2B/g' | sed 's/\//\\\//g')
echo 安装 k3s 版本 $version
mkdir -p /var/lib/rancher/k3s/agent/images/
curl -L -o /var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar.zst "https://us.arloor.dev/https://github.com/k3s-io/k3s/releases/download/${version_url_encoded}/k3s-airgap-images-amd64.tar.zst"
curl -L -o /tmp/k3s "https://us.arloor.dev/https://github.com/k3s-io/k3s/releases/download/${version_url_encoded}/k3s"
install /tmp/k3s /usr/local/bin/


curl -L "https://get.k3s.io/" -o k3s_init.sh
chmod +x k3s_init.sh
. unpass #取消我的http_proxy环境变量
CONTAINERD_HTTP_PROXY=http://127.0.0.1:3128 \
CONTAINERD_HTTPS_PROXY=http://127.0.0.1:3128 \
CONTAINERD_NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
K3S_TOKEN=12345 \
INSTALL_K3S_SKIP_DOWNLOAD=true \
./k3s_init.sh
cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config # 复制 kubeconfig 到默认位置
kubectl get pod -A --watch --output wide
```

## 安装helm

[Installing Helm](https://helm.sh/docs/intro/install/)

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 安装 kubernetes-dashboard

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm search repo kubernetes-dashboard -l 
helm show values kubernetes-dashboard/kubernetes-dashboard --version 7.13.0 > /tmp/values.yaml
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard --set kong.enabled=false
# 临时访问
kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443
```

## 配置 kubernetes-dashboard 的 traefik ingress

- [How to to configure Ingress when deploying on K3S with Traefik? #9554](https://github.com/kubernetes/dashboard/issues/9554)
- [Traefik & Kubernetes with Ingress](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/ingress/)
- [Middleware](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/crd/http/middleware/)

1. Middleware that will redirect http to https
2. Ingress for the http
3. Actual ingress on https

```bash
host=k3s.arloor.com
kubectl apply -f - <<EOF
# 创建k3s-arloor-tls secret
apiVersion: v1
kind: Secret
metadata:
  # secret名
  name: k3s-arloor-tls
  # 证书放置的namespace
  namespace: kubernetes-dashboard
type: kubernetes.io/tls
data:
  tls.crt: $(cat /root/.acme.sh/arloor.dev/fullchain.cer | base64 -w 0)
  tls.key: $(cat /root/.acme.sh/arloor.dev/arloor.dev.key| base64 -w 0)
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-http-redirect
  namespace: kubernetes-dashboard
spec:
  redirectScheme:
    scheme: https
    permanent: true
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-http-redirect
  namespace: kubernetes-dashboard
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    # MUST be <namespace>-<name>@kubernetescrd
    traefik.ingress.kubernetes.io/router.middlewares: kubernetes-dashboard-dashboard-http-redirect@kubernetescrd
spec:
  rules:
  - host: ${host}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard-web
            port:
              number: 8000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-https
  namespace: kubernetes-dashboard
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  tls:
  - hosts:
    - ${host}
    secretName: k3s-arloor-tls
  rules:
    - host: ${host}
      http:
        paths:
          - path: /api/v1/login
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-auth
                port:
                  number: 8000
          - path: /api/v1/csrftoken/login
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-auth
                port:
                  number: 8000
          - path: /api/v1/me
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-auth
                port:
                  number: 8000
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-api
                port:
                  number: 8000
          - path: /metrics
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-api
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-web
                port:
                  number: 8000
EOF
```

## 配置私有镜像仓库

https://docs.k3s.io/installation/private-registry#with-tls

```bash
cat > /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  ttl.arloor.com:
    endpoint:
      - "http://ttl.arloor.com:6666"
EOF
```