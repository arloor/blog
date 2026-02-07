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
- [docker-ce 火山引擎镜像](https://developer.volcengine.com/articles/7132008672707739662)

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

### Dockerfile 规范和常见范式

#### 通用规范

1. 固定 Dockerfile 语法版本，启用 BuildKit 新能力。
2. 基础镜像尽量固定到小版本，生产环境建议再加 digest（防止上游 tag 漂移）。
3. 优先使用多阶段构建（builder/runtime 分离），减小最终镜像体积和攻击面。
4. 优化缓存命中：先 `COPY` 依赖描述文件，再安装依赖，最后 `COPY` 业务代码。
5. 包管理器操作要“同层完成并清理”：
   - Debian/Ubuntu：`apt-get update && apt-get install ... && rm -rf /var/lib/apt/lists/*`
6. 默认使用非 root 用户运行应用。
7. `ENTRYPOINT`/`CMD` 使用 JSON 格式（exec form），避免 shell 包裹导致信号处理异常。
8. 区分 `ARG` 和 `ENV`：`ARG` 只在构建期有效，`ENV` 会进入运行时环境。
9. 敏感信息不要写进镜像层，使用 BuildKit secret mount。
10. 配置 `.dockerignore`，避免把 `.git`、日志、构建产物打进 build context。

#### 指令详解（ARG/ENV/COPY/ADD/VOLUME/WORKDIR）

| 指令 | 作用 | 生效范围 / 时机 | 常见写法 | 注意事项（常见坑） |
|---|---|---|---|---|
| `ARG` | 声明构建参数，用于镜像构建时动态传参 | 仅构建期有效；不会自动进入容器运行时环境 | `ARG APP_VER=1.2.3`<br>`FROM node:${NODE_VER}`<br>`docker build --build-arg APP_VER=2.0 .` | 1) `FROM` 前定义的 `ARG` 仅能用于 `FROM` 行；若后续指令还要用，需要在阶段内再声明一次。<br>2) 不要传密钥，`ARG` 可能出现在构建历史/元数据中。 |
| `ENV` | 设置环境变量，供后续构建步骤和容器运行时使用 | 当前阶段后续指令可见；并写入镜像配置，容器启动后默认存在 | `ENV APP_ENV=prod`<br>`ENV PATH=/app/bin:$PATH` | 1) 会进入最终镜像，避免放敏感信息。<br>2) `ENV` 可覆盖同名 `ARG` 在后续步骤中的效果。 |
| `COPY` | 将本地构建上下文文件（或其他阶段产物）复制进镜像 | 构建期执行，产生新层 | `COPY . /app`<br>`COPY --from=build /out/app /usr/local/bin/app`<br>`COPY --chown=10001:10001 . /app` | 1) 只复制 build context 内文件，不能 `../` 越界。<br>2) 优先于 `ADD` 使用，行为更可预测。<br>3) 先复制依赖文件再安装依赖，可提升缓存命中。 |
| `ADD` | 类似 `COPY`，但支持额外能力（本地 tar 自动解包、URL 源） | 构建期执行，产生新层 | `ADD app.tar.gz /opt/app/`<br>`ADD https://example.com/a.tgz /tmp/` | 1) 除非你明确需要“自动解包/远程 URL”，否则用 `COPY`。<br>2) URL 下载会引入额外不确定性，通常建议改为 `RUN curl/wget` 并做校验。 |
| `VOLUME` | 声明容器运行时挂载点（数据卷） | 主要影响运行时；镜像中记录为元数据 | `VOLUME ["/var/lib/mysql"]`<br>`VOLUME /data` | 1) 更推荐在编排层（Compose/K8s）声明挂载，Dockerfile 里慎用。<br>2) 该路径在运行时会被卷接管，若依赖镜像内后续写入该目录，行为易混淆。 |
| `WORKDIR` | 设置后续指令默认工作目录 | 对后续 `RUN/CMD/ENTRYPOINT/COPY/ADD` 生效 | `WORKDIR /app`<br>`WORKDIR /app/bin` | 1) 目录不存在会自动创建。<br>2) 相对路径会基于上一个 `WORKDIR` 叠加，建议尽量用绝对路径降低歧义。 |

> 速记：可预测复制用 `COPY`，特殊场景（解包/URL）才用 `ADD`；构建参数用 `ARG`，运行时变量用 `ENV`。

#### 常用骨架（Debian 系）

```dockerfile
# syntax=docker/dockerfile:1.7
FROM debian:12.9-slim

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY . /app
```

#### 范式 1：Go 多阶段构建（推荐）

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.24-bookworm AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

#### 范式 2：Node.js 生产镜像（依赖和运行时分层）

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:22-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

FROM node:22-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps /app/node_modules /app/node_modules
COPY . .

RUN useradd -r -u 10001 nodeapp && chown -R nodeapp:nodeapp /app
USER nodeapp

EXPOSE 3000
CMD ["node", "server.js"]
```

#### 常用检查命令

```bash
# lint Dockerfile
docker run --rm -i hadolint/hadolint < Dockerfile

# 使用 BuildKit 构建
DOCKER_BUILDKIT=1 docker build -t myapp:dev .

