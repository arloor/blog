---
title: "Debian10 Install Clang 16"
date: 2024-06-21T14:12:12+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

参考[https://apt.llvm.org/](http://apt.llvm.org/buster/)


```bash
wget https://apt.llvm.org/llvm-snapshot.gpg.key
apt-key add llvm-snapshot.gpg.key
apt install -y software-properties-common
add-apt-repository "deb http://apt.llvm.org/buster/ llvm-toolchain-$(lsb_release -sc)-16 main"
apt update
apt install clang-format-16 clang-16
```