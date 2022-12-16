---
title: "Starship Shell"
date: 2022-12-16T21:22:57+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

## 官方文档

[README.md](https://github.com/starship/starship/blob/master/docs/zh-CN/guide/README.md)

## Windows powershell设置

1. 下载[Nerd Font](https://www.nerdfonts.com/)字体，并将字体文件复制到C://Windows/Fonts下
2. 在[发布页](https://github.com/starship/starship/releases/latest)下载 MSI 包来安装Starship最新版。
3. powershell以管理员运行下列命令，以放开脚本执行

```shell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted  -Scope LocalMachine
```

4. 参考官方文档，修改PowerShell 配置文件

>将以下内容添加到您 PowerShell 配置文件的末尾（通过运行 $PROFILE 来获取配置文件的路径）

```plaintext
Invoke-Expression (&starship init powershell)
```


