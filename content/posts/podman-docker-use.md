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

### 设置 registry mirrors 加速镜像

```bash
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["http://ttl.arloor.com:6666"]
}
EOF
sudo systemctl restart docker
```

### 设置 docker CLI 的 HTTP 代理

这个是用于 build 和 run 时的代理设置。详见：[Use a proxy server with the Docker CLI](https://docs.docker.com/engine/cli/proxy/)

#### 全局设置

> 注意，这个配置文件中还有其他的配置，例如 docker registry 的账户密码，建议不要直接覆盖。

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
docker build --build-arg HTTP_PROXY="http://proxy.example.com:3128" .
# run
docker run --env HTTP_PROXY="http://proxy.example.com:3128" redis
```