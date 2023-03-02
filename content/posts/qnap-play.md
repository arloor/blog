---
title: "威联通NAS折腾"
date: 2022-09-17T14:55:19+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

入手了一台威联通TS-564，当作给自己的奖励。
<!--more-->

## 容器

1. 在appcentor安装Container Station
2. 搜索centos8-stream的LXD镜像，并创建容器
3. 修改容器的网络为Bridge，这样就和局域网里其他的机器网络共通了
4. 开启nas的ssh功能
5. ssh到nas上，执行`lxc exec ${容器名} -- /bin/bash`

> ssh到某机器并且一键登入容器可以:`ssh xxx@xxx.com  -p ${ssh_port} -t 'lxc exec ${容器名} -- /bin/bash'`

lxd的容器完全可以当成富容器来用，除了不能ssh，也是有systemd的，可以运行daemon程序，这点很重要。

## 使用Rsync备份文件到威联通

### 威联通Rsync服务配置

首先到AppCenter中安装HBS3文件备份中心。

![](/img/Snipaste_2023-03-02_22-07-43.png)

然后打开HBS3的Rsync服务，详细配置如下

![](/img/Snipaste_2023-03-02_22-10-38.png)

第三步，在设置中打开ssh服务，因为rync使用了ssh服务。这里我们ssh端口设置成2222了，后面会用到。建议只在需要的时候打开ssh服务，不建议长时间打开ssh服务，因为威联通的ssh服务无法设置禁用密码登陆，密码简单的情况可能有被爆破的风险。

![](/img/Snipaste_2023-03-02_22-13-12.png)

至此，威联通上的rsync服务就配置好了，剩下的是rsync命令的使用了。

### rsync命令使用

参考：[Linux rsync 命令同步文件与目录/文件夹](https://www.myfreax.com/how-to-use-rsync-for-local-and-remote-data-transfer-and-synchronization/)


安装rsync：

```shell
# ubuntu
sudo apt install -y rsync
# centos
sudo yum install -y rsync
# Mac
# 看着是自带的
```

从其他地方备份到威联通上

```shell
rsync -avtP  -e "ssh -p ${ssh_port}" \
--exclude=${exclude1} \
--exclude=${exclude2} \
${src} \
${user}@${host}:/share/CACHEDEV1_DATA/${target}
```

- ${ssh_port} 是威联通ssh服务的端口，在我的配置下是2222
- --exclude 用于排除一些文件或文件夹
- ${src} 是原文件夹
- ${user} 是NAS的用户
- /share/CACHEDEV1_DATA/ 是威联通共享文件夹所在的目录，可以根据自己的情况调整
- -a 存档模式，等效于-rlptgoD。此选项指示rsync递归同步目录，传输特殊设备和块设备，保留符号链接，组，所有权和权限等。
- -z 此选项将强制rsync在数据发送给目标计算机之前对数据进行压缩。
- -P 使用此选项时，rsync将在传输过程中显示进度条并保留部分传输的文件。在慢速或不稳定的网络连接传输大文件时非常有用。
- --delete使用此选项时，rsync将从目标位置删除相同的文件。适合用于镜像文件。
- -q 此选项禁止显示非错误消息。-e此选项使您可以选择其他远程shell程序。默认使用ssh。
-t 该选项用与保持文件的mtime属性不变。mtime是文件的修改时间。如果没有指定-t选项时，目标文件mtime属性会设置为系统时间，导致下次更新检测到mtime不同，从而导致增量更新无效。