[![](https://img.shields.io/github/last-commit/arloor/blog.svg?style=flat)](https://github.com/arloor/blog/commit/master)
![](https://img.shields.io/github/languages/code-size/arloor/blog.svg?style=flat)

# 访问[arloor博客](http://www.arloor.com)
使用hugo生成静态博客

## 安装[hugo 0.96.0 extended](https://github.com/gohugoio/hugo/releases/tag/v0.96.0) （需要支持 scss）

## 部署

```
## 支持centos8和ubuntu20.04
wget -O /usr/local/bin/tarloor http://www.arloor.com/tarloor.sh
bash tarloor
```

## nginx配置（ubuntu20.04下）

```bash
cat > /etc/nginx/sites-enabled/default <<\EOF
log_format  arloor  '$remote_addr # [$time_iso8601] # "$request_uri" # '
                    '$status # '
                    '"$http_user_agent" # "$request_time" # "$http_referer"';

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name          www.arloor.com arloor.com;
    return               301 https://$host$request_uri;
}

server {
    listen               443 ssl http2;
    listen               [::]:443 ssl http2;
    server_name          arloor.com;
    return               301 https://www.arloor.com$request_uri;
}

server {
    listen               443 ssl http2 default_server;
    listen               [::]:443 ssl http2 default_server;

    root /usr/share/nginx/html/blog;
    index index.html index.htm index.nginx-debian.html;
    access_log /var/log/nginx/arloor.access.log arloor;
    server_name          www.arloor.com;

    ssl_certificate      /root/.acme.sh/arloor.dev/fullchain.cer;
    ssl_certificate_key  /root/.acme.sh/arloor.dev/arloor.dev.key;
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

## nginx配置(rhel8下)

```bash
cat > /etc/nginx/conf.d/arloor.conf <<\EOF
log_format  arloor  '$remote_addr # [$time_iso8601] # "$request_uri" # '
                    '$status # '
                    '"$http_user_agent" # "$request_time" # "$http_referer"';

server {
    listen 80;
    listen [::]:80;
    server_name          www.arloor.com arloor.com;
    return               301 https://$host$request_uri;
}

server {
    listen               443 ssl http2;
    listen               [::]:443 ssl http2;
    server_name          arloor.com;
    return               301 https://www.arloor.com$request_uri;
}

server {
    listen               443 ssl http2 default_server;
    listen               [::]:443 ssl http2 default_server;

    root /usr/share/nginx/html/blog;
    index index.html index.htm index.nginx-debian.html;
    access_log /var/log/nginx/arloor.access.log arloor;
    server_name          www.arloor.com;

    ssl_certificate      /root/.acme.sh/arloor.dev/fullchain.cer;
    ssl_certificate_key  /root/.acme.sh/arloor.dev/arloor.dev.key;
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

## 查看nginx访问日志

基于以上log_format，提供一个查看本博客访问日志的脚本：

```bash
cat >/usr/local/bin/arloor <<\EOF
tail -n 10000 `ls -ltc /var/log/nginx/arloor.access.log*|head -n 1|awk '{print $9}'`|awk -F" # " '$3~"(.*post.*|.*about.*|.*page.*|.*tags.*|^\"/\"$)" && $4==200 {printf("%s %15s %-30s %s\n",$2,$1,$3,$5)}'
EOF
chmod +x /usr/local/bin/arloor
arloor
```

效果如下：

```bash
112.2.xxx.xxx   [2022-05-09T11:02:26+08:00] "/about/"
223.70.xxx.x    [2022-05-09T11:02:46+08:00] "/posts/redis/redis-cluster/"
14.25.xxx.xxx   [2022-05-09T11:03:45+08:00] "/posts/i-was-young/"
113.89.xx.xx    [2022-05-09T11:03:58+08:00] "/posts/shell-tricks/"
110.53.xx.xx    [2022-05-09T11:04:01+08:00] "/posts/shell-tricks/"
```

## Windows的特别说明

为了在vscode的markdown预览中展示图片，本仓库设置了下面的软链接。

```bash
lrwxr-xr-x  1 arloor  staff  10  5 19 19:31 img -> static/img
```

在MacOS和Linux上没有任何问题，但是因为Windows的快捷方式不同于软链接，所以Windows需要做特殊处理。

1. 在管理员权限的终端下进行clone，因为创建快捷方式需要管理员权限
2. clone时的命令增加 `-c core.symlinks=true` 选项，这样在clone时会将软链接创建快捷方式。

参考文档：[Git 不同平台下软链接问题](https://murphypei.github.io/blog/2021/03/git-symlink)

> 【ChatGPT】我使用Mac在git仓库中创建了一个软连接，然后push到远程仓库了。其他的系统例如linux、windows git pull下来时能正常使用这个软连接吗

Git在各个操作系统中的行为可能会略有不同。在一些情况下，可能会遇到跨平台使用符号链接（软链接）的问题。

1. **在Linux上**：Linux系统中支持软链接，因此如果你在Mac上创建的软链接，然后push到远程仓库，在Linux上应该可以正常使用。

2. **在Windows上**：在Windows系统中，虽然Git支持软链接，但是默认情况下可能不会创建软链接，取而代之的可能是一个文本文件，其内容是链接到的路径。为了在Windows上创建软链接，需要有管理员权限，并且Git需要在启用了`core.symlinks`选项的情况下运行。但即使如此，Windows的符号链接机制与Unix（包括Mac）系统的机制有所不同，可能并不完全兼容。

请注意，使用软链接可能会引入复杂性，并且可能导致跨平台兼容性问题。如果你的项目需要跨平台，那么可能需要避免使用软链接，或者确保所有用户都理解并可以处理软链接。

> 【ChatGPT】core.symlinks需要在mac上显式指定吗

对于Unix-based系统，如Mac或Linux，git默认会支持软链接（symbolic links），所以在这些系统上你通常不需要显式设置`core.symlinks`。

但是，如果你发现在你的系统上git不支持软链接，你可以尝试显式设置这个选项。你可以在你的仓库目录中运行以下命令来启用它：

```
git config core.symlinks true
```

这将会只对当前的仓库设置这个选项。如果你想全局启用这个选项，你可以添加`--global`选项：

```
git config --global core.symlinks true
```

但是在大多数情况下，你在Mac上不需要这么做。