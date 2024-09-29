---
title: "Nvidia显卡风扇为什么不转？如何手动设置转速"
date: 2024-05-12T19:18:49+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

有人发现电脑在空载或者低负载的时候显卡风扇不转，认为自己显卡出故障了，但其实这是正常的。因为显卡风扇智能启停的特性，风扇在低负载+低温度下会停止运行，只在在高负载下才转动。

## 风扇智能启停

风扇智能启停可以在低负载时获得更低的噪音。这个功能是显卡自带的，并不需要手动开启。但是某些情况下这个功能会失效，这一节就是告诉大家如何避免失效。

### 1. NVIDIA控制面板--管理3D设置--电源管理模式 设置为正常

> **如果没动过这个选项，或者压根没听过Nvidia控制面板，则不需要执行下列操作**

B站有UP主建议电源管理模式选“最高性能优先”，以获得最好的显示效果和响应速度。但是实测这并不会影响显示效果，倒是会让风扇的**智能启停**功能失效，导致在低负载时也**会以30%转速运行**，因此我推荐将电源管理模式设置成正常。注意：nvidia控制面板在windows11中需要在microsoft store中下载，直达链接[https://apps.microsoft.com/detail/9nf8h0h7wmlt?tp=RHJpdmVyR2FtaW5nIE5C&rtc=1&hl=zh-cn&gl=US](https://apps.microsoft.com/detail/9nf8h0h7wmlt?tp=RHJpdmVyR2FtaW5nIE5C&rtc=1&hl=zh-cn&gl=US)

{{< imgx src="/img/nvidia-control-pannel-power-normal.png" alt="" width="700px" style="max-width: 100%;">}}

### 2. 不要使用Nvidia APP beta

Nvidia APP beta虽然相比Nvidia GeForce Experience更现代，但是会导致显存频率在低负载也全频率运行，进而功耗偏高导致风扇智能启停失效。推荐使用Nvidia GeForce Experience，并在游戏内覆盖（`alt + z`）中将性能里**风扇速度目标**设置为自动。

{{<img nvdia-youxineifugai-fan-speed-target.png 350>}}

## 手动风扇转速

### 使用MSI Afterburner(小飞机)设置

afterburner是一款显卡超频、风扇调教、游戏帧率监控软件，可用于所有品牌的nvidia显卡，下载地址:[微星网站下载](https://www.msi.com/Landing/afterburner/graphics-cards)或者[guru3d下载](https://www.guru3d.com/download/msi-afterburner-beta-download/)，这两个都是官方下载链接，不推荐在别的地方下载。我下载的版本是4.6.6(Beta)，虽然是Beta版本，但已经非常稳定，对40系显卡支持也比较好。

> **2024-07-08更新：发现微星的下载链接无效了，推荐走guru3d下载。**

本文主要介绍的是afterburner的风扇调教能力，超频和游戏帧率监控功能不在本文讨论范围内，后面可能会新开博客介绍。

**保持首页的转速设置为auto**

{{< imgx src="/img/afterburner-auto-speed.png" alt="" width="700px" style="max-width: 100%;">}}

注意，auto不开的话，风扇转速会被锁定在固定的速率。下面一节的手动设置转速也是**需要开启auto的**。

**手动设置转速**

在设定-风扇中手动设置转速变化曲线：

{{< imgx src="/img/afterburner-custom-speed.png" alt="" width="600px" style="max-width: 100%;">}}

不过我发现设置手动转速后，风扇最低转速是30%，无法停转。

### 使用FanControl设置

如果需要手动转速时能停转，则需要使用[FanControl](https://github.com/Rem0o/FanControl.Releases)，参考这个[Nvidia 30% and 0 RPM](https://github.com/Rem0o/FanControl.Releases/wiki/Nvidia-30%25-and-0-RPM)进行设置。FanControl功能很强大，可以设置一切风扇，包括机箱风扇、显卡风扇、CPU风扇、水冷水泵等。但用起来比较复杂，我个人觉得大部分人用风扇智能启停就行了。

{{<img fancontrol-overrides-nvidia-hardware-curve.png 500>}}
