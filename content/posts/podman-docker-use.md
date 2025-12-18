---
title: "Podman和Docker使用备忘"
subtitle:
tags:
  - undefined
date: 2025-04-08T10:53:42+08:00
lastmod: 2025-04-08T10:53:42+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
---

<!--more-->

## Docker

- [debian/#install-using-the-repository](https://docs.docker.com/engine/install/debian/#install-using-the-repository)
- [rhel/#install-using-the-repository](https://docs.docker.com/engine/install/rhel/#install-using-the-repository)
- [#daemon-configuration-file](https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file)
- [HTTP 代理环境变量的大小写说明](https://about.gitlab.com/blog/2021/01/27/we-need-to-talk-no-proxy/)

### debian12 安装 docker

```bash
# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### debian13 安装 docker

> 相比 Debian12 的区别仅是使用 DEB822 格式的 sources.list 文件

```bash
# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### centos 9 安装 docker

```bash
dnf -y install dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

### 设置 docker daemon 代理

这个是用于 pull 镜像时的代理设置。

```bash
mkdir -p /etc/systemd/system/docker.service.d
touch /etc/systemd/system/docker.service.d/http-proxy.conf

if ! grep HTTP_PROXY /etc/systemd/system/docker.service.d/http-proxy.conf;
then
cat >> /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:3128/" "HTTPS_PROXY=http://127.0.0.1:3128/" "NO_PROXY=arloor.com,localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF
fi

# Flush changes:
systemctl daemon-reload
#Restart Docker:
systemctl restart docker
#Verify that the configuration has been loaded:
systemctl show --property=Environment docker
# 像这样：Environment=HTTP_PROXY=http://127.0.0.1:8081/ NO_PROXY=localhost,127.0.0.1,docker-registry.so
```

或者：

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json  <<EOF
{
    "proxies": {
        "http-proxy": "http://127.0.0.1:3128",
        "https-proxy": "http://127.0.0.1:3128",
        "no-proxy": "*.arloor.com,.example.org,127.0.0.0/8,localhost,127.0.0.1,docker-registry.somecorporation.com"
    }
}
EOF
systemctl restart docker
```

### 设置 docker CLI 的 HTTP 代理

这个是用于 build 和 run 时的代理设置。详见：[Use a proxy server with the Docker CLI](https://docs.docker.com/engine/cli/proxy/)

#### 全局设置

> 注意，这个配置文件中还有其他的配置，例如 docker registry 的账户密码，不建议直接覆盖。

```bash
mkdir -p ~/.docker
cat > ~/.docker/config.json <<EOF
{
 "proxies": {
   "default": {
     "httpProxy": "http://127.0.0.1:3128",
     "httpsProxy": "http://127.0.0.1:3128",
     "noProxy": "*.arloor.com,.example.org,127.0.0.0/8,localhost,127.0.0.1,docker-registry.somecorporation.com"
   }
 }
}
EOF
```

#### 单次设置

```bash
# build
docker build --build-arg HTTP_PROXY="http://proxy.example.com:3128" . --network=host
# run
docker run --env HTTP_PROXY="http://proxy.example.com:3128" redis --network=host
```

## Podman

- [man podman-run](https://docs.podman.io/en/latest/markdown/podman-run.1.html)
- [man podman-build](https://docs.podman.io/en/stable/markdown/podman-build.1.html)

### 删除 podman build 中途退出的中间镜像

https://github.com/containers/podman/issues/7889

```bash
podman ps --all --storage
buildah rm --all
podman rmi -a
```

### 设置 podman CLI 的 HTTP 代理设置

podman 的 build 和 run 都会默认使用 podman 进程的 http 代理环境变量，如果容器不需要的话，可以使用 `--http-proxy=false` 来关闭。

### Podman 使用 systemd 管理容器

#### podman generate systemd

参考 `man podman-generate-systemd` 或 [podman-generate-systemd(1)](https://docs.podman.io/en/latest/markdown/podman-generate-systemd.1.html)

```bash
podman run -d \
--pull=newer \
--name redis \
--network host \
--replace \
--rm \
redis

podman generate systemd --new --name redis --env=HTTP_PROXY --env=HTTPS_PROXY| tee /lib/systemd/system/redis.service
systemctl daemon-reload
# systemctl enable redis --now
```

其中 podman run 的 `--rm` 和 podman generate systemd 的`--new` 含义都是停止容器时删除容器，下次全新创建。所以 --rm 和 --new 要么同时出现，要么同时缺失。

其中 `--pull=newer` 表示每次都 pull 镜像，这在使用 `latest` 镜像时很有用

#### qualet 运行

参考[podman-systemd.unit.5](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)或者 `man podman-systemd.unit`

```bash
cat > /tmp/proxy.container <<'EOF'
[Unit]
Wants=network-online.target
After=network-online.target
[Container]
Image=docker.io/arloor/rust_http_proxy:bpf
ContainerName=proxy
Pull=newer
PodmanArgs=--privileged
Volume=/tmp:/tmp
Volume=/root/.acme.sh:/root/.acme.sh
Volume=/usr/share/nginx/html:/usr/share/nginx/html
Network=host
Exec=-p 444 -p 443 -p 9443 \
-w /usr/share/nginx/html/blog \
-r arloor \
--never-ask-for-auth
[Service]
Environment=HTTPS_PROXY=http://127.0.0.1:3128
Environment=HTTP_PROXY=http://127.0.0.1:3128
Restart=on-failure
TimeoutStopSec=70
[Install]
WantedBy=default.target
EOF

QUADLET_UNIT_DIRS=/tmp /usr/libexec/podman/quadlet -dryrun #测试
mkdir -p /etc/containers/systemd;mv /tmp/proxy.container /etc/containers/systemd/proxy.container

rm -f /lib/systemd/system/proxy.service
systemctl daemon-reload
systemctl restart proxy
```

生成在 `/run/systemd/generator/proxy.service®`

## Docker Hub pull-through cache

https://distribution.github.io/distribution/about/configuration/ 注意 `Registry:2` 已经不维护的，并且有明显 bug，推荐使用 `Registry:3`

1. 启动 `Registry:3`

```bash
mkdir -p /etc/distribution
cat > /etc/distribution/config.yml <<EOF
version: 0.1
log:
  level: info
http:
  addr: :6666
  debug:
    addr: :3001
    prometheus:
      enabled: true
proxy:
  remoteurl: https://registry-1.docker.io
  username: ${your_docker_hub_username}
  password: ${your_docker_hub_token}
  ttl: 1h
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
EOF
docker stop registry&&docker rm registry
docker run -d --restart=always --network host --name registry \
            -e http_proxy="http://localhost:3128" -e https_proxy="http://localhost:3128" \
            -e HTTP_PROXY="http://localhost:3128" -e HTTPS_PROXY="http://localhost:3128" \
            -v /etc/distribution/config.yml:/etc/distribution/config.yml \
            registry:3 /etc/distribution/config.yml
docker logs -f registry
```

2. 配置 docker daemon

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json  <<EOF
{
    "registry-mirrors": ["http://ttl.arloor.com:6666"]
}
EOF
systemctl restart docker
```

3. 配置 podman

```bash
mkdir -p $HOME/.config/containers
cat > $HOME/.config/containers/registries.conf<<EOF
unqualified-search-registries = ["docker.io"]

[[registry]]
location = "docker.io"

[[registry.mirror]]
location = "ttl.arloor.com:6666"  # 你的镜像加速地址
insecure = true  # 如果镜像站使用HTTP而非HTTPS，设为true
EOF
```

## podman 保存密码

```bash
podman login quay.io -u arloor -p ${token}
cat /run/user/0/containers/auth.json #密码在此
cp /run/user/0/containers/auth.json ~/.config/podman_auth.json
if ! grep REGISTRY_AUTH_FILE ~/.zshrc;then
 export REGISTRY_AUTH_FILE=~/.config/podman_auth.json
 echo "export REGISTRY_AUTH_FILE=~/.config/podman_auth.json" >> ~/.zshrc
 echo " add REGISTRY_AUTH_FILE to ~/.zshrc"
else
 echo "REGISTRY_AUTH_FILE already exists in ~/.zshrc"
fi
```

[why login registry auth.json always been cleared?](https://github.com/containers/podman/discussions/9454)：默认保存在 `/run/user/0` 下，在用户 log out 的时候会被清空。如果需要持久化保存，可以将其复制到其他位置，并设置环境变量 `REGISTRY_AUTH_FILE` 指向该文件或使用 `--authfile` 命令行参数。
