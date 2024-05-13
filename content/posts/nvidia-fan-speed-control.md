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

现在用的电脑是4070 ti super + 13700kf，记录下对风扇的调教。整体调教方向是日常无声音+游戏时散热够用即可。最终效果是

1. 水泵风扇（3pin接口，只能DC调速），常态下4.0v电压，1100转，有轻微声音
2. 冷排风扇轻负载下800转以下，基本听不到声音 
3. N卡风扇常态下风扇停转，玩游戏后开始转，停止游戏后过段时间又停转
<!--more-->


## nvidia显卡风扇设置

### nvidia控制面板电源管理模式选正常

在nvidia控制面板中，设置电源管理模式选正常，**不要选“最高性能优先”，不然GPU风扇最低为30%**，还是有点吵的。如果一定要在某些程序运行时设置最高性能有限，建议在“程序设置”中单独给程序设置。

![alt text](/img/nvidia-control-pannel-power-normal.png)

### msi afterburner中设置转速为auto

![alt text](/img/afterburner-auto-speed.png)

注意，auto不开的话，风扇转速会被锁定在固定的速率。并且在下面一节的**手动设置不同温度的转速也是需要开启auto的**。

auto开启后，并且在电源管理模式为“正常”的情况下，在低负载+低温度（并没有明确温度阈值）时风扇转速会是0，这时候显卡是完全静音的。开始打游戏后风扇会上来，停止游戏后过段时间，转速又会变为0，**这已经符合大部分人的需求吧**。

#### 进阶：通过msi afterburner手动设置转速

> 不太建议手动设置，因为我发现手动设置时，转速最低为30%，无法停转。不过即使可以停转，在温度阈值附近频繁启停也不好，还是auto那种没有明确温度阈值的情况比较好，更“智能”。

![alt text](/img/afterburner-custom-speed.png)

## 水泵风扇调教

因为我的水泵风扇（准确说是螺旋桨）是3pin接口，只能DC调速，最低设置到4.0v，再低水泵就停转了。日常就使用4.0v的电压，此时风扇转速为1100转，有轻微声音，但是基本听不到。

在高负载时则是全速运行，此时声音已经被其他风扇盖过了。

## 冷排风扇调教

我使用的是14cm的风扇，均为PWM调速，使用Fan Control这个软件获得了几个关键转速：

| PWM百分比 | RPM | 说明 |
| --- | --- | --- |
| 0% | 0 | 停转，不推荐 |
| 20% | 500 | 基本无声音 |
| 30% | 800 | 声音很小，可以忽略 |
| 40% | 1000 | 声音很小，但能听到 |
| 50% | 1300 | 有明显声音 |
| 60% | 1500 | 中负载下，有明显声音 |
| 80% | 2000 | 重负载下，有明显声音 |
| 100% | 2500 | 不设置，声音很大，收益很小 |

![alt text](/img/fancontrol-auto-detect-speed.png)

下图是我BIOS中的风扇转速设置，核心思路有几个点

1. 最低为20%，以避免停转。55度以内都是20%，保证无负载时的安静（对于我的13700kf，大部分内容可以认为是无负载的）
2. 70度以内不超过1000转，保证日常轻负载的安静
3. 80度开始，以2000转运行，转速再高的收益就不明显了，声音反而太大

![alt text](/img/bios-cpu-fan-control.bmp)

另外fan step up可以设置一定延迟，比如0.3s，防止突发高负载导致风扇突增fan step down可以灵敏点。

我的思路和Macbook Pro的风扇调教很像，在腾讯lemon cleaner中看到在50度以下mac的风扇都是不转的：

{{< imgx src="/img/mac-lemon-cleaner-fan-stop-under-50.png" alt="" width="400px" style="max-width: 100%;">}}

## 备选水泵和冷排风扇转速设置

**备用1**

![alt text](/img/bios-second-cpu-fan-control.bmp)

**备用2**

![alt text](/img/bios-third-cpu-fan-control.bmp)

**备用3**

![alt text](/img/bios-fourth-cpu-fan-control.bmp)