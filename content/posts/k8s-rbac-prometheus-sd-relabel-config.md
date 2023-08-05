---
title: "使用node-exporter + prometheus + grafana 监控k8s集群"
date: 2023-07-30T23:02:21+08:00
draft: false
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

最近在K8S集群中部署了node-exporter + prometheus + grafana，具体过程可以参考我的Github项目[kubernetes-prometheus-grafana](https://github.com/arloor/kubernetes-prometheus-grafana)。这个博客用来记录下过程中的一些知识点，主要有这些：

| 主题 | 详述 |
| :----------------------------- | :---------------- |
| K8S的RBAC                     | 全称是基于角色的访问控制，K8S权限机制的基础 |
| 在Pod中访问ApiServer           | Prometheus是运行在k8s集群中的一个pod，访问k8s的apiserver时需要一些鉴权机制 |
| Prometheus Service Discovery | Prometheus是pull模型，需要自动地发现k8s集群中有哪些endpoing、node、service等，并watch其变更 |
| Prometheus relabel_configs   | 在prometheus的抓取job中过滤、转换target的label |
<!--more-->

## prometheus manifest简析

prometheus部署的manifest主要有如下几个部分

1. ClusterRole、 ClusterRoleBinding：RBAC权限控制部分，给namespace monitoring下的default serviceaccount赋予了对相关资源的get、list、watch权限。
2. ConfigMap: Prometheus 配置文件部分,创建了alert manager告警规则和prometheus抓取规则，其中包括各种k8s服务发现和relabel configs。
3. Prometheus的Deployment和Service

具体的yaml文件参见我的Github项目[kubernetes-prometheus-grafana](https://github.com/arloor/kubernetes-prometheus-grafana)。第三部分我已经很熟悉了，新知识点主要在第一二部分。

## K8S RBAC访问控制

像我们部署kubernetes-dashboard和prometheus时都需要创建ServiceAccount、ClusterRoleBinding等，这些就是RBAC机制的组成部分。kubernetes-dashboard和prometheus用他们来访问ApiServer。

RBAC是一个权限控制的常见方案，由三个部分组成：ClusterRole、ServiceAccount和ClusterRoleBinding。ClusterRole定义了对一系列资源的访问权限。而ClusterRoleBinding则将ClusterRole赋予给ServiceAccount，也就将角色的权限赋予了账号。这部分可以详见参考文档1，写的很详细了。

在进入下一节介绍pod访问apiserver前，我摘录一些RBAC重要的信息：

1. 每一个namespace下都有一个default的ServiceAccount。
2. 每一个pod都有一个ServiceAccount，没有特别指定的话，pod的ServiceAccount将会是其namespace的default ServiceAccount。
3. 在pod的文件系统中，有个神秘目录：

```bash
/var/run/secrets/kubernetes.io/serviceaccount/
```

这个神秘目录下有三个文件，其内容分别是：

1. token: 该pod的ServiceAccount的token。
2. ca.cert: k8s集群签发ssl证书的ca证书。信任此证书才能访问集群内的https服务，例如apiserver的6443端口。
3. namespace： 该pod的namespace。

后文还将提到这个神秘目录。

## pod访问ApiServer

官方文档[directly-accessing-the-rest-api](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/#without-kubectl-proxy)有介绍了具体方案。简单说可以分为

1. 创建ClusterRoleBinding，赋予某ServiceAccount一定的访问权限
2. 创建该ServiceAccount的临时token。
3. 创建一个curl的pod，并在pod中执行curl访问ApiServer。注意我们携带了token，并且通过 `-k` 跳过了证书验证。

> PS：如果需要长期存在的可以参考:[manually-create-a-long-lived-api-token-for-a-serviceaccount](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#manually-create-a-long-lived-api-token-for-a-serviceaccount)。也可以按照文末附录的[#创建长期存在的token](#创建长期存在的token)流程实验一下。

接下来我们会实施一下，我们直接使用了cluster-admin的角色，免得创建细粒度的ClusterRole，当然这在生产中是不推荐的。我们在最后也清理掉了这个ServiceAccount。shell脚本如下：


```bash
# 创建具有cluster-admin角色的test-admin-user
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-admin-user
  namespace: default

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: test-admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: test-admin-user
  namespace: default
EOF
# 创建test-admin-user的token
token=`kubectl -n default create token test-admin-user`
echo $token
# 创建一个curl pod，并使用token访问apiserver的prometheus exporter
kubectl run curl --image=redhat/ubi9-minimal:9.2-717 --attach --rm --command --restart=Never -- \
curl https://kubernetes.default:443/metrics -k \
-H "Authorization: Bearer $token"
# 清理
kubectl delete ServiceAccount test-admin-user
kubectl delete ClusterRoleBinding test-admin-user
```

上面只是一个实验，那我们的kubernetes-dashboard和prometheus又是如何访问ApiServer的呢？其实也分为三部分：

1. 创建ServiceAccount、ClusterRole、ClusterRoleBinding。
2. 信任pod“神秘目录”下的ca.cert，并发起http请求
3. http请求中携带pod“神秘目录”下的token，作为Authorization请求头。

Prometheus进行k8s服务发现时就遵循上面的流程。

## Service Discovery和Relabel configs

不做追述，给两个Prometheus的官方文档给大家指路。

1. [kubernetes_sd_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
2. [relabel_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config)

Github项目[kubernetes-prometheus-grafana](https://github.com/arloor/kubernetes-prometheus-grafana)中 `prometheus.yaml` 的 `ConfigMap` 是 kubernetes_sd_config 和 relabel_config 的实际例子，可以对照查看。

> PS: Prometheus部署在K8S集群外也可以监控K8S集群，此时需要指定apiserver地址，token和ca_cert（或设置不验证证书）。参考文档中的这段描述：


```bash
# The API server addresses. If left empty, Prometheus is assumed to run inside
# of the cluster and will discover API servers automatically and use the pod's
# CA certificate and bearer token file at /var/run/secrets/kubernetes.io/serviceaccount/.
[ api_server: <host> ]
```


## 附录

### 参考文档

1. [Kubernetes（k8s）权限管理RBAC详解](https://juejin.cn/post/7116104973644988446)
2. [setup-prometheus-monitoring-on-kubernetes](https://github.com/techiescamp/kubernetes-prometheus)

### 创建长期存在的token

首先创建了cluster-admin角色的ServiceAccount "arloor"，并生成长期存在的token

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

其中 `kubectl get` 得到的是Base64编码过的，需要base64解码才能使用：


```bash
base64 -d - <<EOF
xxxxxxx token
EOF
```