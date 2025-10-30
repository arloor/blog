[![](https://img.shields.io/github/last-commit/arloor/blog.svg?style=flat)](https://github.com/arloor/blog/commit/master)
![](https://img.shields.io/github/languages/code-size/arloor/blog.svg?style=flat)

# 访问[arloor 博客](http://www.arloor.com)

使用 hugo 生成静态博客

## 安装[hugo 0.121.1 extended](https://github.com/gohugoio/hugo/releases/tag/v0.121.1) （需要支持 scss）

```bash
cd /tmp
HUGO_VERSION=$(curl -s https://api.github.com/repos/gohugoio/hugo/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
echo "install hugo extended ${HUGO_VERSION}"
curl https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz -L | tar -zxv
install hugo /usr/local/bin
cd -
```

## 部署

```
git clone https://github.com/arloor/blog
git submodule update --init --recursive
```

没有 submodile 中的主题那么构建出来 public 文件中只有 xml 文件，没有网站 html 文件

## nginx 配置（ubuntu20.04 下）

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

## nginx 配置(rhel8 下)

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

## 查看 nginx 访问日志

基于以上 log_format，提供一个查看本博客访问日志的脚本：

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

## Windows 的特别说明

为了在 vscode 的 markdown 预览中展示图片，本仓库设置了下面的软链接。

```bash
ln -fs static/img img
lrwxr-xr-x  1 arloor  staff  10  5 19 19:31 img -> static/img
```

在 MacOS 和 Linux 上没有任何问题，但是因为 Windows 的快捷方式不同于软链接，所以 Windows 需要做特殊处理。

1. 在管理员权限的终端下进行 clone，因为创建快捷方式需要管理员权限
2. clone 时的命令增加 `-c core.symlinks=true` 选项，这样在 clone 时会将软链接创建快捷方式。

参考文档：[Git 不同平台下软链接问题](https://murphypei.github.io/blog/2021/03/git-symlink)

> 【ChatGPT】我使用 Mac 在 git 仓库中创建了一个软连接，然后 push 到远程仓库了。其他的系统例如 linux、windows git pull 下来时能正常使用这个软连接吗

Git 在各个操作系统中的行为可能会略有不同。在一些情况下，可能会遇到跨平台使用符号链接（软链接）的问题。

1. **在 Linux 上**：Linux 系统中支持软链接，因此如果你在 Mac 上创建的软链接，然后 push 到远程仓库，在 Linux 上应该可以正常使用。

2. **在 Windows 上**：在 Windows 系统中，虽然 Git 支持软链接，但是默认情况下可能不会创建软链接，取而代之的可能是一个文本文件，其内容是链接到的路径。为了在 Windows 上创建软链接，需要有管理员权限，并且 Git 需要在启用了`core.symlinks`选项的情况下运行。但即使如此，Windows 的符号链接机制与 Unix（包括 Mac）系统的机制有所不同，可能并不完全兼容。

请注意，使用软链接可能会引入复杂性，并且可能导致跨平台兼容性问题。如果你的项目需要跨平台，那么可能需要避免使用软链接，或者确保所有用户都理解并可以处理软链接。

> 【ChatGPT】core.symlinks 需要在 mac 上显式指定吗

对于 Unix-based 系统，如 Mac 或 Linux，git 默认会支持软链接（symbolic links），所以在这些系统上你通常不需要显式设置`core.symlinks`。

但是，如果你发现在你的系统上 git 不支持软链接，你可以尝试显式设置这个选项。你可以在你的仓库目录中运行以下命令来启用它：

```
git config core.symlinks true
```

这将会只对当前的仓库设置这个选项。如果你想全局启用这个选项，你可以添加`--global`选项：

```
git config --global core.symlinks true
```

但是在大多数情况下，你在 Mac 上不需要这么做。

## 占位符

1. 图片占位符：

```json
{{< imgx src="/img/xxx.png" alt="" width="700px" style="max-width: 100%;">}}
```

2. bilibili 占位符：

```json
{{< bilibili BV1YK4y1s7ZU >}}
```
