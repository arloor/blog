---
title: "docker使用笔记"
author: "刘港欢"
date: 2019-01-02
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

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo touch /etc/systemd/system/docker.service.d/http-proxy.conf

if ! grep HTTP_PROXY /etc/systemd/system/docker.service.d/http-proxy.conf;
then
cat >> /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:3128/" "HTTPS_PROXY=http://127.0.0.1:3128/" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF
```

## 设置国内镜像

除了上面的设置代理，还可以配置国内镜像

```
vi /etc/docker/daemon.json

#写入以下内容
{
 "registry-mirrors": ["https://registry.docker-cn.com"]
}

# 最后
# Flush changes:
sudo systemctl daemon-reload
#Restart Docker:
sudo systemctl restart docker
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
docker build -t proxyserver .
运行
docker run proxyserver

#下面就可以看到proxyserver运行的日志了
2019-01-01 15:09:17.312 [main] INFO  com.arloor.proxyserver.ServerProxyBootStrap - 开启代理 端口:8080
```

## 进入容器一探究竟

上面的容器，最后通过CMD执行了java -jar命令，虽然运行了程序，但容器的运行是个黑盒。现在开始进入这个黑盒。

注释掉DockerFile的最后一行：

```
CMD ["java", "-jar","proxyserver-1.2-jar-with-dependencies.jar"]
```

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

上面我们已经知道了，是可以进入镜像执行一些命令的，比如执行一些解压、设置PATH、新建软连接都是可以的，这就是安装软件的过程了。

而`docker commit`则允许`Create a new image from a container's changes`：由一个被修改过的容器创建一个映像。这给我们提供了魔改镜像、自定义镜像的能力。

以一个需要nodejs8和java８的项目为例：我们以centos为基础映像，启动容器，然后进行魔改（安装jdk和node）。

## 以centos为基础构建image

Dockerfile:
```
FROM centos:7
COPY . /app
WORKDIR /app
EXPOSE 4000
```
集成centos7映像，将本文件夹下的所有文件（是项目代码）复制到容器的`/app`文件下。这里也包括了npm_modules。最后定义暴露4000端口

构建映像：
```
docker build -t simlogin-with-docker .
```

## 用基础映像启动一个容器，并进行修改

```
docker run -it -v ~/Downloads/:/usr/my/docker/download/ simlogin-with-docker /bin/bash
```
解释：使用simlogin-with-docke镜像启动一个container。`-it`表示交互模式——启动容器后会进入docker的shell。`-v ~/Downloads/:/path/in/container`表示将宿主机的`下载`目录挂载到容器的`/usr/my/docker/download/`。最后的`/bin/bash`是容器所执行的CMD。注意我们在Dockfile中并没有定义CMD，所以在这里需要加上`/bin/bash`。实际上不加`/bin/bash`好像也可以。

之后的终端是这样的

```
x1@carbon:~$ docker run -it -v ~/Downloads/:/usr/my/docker/download/ simlogin-with-docker /bin/bash
[root@4c97d816eba7 app]#
```
这样就进入了容器的shell，像不像进入了一个虚拟机

这样就可以对这个“虚拟机”进行修改了：我做了以下：安装java和nodejs、yum安装相关库、pm2、设置PATH、编写启动脚本`/app/run.sh`

这些步骤只讲最后一步，因为前面的步骤和在虚拟机里操作一模一样，而编写run.sh则很关键也有一些坑。

### run.sh

```
#! /bin/bash

. ~/.bashrc  #关键：导入PATH
pm2 start process.json --env local
tail -f /dev/null  # 关键：让此bash进程永远不退出
```
第一个坑：最好手动导入PATH

第二个坑：CMD执行的进程结束，容器进程就结束了。所以加上最后一句让bash进程永不退出。这点坑了我很久。。。

把这些做完之后，这个容器的就是我们需要的样子了。下一步就是将这个容器“持久化”成一个image，这样以后就可以直接启动容器而不需要再做环境修改。

## 持久化修改好的容器

第一点！不要在容器的“交互性”shell中输exit或者ctrl+D！就是不要让这个容器的运行结束

第二步：另起终端。输入`docker ps`或`docker container list`，显示现在运行的容器，显示如下：
```
x1@carbon:~$ docker container list
CONTAINER ID        IMAGE                  COMMAND             CREATED             STATUS              PORTS               NAMES
4c97d816eba7        simlogin-with-docker   "/bin/bash"         22 minutes ago      Up 22 minutes       4000/tcp            distracted_agnesi
x1@carbon:~$ docker ps
CONTAINER ID        IMAGE                  COMMAND             CREATED             STATUS              PORTS               NAMES
4c97d816eba7        simlogin-with-docker   "/bin/bash"         22 minutes ago      Up 22 minutes       4000/tcp            distracted_agnesi
```

第三步：commit容器，也就是“持久化”为镜像了

```
docker commit 4c97d816eba7 simlogin-with-docker:1.0
```

这样就新建了一个simlogin-with-docker:1.0映像。这就是最终的映像啦。

## 运行这个完成体映像

```
docker run  -d -p 80:4000 simlogin-with-docker /app/run.sh
```

`-d`表示在后台运行；

` -p 80:4000`表示宿主机80端口映射容器4000端口；

`/app/run.sh`表示执行的CMD，注意这个sh脚本被我们控制为了永远不会退出。

问题：这个sh脚本不会退出。。所以pm2启动的进程如果异常退出了，这个docker容器也不会退出，也就没有实现监控了。

## 进入这个正在在运行的容器

一开始我用`docker attach containerID`，但是发现有一些问题。后来我用

```
docker exec -it containerID /bin/bash
```

好了，docker算入门了吧

## 删除容器、镜像

一个镜像很容易就超级超级大，有必要删除没用的镜像和容器

要删除镜像，需要首先删除容器。

```
# 删除所有容器
docker rm `docker ps -a -q`
# 删除所有镜像
docker rmi `docker images -a -q`
# 删除带关键字的镜像
docker rmi --force `docker images | grep xxx | awk '{print $3}'`
# 删除没有标签的镜像
docker rmi `docker images -q | awk '/^<none>/ { print $3 }'`
```

# push本地镜像到docker hub

首先`docker login`登录到docker hub，需要输入docker hub的用户名密码

然后，把本地的docker镜像打上用户名的tag..

最后push

```
docker tag ubuntu:18.04 arloor/ubuntu:18.04
docker push arloor/ubuntu:18.04
docker search arloor
```

# centos 7的docker使用

服务器一般是centos系统，记录一下centos中的一些东西

## 安装docker-ce

 卸载旧版本

Docker 的早期版本称为 docker 或 docker-engine。如果安装了这些版本，请卸载它们及关联的依赖资源。

```
 sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
```
安装相关依赖

```
yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
  ```

  设置docker源

  ```
  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
```

安装docker

```
yum install docker-ce
 ```


## iptables

iptables是linux下的防火墙服务。在我的使用中，遇到一个问题：编辑/etc/sysconfig/iptables配置文件后，重启iptables服务(service iptables restart)。正在运行的docker容器可以正常接受请求，却不能向其他服务器发送http请求（tcp流量）。搜索之后发现，docker服务启动时，会增加iptables规则，应该是定义nat规则的。当iptables服务重启时，docker服务增加的iptables就被丢弃了，所以会出现这样的问题。

所以解决方式：

1. 重启docker服务 service docker restart
2. 将docker增加的iptables持久化 iptables save（不怎么推荐且我也不知道有没有什么副作用）