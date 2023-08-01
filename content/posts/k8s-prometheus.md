---
title: "从K8S部署prometheus谈谈K8S RBAC、Promethues服务发现、Prometheus Relabel configs"
date: 2023-07-30T23:02:21+08:00
draft: true
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

在参考[setup-prometheus-monitoring-on-kubernetes](https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/)部署node-exporter + prometheus + grafana的过程中，遇到了一些新主题，需要记录下。主要有这些：
<!--more-->

| 主题 | 详述 |
| :-----------------------------: | :---------------- |
| K8S的RBAC                     | 全称是基于角色的访问控制，K8S权限机制的基础 |
| 在Pod中访问ApiServer           | Prometheus是运行在k8s集群中的一个pod，访问k8s的apiserver时需要一些鉴权机制 |
| Prometheus Service Discovery | Prometheus是pull模型，需要自动地发现k8s集群中有哪些endpoing、node、service等，并watch其变更 |
| Prometheus relabel_configs   | 在prometheus的抓取job中过滤、转换target的label |

## prometheus manifest简析

prometheus部署的manifest主要有如下几个部分

1. ClusterRole、 ClusterRoleBinding：RBAC权限控制部分，给namespace monitoring下的default serviceaccount赋予了对相关资源的get、list、watch权限。
2. ConfigMap: Prometheus 配置文件部分,创建了alert manager告警规则和prometheus抓取规则，其中包括各种k8s服务发现和relabel configs。
3. Prometheus的Deployment和Service

具体的yaml文件在文末的附录部分。接下来我们将主要关注第一二部分，第三部分已经很熟悉了。

## K8S RBAC访问控制

像我们部署kubernetes-dashboard和prometheus时都需要创建ServiceAccount、ClusterRoleBinding等，这些就是RBAC机制的组成部分。kubernetes-dashboard和prometheus用他们来访问ApiServer。

RBAC是一个权限控制的常见方案，由三个部分组成：ClusterRole、ServiceAccount和ClusterRoleBinding。ClusterRole定义了对一系列资源的访问权限。而ClusterRoleBinding则将ClusterRole赋予给ServiceAccount，也就将角色的权限赋予了账号。这部分可以详见参考文档1，写的很详细了。

在进入下一节介绍pod访问apiserver前，我摘录一些RBAC重要的信息：

1. 每一个namespace下都有一个default的ServiceAccount。
2. 每一个pod都有一个ServiceAccount，没有特别指定的话，pod的ServiceAccount将会是其namespace的default ServiceAccount。
3. 在pod中，`/var/run/secrets/kubernetes.io/serviceaccount/` 目录下有三个文件
    1. token: 该pod的ServiceAccount的token。
    2. ca.cert: k8s集群签发ssl证书的ca证书。信任此证书才能访问集群内的https服务，例如apiserver的6443端口。
    3. namespace： 该pod的namespace。

## pod访问ApiServer

官方文档[directly-accessing-the-rest-api](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/#without-kubectl-proxy)有介绍了具体方案。简单说可以分为

1. 创建ClusterRoleBinding，赋予某ServiceAccount一定的访问权限
2. 创建该ServiceAccount的临时token。PS：如果需要长期存在的可以参考:[manually-create-a-long-lived-api-token-for-a-serviceaccount](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#manually-create-a-long-lived-api-token-for-a-serviceaccount)
3. 创建一个curl的pod，并在pod中执行curl访问ApiServer。注意我们携带了token，并且通过 `-k` 跳过了证书验证。

接下来我们会实施一下，我们直接使用了cluster-admin的角色，免得创建细粒度的ClusterRole，当然这在生产中是不推荐的。我们在最后也清理掉了这个ServiceAccount。shell脚本如下：


```bash
# 创建具有cluster-admin角色的admin-user
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
# 创建admin-user的token
token=`kubectl -n default create token admin-user`
echo $token
# 创建一个curl pod，并使用token访问apiserver的prometheus exporter
kubectl run curl --image=radial/busyboxplus:curl --attach --rm -- \
curl https://kubernetes.default:443/metrics -k \
-H "Authorization: Bearer $token"
# 清理
kubectl delete ServiceAccount admin-user
kubectl delete ClusterRoleBinding admin-user
```

上面只是一个实验，那我们的kubernetes-dashboard和prometheus又是如何访问ApiServer的呢？其实也分为三部分：

1. 创建ServiceAccount、ClusterRole、ClusterRoleBinding。
2. 信任 `/var/run/secrets/kubernetes.io/serviceaccount/` 下的ca.cert，并发起http请求
3. http请求中携带 `/var/run/secrets/kubernetes.io/serviceaccount/` 下的token，作为Authorization请求头。

## Service Discovery和Relabel configs

todo


## 附录

### 参考文档发

1. [Kubernetes（k8s）权限管理RBAC详解](https://juejin.cn/post/7116104973644988446)

### manifest yaml

**ClusterRole、 ClusterRoleBinding**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: default
  namespace: monitoring
```

**ConfigMap**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitoring
data:
  prometheus.rules: |-
    groups:
    - name: devopscube demo alert
      rules:
      - alert: High Pod Memory
        expr: sum(container_memory_usage_bytes) > 1
        for: 1m
        labels:
          severity: slack
        annotations:
          summary: High Memory Usage
  prometheus.yml: |-
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - targets:
          - "alertmanager.monitoring.svc:9093"
    scrape_configs:
      - job_name: 'node-exporter'
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_endpoints_name]
          regex: 'node-exporter'
          action: keep
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8080']
      - job_name: 'kubernetes-cadvisor'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
      - job_name: 'kubernetes-service-endpoints'
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name
```

**Deployment、Service**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: monitoring
  labels:
    app: prometheus-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-server
  template:
    metadata:
      labels:
        app: prometheus-server
    spec:
      nodeSelector:
        node-role.kubernetes.io/control-plane: "true"
      containers:
        - name: prometheus
          image: prom/prometheus
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus/"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: prometheus-config-volume
              mountPath: /etc/prometheus/
            - name: prometheus-storage-volume
              mountPath: /prometheus/
      volumes:
        - name: prometheus-config-volume
          configMap:
            defaultMode: 420
            name: prometheus-server-conf
  
        - name: prometheus-storage-volume
          emptyDir: {}

---

apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '9090'
  
spec:
  selector: 
    app: prometheus-server
  type: LoadBalancer 
  ports:
    - port: 9090
      targetPort: 9090 
```