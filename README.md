[![](https://img.shields.io/github/last-commit/arloor/blog.svg?style=flat)](https://github.com/arloor/blog/commit/master)
![](https://img.shields.io/github/languages/code-size/arloor/blog.svg?style=flat)

# 访问[arloor博客](http://www.arloor.com)
使用hugo生成静态博客

## 安装[hugo 0.96.0 extended](https://github.com/gohugoio/hugo/releases/tag/v0.96.0) （需要支持 scss）

## 部署

```
wget -O /usr/local/bin/tarloor http://www.arloor.com/tarloor.sh
bash tarloor
```

## nginx配置（ubuntu下）

```shell
cat > /etc/nginx/sites-enabled/default <<\EOF
server {
    listen 80 default_server;                   
    listen [::]:80 default_server;               
    server_name          www.arloor.com;
    return               301 https://$host$request_uri;
}

server {
    listen               443 ssl default_server;
    listen               [::]:443 ssl default_server;

    root /opt/proxy;
    index index.html index.htm index.nginx-debian.html;
    server_name          www.arloor.com;

    ssl_certificate      /opt/proxy/fullchain;
    ssl_certificate_key  /opt/proxy/private.key;
    error_page 404 /404.html;
    location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ =404;
    }
}
EOF
service nginx restart
```
