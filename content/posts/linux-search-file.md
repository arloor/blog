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