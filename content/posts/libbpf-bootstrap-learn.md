---
title: "libbpf-bootstrap学习"
date: 2024-04-20T11:27:55+08:00
draft: false
categories: [ "undefined"]
tags: ["ebpf"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

本文主要是是对[Building BPF applications with libbpf-bootstrap (nakryiko.com)](https://nakryiko.com/posts/libbpf-bootstrap/#the-user-space-side)的个人理解的总结，这篇文章可以当成是`libbpf-bootstrap`这个项目的`README` ，介绍了它的目标、依赖和用法等。

[BPF相关(1) 工具链libbpf入门指南 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/615573175) 是机器翻译版本，需要的同学可以中英对照自己看下。

文中涉及的`ebpf`代码在[libbpf-bootstrap](https://github.com/libbpf/libbpf-bootstrap)仓库的example中，建议clone下来对照查看。

## 前言

BPF是一种很cool的技术。有了它之后，不需要充分的内核开发经验，也不需要配置内核的开发环境，普通的开发人员也可以改进和追踪内核的功能。

但是，开发BPF程序仍然是一件很麻烦的事情，因为即使是开始一个`hello-world`的 bpf程序，也需要设置一大堆的环境和依赖软件，这使得初入BPF领域开发者十分的困惑。

`libbpf`是一个脚手架项目，为初学者设置好了一切初学BPF所需要的环境与依赖配置，让用户可以直接切入开发而不用去关心那些烦人的配置问题。并且它借鉴了BPF社区开发提供的最佳方式，提供一套全新的现代的开发工作流水线。

并且`libbpf`支持CO-RE（一次编译，到处运行），用于在不通Linux发行版、不同内核版本运行。这依赖于 BPF CO-RE 和内核 BTF 支持，所以请确保您的 Linux 内核在编译时使用 `CONFIG_DEBUG_INFO_BTF=y` Kconfig了。当然，目前高版本的Linux发行版基本都内置了该支持。

[libbpf-bootstrap](https://github.com/libbpf/libbpf-bootstrap)仓库的example中有两个版本：

`minimal`：一个hello-word版本的ebpf程序，它hook了write系统调用，每次write时都打印一行日志。

`bootstrap`：一些有现实意义的ebpf程序，例如tc（traffic control）、profile等例子，他们用到了ebpf更高级的一些特性，相应的复杂度有一些提升。

## 使用libbpf库编写EBPF程序的依赖

1. Clang编译器。至少需要Clang10，CO-RE需要Clang11或Clang12
2. libbpf库
3. bpftool可执行性文件，用来生成vmlinux.h和xx_skel.h
4. zlib (libz-dev or zlib-devel ) and libelf (libelf-dev or elfutils-libelf-devel )

[libbpf-bootstrap](https://github.com/libbpf/libbpf-bootstrap)用git submodule提供了`libbpf`和`bpftool` ，避免依赖系统全局的libbpf和bpftool，所以使用libbpf-bootstrap的话，不需要预先在系统中安装2和3。

## **Libbpf-bootstrap 概览**

原文中提到的libbpf-bootstrap的文件树如下，当前已经发生了一些变化，但是不影响我们理解。

```bash
$ tree
.
├── libbpf
│   ├── ...
│   ... 
├── LICENSE
├── README.md
├── src
│   ├── bootstrap.bpf.c
│   ├── bootstrap.c
│   ├── bootstrap.h
│   ├── Makefile
│   ├── minimal.bpf.c
│   ├── minimal.c
│   ├── vmlinux_508.h
│   └── vmlinux.h -> vmlinux_508.h
└── tools
    ├── bpftool
    └── gen_vmlinux_h.sh

16 directories, 85 files
```

通过git submodule内置了libbpf库，来避免依赖系统全局的libbpf（就是/usr/lib下的那些）。

`tools/` 下内置了`bpftool`的64位可执行文件，来避免依赖全局的`bpftool` 。bpftool可以从`/sys/kernel/btf/vmlinux`生成包含所有`Linux kernel type definitions`的头文件`vmlinux.h`。上面的文件树中，已经生成了5.08内核的vmlinux.h，一般情况下来说CO-RE特性不需要运行BPF程序的主机恰好时5.08版本的内核，所以大多数时候不需要重新生成vmlinux.h。因为有vmlinux.h，所以libbpf不依赖特定版本的kernel-header，这是CO-RE的基础。

另外bpftool还会在make过程中生成bpf c代码的xx_skel.h(骨架头文件）。怎么理解这个骨架头文件呢？BPF程序分为BPF c代码和用户态代码。BPF c代码运行在内核态，用户态代码需要与其交互。回忆一下RPC的交互流程，client要有桩文件才能调用server的服务。这个骨架头文件就是BPF c代码的桩，包含了BPF代码的类型定义，例如全局变量、BPF map、方法声明等。

一个BPF程序的源代码由三部分组成：

- `<app>.bpf.c` files are the BPF C code that contain the logic which is to be executed in the kernel context;
- `<app>.c` is the user-space C code, which loads BPF code and interacts with it throughout the lifetime of the application;
- *optional* `<app>.h` is a header file with the common type definitions and is shared by both BPF and user-space code of the application.

这些代码将在MakeFile定义的编译规则中使用。

## libbpf examples

1. [libbpf-rs/examples at master · libbpf/libbpf-rs · GitHub](https://github.com/libbpf/libbpf-rs/tree/master/examples)
2. [libbpf-bootstrap/examples at master · libbpf/libbpf-bootstrap (github.com)](https://github.com/libbpf/libbpf-bootstrap/tree/master/examples)
3. [deepflow/agent at f76c73dde43e6f7919d72686b6cf79cae3d1d79d · deepflowio/deepflow · GitHub](https://github.com/deepflowio/deepflow/tree/f76c73dde43e6f7919d72686b6cf79cae3d1d79d/agent)  (在此commit之后去除了libbpf的依赖，因为GPL证书太严格了)

## 一些备忘

**libbpf-bootstrap项目初始化**

```bash
git submodule update --init --recursive
yum install -y zlib-devel elfutils-libelf-devel bpftool libbpf
bpftool btf dump file /sys/kernel/btf/vmlinux format c > ./vmlinux.h
```

**寻找libc的动态库，用于uprobe**

```bash
$ find / -name libc.so.6 
/var/lib/containers/storage/overlay/de102d108aeda5726e7c2794014f5c49caa079542e29c15d0f9dbb9ed9280fc1/diff/usr/lib64/libc.so.6
/var/lib/containers/storage/overlay/c34512f6bae849adb22b5cf34a4f42e8054431ca488cd754020c09a7664dbf46/merged/usr/lib64/libc.so.6
/usr/lib64/libc.so.6
```
