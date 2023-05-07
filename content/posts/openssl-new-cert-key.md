---
title: "Openssl新建证书和密钥，及密钥格式"
date: 2023-05-07T15:31:41+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

在 OpenSSL 和其他加密库中，您可能会遇到两种格式的私钥：`-----BEGIN RSA PRIVATE KEY-----` 和 `-----BEGIN PRIVATE KEY-----`。这两种格式的主要区别在于它们的编码方式和包含的信息。

1. `-----BEGIN RSA PRIVATE KEY-----`：

这种格式表示私钥是按照 PKCS#1 标准编码的。它仅包含用于 RSA 算法的私钥信息，不包含其他元数据。文件的内容是一个以 Base64 编码的 DER（Distinguished Encoding Rules）表示的 ASN.1（Abstract Syntax Notation One）结构。通常，这种私钥格式仅适用于 RSA 密钥。

2. `-----BEGIN PRIVATE KEY-----`：

这种格式表示私钥是按照 PKCS#8 标准编码的。与 PKCS#1 不同，PKCS#8 可以用于多种类型的密钥（如 RSA、DSA、EC），并提供了更通用的编码结构。这种格式的私钥包含关于密钥类型和算法的附加信息。与 PKCS#1 类似，文件的内容也是一个以 Base64 编码的 DER 表示的 ASN.1 结构。

总结一下，`-----BEGIN RSA PRIVATE KEY-----` 是特定于 RSA 的 PKCS#1 格式的私钥，而 `-----BEGIN PRIVATE KEY-----` 是更通用的 PKCS#8 格式的私钥，可用于多种加密算法。尽管两者之间有区别，但在实际使用中，许多加密库和工具都可以处理这两种格式。

## 生成证书和私钥

### 生成证书和PKCS#1私钥

```shell
# 生成PKCS#1私钥
openssl genrsa -out privkey.pem 4096
# 从私钥生成证书
openssl req -x509 -key privkey.pem -sha256 -nodes -out cert.pem -days 3650 -subj "/C=/ST=/L=/O=/OU=/CN=example.com"
```

### 生成证书和PKCS#8私钥

```shell
openssl req -x509 -newkey rsa:4096 -sha256 -nodes -keyout privkey.pem -out cert.pem -days 3650 -subj "/C=/ST=/L=/O=/OU=/CN=example.com"
```

### 生成证书和PKCS#8私钥，并转换成PKCS#1私钥

```shell
openssl req -x509 -newkey rsa:4096 -sha256 -nodes -keyout temp.pem -out cert.pem -days 3650 -subj "/C=/ST=/L=/O=/OU=/CN=example.com"
## 转换成PKCS#1私钥
openssl rsa -inform PEM -in temp.pem -outform PEM -out privkey.pem
```


## 私钥转换格式的常用命令

```shell
# 转换成PKCS#8
openssl pkcs8 -topk8 -inform PEM -in privkey.pem -out pkcs8_private_key.pem -outform PEM -nocrypt
# 转换成PKCS#8，也称RSA密钥。
openssl rsa -inform PEM -in privkey.pem -outform PEM -out rsa_aes_privkey.pem
```

```shell
scp root@dc9.arloor.dev:/root/.acme.sh/arloor.dev/arloor.dev.key ./privkey.pem
scp root@dc9.arloor.dev:/root/.acme.sh/arloor.dev/fullchain.cer ./cert.pem
```