---
title: "Nginx安装使用：webserver及反向代理"
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


## centos7添加rpm源安装nginx

> centos8直接yum安装即可

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
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    # 默认80网站
    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        # 博客路径
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        # 上传文件的路径
        # /upload 映射到http://{$upload}/  注意url末尾的“/”加或不加会有区别
        location /upload {
            root   html;
            index  index.html index.htm;
            proxy_pass http://upload/;
        }

        # 上传文件的路径
        # /uploadfile 映射到http://{$upload}/uploadfile 注意url末尾的“/”加或不加会有区别
        location /uploadfile {
            root   html;
            index  index.html index.htm;
            proxy_pass http://upload/uploadfile;
        } 


        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }

    # Settings for a TLS enabled server.

    server {
        listen       443 ssl http2 default_server;
        listen       [::]:443 ssl http2 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        ssl_certificate "1_arloor.com_bundle.crt";
        ssl_certificate_key "2_arloor.com.key";
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_ciphers PROFILE=SYSTEM;
        ssl_prefer_server_ciphers on;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }


    server {
        listen       80;
        server_name  arloor.com;
        # 返回301状态码，永久重定向
        rewrite ^(.*)$  https://$host$1 permanent;
    }

    # 用于上传文件
    upstream upload {
        ip_hash;
        server localhost:8080;
    }

    server {
        listen       80;
        server_name  file.arloor.com moontell.cn;


        location / {
            root   html;
            index  index.html index.htm;
            client_max_body_size 0;
            proxy_pass http://upload;
            # 因为是本地服务，还是要把IP等信息传过去的（不需要高匿，反而需要客户的真实信息）
            proxy_set_header    Host             $host;#保留代理之前的host
            proxy_set_header    X-Real-IP        $remote_addr;#保留代理之前的真实客户端ip
            proxy_set_header    X-Forwarded-For  $proxy_add_x_forwarded_for;
            proxy_set_header    HTTP_X_FORWARDED_FOR $remote_addr;#在多级代理的情况下，记录每次代理之前的客户端真实ip
            proxy_redirect      default;#指定修改被代理服务器返回的响应头中的location头域跟refresh头域数值
        }
    }
    # 用于上传文件结束

    # github反代开始
    upstream github {
        ip_hash;
        server github.com:443;
    }

    server {
        listen       443 ssl;
        server_name  git.arloor.com;

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
        server_name  git.arloor.com;
        # 返回301状态码，永久重定向
        rewrite ^(.*)$  https://$host$1 permanent;
    }
    # github反代结束
}
```

以上配置就完成了80、443端口到github的反向代理。

## 启动nginx

```shell
service nginx start
```