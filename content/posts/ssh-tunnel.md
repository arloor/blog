---
title: "ssh隧道"
date: 2023-11-16T20:20:22+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


## SSH隧道的类型

- 本地端口转发（Local Port Forwarding）：允许你将本地端口上的数据转发到远程服务器。
- 远程端口转发（Remote Port Forwarding）：允许你将远程服务器上的端口转发到本地计算机。
- 动态端口转发（Dynamic Port Forwarding）：创建一个本地的SOCKS代理服务器，可以用于多种目的，如安全浏览。

## **本地端口转发：**

```bash
ssh -L [本地端口]:[目标服务器地址]:[目标端口] root@xxxxx
```

也可以将本地端口转发写到 `~/.ssh/config` 文件中，这样就可以直接在 `ssh [SSH服务器别名]` 时建立端口转发。

```shell
Host xxxxx
  LocalForward 8090 127.0.0.1:8090
```

可以理解为**Local 8090 forward to 127.0.0.1:8090**，即访问本地的8090端口就相当于访问远程服务器的127.0.0.1:8090。

注意有端口转发的tcp连接存在时，`exit` 断开ssh时，ssh命令并不会直接退出，还需要等端口转发连接断开或直接 `ctrl+c` 退出。


## **远程端口转发**

```bash
ssh -R [远程端口]:[本地地址]:[本地端口] root@xxxxxx
```

这允许远程服务器上的用户连接到你本地机器上的服务。

对应的 `.ssh/config` 内容如下：

```bash
RemoteForward 7890 localhost:7890
```

可以理解为**Remote 7890 forward to 本机的localhost:7890**，这其实是让远程服务器使用本机的clash代理

## **动态端口转发**

```bash
ssh -D [本地端口] [SSH服务器用户名]@[SSH服务器地址]
```

这会创建一个SOCKS代理，你可以在浏览器或其他应用程序中配置使用。

## 高级选项

- 可以使用 -N 选项在不执行远程命令的情况下建立SSH连接。
- 使用 -f 选项可以使SSH会话在后台运行。

## 我的ssh config备份

```bash
# 除了pi.arloor.com之外的，所有包含arloor或者家里的lan地址的HostName
## 设置使用socat代理，注意vscode可能把proxyport=6152改成proxyport 6152，注意手动恢复
Host !pi.arloor.com *.arloor.* 192.168.5.*
  ProxyCommand /opt/homebrew/bin/socat - PROXY:localhost:%h:%p,proxyport=6152

# 家里的mac-mini
Host 192.168.5.244
  HostName 192.168.5.244
  User arloor

# 家里的windows11
Host pi.arloor.com
  HostName pi.arloor.com
  LocalForward 7788 192.168.5.127:7788
  User arloor

Host tt.arloor.com
  HostName tt.arloor.com
  User root
```

