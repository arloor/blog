---
title: "华为/荣耀手机关闭系统更新"
date: 2019-11-16T22:43:19+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

1. 下载安卓SDK platform tools（其实就是ADB）。下载地址：[platform-tools](https://developer.android.com/studio/releases/platform-tools.html)
2. 开启手机的开发者模式，开启usb调试
3. 手机连接电脑，允许usb调试
4. 使用`adb shell pm disable-user com.huawei.android.hwouc` 禁用系统更新
5. 使用`adb shell pm enable com.huawei.android.hwouc` 恢复系统更新

荣耀手机对应的是 com.hihonor.ouc

【EOF】
<!--more-->