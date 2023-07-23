---
title: "在K3S集群中创建clash代理服务"
date: 2023-07-23T15:50:30+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 准备文件

首先准备创建docker镜像的文件，有如下这些。可以注意到，没有在docker镜像中放置config.yaml。这将通过config.map挂载到pod中。

```bash
$ tree
.
├── clash-linux-amd64-2022.11.25 # clash可执行文件
├── Country.mmdb # GEOIP规则用到的mmdb文件
└── Dockerfile
```

Dockerfile内容如下：

```bash
FROM alpine:3.18.2
# 设置时区为上海
RUN apk add tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
   && echo "Asia/Shanghai" > /etc/timezone \
   && apk del tzdata
COPY ./ /
```

## 制作镜像并推送到docker hub

```shell
podman build  -t clash -f Dockerfile . --tag docker.io/arloor/clash:1.0
podman login docker.io # 输入账号密码登陆docker hub
podman push docker.io/arloor/clash:1.0
```

## 创建manifest

```bash
cat > cm-clash-conf.yaml <<EOF
# config.yaml
apiVersion: v1
data:
  config.yaml: "port: 3128\nallow-lan: true\n\nproxies:\n- name: \"bwg\"\n  type:
    http\n  server: xxxx\n  port: 444\n  username: xx\n  password:
    xxxx\n  tls: true \n  skip-cert-verify: true\n\nrules:\n-
    IP-CIDR,192.168.0.0/16,DIRECT\n- IP-CIDR,10.0.0.0/8,DIRECT\n- IP-CIDR,172.16.0.0/12,DIRECT\n-
    GEOIP,CN,DIRECT\n- MATCH,bwg\n"
kind: ConfigMap
metadata:
  name: clash-conf
  namespace: default

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: clash
  namespace: default
  labels:
    k8s-app: clash
spec:
  selector:
    matchLabels:
      k8s-app: clash
  template:
    metadata:
      labels:
        k8s-app: clash
    spec:
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
      - name: clash
        image: docker.io/arloor/clash:1.0
        command: [ "/clash-linux-amd64-2022.11.25","-d","/","-f","/etc/clash/config.yaml" ]
        ports:
          - containerPort: 3128 #指定容器ip
            protocol: TCP
        resources:
          limits:
            memory: 100Mi
          requests:
            cpu: 50m
            memory: 50Mi
        volumeMounts:
        - mountPath: "/etc/clash"   #容器挂载的目录（空的）
          name: config   
      terminationGracePeriodSeconds: 30
      volumes:
      - configMap:
          name: clash-conf          #指定使用ConfigMap的名称
        name: config 

---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: clash
  name: clash
  namespace: default
spec:
  ports:
    - port: 3128
      targetPort: 3128
      protocol: TCP
  selector:
    k8s-app: clash
  type: ClusterIP

EOF
kubectl apply -f cm-clash-conf.yaml
```

其中ConfigMap对应的就是config.yaml的内容，我是使用如下命令从文件直接创建的：

```bash
kubectl create cm clash-conf --from-file=config.yaml 
kubectl get cm clash-conf  -o yaml
```

config.yaml内容：

```yaml
port: 3128 
# 绑定0.0.0.0
allow-lan: true 

proxies:
- name: "xxx"
  type: http
  server: xxx
  port: xx
  username: xx
  password: xxx
  tls: true 
  skip-cert-verify: true

rules:
- IP-CIDR,192.168.0.0/16,DIRECT
- IP-CIDR,10.0.0.0/8,DIRECT
- IP-CIDR,172.16.0.0/12,DIRECT
- GEOIP,CN,DIRECT
- MATCH,xxx
```

另外在过程中遇到一点问题是Service写的不对，没有和deployment成功关联，主要是.spec.selector那里没写对，后面直接用expose来创建service了。而且刚好只需要ClusterIp类型的Service即可，expose刚刚好。

> 后面又学习了下，Deployment的 spec.selector.matchLabels 下的labels要和Service的.spec.selector下的labels一致。
> 这也可以形成个最佳实践：如无必要，勿增实体，Service和Deployment的Name**保持一致**，然后给Deployment增加一个label：固定为 **k8s-app: ${name}**，然后Service的selector就填这个**k8s-app: ${name}**

```bash
kubectl expose deployment/clash
```

## 测试

我们开一个curl的pod来测试下

```bash
kubectl run curl --image=radial/busyboxplus:curl --command --attach --rm -- \
curl https://google.com --proxy http://clash.default:3128
# 也可以 kubectl run curl --image=radial/busyboxplus:curl -it --rm来创建pod，然后在pod的bash中执行curl命令
```