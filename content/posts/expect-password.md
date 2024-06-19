---
title: "Expect Password"
date: 2024-06-19T11:05:37+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


对于需要输入密码的命令，通常我们不能简单地通过重定向输入（如使用 `<` 或 `<<` ）来避免手动输入密码。这是因为这些命令通常会直接从终端读取密码，以确保密码的安全性，不会从标准输入（stdin）读取。但是我们可以使用expect工具来自动输入密码。下面是自动实现kinit认证的步骤。

## 安装homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# 然后设置环境变量
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 安装expect

```bash
brew install expect
```

## 编写expect脚本

```bash
cat > ~/bin/work <\EOF
#!/usr/bin/expect -f

set username "user@EXAMPLE.COM"
set password "passwd"

spawn kinit $username
expect "password:"
send "$password\r"
interact
EOF
chmod +x ~/bin/work
```

## 配置MacOS快捷指令

可以配置快捷指令，并固定到菜单栏

![alt text](/img/macos-shortcode-expect-passwd.md)