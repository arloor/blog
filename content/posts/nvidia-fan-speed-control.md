---
title: "Nvidia显卡风扇转速设置"
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

<!--more-->

## 工具介绍——微星afterburner(俗称小飞机)

afterburner是一款显卡超频、风扇调教、游戏帧率监控软件，可用于所有品牌的nvidia显卡，下载地址:[微星网站下载](https://www.msi.com/Landing/afterburner/graphics-cards)或者[guru3d下载](https://www.guru3d.com/download/msi-afterburner-beta-download/)，这两个都是官方下载链接，不推荐在别的地方下载。我下载的版本是4.6.6(Beta)，虽然是Beta版本，但已经非常稳定，对40系显卡支持也比较好。**2024-07-08更新：发现微星的下载链接无效了，推荐走guru3d下载。**

本文主要介绍的是afterburner的风扇调教能力，超频和游戏帧率监控功能不在本文讨论范围内，后面可能会新开博客介绍。

## 推荐：Nvidia控制面板电源管理模式选正常！正常！正常！

**如果没动过这个选项，或者压根没听过Nvidia控制面板，则不需要执行下列操作**

B站有UP主建议电源管理模式选“最高性能优先”，以获得最好的显示效果和响应速度。但是实测这并不会影响显示效果，倒是会让风扇的**智能启停**功能失效，导致在低负载时也**会以30%转速运行**，这样会有一定的噪音。因此，如果想要静音，我推荐在Nvidia控制面板中，将电源管理模式设置成正常。

{{< imgx src="/img/nvidia-control-pannel-power-normal.png" alt="" width="700px" style="max-width: 100%;">}}

注意：nvidia控制面板在windows11中需要在microsoft store中下载，直达链接[https://apps.microsoft.com/detail/9nf8h0h7wmlt?tp=RHJpdmVyR2FtaW5nIE5C&rtc=1&hl=zh-cn&gl=US](https://apps.microsoft.com/detail/9nf8h0h7wmlt?tp=RHJpdmVyR2FtaW5nIE5C&rtc=1&hl=zh-cn&gl=US)

## 转速设置为auto，让显卡自己决定转速

{{< imgx src="/img/afterburner-auto-speed.png" alt="" width="700px" style="max-width: 100%;">}}

注意，auto不开的话，风扇转速会被锁定在固定的速率。而且下面一节的**手动设置转速也是需要开启auto的**。

auto开启后，在低负载+低温度（并没有明确温度阈值）时风扇转速会是0，这时候显卡是完全静音的。开始打游戏后风扇转速会上来。停止游戏后过段时间，转速又会变为0。这就是智能启停。

## 手动设置转速

如果不喜欢auto的智能启停，也可以手动设置转速。但是我发现手动设置时，转速最低为30%，无法停转。即使可以停转，在温度阈值附近频繁启停也不好，还是auto那种没有明确温度阈值的情况比较好，更“智能”。

{{< imgx src="/img/afterburner-custom-speed.png" alt="" width="600px" style="max-width: 100%;">}}

