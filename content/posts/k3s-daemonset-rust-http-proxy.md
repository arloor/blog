---
title: "使用K8S DaemonSet部署rust_http_proxy"
date: 2023-07-23T21:07:02+08:00
draft: false
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 整体说明

1. tls的证书没有使用Secret，感觉没啥必要。
2. ~~使用HostPort来暴露端口，并将coredns的deployment移动到外网的vps上，已避免ClusterFirst的dnsPolicy下的国内dns污染问题~~
3. 使用hostNetwork使用主机网络栈，意义在于暴露端口+使用host的DNS（无污染问题）
4. 使用envFrom comfigMap加载环境变量，这要求configMap中所有字段都是String类型，443、true、false要用双引号包裹。
5. 使用hostPath挂载nginx的目录，展示web网页。

## Dockerfile

```bash
FROM docker.io/redhat/ubi9-micro:9.2-9
# 设置时区为上海，ubi9-micro内置了tzdata 
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone
COPY target/x86_64-unknown-linux-musl/release/rust_http_proxy /
CMD ["/rust_http_proxy"]
```

用的RHEL家的ubi9-micro基础镜像，它和alpine差不多大小，用的glibc，没有musl-libc的一些兼容性问题，并且设置时区更加简单，而且我对RHEL家的东西很有好感，所以就用了。一些相关的介绍：


1. [ubi9-micro](https://catalog.redhat.com/software/containers/ubi9/ubi-micro/615bdf943f6014fa45ae1b58?container-tabs=overview)
2. [为什么我不再使用Alpine Linux](https://www.51cto.com/article/751174.html)

文中提及的问题在我使用基于busybox的curl镜像radial/busyboxplus:curl时也遇到了：

```bash
$ curl https://kubernetes.default.svc
curl: (6) Couldn't resolve host 'kubernetes.default.svc'
```

3. [ubi9-init](https://catalog.redhat.com/software/containers/ubi9-init/6183297540a2d8e95c82e8bd) 

ubi9-init的PID=1的进程为systemd，可以用systemd的方式运行多个进程。推荐用`-d`在后台运行，`-it`在前台的方式没有办法通过 `ctrl + c` 停止容器，因为systemd会忽略正常退出信号，因为这个systemd会。使用例子[ubi8-init加httpd](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/assembly_adding-software-to-a-ubi-container_building-running-and-managing-containers#using-the-ubi-init-images_assembly_adding-software-to-a-ubi-container)





## Proxy的manifest

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: proxy
  labels:
    app: proxy
spec:
  selector:
    matchLabels:
      app: proxy
  template:
    metadata:
      labels:
        app: proxy
    spec:
      hostNetwork: true
      tolerations:
      # 这些容忍度设置是为了让该守护进程集在控制平面节点上运行
      # 如果你不希望自己的控制平面节点运行 Pod，可以删除它们
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: proxy
        image: ccr.ccs.tencentyun.com/arloor/rust_http_proxy:1.1
        envFrom:
        - configMapRef:
            name: proxy-env
        volumeMounts:
        - name: data
          mountPath: /data
        - name: proxy-certs
          mountPath: /certs
      terminationGracePeriodSeconds: 30
      volumes:
      - name: data
        hostPath:
          path: /usr/share/nginx/html/blog 
          type: DirectoryOrCreate
      - configMap:
          name: proxy-certs          #指定使用ConfigMap的名称
        name: proxy-certs

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-env
data:
  port: "444"
  cert: /certs/cert
  raw_key: /certs/key
  basic_auth: "Basic xxxxxxxxxxxx=="
  ask_for_auth: "false"
  over_tls: "true"
  web_content_path: /data

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-certs
data:
  # the data is abbreviated in this example
  cert: |
    -----BEGIN CERTIFICATE-----
    ......
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    ........

```

上面用到了hostPath卷，因为文件夹权限的问题，hostPath卷在容器中只可读，如果要可写，需要调整container的securityContext来赋予特权模式（如下），或者在宿主机上修改文件夹的权限。当然这都不推荐在生产上使用，生产上还是用pvc动态置备比较好。

```bash
        securityContext:
          privileged: true
```

我的那些代理：

![Alt text](/img/telegram-cloud-photo-size-5-6192798952399681427-y.jpg)

## ~~驱逐coredns到外网的VPS~~

> !! 不再需要此操作，因为hostNetwork的dnsPolicy会fallBack到default，也就是使用Host的dns

```bash
kubectl label node sg161 location=out
kubectl label node hk101 location=out
```

```yaml
# p.yaml
spec:
  replicas: 2
  template:
    spec:
      nodeSelector: 
        location: out
```

```bash
kubectl patch deployment coredns -n kube-system --patch-file p.yaml
```

## 替换镜像仓库为腾讯云的

腾讯云的镜像仓库控制台 [https://console.cloud.tencent.com/tcr/?rid=1](https://console.cloud.tencent.com/tcr/?rid=1)。选择广州地区，有个人版可以开通。


```shell
kubectl set image ds/proxy proxy=ccr.ccs.tencentyun.com/arloor/rust_http_proxy:17dbb5ef
# kubectl patch ds proxy --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"ccr.ccs.tencentyun.com/arloor/rust_http_proxy:1.6"}]'
kubectl describe ds proxy|grep Image
```

接下来DaemonSet会进行滚动更新

## 查看pod日志

```bash
cat > /data/bin/lo <<\EOF
kubectl get pod -A -o wide -l app=proxy |awk -v host=$1 '$8==host {print $2}' | xargs -I {} kubectl logs {} -f
EOF
chmod +x /data/bin/lo
lo hk
```

更暴力，一次性查看所有pod的日志

```bash
cat > /data/bin/lol <<EOF
kubectl logs -l app=proxy -f --max-log-requests 20 --tail=5
EOF
chmod +x /data/bin/lol
lol
```