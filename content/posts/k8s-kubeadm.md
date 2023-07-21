---
title: "K8s Kubeadm 1.27.3安装"
date: 2023-07-19T19:48:26+08:00
draft: false
categories: [ "undefined"]
tags: ["k8s"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---
<!--more-->

## kubeadm安装控制面

### 机器配置

```bash
# 关闭swap
swapoff -a # 临时关闭
sed -i '/.*swap.*/d' /etc/fstab # 永久关闭，下次开机生效

# 加载内核模块
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

### 安装containerd

当前版本为1.7.2

```bash
wget  https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz -O /tmp/containerd.tar.gz
tar -zxvf /tmp/containerd.tar.gz -C /usr/local
containerd -v # 1.7.2
## runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 -O /tmp/runc.amd64
install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc
## cni
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz -O /tmp/cni-plugins-linux-amd64-v1.3.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin /tmp/cni-plugins-linux-amd64-v1.3.0.tgz
## 生成containerd配置文件
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
## 使用Systemd作为cggroup驱动
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/'  /etc/containerd/config.toml
## 使用阿里云镜像的sandbox，和下面的kubeadm init --image-repository镜像保持一致，否则kubeadm init时控制面启动失败
sed -i 's/sandbox_image.*/sandbox_image = "registry.aliyuncs.com\/google_containers\/pause:3.9"/' /etc/containerd/config.toml
## 从/etc/containerd/config.toml的disabled_plugins中去掉cri
## systemd服务
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service
```

修改containerd.service的代理配置，否则镜像都拉不下来，calico网络插件也装不了

```bash
vim /lib/systemd/system/containerd.service
# 在[Service]块中增加代理配置
# NO_PROXY中
#  10.96.0.0/16是kubeadm init --service-cidr的默认地址
#  192.168.0.0/16是kubeadmin init --pod-network-cidr我们填入的地址，也是calico网络插件工作的地址
Environment="HTTP_PROXY=http://127.0.0.1:3128/"
Environment="HTTPS_PROXY=http://127.0.0.1:3128/"
Environment="NO_PROXY=192.168.0.0/16,127.0.0.1,10.0.0.0/8,172.16.0.0/12,localhost"
```

启动containerd服务

```bash
systemctl daemon-reload
systemctl enable --now containerd
```

### 安装crictl

```bash
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.0/crictl-v1.27.0-linux-amd64.tar.gz -O /tmp/crictl-v1.27.0-linux-amd64.tar.gz
tar -zxvf /tmp/crictl-v1.27.0-linux-amd64.tar.gz -C /tmp
install -m 755 /tmp/crictl /usr/local/bin/crictl
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock  version
```

### 安装kubtelet kubeadm kubectl

```bash
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
# 在/etc/dnf/dnf.conf的[main]块中增加 exclude=kubelet kubeadm kubectl
echo "exclude=kubelet kubeadm kubectl" >> /etc/dnf/dnf.conf

sudo systemctl enable --now kubelet # 启动kubelet服务，但是会一直重启，这是正常的
kubelet --version # Kubernetes v1.27.3
kubectl version --short # Client Version: v1.27.3
```

### 初始化控制面节点

控制面节点是控制面组件运行的地方，包括etcd和api server。是kubectl打交道的地方.

```bash
# echo $(ip addr|grep "inet " |awk -F "[ /]+" '{print $3}'|grep -v "127.0.0.1") $(hostname) >> /etc/hosts
# echo 127.0.0.1 $(hostname) >> /etc/hosts


# kubeadm config print init-defaults --component-configs KubeletConfiguration > /etc/kubernetes/init-default.yaml
# sed -i 's/imageRepository: registry.k8s.io/imageRepository: registry.aliyuncs.com\/google_containers/' /etc/kubernetes/init-default.yaml
# sed -i 's/criSocket: .*/criSocket: unix:\/\/\/run\/containerd\/containerd.sock/' /etc/kubernetes/init-default.yaml
# sed -i 's/cgroupDriver: .*/cgroupDriver: systemd/' /etc/kubernetes/init-default.yaml

# # 将advertiseAddress改成实际地址
# kubeadm config images pull --config /etc/kubernetes/init-default.yaml
# kubeadm init --config /etc/kubernetes/init-default.yaml

echo $(ip addr|grep "inet " |awk -F "[ /]+" '{print $3}'|grep -v "127.0.0.1") $(hostname) >> /etc/hosts
kubeadm config images pull --image-repository registry.aliyuncs.com/google_containers
kubeadm init --pod-network-cidr=192.168.0.0/16 --image-repository registry.aliyuncs.com/google_containers --cri-socket unix:///run/containerd/containerd.sock
watch crictl --runtime-endpoint=unix:///run/containerd/containerd.sock ps -a
# 如果执行有问题，就kubeadm reset重新进行kubeadm init
```

设置kube config

```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get cs # 使用kubectl与集群交互
```

让其他节点加入集群：我这里只用控制面了，就不操作了


```bash
Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.4.17:6443 --token oafxnp.o4w7gamzg4dz592m \
	--discovery-token-ca-cert-hash sha256:67637fbffe6368ed94990172c0685e3c5f3d2ae53d70577f4e779e430ea9cafd 
```

### 安装网络插件，解决node not ready

```bash
$ kubectl get nodes
NAME   STATUS     ROLES           AGE   VERSION
node   NotReady   control-plane   49m   v1.27.3
$ kubectl describe nodes node|grep KubeletNotReady
  Ready            False   Wed, 19 Jul 2023 22:52:58 +0800   Wed, 19 Jul 2023 22:06:46 +0800   KubeletNotReady              container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
```

下面安装Calico网络插件，前提是 `--pod-network-cidr=192.168.0.0/16`，并且containerd正确设置了代理，否则下载不了Calico

```bash
# 创建tigera operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
# 创建Calico网络插件
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
watch kubectl get pods -n calico-system # 两秒刷新一次，直到所有Calico的pod变成running
```

下面是安装flannel网络插件，和Calico网络插件选一个即可

```bash
wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml -O kube-flannel.yml
sed -i 's/10.244.0.0\/16/192.168.0.0\/16/' kube-flannel.yml
for i in $(grep "image: " kube-flannel.yml | awk -F '[ "]+' '{print $3}'|uniq); do
        echo 下载 $i
        crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull ${i}
done
kubectl apply -f kube-flannel.yml
watch kubectl get pod -n kube-flannel
```

### 让控制面节点也能调度pod 

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-
```

### 检验dns正确

```bash
kubectl run curl --image=radial/busyboxplus:curl -it --rm
nslookup kubernetes.default
```

### 在控制面节点上跑一个nginx的pod

```bash
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml
watch kubectl get pods -o wide # 显示nginx的pod正Running在192.168.254.8上
curl 192.168.254.8
kubectl delete pod nginx # 删除这个pod
```

## 常用组件安装

### 装个我的代理

```bash
cat > proxy.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: proxy
  namespace: default
spec:
  containers:
  - image: arloor/rust_http_proxy:1.0
    imagePullPolicy: IfNotPresent
    name: proxy
    env:
    - name: port
      value: "444"
    - name: basic_auth
      value: "xxxxxxxx"
    - name: ask_for_auth
      value: "false"
    - name: "over_tls"
      value: "true"
  restartPolicy: Always
  ports:
    - containerPort: 444
      hostPort: 444
      name: https
      protocol: TCP
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
EOF
kubectl apply -f proxy.yaml
watch kubectl get pod 
```

### helm包管理器

```bash
wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -O /tmp/helm-v3.12.0-linux-amd64.tar.gz
tar -zxvf /tmp/helm-v3.12.0-linux-amd64.tar.gz -C /tmp
mv /tmp/linux-amd64/helm  /usr/local/bin/
```

### metric server

```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.3/components.yaml
```

修改 `components.yaml` 中容器的启动参数，加入 `--kubelet-insecure-tls` 。

```bash
for i in $(grep "image: " components.yaml | awk -F '[ "]+' '{print $3}'|uniq); do
        echo 下载 $i
        crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull ${i}
done
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock images|grep registry.k8s.io
kubectl apply -f components.yaml
watch kubectl get pod -n kube-system
kubectl get service -n ingress-nginx

NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.97.175.254   <pending>     80:30873/TCP,443:31834/TCP   4m42s
ingress-nginx-controller-admission   ClusterIP      10.99.75.35     <none>        443/TCP                      4m42s
```

metrics-server的pod正常启动后，等一段时间就可以使用kubectl top查看集群和pod的metrics信息。


### kubernetes dashboard

```bash
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml -O dashboard.yaml
```

修改dashboard.yaml成hostNetWork： 参考[K8S Dashboard安裝/操作](https://hackmd.io/@compalAA/SykoBsSbi#Step3-%E6%89%8B%E5%8B%95%E4%B8%8B%E8%BC%89image)

1. Service/kubernetes-dashboard的spec中增加  type: NodePort
2. Deployment/dashboard-metrics-scraper最后一行增加hostNetwork: true 和containers：并排
3. 在args中增加 - --token-ttl=43200 将token过期时间改为12小时
 
```bash
kubectl apply -f dashboard.yaml
watch kubectl get svc -n kubernetes-dashboard
```

```bash
NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE   SELECTOR
dashboard-metrics-scraper   ClusterIP   10.106.143.149   <none>        8000/TCP        53s   k8s-app=dashboard-metrics-scraper
kubernetes-dashboard        NodePort    10.97.248.169    <none>        443:31611/TCP   53s   k8s-app=kubernetes-dashboard
```

`443:31611/TCP` 表示我们可以通过外网ip:31611来访问dashboard，快速得到这个端口可以用下面的命令

```bash
kubectl get svc -n kubernetes-dashboard |grep NodePort|awk -F '[ :/]+' '{print $6}'
```

生成访问token: 参考[creating-sample-user](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)

ServiceAccount

```bash
cat > sa.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
kubectl apply -f sa.yaml
```

ClusterRoleBinding

```bash
cat > roleBind.yaml <<EOF
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
  namespace: kubernetes-dashboard
EOF
kubectl apply -f roleBind.yaml
```

生成登陆的token

```bash
cat > /usr/local/bin/token <<\EOF
echo Port: `kubectl get svc -n kubernetes-dashboard |grep NodePort|awk -F '[ :/]+' '{print $6}'`
echo
echo Token: 
kubectl -n kubernetes-dashboard create token admin-user
EOF
chmod +x /usr/local/bin/token
token
```

通过token访问 `https://ip/31611` 即可访问dashboard。

![](/img/k8s-dashboard.png)

## 参考文档

- [install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [create-cluster-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [containerd get started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
- [kubernetes新版本使用kubeadm init的超全问题解决和建议](https://blog.csdn.net/weixin_52156647/article/details/129765134)
- [calico quick start](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)
- [containerd设置代理](https://blog.51cto.com/u_15343792/5142108)
- [工作负载pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [工作负载deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [使用kubeadm部署Kubernetes 1.27](https://blog.frognew.com/2023/06/kubeadm-install-kubernetes-1.27.html)
- [ingress-nginx deploy](https://kubernetes.github.io/ingress-nginx/deploy/)
- [ingress-nginx 更改地址](https://blog.51cto.com/u_1472521/4909743)
- [ingress-nginx custom-listen-ports](https://docs.nginx.com/nginx-ingress-controller/tutorials/custom-listen-ports/)


## 其他

### metal lb

metallb-native.yaml

```bash
wget https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml -O metallb-native.yaml
for i in $(grep "image: " metallb-native.yaml | awk -F '[ "]+' '{print $3}'|uniq); do
        echo 下载 $i
        crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull ${i}
done
kubectl apply -f metallb-native.yaml
```

```bash
cat > l2.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 10.0.4.100-10.0.4.200
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF
kubectl apply -f l2.yaml
```

### ingress-nginx并通过hostNetwork暴露18080和1443端口

```bash
wget https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-4.7.1/ingress-nginx-4.7.1.tgz
helm show values ingress-nginx-4.7.1.tgz > values.yaml # 查看可以配置的value
```

修改values.yaml：改成使用hostNetwork，并且修改containerPort为非常用端口。我们的环境没有LoadBalencer，所以要用hostNetwork

```yaml
  containerPort:
    http: 18080
    https: 1443
....
  hostNetwork: true
```

```bash
## 预下载registry.k8s.io的镜像
helm template  ingress-nginx-4.7.1.tgz -f values.yaml > ingress-nginx-deploy.yaml
for i in $(grep "image: " ingress-nginx-deploy.yaml | awk -F '[ "]+' '{print $3}'|uniq); do
        echo 下载 $i
        crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull ${i}
done
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock images|grep registry.k8s.io
systemctl disable rust_http_proxy --now #关闭所有占用80、443端口的服务
helm install ingress-nginx ingress-nginx-4.7.1.tgz --create-namespace -n ingress-nginx -f values.yaml

# helm install ingress-nginx ingress-nginx-4.7.1.tgz --create-namespace -n ingress-nginx -f values.yaml
watch kubectl get pods -o wide  -n ingress-nginx
kubectl get services -o wide
kubectl get controller -o wide
```

修改端口

```bash
$ kubectl edit deployment release-name-ingress-nginx-controller #  不知道values.yaml里的extraArgs有用吗
/ -- 搜索，然后修改：
   spec:
      containers:
      - args:
        - /nginx-ingress-controller
        - --publish-service=$(POD_NAMESPACE)/release-name-ingress-nginx-controller
        - --election-id=release-name-ingress-nginx-leader
        - --controller-class=k8s.io/ingress-nginx
        - --ingress-class=nginx
        - --configmap=$(POD_NAMESPACE)/release-name-ingress-nginx-controller
        - --validating-webhook=:8443
        - --validating-webhook-certificate=/usr/local/certificates/cert
        - --validating-webhook-key=/usr/local/certificates/key
        ## 增加以下端口设置
        - --http-port=18080
        - --https-port=1443
$ kubectl delete pod release-name-ingress-nginx-controller-5c65485f4c-lnm2r #删除这个deployment的老pod，就会创建新的pod
```

```bash
systemctl enable rust_http_proxy --now #开启原来的那些服务
curl http://xxxx:18080 # 404即成功
```

### NodePort方式安装Ingress Nginx

```bash
wget -O ingress-nginx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
for i in $(grep "image: " ingress-nginx.yaml | awk -F '[ "]+' '{print $3}'|uniq); do
        echo 下载 $i
        crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull ${i}
done
kubectl apply -f ingress-nginx.yaml
watch kubectl get service -A
```

问题： 在做[local-testing](https://kubernetes.github.io/ingress-nginx/deploy/#local-testing)创建ingress时，连接不到admission。

```bash
$ kubectl create deployment demo --image=httpd --port=80
$ kubectl expose deployment demo
$ kubectl create ingress demo-localhost --class=nginx \
  --rule="demo.localdev.me/*=demo:80"
error: failed to create ingress: Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": EOF
```

测试了下dns
```bash
$ kubectl run curl --image=radial/busyboxplus:curl -it
$ nslookup ingress-nginx-controller-admission.ingress-nginx.svc # dns是通的
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      ingress-nginx-controller-admission.ingress-nginx.svc
Address 1: 10.108.175.87 ingress-nginx-controller-admission.ingress-nginx.svc.cluster.local
$ curl https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s
curl: (6) Couldn't resolve host 'ingress-nginx-controller-admission.ingress-nginx.svc'
$ curl https://ingress-nginx-controller-admission.ingress-nginx.svc.cluster.local:443/networking/v1/ingresses?timeout=10s  -k -v
* SSLv3, TLS handshake, Client hello (1):
* SSLv3, TLS handshake, Server hello (2):
* SSLv3, TLS handshake, CERT (11):
* SSLv3, TLS handshake, Server key exchange (12):
* SSLv3, TLS handshake, Server finished (14):
* SSLv3, TLS handshake, Client key exchange (16):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
> GET /networking/v1/ingresses?timeout=10s HTTP/1.1
> User-Agent: curl/7.35.0
> Host: ingress-nginx-controller-admission.ingress-nginx.svc.cluster.local
> Accept: */*
> 
< HTTP/1.1 400 Bad Request
< Date: Fri, 21 Jul 2023 03:02:07 GMT
< Content-Length: 0
< 
```

类似的问题在 kubernetes.default 也一样

```bash
[ root@curl:/ ]$ nslookup kubernetes.default
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
[ root@curl:/ ]$ curl https://kubernetes.default -k
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/\"",
  "reason": "Forbidden",
  "details": {},
  "code": 403
[ root@curl:/ ]$ curl https://kubernetes.default.svc -k
curl: (6) Couldn't resolve host 'kubernetes.default.svc'
[ root@curl:/ ]$ curl https://kubernetes.default.svc.cluster.local -k
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/\"",
  "reason": "Forbidden",
  "details": {},
  "code": 403
}
```