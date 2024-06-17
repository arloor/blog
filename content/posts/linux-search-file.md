---
title: "Linux包管理工具搜索特定文件/列出包的所有文件"
date: 2024-06-18T01:09:02+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## yum

### 搜索文件

```bash
yum makecache
yum provides "*/libc.a" # 搜索不在标准路径的文件，前面加上*/
yum provides repoquery # 搜索在标准路径下的文件
```

### 列出文件

```bash
yum install -y yum-utils # 安装repoquery
repoquery -l yum-utils # 列出yum-utils包的所有文件
```

## apt

在基于 Debian 的 Linux 发行版（如 Ubuntu）中，你可以使用 `apt-file` 工具来查询某个文件是由哪个软件包提供的。以下是具体步骤：

### 安装 `apt-file`

如果你的系统中还没有安装 `apt-file`，你需要先进行安装：

```bash
sudo apt update
sudo apt install apt-file
```

### 更新 `apt-file` 的索引

安装完成后，需要更新 `apt-file` 的索引以确保其数据库是最新的：

```bash
sudo apt-file update
```

### 查询文件所属的软件包

使用以下命令查询某个文件由哪个包提供。例如，要查找 `/usr/bin/ls` 文件是由哪个包提供的，可以运行：

```bash
apt-file search /usr/bin/ls
```

输出结果类似于：

```plaintext
coreutils: /usr/bin/ls
```

这表明 `/usr/bin/ls` 文件由 `coreutils` 包提供。

### 示例

假设你要查找 `/usr/bin/vi` 文件所属的软件包，可以执行以下命令：

```bash
apt-file search /usr/bin/vi
```

输出可能是：

```plaintext
vim-common: /usr/bin/vi
```

这表示 `/usr/bin/vi` 文件由 `vim-common` 包提供。

### 其他有用的命令

- **列出包提供的所有文件：**
  如果你想查看某个包提供的所有文件，可以使用以下命令：

  ```bash
  apt-file list <package_name>
  ```

  例如：

  ```bash
  apt-file list coreutils
  ```

- **搜索包含某个文件的包：**
  如果你不确定文件的完整路径，可以只使用文件名的一部分：

  ```bash
  apt-file search <partial_filename>
  ```

  例如：

  ```bash
  apt-file search bin/ls
  ```

### 小结

通过 `apt-file` 工具，你可以方便地查询某个文件由哪个软件包提供。这对于解决依赖问题或者查找某些命令所在的包非常有用。记得在每次查询之前更新索引以确保结果的准确性。