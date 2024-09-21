---
title: "Windows WSL2使用"
date: 2022-04-06T13:45:23+08:00
draft: false
categories: [ "undefined"]
tags: ["windows"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

wsl全称是windows的linux子系统，可以理解为在你的windows电脑上提供一个linux的工作环境，举个简单的例子是：windows没有bash，执行不了shell脚本，但是有了wsl之后，就有了bash。注意，wsl不是虚拟机，wsl不是和windows隔离的，所以是能操作windows的文件的。从另一个角度看，windows就一个linux发行版。

## windows虚拟化的基础知识

| windows功能 | 作用 | 其他 |
| --- | --- | --- |
| Hyper-V | 微软自己的虚拟化工具 | 包含了“管理工具”和“平台”，其中“平台”包含“服务”和“虚拟机监控程序” |
| Windows Subsystem for Linux | WSL1，不是我们讨论的WSL2所需要的 | |
| Virtual Machine Platform | 虚拟机平台（WSL2的底层依赖） | 看到说Hyper-V也依赖这个，但启用Hyper-V并不需要启用虚拟机平台，因此我觉得Hyper-V依赖的是“Hyper-V虚拟机监控程序”吧 |
| Windows Sandbox | 一个隔离的桌面环境 | 我反正没用过，不了解 |
| Windows 虚拟机监控程序平台 | 用于支持vmware等第三方虚拟机软件 | |

{{<imgx src="/img/windows-feature-disable-virt.png" width="400px">}}

> 1. 虚拟机平台会一定程度上影响游戏性能，为了游戏性能，可以关闭虚拟机平台、Hyper-V。Windows虚拟机监控程序平台、适用于Linux的Windows子系统我理解是不影响游戏性能的。参考[用于在 Windows 11 中优化游戏性能的选项](https://prod.support.services.microsoft.com/zh-cn/windows/%E7%94%A8%E4%BA%8E%E5%9C%A8-windows-11-%E4%B8%AD%E4%BC%98%E5%8C%96%E6%B8%B8%E6%88%8F%E6%80%A7%E8%83%BD%E7%9A%84%E9%80%89%E9%A1%B9-a255f612-2949-4373-a566-ff6f3f474613)。
> 2. Hyper-V和vmware等软件是冲突的，详见[虚拟化应用程序无法与 Hyper-V、Device Guard 和 Credential Guard 协同工作](https://learn.microsoft.com/zh-cn/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v)

关闭虚拟机平台和Hyper-V虚拟机监控程序：

```bash
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
DISM /Online /Disable-Feature /FeatureName:Microsoft-Hyper-V-All /NoRestart
@REM 其实只要关闭 Microsoft-Hyper-V-Hypervisor 就行了
```

开启虚拟机平台和Hyper-V虚拟机监控程序：

```bash
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V-All /NoRestart
```

查看所有windows功能

```bash
dism.exe /online /Get-Features
```

## %userprofile%/.wslconfig

```toml
[wsl2]
# networkingMode=bridged
# vmSwitch=Home # 此处的名称和指定的虚拟网络交换机一致
# dhcp=false # 禁用DHCP，在WSL2系统中通过设置Linux的静态IP实现获取IP
networkingMode = mirrored # 端口自动转发，Windows和WSL共享端口，都使用127.0.0.1
dnsTunneling = true # WSL的DNS请求通过Windows转发
firewall = true # WSL同步Windows防火墙规则
autoProxy = true # Windows设置代理时自动同步给WSL，就是使用clash代理

[experimental]
sparseVhd = true # 自动清理磁盘空间
autoMemoryReclaim = dropcache # 可以在gradual 、dropcache 、disabled之间选择，选择dropcache让WSL中Docker正常运行
```

## 安装WSL2

```bash
@REM 启用VMP 虚拟机平台
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
echo you may need reboot to take effect
@REM 启用wslservice
sc.exe config wslservice start= demand
wsl --set-default-version 2
wsl -v
wsl --list --online
wsl --install -d Debian
```

## 设置默认root用户

```bash
debian config --default-user root
```

## 第一次启动

设置用户名和密码：

![](/img/Snipaste_2024-09-21_16-56-02.png)

启用systemd：

```bash
if ! grep -q "systemd=true" /etc/wsl.conf; then
    echo -e "[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf
fi
```

执行 `wsl --shutdown` 重启wsl，然后就可以使用systemd了。

## 其他设置

### apt设置代理

默认安装的Debian的默认源是官方源，国内比较慢，直接配置apt代理，支持我的ProxyOverTls哦。

```
cat <<EOF | sudo tee /etc/apt/apt.conf.d/proxy.conf
Acquire::http::Proxy "https://user:passwd@server:port/";
Acquire::https::Proxy "https://user:passwd@server:port/";
EOF
```

### apt不更新某软件

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

### git设置

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

直接原因是我有很多shell脚本，原本git.exe的bash是可以执行crlf的shell文件的。安装wsl后，bash被替换为了Debian的bash，不能处理crlf的shell文件。——我需要shell脚本是lf的。根本原因，换行符的问题是一个历史遗留问题，是操作系统之间的壁垒。现代的ide或者文本编辑器都是跨平台使用的，他们能处理换行符的问题，那么用vscode，idea就行了，不要用windows的老版文本编辑器了。我已经比较习惯在linux处理文本了，vim、grep、awk、sed等等很爽，wsl的最大好处就是在windows上能用上原生的bash，那就文本全部linux化好了。

## 其他参考

- [WSL2设置镜像网络模式](https://www.ryanshang.com/2024/01/06/WSL2%E8%AE%BE%E7%BD%AE%E9%95%9C%E5%83%8F%E7%BD%91%E7%BB%9C%E6%A8%A1%E5%BC%8F/)
- [WSL 中的高级设置配置](https://learn.microsoft.com/zh-cn/windows/wsl/wsl-config)

## 常见报错解决

### 0x80070422 wslservice服务未启动

```bash
无法启动服务，原因可能是已被禁用或与其相关联的设备没有启动。
Error code: Wsl/0x80070422
```

解决方案：

```bash
sc.exe config wslservice start= demand
```

### 0x8004032d 虚拟机平台功能未启用

```bash
WslRegisterDistribution failed with error: 0x8004032d
Error: 0x8004032d (null)
```
解决方案：在启用和关闭windows功能中打开“虚拟机平台”或使用下面的cmd命令并重启

```bash
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

### 端口被占用问题解决

```bash
# 查看当前动态端口范围
netsh int ipv4 show dynamicport tcp
# 查看被使用的端口
netsh int ipv4 show excludedportrange protocol=tcp

# 修改动态端口范围
netsh int ipv4 set dynamic tcp start=50000 num=15536
netsh int ipv6 set dynamic tcp start=50000 num=15536
# 重启网络
net stop winnat
net start winnat
```

## 卸载发行版

```bash
wsl --uninstall Debian
wsl --unregister Debian
```
