---
title: "使用K8S DaemonSet部署rust_http_proxy"
date: 2023-07-23T21:07:02+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 整体说明

1. tls的证书没有使用Secret，感觉没啥必要
2. 使用hostNetwork来暴露端口，并且使用host的DNS
3. 将coredns的deployment移动到外网的vps上
4. 使用envFrom comfigMap加载环境变量，这要求configMap中所有字段都是String类型，443、true、false要用双引号包裹

## Proxy的manifest

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: proxy
  labels:
    k8s-app: proxy
spec:
  selector:
    matchLabels:
      name: proxy
  template:
    metadata:
      labels:
        name: proxy
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
        image: docker.io/arloor/rust_http_proxy:1.0
        envFrom:
        - configMapRef:
            name: proxy-env
        volumeMounts:
        - name: proxy-certs
          mountPath: /certs
      terminationGracePeriodSeconds: 30
      volumes:
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

## 驱逐cored n s到外网的VPS

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
kubectl set image ds/proxy proxy=ccr.ccs.tencentyun.com/arloor/rust_http_proxy:1.0
```

接下来DaemonSet会进行滚动更新