---
title: "tcpdump使用"
date: 2023-05-17T14:43:02+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

工作中需要用到tcpdump，这里做一下备忘，主要知识来源是 `man tcpdump`和ChatGPT-4。

## 常用命令

### 查看明文通信内容

查看IPv4的到80端口的http协议明文。

```bash
tcpdump  -A -nn -s 0 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
```

`-A` 表示用ASCII编码打印tcp包内容，用于查看http等明文协议

可以增加`and src host 101.33.xx.xx` 的条件来指定来源ip，此时只打印请求;增加`and dest host 101.33.xx.xx`，此时只打印响应；增加`and host 101.33.xx.xx`，此时请求和响应都会打印。

具体条件表达式可以参见`man pcap-filter`

只适用于IPv4的原因是上面的表达式中用到IPv4协议头部字段中的长度，换成IPv6的包，就不对了。IPv6版本的就没这么容易了，因为IPv6的payload length(ip6[4:2])包含了`Extension header`和TCP数据，而`Extension header`长度计算比较复杂，也没看到网上有正确的写法，鉴于这是一个老软件了，我倾向于相信网上没有资料就是没有解法。

### 查看localhost的包

> 来自ChatGPT-4

`tcpdump`通常是用来捕获通过网络接口传输的数据包，而不是那些仅在本地主机之间传输的数据包。

127.0.0.1是一个特殊的IP地址，也被称为loopback地址。当你的计算机向这个地址发送数据时，数据包不会真正离开你的计算机，而是会在本地进行处理。因此，如果你试图用`tcpdump`在一个物理网络接口（如eth0）上捕获发送到127.0.0.1的数据包，你可能无法捕获到任何数据包，因为这些数据包并没有通过该网络接口。

如果你想要用`tcpdump`捕获127.0.0.1上的网络流量，你应该在loopback接口（在Linux系统中通常被命名为lo）上运行`tcpdump`。例如：

```bash
sudo tcpdump -i lo
```

这将允许你捕获在本地主机上发送和接收的数据包。请注意，你可能需要管理员权限来运行`tcpdump`。


## 向ChatGPT的提问

### 为什么有时候tcpdump没有在length n后面打印http的请求详情？

`tcpdump` 是一个非常强大的网络工具，用于捕获网络上的数据包。它可以显示关于 TCP/IP 和其他网络包的详细信息，但并不总是显示应用层协议（如 HTTP）的详细内容。

这可能有几个原因：

1. **加密的数据流**：如果 HTTP 流量通过 SSL/TLS（也就是 HTTPS）进行加密，`tcpdump` 就无法读取 HTTP 报文的内容。你只会看到 TCP 层面的数据，但看不到应用层（即 HTTP）的数据。

2. **捕获的数据包长度**：`tcpdump` 的默认设置可能不会捕获整个数据包的内容。为了提高效率，`tcpdump` 可能只捕获每个数据包的前 N 字节（通常为 68、96 或 128 字节）。如果 HTTP 头部信息或请求/响应主体被截断，那么你可能无法看到完整的 HTTP 信息。使用 `-s` 参数可以调整捕获的数据包长度，例如，`tcpdump -s 0` 会捕获整个数据包。

3. **`tcpdump` 的输出选项**：`tcpdump` 的默认输出可能不包括 HTTP 请求的详细信息。使用 `-A` 参数（表示 ASCII），或 `-X` 参数（表示十六进制和 ASCII）可以显示 HTTP 头部和主体内容。例如：`tcpdump -A 'port 80'` 或 `tcpdump -X 'port 80'`。

需要注意的是，为了能正确解析和显示 HTTP 内容，`tcpdump` 需要能够捕获到完整的 TCP 连接，包括 SYN/SYN-ACK/ACK 握手过程。如果开始部分被遗漏，`tcpdump` 可能无法正确解析后续的 HTTP 数据包。

### tcpdump中怎么显示port而不是port的别名

默认情况下，tcpdump会尝试将已知的端口号转换为服务名称（例如，将80端口转换为http）。如果你想让tcpdump直接显示端 maverick.   

默认情况下，tcpdump会将端口显示为服务名称，比如将"80"显示为"http"。如果你希望tcpdump直接显示端口号，而不是服务名称，你可以使用 `-nn` 参数。"-n" 参数的作用是不把主机的网络地址转换成名字，"-nn" 参数的作用是不把网络地址和端口转换成家名书。

例如，你可以运行以下命令：

```bash
tcpdump -nn 'port 80'
```

在这个命令中，tcpdump将会显示端口号，而不是将它们转换为服务名称。