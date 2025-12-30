---
title: "K3S上手玩"
subtitle:
tags:
  - k8s
date: 2025-12-24T22:12:47+08:00
lastmod: 2025-12-24T22:12:47+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
---

在上文 [K3S 多云环境下的离线部署](/posts/k3s-multi-cloud-air-gap-install/) 中已经玩过了 1.27.3 版本的 k3s。在今年又重新玩了一遍，再次记录一下。这一次的重点是：

1. IPv4/IPv6 双栈集群的搭建
2. K3S 备份、升级、回滚
3. Kubernetes Dashboard 部署
4. ArgoCD 部署，实现 GitOps
5. reloader 部署，实现配置变更自动重启 Pod

<!--more-->

## K3S 优势

K3S 是一个轻量级的 Kubernetes 发行版，专为资源受限的环境设计。它的优势包括：

- 轻量级：K3S 的二进制文件非常小，适合在边缘设备和物联网设备上运行。
- 易于安装和配置：
  - K3S 提供了简单的安装脚本，可以快速部署一个完整的 Kubernetes 集群。
  - 使用单个二进制文件(k3s)即可运行所有组件，简化了安装过程。
- 低资源消耗：K3S 设计时考虑了资源效率，适合在低功耗设备上运行。
- 内置组件：
  - K3S 集成了许多常用的 Kubernetes 组件，如 Flannel 网络插件和 SQLite 数据库，简化了集群管理。
  - 内置[LoadBalancer 实现](https://docs.k3s.io/networking/networking-services?_highlight=servicelb#service-load-balancer)，而不是像 k8s 那样没有 LoadBalancer 实现，导致裸机安装情况下得用 NodePort、HostPort、HostNetwork 来暴露服务，或者安装 Metallb。
    - 使用 Node 的 ip 作为 LoadBalancer 的 ip。需要保证多个 LoaderBalancer Service 的端口不冲突
    - 具体实现见 [klipper-lb](https://github.com/k3s-io/klipper-lb)，比较简单。是通过 NAT 将流量转发到 Service 的 Cluster IP 上，然后 kube-proxy 再将流量转发到 Pod 上（这一步包含负载均衡和故障迁移能力）
- 文档[docs.k3s.io](https://docs.k3s.io/)很清晰。PS：不要看中文版的文档，也不要看 rancher 中国的文档，垃圾
- Flannel 的 wireguard 后端支持允许多云环境下的集群网络互通

## 参考文档：

- [离线部署](https://docs.k3s.io/installation/airgap)
- [混合云/多云集群](https://docs.k3s.io/networking/distributed-multicloud)
- [ipv4+ipv6 双栈](https://docs.k3s.io/networking/basic-network-options#dual-stack-ipv4--ipv6-networking)
- [需要放开的端口](https://docs.k3s.io/installation/requirements#inbound-rules-for-k3s-nodes)

## 安装 K3S server

1. 使用离线安装的方式，提前下载好 k3s 二进制文件和 airgap 镜像包
2. 开启 IPv4/IPv6 双栈
3. 使用 flannel 的 wireguard-native 后端，开启多云网络互通
4. 仅给 containerd 配置代理环境变量，加速镜像拉取，不影响 kubectl、kubelet。参考：[Configuring an HTTP proxy](https://docs.k3s.io/advanced#configuring-an-http-proxy)。

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
./k3s_init.sh \
--cluster-cidr=10.42.0.0/16,fd00:cafe:42::/56 --service-cidr=10.43.0.0/16,fd00:cafe:43::/112 --flannel-ipv6-masq \
--node-external-ip="`curl https://ttl.arloor.com/ip -k`" \
--flannel-backend=wireguard-native \
--flannel-external-ip \
cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config # 复制 kubeconfig 到默认位置
kubectl get pod -A --watch --output wide
```

## 安装 k3s agent

1. 使用离线安装的方式，提前下载好 k3s 二进制文件和 airgap 镜像包
2. 仅给 containerd 配置代理环境变量，加速镜像拉取，不影响 kubectl、kubelet。参考：[Configuring an HTTP proxy](https://docs.k3s.io/advanced#configuring-an-http-proxy)。

```bash
k3s_server=https://v6.arloor.com:6443
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
K3S_URL=${k3s_server} \
./k3s_init.sh \
--node-external-ip="`curl https://ttl.arloor.com/ip -k`"
```

## 创建 ServiceAccount 和 ClusterRoleBinding

```yaml
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

## 重新签发 TLS 证书，增加自己的域名

```bash
domain=k3s.arloor.com
cat > /etc/rancher/k3s/config.yaml <<EOF
tls-san:
  - ${domain}
  - kubernetes
  - kubernetes.default
  - kubernetes.default.svc
  - kubernetes.default.svc.cluster.local
  - localhost
  - station
EOF
# 或者在k3s服务中增加 --tls-san xxx.com
systemctl restart k3s
```

## 设置私有镜像仓库

```bash
cat > /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  docker.io:
    endpoint:
      - "http://ttl.arloor.com:6666"
EOF
systemctl restart k3s
```

## 导入 ACME 的 TLS 证书

```yaml
#! /bin/bash

namespace="default monitoring kubernetes-dashboard"
for ns in ${namespace}; do
  kubectl apply -f -  <<EOF
apiVersion: v1
kind: Secret
metadata:
  # secret名
  name: k3s-arloor-tls
  # 证书放置的namespace
  namespace: ${ns}
type: kubernetes.io/tls
data:
  tls.crt: $(cat /root/.acme.sh/arloor.dev/fullchain.cer | base64 -w 0)
  tls.key: $(cat /root/.acme.sh/arloor.dev/arloor.dev.key| base64 -w 0)
EOF
done
```

## 安装 kubernetes-reflector 实现跨命名空间同步 cm 和 secret

用于下面的 cert-manager 签发的证书 secret 跨命名空间同步

```bash
kubectl -n kube-system apply -f https://github.com/emberstack/kubernetes-reflector/releases/latest/download/reflector.yaml
```

## Cert-Manager 部署

> 签发很慢很慢，要 10 来分钟。。建议还是先用宿主机的 acme.sh 签发好证书，然后导入到 k3s 集群中

- [kubectl apply 安装](https://cert-manager.io/docs/installation/kubectl/#steps)
- [acme 配置](https://cert-manager.io/docs/configuration/acme/#all-together)
- [使用 Cloudflare DNS-01 Issuer](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
- [创建 Certificate 资源](https://cert-manager.io/docs/usage/certificate/)
- [The cert-manager Command Line Tool (cmctl)](https://cert-manager.io/docs/reference/cmctl/)

安装：

```bash
kubectl create namespace cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml

# 为 cert-manager 相关的 deployment 配置 HTTP 代理
kubectl set env deployment/cert-manager -n cert-manager HTTP_PROXY=http://mihomo.default.svc.cluster.local:7890 HTTPS_PROXY=http://mihomo.default.svc.cluster.local:7890 NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,.svc,.cluster.local
kubectl set env deployment/cert-manager-webhook -n cert-manager HTTP_PROXY=http://mihomo.default.svc.cluster.local:7890 HTTPS_PROXY=http://mihomo.default.svc.cluster.local:7890 NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,.svc,.cluster.local
kubectl set env deployment/cert-manager-cainjector -n cert-manager HTTP_PROXY=http://mihomo.default.svc.cluster.local:7890 HTTPS_PROXY=http://mihomo.default.svc.cluster.local:7890 NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,.svc,.cluster.local
kubectl rollout restart deployment cert-manager -n cert-manager
kubectl rollout restart deployment cert-manager-webhook -n cert-manager
kubectl rollout restart deployment cert-manager-cainjector -n cert-manager
# 等待 cert-manager 相关的 pod 全部运行起来
kubectl get pod -n cert-manager -w

# 安装 cmctl 工具，用于验证 cert-manager api-server 的安装情况
OS=$(go env GOOS); ARCH=$(go env GOARCH); curl -fsSL -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_${OS}_${ARCH}
chmod +x cmctl
sudo mv cmctl /usr/local/bin
# 验证安装
cmctl check api
```

签发证书：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: "your-cloudflare-api-token-here"
---
apiVersion: v1
kind: Secret
metadata:
  name: cert-pkcs12-password
  namespace: default
type: Opaque
stringData:
  password: "123456"
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cluser-issuer
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: root@xxxxx.xxxx
    # If the ACME server supports profiles, you can specify the profile name here.
    # See #acme-certificate-profiles below.
    profile: tlsserver
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      # This is your identity with your ACME provider. Any secret name may be
      # chosen. It will be populated with data automatically, so generally
      # nothing further needs to be done with the secret. If you lose this
      # identity/secret, you will be able to generate a new one and generate
      # certificates for any/all domains managed using your previous account,
      # but you will be unable to revoke any certificates generated using that
      # previous account.
      name: default-issuer-account-key
    solvers:
      # - http01:
      #     ingress:
      #       ingressClassName: nginx
      #   selector:
      #     matchLabels:
      #       "use-http01-solver": "true"
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
        selector:
          dnsNames:
            - "arloor.com"
            - "*.arloor.com"
            - "arloor.dev"
            - "*.arloor.dev"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: arloor-combined-cert
  namespace: default
spec:
  secretTemplate:
    annotations:
      # 向所有的命名空间反射此 secret
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: ""
      reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: ""
  privateKey:
    algorithm: RSA
    encoding: PKCS1 #PKCS8
    size: 2048
    rotationPolicy: Never # 或 Always

  # keystores allows adding additional output formats. This is an example for reference only.
  keystores:
    pkcs12:
      create: true
      passwordSecretRef:
        name: cert-pkcs12-password
        key: password
      profile: Modern2023

  secretName: arloor-combined-tls
  issuerRef:
    name: letsencrypt-cluser-issuer
    kind: ClusterIssuer
  dnsNames:
    - arloor.dev
    - "*.arloor.dev"
    - arloor.com
    - "*.arloor.com"
# # 查看证书状态
# kubectl describe certificate arloor-combined-cert -n default
# # 查看生成的证书 secret
# kubectl get secret arloor-combined-tls -n default -o yaml
```

cmctl 使用

```bash
$ kubectl get certificate
NAME                   READY   SECRET                AGE
arloor-combined-cert   True    arloor-combined-tls   13h

$ cmctl renew arloor-combined-cert -n default
Manually triggered issuance of Certificate default/arloor-combined-cert

$ kubectl get certificaterequest
NAME                              READY   AGE
arloor-combined-cert-tls-8rbv2         False    10s

$ cmctl status certificate arloor-combined-cert -n default
```

> 如果 cmctl renew 很慢，可以尝试删除对应的 CertificateRequest 资源，会触发重建。

## 安装 kubernetes-dashboard

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
# helm search repo kubernetes-dashboard -l
helm show values kubernetes-dashboard/kubernetes-dashboard --version 7.14.0 > /tmp/values.yaml
# 升级也使用相同的命令
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard --set kong.enabled=false
```

![alt text](/img/k3s-dashboard-pod.png)

## 配置 kubernetes-dashboard 的 ingress

```yaml
host="dash.arloor.com" # host="*.arloor.com"支持通配符
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
  - host: "${host}"
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
    - "${host}"
    secretName: k3s-arloor-tls
  rules:
    - host: "${host}"
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

## 修改 traefik 的 websecure 端口

[Traefik Ingress Controller](https://docs.k3s.io/networking/networking-services#traefik-ingress-controller)

```yaml
cat > /var/lib/rancher/k3s/server/manifests/traefik-mine.yaml << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ports:
      websecure:
        port: 8443
        exposedPort: 8443
EOF
kubectl apply -f /var/lib/rancher/k3s/server/manifests/traefik-mine.yaml
```

## Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# kubectl get pods -n argocd -w
# 修改argocd-server的service类型为NodePort或者LoadBalancer，方便外部访问
kubectl -n argocd get svc argocd-server -o yaml | sed 's/type: ClusterIP/type: NodePort/' | kubectl apply -f -
# 获取初始密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# kubectl port-forward service/argocd-server  8080:80 -n argocd

# argocd-server不再使用tls
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd

# 为argocd-repo-server配置git HTTP代理
kubectl set env deployment/argocd-repo-server -n argocd HTTP_PROXY=http://mihomo.default.svc.cluster.local:7890 HTTPS_PROXY=http://mihomo.default.svc.cluster.local:7890 NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,.svc,.cluster.local
kubectl rollout restart deploy argocd-repo-server -n argocd;
```

```yaml
# 创建 argocd 的 TLS secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: k3s-arloor-tls
  namespace: argocd
type: kubernetes.io/tls
data:
  tls.crt: $(cat /root/.acme.sh/arloor.dev/fullchain.cer | base64 -w 0)
  tls.key: $(cat /root/.acme.sh/arloor.dev/arloor.dev.key| base64 -w 0)
EOF

# 配置 argocd 的 ingressroute
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`argocd.arloor.com`)
      priority: 10
      services:
        - name: argocd-server
          port: 80
    - kind: Rule
      match: Host(`argocd.arloor.com`) && Headers(`Content-Type`, `application/grpc`)
      priority: 11
      services:
        - name: argocd-server
          port: 80
          scheme: h2c
  tls:
    secretName: k3s-arloor-tls
EOF
```

![alt text](/img/k3s-argocd-workload.png)

删除 argocd

```bash
kubectl delete namespace argocd
```

此时还剩下 argocd 相关的 CRD 资源，可以通过下面命令删除

```bash
kubectl get crd | grep argoproj.io | awk '{print $1}' | xargs kubectl delete crd
```

还有一些 ClusterRole 和 ClusterRoleBinding 资源，可以通过下面命令删除

```bash
kubectl get clusterrole | grep argocd | awk '{print $1}' | xargs kubectl delete clusterrole
kubectl get clusterrolebinding | grep argocd | awk '{print $1}' | xargs kubectl delete clusterrolebinding
```

## 使用 Reloader 监听 cm 和 scr 的变化并重启工作负载

- [github.com/stakater/Reloader](https://github.com/stakater/Reloader?tab=readme-ov-file#-installation)

```bash
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    # 监听所有关联的 ConfigMap 和 Secret
    reloader.stakater.com/auto: "true"
    # 监听所有关联的 Secret
    secret.reloader.stakater.com/auto: "true"
    # 监听所有关联的 ConfigMap
    configmap.reloader.stakater.com/auto: "true"

    # 或者指定具体的 ConfigMap/Secret
    configmap.reloader.stakater.com/reload: "my-config,another-config"
    secret.reloader.stakater.com/reload: "my-secret"
spec:
  # ... deployment spec
```

支持 Deployment、DaemonSet、StatefulSet、ReplicaSet、CronJob

查看日志

```bash
kubectl logs -f deployment/reloader-reloader --tail 100
```

## 在 MacOS 上管理

```bash
mkdir -p ~/.kube
scp -P 2222 root@k3s.arloor.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config
curl -LO "https://dl.k8s.io/release/v1.33.1/bin/darwin/arm64/kubectl"
chmod +x kubectl
mv kubectl /data/bin/
sed -i "" 's/127.0.0.1/v6.arloor.com/' ~/.kube/config
kubectl get nodes
```

## 在 Linux 上管理

```bash
mkdir -p ~/.kube
scp -P 2222 root@k3s.arloor.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config
curl -LO "https://dl.k8s.io/release/v1.33.1/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /data/bin/
sed -i 's/127.0.0.1/v6.arloor.com/' ~/.kube/config
kubectl get nodes
```

## 删除镜像

```bash
crictl rmi --prune
crictl rmi -a
```

## 快速 exec 容器

```bash
cat > /usr/local/bin/attach <<'EOF'
kubectl exec -it -n ${2:-default} $(kubectl get pods -l app=$1 -n ${2:-default} -o jsonpath='{.items[0].metadata.name}') -- /bin/sh
EOF
chmod +x /usr/local/bin/attach
```

第一个参数是 `app label` 的值，第二个参数是 `namespace`

## 查看日志

```bash
kubectl logs -f --tail 1000 --timestamps -l app=proxy
```

## 修改 app 的镜像

```bash
# 修改Deployment中的镜像
kubectl set image deployment/deployment-name container-name=new-image:tag -n namespace

# 示例
kubectl set image deployment/nginx-deployment nginx=nginx:1.21 -n default

# 修改DaemonSet中的镜像
kubectl set image daemonset/daemonset-name container-name=new-image:tag -n namespace

# 修改StatefulSet中的镜像
kubectl set image statefulset/statefulset-name container-name=new-image:tag -n namespace
```

## 查看集群资源使用情况

```bash
kubectl top pods -A --sum --sort-by=memory
```

## 备份 sqllite 数据和 server token

```bash
cat > /usr/local/bin/backup_k3s.sh <<'EOF'
#!/bin/bash

tar -zcvf k3s.server.db.tar.gz  -C /var/lib/rancher/k3s/server/db/ .
tar -zcvf k3s.server.token.tar.gz -C /var/lib/rancher/k3s/server token
EOF
chmod +x /usr/local/bin/backup_k3s.sh
```

k3s.server.db.tar.gz 和 k3s.server.db.tar.gz 分别是数据库和 token 的备份文件

## 恢复 sqllite 数据和 server token

恢复后你的工作负载会回到备份时的状态，之后的变更都会丢失

```bash
systemctl stop k3s
tar -zxvf k3s.server.db.tar.gz -C /var/lib/rancher/k3s/server/db/
tar -zxvf k3s.server.token.tar.gz -C /var/lib/rancher/k3s/server
systemctl start k3s
```

## 升级 k3s

先逐个升级 Server 节点，然后再升级 Agent 节点。

```bash
version=$(curl -s https://api.github.com/repos/k3s-io/k3s/releases/latest | jq -r '.tag_name')
version_url_encoded=$(echo $version | sed 's/+/%2B/g' | sed 's/\//\\\//g')
echo 安装 k3s 版本 $version
curl -L -o /tmp/k3s "https://us.arloor.dev/https://github.com/k3s-io/k3s/releases/download/${version_url_encoded}/k3s"
cp /usr/local/bin/k3s /usr/local/bin/k3s.bak.$(date +%F_%T)
install /tmp/k3s /usr/local/bin/
systemctl restart k3s # k3s-agent
```

## 回滚 k3s

恢复 sqllite 数据和 server token 到升级前的备份状态，然后替换回旧版本的 k3s 二进制文件
