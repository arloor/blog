---
title: "Nginx安装以及反向代理设置(HTTPS)"
date: 2019-08-15T20:38:59+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

试试nginx
<!--more-->


## 添加rpm源安装nginx

```shell
rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum repolist
yum install -y nginx
```

## 生成ssl的证书以及私钥

```shell
cd /etc/nginx/
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout nginx.key -out nginx.crt

req是openssl证书请求的子命令
-newkey rsa:2048 -keyout private_key.pem 表示生成私钥(PKCS8格式)
-nodes 表示私钥不加密，若不带参数将提示输入密码
-x509表示输出证书
-days36500 为100年有效期，此后根据提示输入证书拥有者信息
-keyout 代表私钥全路径
-out 代表证书全路径
```

## 编辑nginx.conf

```shell
# vi /etc/nginx/nginx.conf
worker_processes 1;
events {
    worker_connections 1024;
}
http {
    upstream github {
        ip_hash;
        server github.com:443;
    }

    server {
        listen       443 ssl;
        server_name  localhost;

        ssl_certificate      nginx.crt;
        ssl_certificate_key  nginx.key;

        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;

        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;

        location / {
            root   html;
            index  index.html index.htm;
            proxy_pass https://github;
            proxy_set_header   Host             github.com:443;
        }

    }
server {
    listen       80;
    server_name  localhost;
    # 返回301状态码，永久重定向
    rewrite ^(.*)$  https://$host$1 permanent;
}
}
```

以上配置就完成了80、443端口到github的反向代理。

## 启动nginx

```shell
service nginx start
```