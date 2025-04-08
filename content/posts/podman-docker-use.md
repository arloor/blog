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

- [debian/#install-from-a-package](https://docs.docker.com/engine/install/debian/#install-from-a-package)
- [rhel/#install-using-the-repository](https://docs.docker.com/engine/install/rhel/#install-using-the-repository)
- [#daemon-configuration-file](https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file)
- [HTTP 代理环境变量的大小写说明](https://about.gitlab.com/blog/2021/01/27/we-need-to-talk-no-proxy/)

### debian12 安装 docker

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### centos 9 安装 docker

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

### 设置 docker daemon 代理

这个是用于 pull 镜像时的代理设置。

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo touch /etc/systemd/system/docker.service.d/http-proxy.conf

if ! grep HTTP_PROXY /etc/systemd/system/docker.service.d/http-proxy.conf;
then
cat >> /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:3128/" "HTTPS_PROXY=http://127.0.0.1:3128/" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF
fi

# Flush changes:
sudo systemctl daemon-reload
#Restart Docker:
sudo systemctl restart docker
#Verify that the configuration has been loaded:
sudo systemctl show --property=Environment docker
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

## 删除 podman build 中途退出的中间镜像

https://github.com/containers/podman/issues/7889

```bash
podman ps --all --storage
buildah rm --all
podman rmi -a
```

## 设置 podman CLI 的 HTTP 代理设置

podman 的 build 和 run 都会默认使用 podman 进程的 http 代理环境变量，如果容器不需要的话，可以使用 `--http-proxy=false` 来关闭。

## Podman 使用 systemd 管理容器

### podman generate systemd

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

### qualet 运行

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
            registry:3.0.0-rc.4 /etc/distribution/config.yml
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
