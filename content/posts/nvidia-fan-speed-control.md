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

现在用的电脑显卡是4070 ti super + 13700kf，在调教CPU风扇和水泵风扇之后，还是一直有声音，通过aida64看了下，GPU风扇一直30%，于是看看怎么调整。


## nvidia控制面板电源管理模式选正常

在nvidia控制面板中，设置电源管理模式选正常，**不要选“最高性能优先”，不然GPU风扇最低为30%**，还是有点吵的。如果一定要在某些程序运行时设置最高性能有限，建议在“程序设置”中单独给程序设置。

![alt text](/img/nvidia-control-pannel-power-normal.png)

## msi afterburner中设置转速为auto

![alt text](/img/afterburner-auto-speed.png)

注意，auto不开的话，风扇转速会被锁定在固定的速率。并且在下面一节的**手动设置不同温度的转速也是需要开启auto的**。

auto开启后，并且在电源管理模式为“正常”的情况下，在低负载+低温度时风扇转速会是0，这时候显卡是完全静音的。开始打游戏后风扇会上来，停止游戏后过段时间，转速又会变为0，**这已经符合大部分人的需求吧**。

### 进阶：通过msi afterburner手动设置转速

> 不太建议手动设置，因为可能导致在温度阈值附近波动时，风扇频繁启停，第一声音比较烦人，第二是对风扇寿命也有影响。建议是直接开启auto即可。

![alt text](/img/afterburner-custom-speed.png)