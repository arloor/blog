---
title: "在Rust项目中集成libbpf-rs"
date: 2024-04-20T11:47:53+08:00
draft: false
categories: [ "undefined"]
tags: ["ebpf"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

前面已经有两篇博客记录了ebpf的一些知识，这篇则是实操。作为一个对C语言和Rust有一定了解的选手，我选择使用 `libbpf-rs` 开发ebpf应用，这就记录下我在Rust项目中集成 `libbpf-rs` 的过程。

<!--more-->