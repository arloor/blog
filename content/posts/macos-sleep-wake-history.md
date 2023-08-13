---
title: "MacOS睡眠和唤醒历史"
date: 2023-08-13T11:29:33+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 查看用户唤醒历史

```bash
pmset -g log|grep -v "DarkWake"|grep -E  "Wake from"
```

## 查看所有睡眠和唤醒历史

内容会有点多，而且包含DarkWake

```bash
pmset -g log|grep -E  "Entering Sleep state|Wake from"
```

## 什么是DarkWake

在 macOS 中，"DarkWake" 和 "Wake" 代表了两种不同类型的唤醒状态：

1. **Wake**: 当你听到 "Wake from Sleep"，这意味着系统从睡眠状态完全唤醒。在这种状态下，所有硬件和系统服务都将完全启动，屏幕将被打开，用户可以与系统进行交互。

2. **DarkWake**: 这是一种特殊类型的唤醒状态，其中系统会部分唤醒来执行某些任务，但不会完全唤醒，屏幕通常保持关闭，用户界面不可用。这种状态常用于例如电邮或日历更新、Time Machine 备份、网络连接的维护等后台任务。DarkWake 的优势是它允许系统执行必要的任务，同时消耗的电源更少，并保持了大部分的睡眠状态。

总体来说，"DarkWake from Sleep" 和 "Wake from Sleep" 的主要区别在于唤醒的级别和目的。DarkWake 是一种低电量的、部分唤醒状态，用于后台任务，而普通的 Wake 则是完全的唤醒，用于用户交互。

不过啊，DarkWake不是全Dark。他会唤醒我USB拓展坞上的设备，让我的键盘灯亮起来。