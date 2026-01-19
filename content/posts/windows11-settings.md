---
title: "windows11设置、性能优化"
date: 2023-12-04T22:18:31+08:00
draft: false
categories: ["undefined"]
tags: ["windows"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
highlightjslanguages:
  - powershell
---

## 开启无需密码自动登录

1. 以管理员运行 cmd，输入：

```bash
reg ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f
```

2. 重启电脑，让新注册表生效
3. 在开始菜单输入：`netplwiz` ，并取消勾选

![Alt text](/img/cancel-password-login-for-windows11.png)

4. 再次重启就不需要密码登录了

## 减少“以管理员启动”的提示

开始菜单搜索 UAC（更改用户账户控制设置），拉到最下面

## 性能优化

首先是参考[用于在 Windows 11 中优化游戏性能的选项](https://prod.support.services.microsoft.com/zh-cn/windows/%E7%94%A8%E4%BA%8E%E5%9C%A8-windows-11-%E4%B8%AD%E4%BC%98%E5%8C%96%E6%B8%B8%E6%88%8F%E6%80%A7%E8%83%BD%E7%9A%84%E9%80%89%E9%A1%B9-a255f612-2949-4373-a566-ff6f3f474613)关闭内存完整性和虚拟机平台(VMP)。

### 在设置中关闭内存完整性判断

![alt text](/img/window11-mem-wanzhengxing-protection.png)

### 关闭虚拟机平台(VMP)

![alt text](/img/window11-software-and-gongneng.png)

windows 的文章说只需要关闭 VMP，我这里关闭了更多：hyper-v、windows 虚拟机监控程序平台、虚拟机平台(VMP)、适用于 linux 的 windows 子系统

{{<imgx src="/img/windows-feature-disable-virt.png" width="400px">}}

关闭虚拟机平台和 Hyper-V 虚拟机监控程序：

```bash
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
DISM /Online /Disable-Feature /FeatureName:Microsoft-Hyper-V-All /NoRestart
```

开启虚拟机平台和 Hyper-V 虚拟机监控程序：

```bash
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V-All /NoRestart
```

或者使用 bcedit 命令关闭 hyper-v：

```bash
bcdedit /set hypervisorlaunchtype off
```

启用 hyper-v：

```bash
bcdedit /set hypervisorlaunchtype auto
```

### 使用 intel 大小核的 CPU 时，控制面板“选择电源计划”选择平衡或者高性能（更推荐平衡），千万不要选卓越性能

这涉及到大小核的调度策略，更多请搜索异构调度策略。参考：

- [玩一玩 win11 中与大小核调度策略有关的隐藏高级电源设置](https://nga.178.com/read.php?tid=35222326)
- [赛博朋克 2077 的幽默“优先性能核心”，简单修改电源设置即可让帧数提高 10-15%](https://nga.178.com/read.php?tid=39471892)

## 应用已卸载但是设置->应用中还有

在注册表中删除即可

```go
计算机\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
```

## 应用已卸载，但是残留了服务

在注册表中删除即可

```bash
计算机\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services
```

## 窗口最小化

1. `ALT+Esc` 可以使当前窗口最小化。
2. `Win+D` 最小化所有窗口，再按一下就可以还原窗口。
3. `Windows+M` 最小化所有窗口 。
4. `Windows+Shift+M` 还原最小化的窗口。
5. `Alt+空格+N` 最小化当前窗口(和浏览器的最小化一样)
6. `ALT+TAB` 这个是切换窗口的按钮，切换到另外一个窗口，这个窗口自然也可以最小化。

## 恢复老的右键菜单

以管理员运行：

```bash
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f
taskkill /F /IM explorer.exe
explorer.exe
```

## 关闭 edge 浏览器的自动更新

[如何禁用 Microsoft Edge 自动更新 (Windows, Linux, macOS)
Posted by sysin on 2022-09-03](https://sysin.org/blog/disable-edge-auto-update/#Microsoft-Edge-for-Windows)

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

## 关闭 Microsoft Store 中的应用自动更新

[如何禁用微软商店自动更新应用](https://answers.microsoft.com/zh-hans/windows/forum/all/%E5%A6%82%E4%BD%95%E7%A6%81%E7%94%A8%E5%BE%AE/1fc27709-3665-47f0-bfca-5b0212e22372)

您好，请尝试用如下方法设定

使用组策略启用/禁用应用程序的自动更新：

1. 通过 windows+R 打开运行窗口，在运行中键入 gpedit.msc 打开组策略编辑器。

2. 从左窗格导航到以下内容：本地计算机策略>>计算机配置>>管理模板>>Windows 组件>>应用商店。

![alt text](/img/services-disable-microsoft-store-update.png)

3. 在右侧，双击“关闭自动下载和安装更新”。

4. 选中已启用单选按钮，然后单击应用和确定。

5. 现在以管理权限启动命令提示符并粘贴以下命令以使更改生效：`gpupdate/force`

你现在已成功禁用 Microsoft Store 应用程序的自动更新。

要为应用程序启用自动更新，只需返回组策略编辑器并选择未配置或已禁用单选按钮。

## 删除文件资源管理器侧边栏显示的 linux 文件夹

修改注册表：

```bash
HKEY_CURRENT_USER\Software\Classes\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}
```

将 `System.IsPinnedToNameSpaceTree` 从 1 改成 0
