---
title: "docker杂说"
author: "刘港欢"
date: 2019-01-01
categories: [ "docker"]
tags: ["program"]
weight: 10
---

docker很火，所以我想入门。这篇文章是记录学习的，所以可能很乱，称为杂说
<!--more-->

# 变成自己的docker

为了用的顺手，做两方面调整：配置使用代理、设置不需要sudo

## 设置docker命令使用代理

在之前的博客中，我多次提到使用`. pass`来设置shell的代理，但是这对docker没有作用。

在使用systemd的linux发行版中（比如ubuntu 18.04），可以这样配置：参见[#httphttps-proxy](https://docs.docker.com/config/daemon/systemd/#httphttps-proxy)

```
#覆盖 the default docker.service file
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo vim /etc/systemd/system/docker.service.d/http-proxy.conf

# 写入下列内容，配置proxy
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:8081/" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"

# Flush changes:
sudo systemctl daemon-reload
#Restart Docker:
sudo systemctl restart docker
#Verify that the configuration has been loaded:
sudo systemctl show --property=Environment docker
# 像这样：Environment=HTTP_PROXY=http://127.0.0.1:8081/ NO_PROXY=localhost,127.0.0.1,docker-registry.so
```

## 配置不需要sudo

```
sudo groupadd docker
sudo usermod -aG docker $USER
```

解释：

The Docker daemon binds to a Unix socket instead of a TCP port. By default that Unix socket is owned by the user root and other users can only access it using sudo. The Docker daemon always runs as the root user.

If you don’t want to preface the docker command with sudo, create a Unix group called docker and add users to it. When the Docker daemon starts, it creates a Unix socket accessible by members of the docker group.

重启一下电脑（虚拟机/服务器）这样就可以不加sudo地使用docker了。如果在运行docker命令时报：
```
WARNING: Error loading config file: /home/user/.docker/config.json -
stat /home/user/.docker/config.json: permission denied
```
是因为`~/.docker/`directory was created with incorrect permissions due to the sudo commands.

这时候就把这个文件夹删掉好了。或者参照官网：

To fix this problem, either remove the ~/.docker/ directory (it is recreated automatically, but any custom settings are lost), or change its ownership and permissions using the following commands:
```
$ sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
$ sudo chmod g+rwx "$HOME/.docker" -R
```

# java的简单docker使用

以自己的proxyserver为例子：

## 编写Dockerfile
```
mkdir docker-proxyserver
# 里面放Dockerfile和proxyserver-1.2-jar-with-dependencies.jar
```
Dockerfile内容：
```
FROM java:8
COPY . /var/www/java  
WORKDIR /var/www/java  
#RUN java -jar proxyserver-1.2-jar-with-dependencies.jar 
CMD ["java", "-jar","proxyserver-1.2-jar-with-dependencies.jar"]
```
解释：

1. 以java8为基础映像
2. 将该文件夹下所有文件复制到容器的/var/www/java文件夹
3. 已/var/www/java作为工作目录
4. 被注释掉了：不需要在cmd前做什么
5. CMD: docker run会执行这行命令：启动proxyserver

## 构建image、容器、运行

```
cd docker-proxyserver
#构建
sudo docker build -t proxyserver .
运行
sudo docker run proxyserver

#下面就可以看到proxyserver运行的日志了
2019-01-01 15:09:17.312 [main] INFO  com.arloor.proxyserver.ServerProxyBootStrap - 开启代理 端口:8080
```

## 进入容器一探究竟

上面的容器，最后通过CMD执行了java -jar命令，虽然运行了程序，但容器的运行是个黑盒。现在开始进入这个黑盒。

注释掉DockerFile的最后一行：`CMD ["java", "-jar","proxyserver-1.2-jar-with-dependencies.jar"]`。

重新构建映像，并以交互模式run容器：

```
sudo docker build -t proxyserver .
docker run -it  proxyserver /bin/bash 　＃-it表示交互模式
#或者：docker run -it  proxyserver
```
之后的terminal:
```
x1@carbon:~/docker-proxyserver$ docker run -it  proxyserver /bin/bash
root@2afdacfb0dff:/var/www/java# ls
Dockerfile  proxyserver-1.2-jar-with-dependencies.jar
root@2afdacfb0dff:/var/www/java# uname -a
Linux 2afdacfb0dff 4.15.0-43-generic #46-Ubuntu SMP Thu Dec 6 14:45:28 UTC 2018 x86_64 GNU/Linux
root@2afdacfb0dff:/var/www/java# echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
root@2afdacfb0dff:/var/www/java# reboot
Failed to talk to init daemon.
```
这就像一个虚拟机啊。可以看出不同的大概是最后一个命令`reboot`的执行结果：Failed to talk to init daemon.可以看出进程隔离这个原理的影子吧

# 自己改造一个镜像

上面我们已经知道了，是可以进入镜像执行一些命令的，比如执行一些解压、设置PAHT、新建软连接都是可以的，这就是安装软件的过程了。

而`docker commit`则允许`Create a new image from a container's changes`：由一个被修改过的容器创建一个映像。这给我们提供了魔改镜像、自定义镜像的能力。具体展开：todo