# 构建时挂载 secret（示例：npm 私有源）
DOCKER_BUILDKIT=1 docker build \
  --secret id=npmrc,src=$HOME/.npmrc \
  -t myapp:dev .
```

### BuildKit：原理、作用和使用

#### BuildKit 是什么

BuildKit 是 Docker 新一代构建引擎（旧引擎一般称为 legacy builder）。  
核心目标是：更快、更可复用、更安全、更适合多平台和 CI/CD 分布式构建。

#### 工作原理（从 Dockerfile 到镜像）

```text
Dockerfile
  -> Frontend 解析（dockerfile frontend）
  -> LLB（Low-Level Build）有向无环图 DAG
  -> Solver 计算依赖、并行调度、命中缓存
  -> Worker 执行具体步骤（snapshot/content store）
  -> Exporter 输出结果（image/registry/local/tar/oci）
```

1. Frontend 阶段：把 Dockerfile 转成 LLB。  
   LLB 是 BuildKit 的中间表示，天然支持“图”而不是简单线性流水。
2. Solver 阶段：基于 LLB 解析依赖关系，构建执行计划。  
   可以并行执行互不依赖的步骤，也可以跳过未被引用的 stage。
3. Worker 阶段：执行 `RUN/COPY` 等操作并生成快照（snapshot）。  
   每一步输入（命令、文件哈希、构建参数、挂载）都会参与 cache key 计算。
4. Export 阶段：把结果导出为镜像或者文件系统。  
   除了常规镜像，还支持 `local/tar/oci` 等输出方式。

#### 缓存机制（BuildKit 的核心价值）

1. 指令缓存：命令和输入不变时复用层。
2. 内容寻址：基于内容哈希判断是否可复用，避免“仅时间戳变化导致全失效”。
3. 远程缓存：支持把缓存导出到 registry/local，再在其他机器导入。
4. 挂载缓存：`RUN --mount=type=cache` 为包管理器缓存目录，减少重复下载。
5. 增量上下文：只传需要的 build context 内容，减少构建 IO。

#### BuildKit 的主要作用

| 能力 | 具体收益 | 典型场景 |
|---|---|---|
| 并行与 DAG 调度 | 构建更快，尤其多阶段和大仓库 | CI 构建耗时优化 |
| 更强缓存 | 更高命中率，跨机器复用缓存 | 自建 CI、频繁重建 |
| 安全挂载 | 构建期 secret/ssh 不落镜像层 | 私有依赖、私有 git |
| 多平台构建 | 一次构建 `amd64/arm64` | 发布多架构镜像 |
| 灵活导出 | 输出镜像、OCI、本地产物 | 二进制产物提取 |

#### 如何启用 BuildKit

> 新版本 Docker 通常默认启用；不同发行版可能有差异，建议显式指定。

```bash
# 一次性启用（最稳妥）
DOCKER_BUILDKIT=1 docker build -t myapp:dev .

# 查看 buildx（buildx 是 BuildKit 的常用入口）
docker buildx version
docker buildx ls
```

可选（daemon 级开启）：

```json
{
  "features": {
    "buildkit": true
  }
}
```

对应文件一般是 `/etc/docker/daemon.json`，修改后重启 Docker。

#### 常用用法

1. 指定语法版本（建议加在 Dockerfile 首行）：

```dockerfile
# syntax=docker/dockerfile:1.7
```

2. cache mount（包管理器缓存）：

```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

3. secret mount（不写入镜像层）：

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=npmrc,src=$HOME/.npmrc \
  -t myapp:dev .
```

```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

4. ssh mount（拉私有 git 依赖）：

```bash
DOCKER_BUILDKIT=1 docker build --ssh default -t myapp:dev .
```

```dockerfile
RUN --mount=type=ssh git clone git@github.com:your/private-repo.git
```

5. 导出/导入 registry 缓存（CI 非常实用）：

```bash
docker buildx build \
  --cache-from=type=registry,ref=registry.example.com/ns/myapp:buildcache \
  --cache-to=type=registry,ref=registry.example.com/ns/myapp:buildcache,mode=max \
  -t registry.example.com/ns/myapp:latest \
  --push .
```

6. 多平台构建：

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t registry.example.com/ns/myapp:latest \
  --push .
```

#### BuildKit 使用建议

1. Dockerfile 首行固定 `# syntax=docker/dockerfile:1.x`，避免环境差异。
2. 依赖描述文件单独 `COPY`，保证缓存可复用。
3. secret/ssh 一律走 mount，不要用 `ARG/ENV` 传密钥。
4. CI 中优先配 registry cache，收益通常明显。
5. 排查缓存问题时加 `--progress=plain` 看详细日志。

#### 常见误区

1. 以为 `ARG` 适合传密钥：不合适，可能被元数据或历史暴露。
2. 只用 `docker build` 不用 `buildx`：很多高级能力（多平台/缓存导出）发挥不出来。
3. 忽略 `.dockerignore`：build context 太大，缓存和传输都会变慢。
4. 大量使用 `ADD URL`：可复现性差，通常改为 `RUN curl` + 校验更稳。

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
