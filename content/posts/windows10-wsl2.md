---
title: "windows wsl2使用"
date: 2022-04-06T13:45:23+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

wsl全称是windows的linux子系统，可以理解为在你的windows电脑上提供一个linux的工作环境，举个简单的例子是：windows没有bash，执行不了shell脚本，但是有了wsl之后，就有了bash。注意，wsl不是虚拟机，wsl不是和windows隔离的，所以是能操作windows的文件的。从另一个角度看，windows就一个linux发行版。

## 安装

windows10 2004版本以后可以使用

```
wsl --install
```

详见[https://docs.microsoft.com/zh-cn/windows/wsl/install](https://docs.microsoft.com/zh-cn/windows/wsl/install)

会增加一个ubuntu20.04版本

## windows terminal使用

根据[之前的windows terminal配置](/posts/windows-terminal/#配置文件)把ubuntu的配色方案改为`Atom`。

## apt设置代理

默认安装的ubuntu的默认源是官方源，国内比较慢，直接配置apt代理，支持我的ProxyOverTls哦。

```
vim /etc/apt/apt.conf.d/proxy.conf
Acquire::http::Proxy "https://user:passwd@server:port/";
Acquire::https::Proxy "https://user:passwd@server:port/";
```

## git设置

由于wsl支持windows和linux的命令互操作，你实际上会有两个git，一个wsl的git，一个windows的git.exe。下面说说wsl的git怎么使用

```
git config --global user.name "user"
git config --global user.email "xx@xx.com"
git config --global credential.helper store
# wsl的git忽略文件权限的变更
git config --global core.filemode false
# wsl的git 提交时自动将crlf转换为lf，checkout时不转成crlf
git config --global core.autocrlf input
```

windows的git.exe也执行下：

```
# wsl的git 提交时自动将crlf转换为lf，checkout时不转成crlf
git config --global core.autocrlf input
```

autocrlf的配置详见[git文档](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration#_formatting_and_whitespace)

简单解释就是：

- windows使用crlf换行，linux和macos使用lf换行（早期macos使用cr换行）
- autocrlf=true，提交到index时自动将crlf换成lf，checkout时自动将lf换成crlf。适合windows使用，widnwos默认配置
- autocrlf=input，提交到index时自动将crlf换成lf，checkout时不自动转换。适合macos和linux用。
- autocrlf=false，不自动转换换行符。

git文档推荐，linux和macos使用input，windows使用true。这样保证index、linux、macos中永远是lf，windows中是crlf。

**但是**我的设置成了windows上也是input。

直接原因是我有很多shell脚本，原本git.exe的bash是可以执行crlf的shell文件的。安装wsl后，bash被替换为了Ubuntu的bash，不能处理crlf的shell文件。——我需要shell脚本是lf的。

根本原因，换行符的问题是一个历史遗留问题，是操作系统之间的壁垒。现代的ide或者文本编辑器都是跨平台使用的，他们能处理换行符的问题，那么用vscode，idea就行了，不要用windows的老版文本编辑器了。

我已经比较习惯在linux处理文本了，vim、grep、awk、sed等等很爽，wsl的最大好处就是在windows上能用上原生的bash，那就文本全部linux化好了。