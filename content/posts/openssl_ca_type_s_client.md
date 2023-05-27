---
title: "Openssl使用：自定义CA签发证书、私钥格式、s_client使用"
date: 2023-05-11T11:35:02+08:00
draft: false
categories: [ "undefined"]
tags: ["notion"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

# 使用自定义CA签发SSL证书

## 签发CA并使用CA签发SSL证书

1. 在 `~/ca` 创建CA证书和私钥，私钥为 `cakey.pem` ，公钥为 `ca.pem` 。 `ca.pem` 后续将被安装到系统并信任。
2. 在 `~/ca/certs` 创建自定义SSL证书，私钥为 `privkey.pem` ，公钥为 `cert.pem`。他们将被用于启动https服务。

```bash
[ ! -d ~/ca ] &&{
    mkdir ~/ca
}
cd ~/ca
[ ! -f cakey.pem -o ! -f ca.pem ]&&{
  if [ -f cakey.pem ]; then
    rm -f cakey.pem
  fi
  if [ -f ca.pem ]; then
      rm -f ca.pem
  fi
cat > openssl.conf <<\EOF
[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName_min                 = 0
stateOrProvinceName_min         = 0
localityName_min                = 0
organizationName_min            = 0
organizationalUnitName_min      = 0
commonName                      = Common Name
emailAddress_min                = 0

[ v3_ca ]
# Extensions for a typical CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

# 使用liuganghuan.com创建SSL证书，作为CA
openssl req -config ~/ca/openssl.conf -x509 -newkey rsa:4096 -sha256 -nodes -keyout temp.pem -extensions v3_ca -out ca.pem -days 36500 -subj "/CN=liuganghuan"
openssl rsa -inform PEM -in temp.pem -outform PEM -out cakey.pem
openssl x509 -in ca.pem -noout -text
echo 
echo -e "\033[32mnew ca.pem generated! please install ~/ca/ca.pem !!!\033[0m"
echo -e "\033[32m================================\033[0m"
}

[ ! -d ~/ca/certs ] &&{
    mkdir ~/ca/certs
}
cd ~/ca/certs
# 使用CA给arloor.com颁发证书
openssl genrsa -out privkey.pem 2048
openssl req -new -key privkey.pem -out localhost.csr -subj "/CN=arloor.com"
# 设置证书的使用范围
cat > cert.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.2 = 127.0.0.1
DNS.3 = arloor.com
DNS.4 = *.arloor.com
DNS.5 = arloor.dev
DNS.6 = *.arloor.dev
EOF

openssl x509 -req -in localhost.csr -out cert.pem -days 36500 \
  -CAcreateserial -CA ../ca.pem -CAkey ../cakey.pem \
  -CAserial serial -extfile cert.ext

openssl x509 -in cert.pem -noout -text
openssl verify -CAfile ~/ca/ca.pem cert.pem
cat ~/ca/ca.pem >> cert.pem
```

## Mac下安装自定义CA证书

使用访达打开 `~/ca` 双击 `ca.pem` ，会打开“钥匙串访问”，将其安装到“系统”级别的“证书”下。

如果没有弹出安装CA证书的提示，也可以拖动`ca.pem` 到“系统”级别的“证书”的空白部分。

最后设置信任该自定义CA证书。

![40b3dc93b8c02c2b48dff3d526f8b873.png](/img/40b3dc93b8c02c2b48dff3d526f8b873.png)

![fac03ac28e578a2a458b150fef497290.png](/img/fac03ac28e578a2a458b150fef497290.png)

![8d7b336fd9e376eb116acb1e7d93d69a.png](/img/8d7b336fd9e376eb116acb1e7d93d69a.png)

## 参考文档

[CA & OpenSSL自签名证书](https://juejin.cn/post/7092789498823573518#heading-20)

在 OpenSSL 和其他加密库中，您可能会遇到两种格式的私钥：`-----BEGIN RSA PRIVATE KEY-----` 和 `-----BEGIN PRIVATE KEY-----`。这两种格式的主要区别在于它们的编码方式和包含的信息。

1. `-----BEGIN RSA PRIVATE KEY-----`：

这种格式表示私钥是按照 PKCS#1 标准编码的。它仅包含用于 RSA 算法的私钥信息，不包含其他元数据。文件的内容是一个以 Base64 编码的 DER（Distinguished Encoding Rules）表示的 ASN.1（Abstract Syntax Notation One）结构。通常，这种私钥格式仅适用于 RSA 密钥。

2. `-----BEGIN PRIVATE KEY-----`：

这种格式表示私钥是按照 PKCS#8 标准编码的。与 PKCS#1 不同，PKCS#8 可以用于多种类型的密钥（如 RSA、DSA、EC），并提供了更通用的编码结构。这种格式的私钥包含关于密钥类型和算法的附加信息。与 PKCS#1 类似，文件的内容也是一个以 Base64 编码的 DER 表示的 ASN.1 结构。

总结一下，`-----BEGIN RSA PRIVATE KEY-----` 是特定于 RSA 的 PKCS#1 格式的私钥，而 `-----BEGIN PRIVATE KEY-----` 是更通用的 PKCS#8 格式的私钥，可用于多种加密算法。尽管两者之间有区别，但在实际使用中，许多加密库和工具都可以处理这两种格式。

## 不使用CA生成证书和各种格式的私钥

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


## openssl s_client

通过 `s_client` 发送http1.1的请求并打印响应。不支持http2的二进制数据

- `-quiet` 表示不打印证书信息
- `-ign_eof` 表示处理半关闭

更多可以看 `man openssl`的 s_client 部分

```shell
(echo -ne "GET /ip HTTP/1.1\r\nConnection: Close\r\n\r\n") |openssl s_client -quiet -ign_eof -alpn http/1.1 -ignore_critical  -connect www.arloor.com:443 2>/dev/null
```

交互式终端：在最后增加 `-crlf` 将换行设置为http协议的 `\r\n`

```shell
openssl s_client -showcerts -ign_eof -alpn http/1.1 -ignore_critical  -connect www.arloor.com:443 -crlf 2>/dev/null
```

试试继续输入`GET / HTTP/1.1`加两个Enter。

