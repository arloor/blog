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

推荐使用组策略或注册表来做，参考[https://www.disktool.cn/content-center/stop-windows-11-update-666.html](https://www.disktool.cn/content-center/stop-windows-11-update-666.html)

### 组策略

组策略是管理员为计算机和用户定义的，用来控制应用程序、系统设置和管理模板的一种机制，通俗一点说，即为介于控制面板和注册表之间的一种修改系统、设置程序的工具。当然，我们也可以通过本地组策略编辑器来关闭Win11更新。

**关闭自动更新**

> 理论上，做了这一步之后就不需要后面的组策略配置了，因为已经完全关闭了

组合键 `Win + R` 输入 `gpedit.msc` 回车 打开组策略编辑器。导航到**计算机配置 > 管理模板 > Windows组件 > Windows 更新 > 管理最终用户体验**，双击进入。然后修改两个选项：

| 选项名称 | 配置 | 说明 |
| --- | --- | --- |
| 配置自动更新 | 已禁用 | 如果将此策略的状态设置为“已禁用”，则必须手动下载并安装 Windows 更新中可用的任何更新。若要执行此操作，请使用“开始”搜索 Windows 更新。 |
| 删除使用所有Windows更新功能的访问权限 | 已启用 | 此设置允许你删除扫描 Windows 更新所需的访问权限。如果启用此设置，将删除用户扫描、下载和安装 Windows 更新所需的访问权限。 |

重启电脑后就生效了。

![alt text](/img/windows11-gpedit-close-update.png)

**配置target version**

> 比如想停留在23H2，不想升级24H2

组合键 `Win + R` 输入 `gpedit.msc` 回车 打开组策略编辑器。导航到**计算机配置 > 管理模板 > Windows组件 > Windows 更新 > 管理从Windows更新提供的更新**，双击进入。点击“选择目标功能更新版本”，将其配置为“已启用”，然后在下方填入你想停留的版本，比如“23H2”，然后点击应用。重启电脑后就生效了。

![alt text](/img/windows11-gpedit-target-version.png)


**关闭自动更新驱动程序**

> 有人反馈自动更新amd显卡驱动导致蓝屏，整体来说专业的事还是找驱动大师这种软件搞把。

组合键 `Win + R` 输入 `gpedit.msc` 回车 打开组策略编辑器。导航到**计算机配置 > 管理模板 > Windows组件 > Windows 更新 > Windows更新不包含驱动程序**，双击进入，设置为已启用。重启电脑后就生效了。

![alt text](/img/windows11-gpedit-disable-driver-update.png)

### 注册表

首先要说，上面设置的组策略最终也是通过修改注册表来生效的。组策略修改生在有图形界面，因此我不推荐使用注册表修改，而且也不推荐混用组策略和注册表修改，因为可能出现不一致的情况。

**关闭自动更新**

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows。
3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“项”，然后将其命名为“AU”。
5. 在新建的AU文件夹右侧空白页面中右键单击并选择“新建”>“DWORD（32位）值”，然后将其命名为“NoAutoUpdate”。
6. 双击新建的NoAutoUpdate，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机即可彻底关闭Windows更新。

**禁止手动检查更新**

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows。
3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“DWORD（32位）值”，然后将其命名为“SetDisableUXWUAccess”。
6. 双击新建的SetDisableUXWUAccess，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机，windows设置中就无法手动检查更新了。

**禁止自动更新驱动**

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows。
3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“DWORD（32位）值”，然后将其命名为“ExcludeWUDriversInQualityUpdate”。
6. 双击新建的ExcludeWUDriversInQualityUpdate，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机即可关闭驱动自动更新。

**CMD一键设置**

问了chatgpt老师，可以以管理员权限启动cmd，输入下面的脚本一键完成:

```bash
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f
```

这个脚本使用了 `reg add` 命令来添加或修改注册表项。参数 `/v` 指定值的名称，`/t` 指定数据类型，`/d` 指定数据内容，`/f` 表示强制覆盖而不提示。可以从[此处](/bat/disable_windows_updates.bat)下载本脚本。
