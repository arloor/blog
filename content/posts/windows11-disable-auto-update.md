---
title: "Windows11彻底禁止自动更新"
date: 2024-06-28T21:05:32+08:00
draft: false
categories: [ "undefined"]
tags: 
- windows
- bat
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

关于windows自动更新，我的建议是关闭windows自动更新，时常到[Windows 11, version 23H2 update history](https://support.microsoft.com/en-us/topic/windows-11-version-23h2-update-history-59875222-b990-4bd9-932f-91a5954de434)和[Windows 11版本 23H2 更新历史记录](https://support.microsoft.com/zh-cn/topic/windows-11%E7%89%88%E6%9C%AC-23h2-%E6%9B%B4%E6%96%B0%E5%8E%86%E5%8F%B2%E8%AE%B0%E5%BD%95-59875222-b990-4bd9-932f-91a5954de434)看看有没有有用的更新。看到有更新后，千万别急着更新，过个十天半个月用搜索引擎搜搜看看该更新有没有问题再说。比如最近的[kb5039302](https://support.microsoft.com/en-us/topic/june-25-2024-kb5039302-os-builds-22621-3810-and-22631-3810-preview-0ab34e3f-bca9-4a52-a1a4-404bf8162f58)就存在虚拟机无限重启的问题。很多大问题是不会被windows官方写在页面上的，都是外面媒体爆出来的。

下面就介绍下彻底关闭windows自动更新的方式。参考[https://www.disktool.cn/content-center/stop-windows-11-update-666.html](https://www.disktool.cn/content-center/stop-windows-11-update-666.html)，我推荐使用组策略或注册表来彻底关闭windows自动更新。在文章最开始，我们给出windows11 pro版的一键脚本分别**彻底关闭更新**和**允许手动检查更新**，以管理员权限运行即可。之后会介绍手动设置组策略和注册表的方式，方便了解上面的脚本到底干了啥。另外，我也推荐关闭windows自带的驱动更新，防止出现显卡掉驱动等问题。

## 彻底关闭更新

```bash
@echo off
REM -- 禁止自动更新
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
REM -- 禁止在windows设置中检查更新
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f
REM -- windows更新中不包含驱动程序更新（防止windows带了错误的驱动，特别是显卡驱动）
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f
```

这个脚本使用了 `reg add` 命令来添加或修改注册表项。参数 `/v` 指定值的名称，`/t` 指定数据类型，`/d` 指定数据内容，`/f` 表示强制覆盖而不提示。执行后并重启后，windows自动更新就已经禁用了，并且会发现windows设置中的更新选项变灰，无法点击。

## 允许手动检查更新

```bash
@echo off
REM -- 允许手动检查更新
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 0 /f
```

执行后打开windows设置中的更新，会发现可以手动检查更新并安装了。

## 本站准备好的bat文件

- [关闭windows更新.bat](/bat/disable_windows_updates.bat)
- [允许手动检查更新.bat](/bat/enable_windows_updates.bat)

这两个bat文件可以直接下载使用，双击运行即可。它们都能自动获取管理员权限，因此不需要手动以管理员身份运行。

## 组策略

组策略是管理员为计算机和用户定义的，用来控制应用程序、系统设置和管理模板的一种机制，通俗一点说，即为介于控制面板和注册表之间的一种修改系统、设置程序的工具。当然，我们也可以通过本地组策略编辑器来关闭Win11更新。

更改完组策略后，需要重启机器或执行 `gpupdate /force` 来让组策略生效。

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

## 注册表

首先要说，上面设置的组策略最终也是通过修改注册表来生效的。组策略修改生在有图形界面，因此我不推荐使用注册表修改，而且也不推荐混用组策略和注册表修改，因为可能出现不一致的情况。

**关闭自动更新**

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：

```bash
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows
```

3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“项”，然后将其命名为“AU”。
5. 在新建的AU文件夹右侧空白页面中右键单击并选择“新建”>“DWORD（32位）值”，然后将其命名为“NoAutoUpdate”。
6. 双击新建的NoAutoUpdate，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机即可彻底关闭Windows更新。

**禁止手动检查更新**

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：

```bash
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows
```

3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“DWORD（32位）值”，然后将其命名为“SetDisableUXWUAccess”。
6. 双击新建的SetDisableUXWUAccess，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机，windows设置中就无法手动检查更新了。

**禁止自动更新驱动**

1. 按Win+R输入regedit并按Enter键打开注册表编辑器。
2. 导航到此路径：

```bash
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows
```

3. 右键单击Windows文件夹，选择“新建”>“项”，然后将其命名为“WindowsUpdate”。
4. 右键单击新建的WindowsUpdate文件夹，选择“新建”>“DWORD（32位）值”，然后将其命名为“ExcludeWUDriversInQualityUpdate”
6. 双击新建的ExcludeWUDriversInQualityUpdate，在弹出窗口中将其数值数据从0更改为1，然后单击“确定”。
7. 关闭注册表编辑器，重启计算机即可关闭驱动自动更新。


## 禁止edge自动更新

禁用

```powershell
taskkill /im MicrosoftEdgeUpdate.exe /f
taskkill /im msedge.exe /f

sc.exe stop edgeupdate
sc.exe config edgeupdate start=disabled
sc.exe stop edgeupdatem
sc.exe config edgeupdatem start=disabled
sc.exe stop MicrosoftEdgeElevationService
sc.exe config MicrosoftEdgeElevationService start=disabled

# schtasks.exe /Delete /TN \MicrosoftEdgeUpdateBrowserReplacementTask /F
# schtasks.exe /Delete /TN \MicrosoftEdgeUpdateTaskMachineCore /F
# schtasks.exe /Delete /TN \MicrosoftEdgeUpdateTaskMachineUA /F
Get-ScheduledTask -taskname MicrosoftEdgeUpdate* | Unregister-ScheduledTask -Confirm: $false
```

启用

```powershell
sc.exe config edgeupdate start= delayed-auto

# 启用 edgeupdatem 服务
sc.exe config edgeupdatem start= demand
```