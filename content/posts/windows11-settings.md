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