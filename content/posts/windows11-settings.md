---
title: "windows11设置、性能优化"
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

## 关闭edge浏览器的自动更新

[edge浏览器怎么禁止自动更新](https://answers.microsoft.com/zh-hans/microsoftedge/forum/all/edge%E6%B5%8F%E8%A7%88%E5%99%A8%E6%80%8E%E4%B9%88/5644695a-bf34-461e-b3ac-34b663dad965)

`win + r` 运行 `services.msc`，找到下面两个服务，改成禁用

![alt text](/img/services-disable-edge-update.png)

以管理员权限运行powershell，输入：

```bash
# 禁用 edgeupdate 服务
Set-Service -Name 'edgeupdate' -StartupType Disabled -Status Stopped

# 禁用 edgeupdatem 服务
Set-Service -Name 'edgeupdatem' -StartupType Disabled -Status Stopped

Write-Host "edgeupdate 和 edgeupdatem 服务已被禁用。"
```

## 关闭Microsoft Store中的应用自动更新

[如何禁用微软商店自动更新应用](https://answers.microsoft.com/zh-hans/windows/forum/all/%E5%A6%82%E4%BD%95%E7%A6%81%E7%94%A8%E5%BE%AE/1fc27709-3665-47f0-bfca-5b0212e22372)

您好，请尝试用如下方法设定

使用组策略启用/禁用应用程序的自动更新：

1. 通过windows+R 打开运行窗口，在运行中键入gpedit.msc打开组策略编辑器。

2. 从左窗格导航到以下内容：本地计算机策略>>计算机配置>>管理模板>>Windows组件>>应用商店。

![alt text](/img/services-disable-microsoft-store-update.png)

3. 在右侧，双击“关闭自动下载和安装更新”。

4. 选中已启用单选按钮，然后单击应用和确定。

5. 现在以管理权限启动命令提示符并粘贴以下命令以使更改生效：`gpupdate/force`

你现在已成功禁用Microsoft Store应用程序的自动更新。

要为应用程序启用自动更新，只需返回组策略编辑器并选择未配置或已禁用单选按钮。

## 删除文件资源管理器侧边栏显示的linux文件夹

在注册表中删除即可

```bash
HKEY_CURRENT_USER\Software\Classes\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}
```