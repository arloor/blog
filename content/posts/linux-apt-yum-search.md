---
title: "Linux包管理工具搜索特定文件/列出包的所有文件【apt/yum】"
date: 2024-06-18T01:09:02+08:00
draft: false
categories: ["undefined"]
tags: ["linux"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
---

<!--more-->

## yum

### 查询文件所属的软件包

例如搜索 `libc.a` （glibc 的静态文件）和 repoquery 可执行文件所属的包：

```bash
yum makecache
yum provides "*/libc.a" # 搜索不在标准路径的文件，前面加上*/
yum provides repoquery # 搜索在标准路径下的文件
```

### 列出包里所有的文件

```bash
yum install -y yum-utils # 安装repoquery
repoquery -l yum-utils # 列出yum-utils包的所有文件
```

### 搜索包

```bash
yum search clang
```

## apt

### 查询文件所属的软件包

使用以下命令查询某个文件由哪个包提供。例如，要查找 `/usr/bin/ls` 文件是由哪个包提供的，可以运行：

```bash
sudo apt update
sudo apt install apt-file
sudo apt-file update
apt-file search /usr/bin/ls
# 不确定全路径名称的话，可以输入一部分路径，例如
apt-file search bin/ls # 不知道是 /usr/bin还是/usr/sbin
```

输出结果类似于：

```plaintext
coreutils: /usr/bin/ls
```

这表明 `/usr/bin/ls` 文件由 `coreutils` 包提供。

### 列出包提供的所有文件

如果你想查看某个包提供的所有文件，可以使用以下命令：

```bash
apt-file list <package_name>
```

例如：

```bash
apt-file list coreutils
```

### 搜索包

```bash
apt-cache search clang
```
