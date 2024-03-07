---
title: "WSL1安装"
date: 2024-03-07T21:42:22+08:00
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