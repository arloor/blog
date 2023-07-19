---
title: "K8s Install"
date: 2023-07-18T20:15:30+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

环境：rhel9.2

- [Install Tools](https://kubernetes.io/docs/tasks/tools/)
- [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [create-cluster-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

## kubectl

```shell
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo yum install -y kubectl
kubectl version --output=yaml # 打印版本信息，当前为v1.27.3
```

版本信息如下：（因为cluster还没起来，所以没有server的信息

```yaml
clientVersion:
  buildDate: "2023-06-14T09:53:42Z"
  compiler: gc
  gitCommit: 25b4e43193bcda6c7328a6d147b1fb73a33f1598
  gitTreeState: clean
  gitVersion: v1.27.3
  goVersion: go1.20.5
  major: "1"
  minor: "27"
  platform: linux/amd64
kustomizeVersion: v5.0.1

The connection to the server localhost:8080 was refused - did you specify the right host or port?
```


## kind

### 安装kind

```shell
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind --version # 当前版本为0.20.0
```

### 创建cluster

```shell
yum install -y podman # 安装podman
kind create cluster --name demo --wait 5m 
# 使用默认的node image创建cluster。https://hub.docker.com/r/kindest/node/。 
# kind 版本和镜像版本有对应关系，在release页面查看 https://github.com/kubernetes-sigs/kind/releases
```

输出：

```shell
enabling experimental podman provider
Creating cluster "demo" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼 
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Waiting ≤ 5m0s for control-plane = Ready ⏳ 
 • Ready after 17s 💚
Set kubectl context to "kind-demo"
You can now use your cluster with:

kubectl cluster-info --context kind-demo

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community
```

此时，查看podman的容器列表，可以看到：

```shell
# podman ps
CONTAINER ID  IMAGE                                                                                           COMMAND     CREATED        STATUS        PORTS                      NAMES
6313438e57a5  docker.io/kindest/node@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317add2c9ba72              5 minutes ago  Up 5 minutes  127.0.0.1:39025->6443/tcp  demo-control-plane
```

使用kubectl查看cluster信息：

```shell
# kubectl version --output=yaml
clientVersion:
  buildDate: "2023-06-14T09:53:42Z"
  compiler: gc
  gitCommit: 25b4e43193bcda6c7328a6d147b1fb73a33f1598
  gitTreeState: clean
  gitVersion: v1.27.3
  goVersion: go1.20.5
  major: "1"
  minor: "27"
  platform: linux/amd64
kustomizeVersion: v5.0.1
serverVersion:
  buildDate: "2023-06-15T00:36:28Z"
  compiler: gc
  gitCommit: 25b4e43193bcda6c7328a6d147b1fb73a33f1598
  gitTreeState: clean
  gitVersion: v1.27.3
  goVersion: go1.20.5
  major: "1"
  minor: "27"
  platform: linux/amd64

# kubectl cluster-info         
Kubernetes control plane is running at https://127.0.0.1:39025
CoreDNS is running at https://127.0.0.1:39025/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

再看看 `~/.kube/config` 集群配置文件：

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJek1EY3hPREV5TXpNME0xb1hEVE16TURjeE5URXlNek0wTTFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTUFECjdUWUhBUUkyQUtDQlNOMzZaTm1YSVFnZFNrR0sxNTIySzhvclJHZlBmTVBueWJsbWNheTJzKzQxZ05nVUZPQm0KUGRNODIwbUNvdEY2U09nWHNULzI4cWdWL2pBRVB3bWhkMDJHa2k2VXZXWVNDb2hxRE10cHpDRks5U3VSZkdOSApsOG5JczlSR2RsYzVteXkyVXJwM3hYcEIyVThqYkxDcUdmOFJoSmVpK0ZmSzQxNUtqRkY0bGpyZmxvK1hwbk5OCnFCYXAxbUFpNmp1SzYzeDhpbDFFTWtvV3pCdmhQOWwvY2Y1bkRZNnAxcHh2cm5nUzR0UTFraitRRnhNMlovK3EKd05WbTZNUytMd044c1BhNE9sOGF3L3RmbGg5OVJscExzemNTTjlpRlRUNk5zdXYxdTJVc3ZHQkJLZVFRVUliVwpYaWZlU0plV1lVd01oTGp3a2ZjQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZQVVBFdCtPbzdPaFlZa0FsTkZjaTkwODlmaGJNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBQWp6WWNJaWZqZzZxenloekdkZgpobmQwaVY2ZlEwcHI1SGNPVFdVL2lXRUtKbmJYdncvK1FVMjRIYmJaYU5GL01JaktRMDdReTdEZVBERGdRTGdvCkw5SFQ2ODFPeFJpU1dEWkMrUzBFRmRmMk82cEhtbnFOVDluQTN6VnRzOGFvZnljZ0JTamg0WFg2Z3ZMUFVVZDMKNDMxVG9hZUU0eDNtbWNDcGNUdTNZNk1sQm1ZcCtCVkdHZk0xTDJIenE3L0VNZWRCVU13Z2ZKVEhPL2w3d3ZwWApNWXF2c0VFUnVXdEhBR2xrV0hmWTVya3ZtdVRpbG8veFhkQ2xWaGVxUFhTMG81Ulo5Z3g3L2N1WE1NVUJKbTI3Cmk2ZzVJQm94VkJrZzhsd3UxbHFJNlFjQVd4Ryt0RFlweVE4SVIzOWxpSzUxNnI3c2lPSmRDWnM3T0dudy9EaVMKL2xJPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://127.0.0.1:39025
  name: kind-demo
contexts:
- context:
    cluster: kind-demo
    user: kind-demo
  name: kind-demo
current-context: kind-demo
kind: Config
preferences: {}
users:
- name: kind-demo
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURJVENDQWdtZ0F3SUJBZ0lJSVd1TEZtRlFEY3N3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TXpBM01UZ3hNak16TkROYUZ3MHlOREEzTVRjeE1qTXpORFZhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQXZtd0phU3FCeGhkWnhPUlYKaSsvckpMdDdxallXN0FXZGptc0NYNmxxM2EvVVNMbHNwYU0rYitISTVUcnJ4RnRSd2gwQXI0cVRTRnZiNnh0cwpuM3VTbnNUMFlDOGkxWWxUTnVzbExxVjJyYVlZQzF5c2ZQMVBsTnl5ZEJlUU90ZHNBWEhuOExtUEJZN2tpaEFjCjdDU0dpTUdxWFppS1U4QXRpVXZ6RzZmV1ZjTjliTDNjQ1BoaEtiWE96ZzBDM3dXMkZTczBWMHVXc0ttMjcvWEEKTlR3NkZneE9scndoTkRiRVVxZFJoUmpmSHNGT01mQVVScjhTRUs2LzhrQ2c2bzhmUlQ1cUtwTkVzNzdnZTE1dApQUkNqWmhJemJRQ3BFVUIxZERvMW5BUndDeWZiQ2pCd0RkU1ViYWk3RkJwd0pleThYcWQwcFBCaThOU2ZTb0RCCktxLytNd0lEQVFBQm8xWXdWREFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RBWURWUjBUQVFIL0JBSXdBREFmQmdOVkhTTUVHREFXZ0JUMUR4TGZqcU96b1dHSkFKVFJYSXZkUFBYNApXekFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBY0dJNXhVZ25XeHRTZ3V0aEVNMUdxdk5JRGI3TlNLaUhTNHplCmFxTkNVb1lVRUtPNzBxYmFLTHdXbUw2REx2U0xzQlpYSWI2SE1OeXlZNEVSS2F0eWl1ZlpkUEJYSlg2WEptdUcKSDRLczBjQmxHRUhhbThpZlFsRDlvYXRhOVBxdlFSMkc1Njc5SnJYK3EyQnMxTElqWSszNUxQUGJWSzBJZlBOdQpMaDdaUTJhZVdXRTlXVW0rNkkvT0Z0R0xKbzd3L3I4bEhKemxITktRMGJpNzgwUnZRNDB5YzlRVnBnRWY2NEcrCjRJclJMVnFyOVp1SlRMVXpZREFhWG5ZVW5UUEx0MnAwZElDMzYrYlpGSlc4Q0syS3ZKeC8rcnpNamIzTWVLdXMKdzBRemQyVmxTZHord0hNUmZsclVCV2lIcFJTU2p4aTRrL25tSiswdER5YnN5akNSYVE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb2dJQkFBS0NBUUVBdm13SmFTcUJ4aGRaeE9SVmkrL3JKTHQ3cWpZVzdBV2RqbXNDWDZscTNhL1VTTGxzCnBhTStiK0hJNVRycnhGdFJ3aDBBcjRxVFNGdmI2eHRzbjN1U25zVDBZQzhpMVlsVE51c2xMcVYycmFZWUMxeXMKZlAxUGxOeXlkQmVRT3Rkc0FYSG44TG1QQlk3a2loQWM3Q1NHaU1HcVhaaUtVOEF0aVV2ekc2ZldWY045YkwzYwpDUGhoS2JYT3pnMEMzd1cyRlNzMFYwdVdzS20yNy9YQU5UdzZGZ3hPbHJ3aE5EYkVVcWRSaFJqZkhzRk9NZkFVClJyOFNFSzYvOGtDZzZvOGZSVDVxS3BORXM3N2dlMTV0UFJDalpoSXpiUUNwRVVCMWREbzFuQVJ3Q3lmYkNqQncKRGRTVWJhaTdGQnB3SmV5OFhxZDBwUEJpOE5TZlNvREJLcS8rTXdJREFRQUJBb0lCQUdJSXBOK3JycHdaTVhJWQpTNko3cGdlSExpZDNLVjNobGpmWUI2VFFSK0JSd1d5ZmFidnN5eHcybFlMT1Rzc01hSThTOTJOb2FHTDhSOEJHCm9pbUpLUGJzVnhPZHNNVldxYXpBYXFnVkw0QSszbW9iRUFKWk56dGdVODlJd2t4STA2WDZ5bm80VGRXQ3QwNE0KOVpidFJ3WHBEcGlaQzc0S1ZtYzAzcmdDTkdwNkV0aG1mbWtGcmd1UlBDSS9tT3d3MXlHcWZ2WWlJRytEbERKTgpWYzNYQzByR3FISGpiZWdYUG9CUENFTE80amwrYzl2cUl0RjgzUHoxb3RtYUhydzhINnR6Q0tGeHoyTDBKbGsrCjF2cnNMWnRLeXRMeUcvbVdHOE03ak0yVnRBR2FNT0EycFhQT0dZQWNrSmlFZlYrM3BJN1lOYm9LNEszSVluVmwKVG40SWFTRUNnWUVBMGJIZVg3Ujg0T0szVjNlUXZ4a0NEcm1zNG5zckF5azdEV3JDdDNlblBUQjdVbkNKQ01KNgpaNU1JR3hzNHROVHZYWEh0cFBvZ3BPOHFZWlY1SHBUNkZrc3RiMytCaXFlRXpHMlRmMFdUOXlYUzFKZU9BeFhDCnVaWjhNRnJ6UWpCeG5Wa3RoM0dzM3AwaHBNdzJZaE9LbGt3T21HdVJFTlpnOGI2eUlvRHBabmNDZ1lFQTZIaXIKaVRPME8xZjNDR0lVdjRMT2ZIUkczYlRvT2tuU2ZCS09pYXdub1JNeWtxWSsvbiszNFplN0VieTA0TzRnM3F5SwpTaTgyWGwzNzhxLzE2VXNIZEV2MXNiUXZuV3dUS1B3UE52bU9vc2t1dVFVZXhSZmFNd0pScEMvbWhwSm04dHh5CkNXWkI1R0oyd09ZWWcrc1NvVjFmZnJNUitBejM4TEpTbkpMMkNTVUNnWUJ2WnVCdDFkUTJJUndvRXJSS1liM1AKRnVON0d0WTZBckNGcXo4dyt4ZFZFYW1pblhpZnQ3b1J4bklhL0hZKzA1VXEvcml5MmROMzdEdUd4a01uZFJ2Nwp0Z3E0WG5QeXRwWjlpSVZBcXpVMXF0bDc2ZHdmVlhNeTUzaW9zOWppUkJ4SDdMV2NiRTdib1h6Yk1VWi9Da1NwCkhsVHVzczdKdENxaW81MjlhT0VXZHdLQmdEYWtCazJkWllOOVRZY2U1cG1NK1ZPdlVPalRtTEg2b0FxaG9mY2kKQzc2RWNLS2ZpTGJ3OWh1RU9tZ1Uzcjd2dWJJZEEvUWozTGVaaDVxbldUbVlkUXdVdm84aU52N2RaRE9CNjJHVQpqcjRjWTJzQmxSWG1ZVmNUK0hTSy9iZ3J1UjdrU2JtRDI0RCswOExMVW4vUFJQWEFxSzF6RVlvb0lpN2sreDNxClBRSXhBb0dBZUdiUlJjSlRwUXAzRmlMQ1E0VFpmeHAzUmUwalNXZTBScTFlUUpoekNySm1qRVZkbnArUzdYZUoKbnpaYVBOdGphWnFWbFVPN1k3a2RYay9jRThJTWFla2huR2h5cjFkL1J3L21GdDdySnBoekdYMlFPdTBCNzZNQQpEWUhRQTNrSVJoRmRDajF3MVkzalBPYVFqc2pUZ25CbUZLWDZYSENZYllkbDFKaXA2MkE9Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==

```

我们再创建一个 `prod` 集群：

```shell
kind create cluster --name prod --wait 5m
```

再看 kubeconfig文件，可以看到两个context，两个cluster，两个user

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJek1EY3hPREV5TXpNME0xb1hEVE16TURjeE5URXlNek0wTTFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTUFECjdUWUhBUUkyQUtDQlNOMzZaTm1YSVFnZFNrR0sxNTIySzhvclJHZlBmTVBueWJsbWNheTJzKzQxZ05nVUZPQm0KUGRNODIwbUNvdEY2U09nWHNULzI4cWdWL2pBRVB3bWhkMDJHa2k2VXZXWVNDb2hxRE10cHpDRks5U3VSZkdOSApsOG5JczlSR2RsYzVteXkyVXJwM3hYcEIyVThqYkxDcUdmOFJoSmVpK0ZmSzQxNUtqRkY0bGpyZmxvK1hwbk5OCnFCYXAxbUFpNmp1SzYzeDhpbDFFTWtvV3pCdmhQOWwvY2Y1bkRZNnAxcHh2cm5nUzR0UTFraitRRnhNMlovK3EKd05WbTZNUytMd044c1BhNE9sOGF3L3RmbGg5OVJscExzemNTTjlpRlRUNk5zdXYxdTJVc3ZHQkJLZVFRVUliVwpYaWZlU0plV1lVd01oTGp3a2ZjQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZQVVBFdCtPbzdPaFlZa0FsTkZjaTkwODlmaGJNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBQWp6WWNJaWZqZzZxenloekdkZgpobmQwaVY2ZlEwcHI1SGNPVFdVL2lXRUtKbmJYdncvK1FVMjRIYmJaYU5GL01JaktRMDdReTdEZVBERGdRTGdvCkw5SFQ2ODFPeFJpU1dEWkMrUzBFRmRmMk82cEhtbnFOVDluQTN6VnRzOGFvZnljZ0JTamg0WFg2Z3ZMUFVVZDMKNDMxVG9hZUU0eDNtbWNDcGNUdTNZNk1sQm1ZcCtCVkdHZk0xTDJIenE3L0VNZWRCVU13Z2ZKVEhPL2w3d3ZwWApNWXF2c0VFUnVXdEhBR2xrV0hmWTVya3ZtdVRpbG8veFhkQ2xWaGVxUFhTMG81Ulo5Z3g3L2N1WE1NVUJKbTI3Cmk2ZzVJQm94VkJrZzhsd3UxbHFJNlFjQVd4Ryt0RFlweVE4SVIzOWxpSzUxNnI3c2lPSmRDWnM3T0dudy9EaVMKL2xJPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://127.0.0.1:39025
  name: kind-demo
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJek1EY3hPREV5TlRNd09Wb1hEVE16TURjeE5URXlOVE13T1Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBT1FiCm1mY1htUGlORnlyWVFqZmd4WSs0Y2dqeFhVdUc2Nlp3SGpMS1I4VzlSbzJvTVdOZ0tqS3J5VkFXNTl4eVd3MnEKVEkzYVhZNmFUZkQweWZsQU9sRjFjTDZpdzU1YmVMSUdoZFlJcG1lWVozdjRPQ1g4OHlHRzZqNlZ6L1dnOGd4dQpCN01IV2YzQ0RvTk8yTHF4VzhaQVh0Ny9HTWNxMmZqSjRmZFlwU2E4emQ5UjlucVkrbkNCcVNkTDE4UXFlRXVNCkdWa3VpZHREMUFqSng3di8zVGhNNHhwUldlYWZYNXZrZ3lwdm82dTlSdC9YeUwvVUI3NWg5bjlvRkNJRFlJMHgKUk1uaDFUQTgvK0pDeE1VZWQwbzdnbE0rVXlNRElNbUNvZjVpSUNRcTFQN1cxNmQwalB0NWU1dmM5UHlqVUIyUQpIUFkybTdBNFhIbGtoWXZnM3c4Q0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZBOWlxWFRyYk43U1BQak84eGZtUmpiK3RPUm5NQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBSi9FdFpvZWE1TDVyTkEwemI0dAprSERZNjFPb2d3bTJUWXBpczJuTDNzcGttSnFTK3B1WnRqaUQwczhjUGZQSGdtKzhrblpyUzcwelErOGZwdXA3CmVyV3VxSmNvOVpDTXZxRHBTR3ljUWFOdDlkeERkdWVqU0JLZkNiaXRaSnRwa01QTGtXNHRmV1VSOTdTVmFJeFkKY0t3dGltWlBKVVZ6NUJMUTBJY0hzMWFBS0puN3lKaXloVWlpR1lRQ0h2d0hzUHBDMW94SEFMY3ZPeGZscGRlOAo4MzJ2dlpKNVRGbGdSVXRWUFRoSG45bmthWmhpYXBEOGljcURnUElCU2lZMTBkamd4eW1SbGlJS1JzckY0dHRjCmwwNWlISzIzQzZYQjlkU0tkUGhHeU1LaFROMDB1OEVWMktjREUybUFHRk1KUHZsTDFQVlo3WlJMMmdQV2NrV3AKNmFnPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://127.0.0.1:46229
  name: kind-prod
contexts:
- context:
    cluster: kind-demo
    user: kind-demo
  name: kind-demo
- context:
    cluster: kind-prod
    user: kind-prod
  name: kind-prod
current-context: kind-prod
kind: Config
preferences: {}
users:
- name: kind-demo
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURJVENDQWdtZ0F3SUJBZ0lJSVd1TEZtRlFEY3N3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TXpBM01UZ3hNak16TkROYUZ3MHlOREEzTVRjeE1qTXpORFZhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQXZtd0phU3FCeGhkWnhPUlYKaSsvckpMdDdxallXN0FXZGptc0NYNmxxM2EvVVNMbHNwYU0rYitISTVUcnJ4RnRSd2gwQXI0cVRTRnZiNnh0cwpuM3VTbnNUMFlDOGkxWWxUTnVzbExxVjJyYVlZQzF5c2ZQMVBsTnl5ZEJlUU90ZHNBWEhuOExtUEJZN2tpaEFjCjdDU0dpTUdxWFppS1U4QXRpVXZ6RzZmV1ZjTjliTDNjQ1BoaEtiWE96ZzBDM3dXMkZTczBWMHVXc0ttMjcvWEEKTlR3NkZneE9scndoTkRiRVVxZFJoUmpmSHNGT01mQVVScjhTRUs2LzhrQ2c2bzhmUlQ1cUtwTkVzNzdnZTE1dApQUkNqWmhJemJRQ3BFVUIxZERvMW5BUndDeWZiQ2pCd0RkU1ViYWk3RkJwd0pleThYcWQwcFBCaThOU2ZTb0RCCktxLytNd0lEQVFBQm8xWXdWREFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RBWURWUjBUQVFIL0JBSXdBREFmQmdOVkhTTUVHREFXZ0JUMUR4TGZqcU96b1dHSkFKVFJYSXZkUFBYNApXekFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBY0dJNXhVZ25XeHRTZ3V0aEVNMUdxdk5JRGI3TlNLaUhTNHplCmFxTkNVb1lVRUtPNzBxYmFLTHdXbUw2REx2U0xzQlpYSWI2SE1OeXlZNEVSS2F0eWl1ZlpkUEJYSlg2WEptdUcKSDRLczBjQmxHRUhhbThpZlFsRDlvYXRhOVBxdlFSMkc1Njc5SnJYK3EyQnMxTElqWSszNUxQUGJWSzBJZlBOdQpMaDdaUTJhZVdXRTlXVW0rNkkvT0Z0R0xKbzd3L3I4bEhKemxITktRMGJpNzgwUnZRNDB5YzlRVnBnRWY2NEcrCjRJclJMVnFyOVp1SlRMVXpZREFhWG5ZVW5UUEx0MnAwZElDMzYrYlpGSlc4Q0syS3ZKeC8rcnpNamIzTWVLdXMKdzBRemQyVmxTZHord0hNUmZsclVCV2lIcFJTU2p4aTRrL25tSiswdER5YnN5akNSYVE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb2dJQkFBS0NBUUVBdm13SmFTcUJ4aGRaeE9SVmkrL3JKTHQ3cWpZVzdBV2RqbXNDWDZscTNhL1VTTGxzCnBhTStiK0hJNVRycnhGdFJ3aDBBcjRxVFNGdmI2eHRzbjN1U25zVDBZQzhpMVlsVE51c2xMcVYycmFZWUMxeXMKZlAxUGxOeXlkQmVRT3Rkc0FYSG44TG1QQlk3a2loQWM3Q1NHaU1HcVhaaUtVOEF0aVV2ekc2ZldWY045YkwzYwpDUGhoS2JYT3pnMEMzd1cyRlNzMFYwdVdzS20yNy9YQU5UdzZGZ3hPbHJ3aE5EYkVVcWRSaFJqZkhzRk9NZkFVClJyOFNFSzYvOGtDZzZvOGZSVDVxS3BORXM3N2dlMTV0UFJDalpoSXpiUUNwRVVCMWREbzFuQVJ3Q3lmYkNqQncKRGRTVWJhaTdGQnB3SmV5OFhxZDBwUEJpOE5TZlNvREJLcS8rTXdJREFRQUJBb0lCQUdJSXBOK3JycHdaTVhJWQpTNko3cGdlSExpZDNLVjNobGpmWUI2VFFSK0JSd1d5ZmFidnN5eHcybFlMT1Rzc01hSThTOTJOb2FHTDhSOEJHCm9pbUpLUGJzVnhPZHNNVldxYXpBYXFnVkw0QSszbW9iRUFKWk56dGdVODlJd2t4STA2WDZ5bm80VGRXQ3QwNE0KOVpidFJ3WHBEcGlaQzc0S1ZtYzAzcmdDTkdwNkV0aG1mbWtGcmd1UlBDSS9tT3d3MXlHcWZ2WWlJRytEbERKTgpWYzNYQzByR3FISGpiZWdYUG9CUENFTE80amwrYzl2cUl0RjgzUHoxb3RtYUhydzhINnR6Q0tGeHoyTDBKbGsrCjF2cnNMWnRLeXRMeUcvbVdHOE03ak0yVnRBR2FNT0EycFhQT0dZQWNrSmlFZlYrM3BJN1lOYm9LNEszSVluVmwKVG40SWFTRUNnWUVBMGJIZVg3Ujg0T0szVjNlUXZ4a0NEcm1zNG5zckF5azdEV3JDdDNlblBUQjdVbkNKQ01KNgpaNU1JR3hzNHROVHZYWEh0cFBvZ3BPOHFZWlY1SHBUNkZrc3RiMytCaXFlRXpHMlRmMFdUOXlYUzFKZU9BeFhDCnVaWjhNRnJ6UWpCeG5Wa3RoM0dzM3AwaHBNdzJZaE9LbGt3T21HdVJFTlpnOGI2eUlvRHBabmNDZ1lFQTZIaXIKaVRPME8xZjNDR0lVdjRMT2ZIUkczYlRvT2tuU2ZCS09pYXdub1JNeWtxWSsvbiszNFplN0VieTA0TzRnM3F5SwpTaTgyWGwzNzhxLzE2VXNIZEV2MXNiUXZuV3dUS1B3UE52bU9vc2t1dVFVZXhSZmFNd0pScEMvbWhwSm04dHh5CkNXWkI1R0oyd09ZWWcrc1NvVjFmZnJNUitBejM4TEpTbkpMMkNTVUNnWUJ2WnVCdDFkUTJJUndvRXJSS1liM1AKRnVON0d0WTZBckNGcXo4dyt4ZFZFYW1pblhpZnQ3b1J4bklhL0hZKzA1VXEvcml5MmROMzdEdUd4a01uZFJ2Nwp0Z3E0WG5QeXRwWjlpSVZBcXpVMXF0bDc2ZHdmVlhNeTUzaW9zOWppUkJ4SDdMV2NiRTdib1h6Yk1VWi9Da1NwCkhsVHVzczdKdENxaW81MjlhT0VXZHdLQmdEYWtCazJkWllOOVRZY2U1cG1NK1ZPdlVPalRtTEg2b0FxaG9mY2kKQzc2RWNLS2ZpTGJ3OWh1RU9tZ1Uzcjd2dWJJZEEvUWozTGVaaDVxbldUbVlkUXdVdm84aU52N2RaRE9CNjJHVQpqcjRjWTJzQmxSWG1ZVmNUK0hTSy9iZ3J1UjdrU2JtRDI0RCswOExMVW4vUFJQWEFxSzF6RVlvb0lpN2sreDNxClBRSXhBb0dBZUdiUlJjSlRwUXAzRmlMQ1E0VFpmeHAzUmUwalNXZTBScTFlUUpoekNySm1qRVZkbnArUzdYZUoKbnpaYVBOdGphWnFWbFVPN1k3a2RYay9jRThJTWFla2huR2h5cjFkL1J3L21GdDdySnBoekdYMlFPdTBCNzZNQQpEWUhRQTNrSVJoRmRDajF3MVkzalBPYVFqc2pUZ25CbUZLWDZYSENZYllkbDFKaXA2MkE9Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
- name: kind-prod
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURJVENDQWdtZ0F3SUJBZ0lJRUJPRkI3NFozdkV3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TXpBM01UZ3hNalV6TURsYUZ3MHlOREEzTVRjeE1qVXpNVEZhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQTd3VThuN3lHVzc2MGsydHMKbWxwemZlM2MzOHM5SUNKRDNMUjM4Z0FDaDdUYU8vTjVVRU1tS01iRFk2S0hOZjFFakFJdW9vNG9EakpFRlJIQgpvVlNtWGVERTZ2MDlLd1FYTk9pbm9VRDcxRm96OSs1ZVhlcmVRUkJkUGRpaWZab2FZTzV0N2ZTdTVqYWpTMUkzCk8rd1FyN0o3d3dPc3JhcEZJRmYvTFl2ODljcm0xVTE2QWQ3VFNwRWh6VjFPWFQyRE1sbzhwcXowNVpzUTV3VU8KUWNSZWNHQ0hCQ25tOVJlVXNxNnR2bnJGc0gvNnIrcXNTNVQxYmJXc3lEZ0wyenBtNmVoeHcvM2xibDVwUUxnSgo1RHh0SFF3SHdpM2p4RU1PMlFpdDdxZjFsUml5dmhENVNEalV0OTd5dSsvbFMwWlI2STJkYWgyMFZta3dCeVk5CkdUaVBqd0lEQVFBQm8xWXdWREFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RBWURWUjBUQVFIL0JBSXdBREFmQmdOVkhTTUVHREFXZ0JRUFlxbDA2MnplMGp6NHp2TVg1a1kyL3JUawpaekFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBczNKbHlnQlgzNWhCZ3VTTndLMHowUUNYcTRydDRxZ1ZXam5zCk9zWTAzRUpmMVhiMnVvS0xnSW9yVy9KVzZqYWNHdXo2ZWl6TzRjSXFMcTV1dWhROEhybnhqVGVmNDgzSGdmdjYKbmQ1SXZDNHFWZUt6WDd0eVlOLzVlM1Z0ZmhkK0JUUTVMWTBNNGpkMVhXL3dWQi9IdU8rUmhNN1hhNUo0alJGagphSHp2QkdFR0M1UDltbzdmM3VUTlNBdnAwbGRzMS9HTHRCWjYva3NjbllGQ0hudWpDdUdUNmdBdWh3Nkt1VURQCncwMzExbHFlVjZxRzBSWHF6KzIxcjNTUzBCWE82UHBqN0VvQzhnbWltS0p2OEU4Q01rajU1bXByMCtBa2NZRUYKMExnSW1IbTEyRHorVmlZbUlWT1RidWRzNkYxTEt3d01yUmQ2WFdlQlFUQ1VIb04vSlE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcFFJQkFBS0NBUUVBN3dVOG43eUdXNzYwazJ0c21scHpmZTNjMzhzOUlDSkQzTFIzOGdBQ2g3VGFPL041ClVFTW1LTWJEWTZLSE5mMUVqQUl1b280b0RqSkVGUkhCb1ZTbVhlREU2djA5S3dRWE5PaW5vVUQ3MUZvejkrNWUKWGVyZVFSQmRQZGlpZlpvYVlPNXQ3ZlN1NWphalMxSTNPK3dRcjdKN3d3T3NyYXBGSUZmL0xZdjg5Y3JtMVUxNgpBZDdUU3BFaHpWMU9YVDJETWxvOHBxejA1WnNRNXdVT1FjUmVjR0NIQkNubTlSZVVzcTZ0dm5yRnNILzZyK3FzClM1VDFiYldzeURnTDJ6cG02ZWh4dy8zbGJsNXBRTGdKNUR4dEhRd0h3aTNqeEVNTzJRaXQ3cWYxbFJpeXZoRDUKU0RqVXQ5N3l1Ky9sUzBaUjZJMmRhaDIwVm1rd0J5WTlHVGlQandJREFRQUJBb0lCQVFES2V1YzJjbUJuakJBdwo2a25nSUV2Q0hDU0dPUWVaRnkzaDQ4ZlFiQTI0cEk1VFJ4ZzMxQXFaZEhmRkNjUDlDb1p0RE5Rd3hMaE4vbXNLClpqWmYwdlAwaHhxSjd1bEliWGl6UzN2bDhNVGt5VjFJNU5kd1BDejNkVU5ueHdNdjM4SUU1emFjNUREZHVOOXcKU1QrZE5ZZVZMMkFFZmpKa0U5L25YR1JCVTF1Qll6UWk3RHVSUXlJNWRzdnBvNjgrNlhqY2p6alZRSy9RTklvagpsbGVuVEpJL243a1ZnZ1FXMDZkdkJaeURlWVhlKzJkNm9KZG9tTEwrTlRSVndmdng3dVpVSWNxYXpzSWpRN0E5CmtVWWVyWVhkcTZpejZZWUZHQkVkY0J6L0pPQlV3N2VWMnBhNjdXd3lXdWxGWVFJZVY2TktjYW1oZTRXUGlYOUgKdEgwY2pQRXhBb0dCQVB5WXNNR0tqWGc2ek1JeXJkU2ZXWVplT0JneENXU0p2SGdNTUxjMHZ4ei8zSjA3NG0zTgo4dXoxMFBtbG5JNkxFTE9VUWRXUG9lV2ZFL2dTbFVGL1dLdmhSKzRnVGozbTIxd2lGODNHNEF4cFVpbW80OUdwClI4enhUT3hDbThyVVNwSytXS1pVd1V6c2lobkM4czQwUEJlTFU5d2lCaFdyR01pdXF0c00xcHRWQW9HQkFQSTkKdDVlR3p0T2FSOFAzd2hLZHNVUXdyWmc1V3ZyaGVzaUR4UE9lVG50MHAvekJpcmxBdFZuVFFMY3VmQnBqazlMSApWTUp3bGJtMFJnc3AzTHd4cGpXSEl4YWptTXdmZ1IzcXNFTzJ5dldFQitVcVBSOStSSVNWa1I3QmFDU01XVkNIClBXMEQ2eTVwMURDY005T1R0Mm44eG12ZzRZUnlER0J4SFprc2tXZFRBb0dCQU1DdG5FN1Y2Rm5veUYzdUdJa1MKMEZCZHVINURrWDJlVHlSbmNCV2Y1NVF3VzlHWVozMEkxeUFIMWxOSUQrYnZqMXJjWVdlTk81cVRRTUUvTTVrVgprY2J5ZmxMWFU3ZUdUSmUzN2Q1cXNHYm5RK1JCVHg2VCtSQU1sSGUzeTJ6cGlNVHM2MlJkVEdIb0lPUEx3RGlvCndabllEcXpoU3pEbUpXNlhSZjczaVJCTkFvR0JBS3dpWXhXUHUrVHRtdFdNZHlJWFlHSGVYVnp3Vk5BMTdiUVMKdnArRy9Lb0pxVjJZZ21WRnNCaVdYMFJNQ2ZBT2xucVBIcEhVd3ZCbFEraW01SzN1Y2ZkVGdnR1NXditoMjNSUQowdFFyVG1uTVduZmozZTlGSUpjK1dSTUx5RjlBUkM5UENyMHVyYTRia2FiQk9LcStLdlZybyt3QXJ3QVlzdWJOCk9vVWdBR3IxQW9HQUM3cEY0MTZxenFtRHhRL0dqNXpvanpWMzFDRzdDRTRHYlh1SWlHNkVYMyt5NTd0VEhzcDgKWFhZOTA1R0xveEZHanR6eHRxcnE1WjNVcWdPSFQvdk1sRGdMZjBsbmk0MG95VE50MXRnYWRvMUk2TXlJVVovSwo5c2VoOUsraDdNcGVENEF4NGcrUm5TWmRpNlI0eHFOY1BTSllOaXU3UXZJNTdlNG1lY3lzWmw4PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
```

可以使用 `--context`指定集群和user

```shell
kubectl cluster-info --context kind-prod
```

### 删除集群

```shell
kind delete cluster --name prod
kubectl config use-context kind-demo # 将current-context设置为之前的demo集群
```

### 将docker镜像加载到cluster中

```shell
podman build -t rust_http_proxy .
podman tag rust_http_proxy:latest rust_http_proxy:1.0 # k8s的Kubernetes imagePullPolicy 不允许使用latest的镜像。所以给个版本标记
yum install -y docker # 安装podman的docker兼容层，用于下面的docker-image命令
kind load docker-image rust_http_proxy:1.0 --name demo
podman exec -it  demo-control-plane crictl images # 查看集群中的镜像列表
```

集群中的镜像列表如下：

```yaml
IMAGE                                      TAG                  IMAGE ID            SIZE
docker.io/arloor/rust_http_proxy           1.0                  540e623206d7e       22.2MB
docker.io/kindest/kindnetd                 v20230511-dc714da8   b0b1fa0f58c6e       27.7MB
docker.io/kindest/local-path-helper        v20230510-486859a6   be300acfc8622       3.05MB
docker.io/kindest/local-path-provisioner   v20230511-dc714da8   ce18e076e9d4b       19.4MB
localhost/rust_http_proxy                  1.0                  65631e7a5e1da       22.2MB
registry.k8s.io/coredns/coredns            v1.10.1              ead0a4a53df89       16.2MB
registry.k8s.io/etcd                       3.5.7-0              86b6af7dd652c       102MB
registry.k8s.io/kube-apiserver             v1.27.3              c604ff157f0cf       83.5MB
registry.k8s.io/kube-controller-manager    v1.27.3              9f8f3a9f3e8a9       74.4MB
registry.k8s.io/kube-proxy                 v1.27.3              9d5429f6d7697       72.7MB
registry.k8s.io/kube-scheduler             v1.27.3              205a4d549b94d       59.8MB
registry.k8s.io/pause                      3.7                  221177c6082a8       311kB
```

### 进入控制面看看

```shell
podman exec -it demo-control-plane /bin/sh
```

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
mkdir -p /usr/local/containerd
tar -zxvf containerd.tar.gz -C /usr/local/containerd
/usr/local/containerd/bin/containerd -v # 1.7.2
echo 'export PATH=$PATH:/usr/local/containerd/bin/' > /etc/profile.d/containerd_path.sh
. /etc/profile.d/containerd_path.sh
containerd -v # 1.7.2
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
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/ipv4/ip_forward
kubeadm init --pod-network-cidr=192.168.0.0/16
```

