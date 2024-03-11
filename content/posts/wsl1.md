---
title: "WSL1安装"
date: 2023-03-07T21:42:22+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```bash
 wsl --install --no-distribution
```

![alt text](/img/windows-feature-enable-wsl1.png)

重启电脑

```bash
wsl --set-default-version 1
wsl --install --enable-wsl1
```

根据提示设置用户名密码

```bash
cat > /usr/local/bin/pass <<EOF
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export no_proxy=192.168.0.0/16,127.0.0.1,10.0.0.0/8,172.16.0.0/12,localhost
EOF
cat > /usr/local/bin/unpass <<EOF
export http_proxy=
export https_proxy=
export HTTP_PROXY=
export HTTPS_PROXY=
EOF
. pass
curl https://www.google.com
cat > /etc/profile.d/proxy.sh <<EOF
. /usr/local/bin/pass
EOF
```