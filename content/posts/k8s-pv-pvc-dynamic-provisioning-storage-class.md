---
title: "K8S持久化卷、动态置备、StorageClass"
date: 2023-07-31T22:56:47+08:00
draft: false
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

在之前对K8S的使用中，已经用到了Volumes来给pod挂载文件，具体来说用到了HostPath、emptyDir、ConfigMap这几种类型的Volumes。最近在部署grafana时，遇到PersistentVolumeClaim的API类型，研究了一下，发现涉及的东西挺多的，有
<!--more-->

- 持久化卷 PersistentVolume
- 持久化卷声明 PersistentVolumeClaim
- 动态置备（Dynamic Provisioning）
- StorageClass
- local-path-provisioning（Rancher提供）

今天开个博客记录下。

## 持久化卷

和持久化卷对应的是短暂性卷（Ephemeral volume），短暂性卷的生命周期和pod一样，pod销毁则短暂性卷也销毁，最典型的emptyDir的Volume。持久化卷的生命周期则超越了pod，例如hostPath卷在pod销毁后还会继续存在，因为他本质就是宿主机上的文件。

## 动态置备流程

和动态置备对应的是静态置备。静态置备指的是需要预先准备，系统管理员采购、格式化、分配好磁盘后pod才可以使用。动态置备的流程则是使用时按需自动分配，整体流程是：

1. 创建指定StorageClass的PersistentVolumeClaim。意味着向某StorageClass申请（claim）持久化卷。（如果有默认StorageClass的话，可以不指定StorageClass）
2. 该StorageClass对应的插件将生成对应的PersistentVolume。
3. pod template中指定volumes为PersistentVolumeClaim，并volumeMounts到pod的文件系统中。

可以看到，需要K8S使用者做的是提出对存储资源的申请，而不需要他关注存储资源的底层细节（在哪里，是什么，怎么样），这些细节都是由StorageClass对应的插件来控制的。

在[grafana在k8s部署的官方文档](https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/)中就有通过动态置备claim（申请）持久化卷的例子，摘录manifest如下：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: grafana
  name: grafana
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      securityContext:
        fsGroup: 472
        supplementalGroups:
          - 0
      containers:
        - name: grafana
          image: grafana/grafana:9.1.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: http-grafana
              protocol: TCP
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /robots.txt
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 30
            successThreshold: 1
            timeoutSeconds: 2
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            tcpSocket:
              port: 3000
            timeoutSeconds: 1
          resources:
            requests:
              cpu: 250m
              memory: 750Mi
          volumeMounts:
            - mountPath: /var/lib/grafana
              name: grafana-pv
      volumes:
        - name: grafana-pv
          persistentVolumeClaim:
            claimName: grafana-pvc

---

apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  ports:
    - port: 3000
      protocol: TCP
      targetPort: http-grafana
  selector:
    app: grafana
  sessionAffinity: None
  type: LoadBalancer

```

在k3s集群中应用上面的manifest后，我们可以看到集群中出现了pv和pvc：

```bash
$ kubectl get pvc -A                                             
NAMESPACE    NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
monitoring   grafana-pvc   Bound    pvc-60fb480b-ebee-4290-9c1e-fbc6c3d8a7e4   1Gi        RWO            local-path     46h
$ kubectl describe pvc grafana-pvc -n monitoring
Name:          grafana-pvc
Namespace:     monitoring
StorageClass:  local-path # Cluster默认的StorageClass
Status:        Bound
Volume:        pvc-60fb480b-ebee-4290-9c1e-fbc6c3d8a7e4
Labels:        <none>
Annotations:   pv.kubernetes.io/bind-completed: yes
               pv.kubernetes.io/bound-by-controller: yes
               volume.beta.kubernetes.io/storage-provisioner: rancher.io/local-path
               volume.kubernetes.io/selected-node: mi
               volume.kubernetes.io/storage-provisioner: rancher.io/local-path
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      1Gi
Access Modes:  RWO
VolumeMode:    Filesystem
Used By:       grafana-6b5b6f6867-6snzv
Events:        <none>
$ kubectl get pv -A 
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS   REASON   AGE
pvc-60fb480b-ebee-4290-9c1e-fbc6c3d8a7e4   1Gi        RWO            Delete           Bound    monitoring/grafana-pvc   local-path              46h
$ kubectl describe pv pvc-60fb480b-ebee-4290-9c1e-fbc6c3d8a7e4 -A
Name:              pvc-60fb480b-ebee-4290-9c1e-fbc6c3d8a7e4
Labels:            <none>
Annotations:       pv.kubernetes.io/provisioned-by: rancher.io/local-path
Finalizers:        [kubernetes.io/pv-protection]
StorageClass:      local-path
Status:            Bound
Claim:             monitoring/grafana-pvc
Reclaim Policy:    Delete
Access Modes:      RWO
VolumeMode:        Filesystem
Capacity:          1Gi
Node Affinity:     
  Required Terms:  
    Term 0:        kubernetes.io/hostname in [mi]
Message:           
Source:
    Type:          HostPath (bare host directory volume) # 本质还是个HostPath
    Path:          /var/lib/rancher/k3s/storage/pvc-60fb480b-ebee-4290-9c1e-fbc6c3d8a7e4_monitoring_grafana-pvc
    HostPathType:  DirectoryOrCreate
Events:            <none>
```

local-path这个StorageClass对应k3s内置的[local-path-provisioning](https://github.com/rancher/local-path-provisioner)插件，他的作用就是：Dynamic provisioning the volume using `hostPath` or `local` 。上面创建的PV的类型就是hostPath类型的。并且这个PV的 `Node Affinity`定义了只有`kubernetes.io/hostname=mi`这个node上的pod能使用这个PV。原因是HostPath或local类型的卷都是本地卷，而不是网络附加的卷，只能在本机上使用。

提到这个local-path-provisioning，还得再次感叹k3s的“约定优于配置”的思想。给我一个开箱即用的默认的动态置备的storageClass，让我部署grafana的时候没有撞墙。



## 参考文档

- [kubernetes volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [kubernetes persistent-volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Kubernetes学习(rancher-local-path-provisioner)](https://izsk.me/2020/07/24/Kubernetes-Rancher-local-path-provisioner/)
