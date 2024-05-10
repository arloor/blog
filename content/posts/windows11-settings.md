---
title: "windows11 设置"
date: 2023-12-04T22:18:31+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 开启无需密码自动登录

1. 以管理员运行cmd，输入：

```bash
reg ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f
```

2. 重启电脑，让新注册表生效
3. 在开始菜单输入：`netplwiz` ，并取消勾选

![Alt text](/img/cancel-password-login-for-windows11.png)

4. 再次重启就不需要密码登录了


## 减少“以管理员启动”的提示

开始菜单搜索UAC（更改用户账户控制设置），拉到最下面

## 性能优化

### 在设置中关闭内存完整性判断

![alt text](/img/window11-mem-wanzhengxing-protection.png)

### 关闭hyper-v

![alt text](/img/window11-software-and-gongneng.png)

关闭 hyper-v、windows虚拟机监控程序平台、虚拟机平台、适用于linux的windows子系统

### 使用intel大小核的CPU时，控制面板“选择电源计划”选择平衡或者高性能（更推荐平衡），千万不要选卓越性能

这涉及到大小核的调度策略，更多请搜索异构调度策略。参考：

- [玩一玩win11中与大小核调度策略有关的隐藏高级电源设置](https://nga.178.com/read.php?tid=35222326)
- [赛博朋克2077的幽默“优先性能核心”，简单修改电源设置即可让帧数提高10-15%](https://nga.178.com/read.php?tid=39471892)

## 关闭windows自动更新

推荐使用组策略或注册表来做。

### 组策略

组策略是管理员为计算机和用户定义的，用来控制应用程序、系统设置和管理模板的一种机制，通俗一点说，即为介于控制面板和注册表之间的一种修改系统、设置程序的工具。当然，我们也可以通过本地组策略编辑器来关闭Win11更新。

**关闭自动更新**

组合键 Win + R 输入 gpedit.msc 回车 打开组策略编辑器：计算机配置 > 管理模板 > Windows组件 > Windows 更新 > 管理最终用户体验，双击进入。

进入后选择 配置自动更新，右键编辑属性，在弹出的配置窗口中选择 已禁用。


**配置target version**

> 比如不想升级到windows 11, 24H2

1. 按Win+R输入gpedit.msc并按Enter键打开本地组策略编辑器。
2. 转到此路径：本地计算机策略>计算机配置>管理模板>Windows组件>Windows更新>适用于企业的Windows更新。
转到适用于企业的Windows更新文件夹
3. 双击此文件夹下的“选择目标功能更新版本”设置。
4. 在弹出窗口中将其配置为“已启用”，在左下方长条框中填入“23H2”（或者其他您想停留的Windows11版本），然后单击“应用”>“确定”即可。
5. 关闭本地组策略编辑器，重启计算机即可彻底停止Win11更新。

## 注册表

> 实际上，上面的组策略最终也是通过修改注册表实现的

Windows注册表实质上是一个庞大的数据库，存储着各种各样的计算机数据与配置，我们可以通过编辑注册表来解决一些很难搞定的计算机问题，比如彻底关闭Win11更新。

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows。
3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“项”，然后将其命名为“AU”。
5. 在新建的AU文件夹右侧空白页面中右键单击并选择“新建”>“DWORD（32位）值”，然后将其命名为“NoAutoUpdate”。
6. 双击新建的NoAutoUpdate，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机即可彻底关闭Windows更新。