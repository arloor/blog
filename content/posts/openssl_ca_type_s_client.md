---
title: "Openssl使用：自定义CA签发证书、私钥格式、s_client使用"
date: 2023-05-11T11:35:02+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 签发CA并使用CA签发SSL证书

1. 在 `~/ca` 创建CA证书和私钥，私钥为 `ca_key.pem` ，公钥为 `ca.pem` 。 `ca.pem` 后续将被安装到系统并信任。
2. 在 `~/ca/certs` 创建自定义SSL证书，私钥为 `privkey.pem` ，公钥为 `cert.pem`。他们将被用于启动https服务。

脚本下载：[ca.sh](/sh/ca.sh)。

```bash
curl https://arloor.com/sh/ca.sh | bash
```

由于[iOS 13 和 macOS 10.15 中的可信证书应满足的要求](https://support.apple.com/zh-cn/103769)的限制，我们签发的证书最大有效时间只能是825天，否则会被safari报非标准证书，苹果就是屁事多。

## Mac下安装自定义CA证书

使用访达打开 `~/ca` 双击 `ca.pem` ，会打开“钥匙串访问”，将其安装到“系统”级别的“证书”下。

如果没有弹出安装CA证书的提示，也可以拖动`ca.pem` 到“系统”级别的“证书”的空白部分。

最后设置信任该自定义CA证书。

![40b3dc93b8c02c2b48dff3d526f8b873.png](/img/40b3dc93b8c02c2b48dff3d526f8b873.png)

![fac03ac28e578a2a458b150fef497290.png](/img/fac03ac28e578a2a458b150fef497290.png)

![8d7b336fd9e376eb116acb1e7d93d69a.png](/img/8d7b336fd9e376eb116acb1e7d93d69a.png)

## Windows安装CA

[https://learn.microsoft.com/zh-cn/windows-hardware/drivers/install/installing-test-certificates](https://learn.microsoft.com/zh-cn/windows-hardware/drivers/install/installing-test-certificates)

```bash
certmgr /add ca.pem /s /r localMachine root
```

## 参考文档

[CA & OpenSSL自签名证书](https://juejin.cn/post/7092789498823573518#heading-20)

## 私钥的各种格式

在 OpenSSL 和其他加密库中，您可能会遇到两种格式的私钥：`-----BEGIN RSA PRIVATE KEY-----` 和 `-----BEGIN PRIVATE KEY-----`。这两种格式的主要区别在于它们的编码方式和包含的信息。

1. `-----BEGIN RSA PRIVATE KEY-----`：

这种格式表示私钥是按照 PKCS#1 标准编码的。它仅包含用于 RSA 算法的私钥信息，不包含其他元数据。文件的内容是一个以 Base64 编码的 DER（Distinguished Encoding Rules）表示的 ASN.1（Abstract Syntax Notation One）结构。通常，这种私钥格式仅适用于 RSA 密钥。

2. `-----BEGIN PRIVATE KEY-----`：

这种格式表示私钥是按照 PKCS#8 标准编码的。与 PKCS#1 不同，PKCS#8 可以用于多种类型的密钥（如 RSA、DSA、EC），并提供了更通用的编码结构。这种格式的私钥包含关于密钥类型和算法的附加信息。与 PKCS#1 类似，文件的内容也是一个以 Base64 编码的 DER 表示的 ASN.1 结构。

总结一下，`-----BEGIN RSA PRIVATE KEY-----` 是特定于 RSA 的 PKCS#1 格式的私钥，而 `-----BEGIN PRIVATE KEY-----` 是更通用的 PKCS#8 格式的私钥，可用于多种加密算法。尽管两者之间有区别，但在实际使用中，许多加密库和工具都可以处理这两种格式。

## 不使用CA生成证书和各种格式的私钥

### 生成证书和PKCS#1私钥

```bash
# 生成PKCS#1私钥
openssl genrsa -out privkey.pem 4096
# 从私钥生成证书
openssl req -x509 -key privkey.pem -sha256 -nodes -out cert.pem -days 3650 -subj "/C=/ST=/L=/O=/OU=/CN=example.com"
```

### 生成证书和PKCS#8私钥

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -nodes -keyout privkey.pem -out cert.pem -days 3650 -subj "/C=/ST=/L=/O=/OU=/CN=example.com"
```

### 生成证书和PKCS#8私钥，并转换成PKCS#1私钥

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -nodes -keyout temp.pem -out cert.pem -days 3650 -subj "/C=/ST=/L=/O=/OU=/CN=example.com"
## 转换成PKCS#1私钥
openssl rsa -inform PEM -in temp.pem -outform PEM -out privkey.pem
```


## 私钥转换格式的常用命令

```bash
# 转换成PKCS#8
openssl pkcs8 -topk8 -inform PEM -in privkey.pem -out pkcs8_private_key.pem -outform PEM -nocrypt
# 转换成PKCS#1，也称RSA密钥。
openssl rsa -inform PEM -in privkey.pem -outform PEM -out rsa_aes_privkey.pem
```


## openssl s_client

通过 `s_client` 发送http1.1的请求并打印响应。不支持http2的二进制数据

- `-quiet` 表示不打印证书信息
- `-ign_eof` 表示处理半关闭

更多可以看 `man openssl`的 s_client 部分

```bash
(echo -ne "GET /ip HTTP/1.1\r\nConnection: Close\r\n\r\n") |openssl s_client -quiet -ign_eof -alpn http/1.1 -ignore_critical  -connect www.arloor.com:443 2>/dev/null
```

交互式终端：在最后增加 `-crlf` 将换行设置为http协议的 `\r\n`

```bash
openssl s_client -showcerts -ign_eof -alpn http/1.1 -ignore_critical  -connect www.arloor.com:443 -crlf 2>/dev/null
```

试试继续输入`GET / HTTP/1.1`加两个Enter。


## 从pem格式证书和私钥生成pkcs12

surge mac的MitM解析https数据可以导入pkcs12格式的ca证书，这里就转换下

```bash
openssl pkcs12 -export -inkey cakey.pem -in ca.pem -password pass:"123456" -out ca.p12 -name myalias
```

查看：

```bash
openssl pkcs12 -in ca.p12 -password pass:"123456" -info
```