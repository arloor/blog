---
title: "Windows WSL2使用"
date: 2022-04-06T13:45:23+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
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

## 开启systemd

```bash
echo -e "[boot]\nsystemd=true" | sudo tee -a /etc/wsl.conf
```

## 配置WSL2内存限制

因为linux的buffer/cache机制，wsl会占用大量内存，体现在windows任务管理器中vmmemwsl内存占用很高。可以手动进行下限制：

在`C:\Users\<YourUserName>\.wslconfig`中增加：

```bash
# Settings apply across all Linux distros running on WSL 2
[wsl2]

# Limits VM memory to use no more than 4 GB, this can be set as whole numbers using GB or MB
memory=4GB 

# Sets the VM to use two virtual processors
#processors=2

# Specify a custom Linux kernel to use with your installed distros. The default kernel used can be found at https://github.com/microsoft/WSL2-Linux-Kernel
#kernel=C:\\temp\\myCustomKernel

# Sets additional kernel parameters, in this case enabling older Linux base images such as Centos 6
#kernelCommandLine = vsyscall=emulate

# Sets amount of swap storage space to 8GB, default is 25% of available RAM
#swap=8GB

# Sets swapfile path location, default is %USERPROFILE%\AppData\Local\Temp\swap.vhdx
#swapfile=C:\\temp\\wsl-swap.vhdx

# Disable page reporting so WSL retains all allocated memory claimed from Windows and releases none back when free
#pageReporting=false

# Turn off default connection to bind WSL 2 localhost to Windows localhost
#localhostforwarding=true

# Disables nested virtualization
#nestedVirtualization=false

# Turns on output console showing contents of dmesg when opening a WSL 2 distro for debugging
#debugConsole=true
```

## 快速设置代理

我的环境是在windows中使用clash for windows，为了让WSL中能用上代理，专门写了两个脚本：

```bash
# /usr/local/bin/pass

## nameserver就是windows的地址，主要要给clash for windows打开allow lan
gateway=`cat /etc/resolv.conf|grep  -E "^nameserver"| awk '{print $2}'`
export http_proxy=http://${gateway}:7890
export https_proxy=http://${gateway}:7890
git config --global http.proxy ${http_proxy}
git config --global https.proxy ${http_proxy}
```

```bash
# /usr/local/bin/unpass
export http_proxy=
export https_proxy=
```

这样在启用和关闭代理时只要执行`. pass`和`. unpass`即可


## apt设置代理

默认安装的ubuntu的默认源是官方源，国内比较慢，直接配置apt代理，支持我的ProxyOverTls哦。

```
vim /etc/apt/apt.conf.d/proxy.conf
Acquire::http::Proxy "https://user:passwd@server:port/";
Acquire::https::Proxy "https://user:passwd@server:port/";
```

## apt不更新某软件

apt-mark 可以对软件包进行设置（手动/自动）安装标记，也可以用来处理软件包的 dpkg(1) 选中状态，以及列出或过滤拥有某个标记的软件包。 

apt-mark常用命令

```
apt-mark auto – 标记指定软件包为自动安装
apt-mark manual – 标记指定软件包为手动安装
apt-mark minimize-manual – Mark all dependencies of meta packages as automatically installed.
apt-mark hold – 标记指定软件包为保留(held back)，阻止软件自动更新
apt-mark unhold – 取消指定软件包的保留(held back)标记，解除阻止自动更新
apt-mark showauto – 列出所有自动安装的软件包
apt-mark showmanual – 列出所有手动安装的软件包
apt-mark showhold – 列出设为保留的软件包

比如保留某个软件不更新可以使用hold标记,如docker
sudo apt-mark hold docker*

sudo apt-mark showhold

如果要解除保留可以使用unhold
sudo apt-mark unhold docker*
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