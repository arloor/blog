---
title: "Nvidia显卡风扇转速设置"
date: 2024-05-12T19:18:49+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 工具介绍——微型afterburner(俗称小飞机)

afterburner是一款显卡超频、风扇调教、游戏帧率监控软件，可用于所有品牌的nvidia显卡，下载地址:[微星网站下载](https://www.msi.com/Landing/afterburner/graphics-cards)或者[guru3d下载](https://www.guru3d.com/download/msi-afterburner-beta-download/)，这两个都是官方下载链接，不推荐在别的地方下载。我下载的版本是4.6.6(Beta)，虽然是Beta版本，但已经非常稳定，对40系显卡支持也比较好。**2024-07-08更新：发现微星的下载链接无效了，推荐走guru3d下载。**

本文主要介绍的是afterburner的风扇调教能力，超频和游戏帧率监控功能不在本文讨论范围内，后面可能会新开博客介绍。

## 推荐：Nvidia控制面板电源管理模式选正常！正常！正常！

**如果没动过这个选项，或者压根没听过Nvidia控制面板，则不需要执行下列操作**

B站有UP主建议电源管理模式选“最高性能优先”，以获得最好的显示效果和响应速度。但是实测这并不会影响显示效果，倒是会让风扇的**智能启停**功能失效，导致在低负载时也**会以30%转速运行**，这样会有一定的噪音。因此，如果想要静音，我推荐在Nvidia控制面板中，将电源管理模式设置成正常。

![alt text](/img/nvidia-control-pannel-power-normal.png)

注意：nvidia控制面板在windows11中需要在microsoft store中下载，直达链接[https://apps.microsoft.com/detail/9nf8h0h7wmlt?tp=RHJpdmVyR2FtaW5nIE5C&rtc=1&hl=zh-cn&gl=US](https://apps.microsoft.com/detail/9nf8h0h7wmlt?tp=RHJpdmVyR2FtaW5nIE5C&rtc=1&hl=zh-cn&gl=US)

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

我使用的是14cm的风扇，均为PWM调速，使用Fan Control这个软件([下载地址](https://getfancontrol.com/))获得了几个关键转速：

| PWM百分比 | RPM | 说明 |
| --- | --- | --- |
| 0% | 0 | 停转，不推荐 |
| 20% | 500 | 基本无声音 |
| 25% | 650 | 基本无声音 |
| 30% | 800 | 声音很小，可以忽略 |
| 40% | 1000 | 声音很小，但能听到 |
| 50% | 1300 | 有明显声音 |
| 60% | 1500 | 中负载下，有明显声音 |
| 80% | 2000 | 重负载下，有明显声音 |
| 100% | 2500 | 不设置，声音很大，收益很小 |

![alt text](/img/fancontrol-auto-detect-speed.png)

至于转速设置我并没有使用Fan control，而是在BIOS设置的。下图是我BIOS中的风扇转速设置，核心思路有几个点

1. 55度以内都是25%，不超过650转，保证无负载时的安静（对于我的13700kf，大部分内容可以认为是无负载的）
2. 60度以内不超过1000转，保证日常轻负载的安静
3. 70度以内，不超过2000转。
3. 80度开始，全速运行。在我的散热条件下，基本不会达到80度，所以这个设置基本不会生效。

![alt text](/img/bios-cpu-fan-control.bmp)

另外fan step up可以设置一定延迟，比如0.3s，防止突发高负载导致风扇突增fan step down可以灵敏点。

我的思路和Macbook Pro的风扇调教很像，在腾讯lemon cleaner中看到在50度以下mac的风扇都是不转的：

{{< imgx src="/img/mac-lemon-cleaner-fan-stop-under-50.png" alt="" width="400px" style="max-width: 100%;">}}

## BIOS降压

从12代Intel CPUk开始，都有加入了CEP功能，导致CPU电压过高，温度过高，功耗过高。这里参考[【调调BIOS CPU就能暴降30度？！微星B板Z板新微码降压教程 + TRYX全球首款曲面屏水冷测试 【翼王工作室】】 【精准空降到 15:02】](https://www.bilibili.com/video/BV1sZ421Y7H1/?share_source=copy_web&vd_source=38a28c20d917b5ddaf8230ed27e499ff&t=902)给我的13700kf+b760迫击炮2代的组合做到性能无损的情况下降低功耗，降低CPU温度，效果非常显著，下面是我的bios配置：


- AC Loadline: [Auto]->[65]
- Microcode Selection: [自动]->[No UVP]
- 扩展内存预设技术(XMP)：[禁止]->[预设文件1]
- CPU Core Voltage Offset Mode：[自动]->[ -(By CPU)]
- CPU Core Voltage Offset: [Auto]->[0.160]
- CPU Lite Load Control: [Normal]->[高级]
- CPU AC Loadline: [Auto]->[65]
- CPU重载线校准控制：[自动]->[Mode 6]

2024-06-17更新：我把CPU换成了14600kf来使用B760m主板的关闭CEP功能，参考的操作在[【调调BIOS CPU就能暴降30度？！微星B板Z板新微码降压教程 + TRYX全球首款曲面屏水冷测试 【翼王工作室】】 【精准空降到 10:47】]( https://www.bilibili.com/video/BV1sZ421Y7H1/?share_source=copy_web&vd_source=38a28c20d917b5ddaf8230ed27e499ff&t=647)

> 参考视频下的评论：刚手动调完参数，不是给得很极限，可以给做参考。14600kf，微星b760迫击炮2代，123h微码，AC10，DC110，防降压mode7，R23跑分功耗从200-205W下降到150-155W，降幅接近25%；；FPU烤机功耗从180W峰值下降到145W不到，降幅20%。电压方面，R23烤机从1.286V下降到1.166V，FPU烤机则是从1.268V下降到1.142V，均过了R23烤机30分钟测试和10分钟以上的FPU烤机。单看效果来说只能说非常明显，全程没有蓝过一次屏，甚至感觉还能再降，不知道手头这颗的体制怎么样。