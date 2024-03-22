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