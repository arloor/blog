---
title: "Golang"
subtitle:
tags: 
- golang
date: 2024-10-13T01:14:37+08:00
lastmod: 2024-10-13T01:14:37+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

## 安装golang (linux-amd64)

```bash
version=1.22.6
curl https://go.dev/dl/go${version}.linux-amd64.tar.gz -Lf -o /tmp/golang.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/golang.tar.gz
if ! grep "go/bin" ~/.zshrc;then
  export PATH=$PATH:/usr/local/go/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
fi
```

或者到[https://go.dev/dl/](https://go.dev/dl/)下载安装包安装

## 设置go test的快捷命令

```bash
mkdir -p ~/bin
if ! grep "PATH=~/bin" ~/.zshrc;then
  export PATH=~/bin:$PATH
  echo 'export PATH=~/bin:$PATH' >> ~/.zshrc
fi
cat > ~/bin/testgo <<\EOF                    
go test -gcflags='all=-N -l' -v "$@"
EOF
chmod +x ~/bin/testgo
```