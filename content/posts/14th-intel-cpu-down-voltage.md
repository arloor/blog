---
title: "14600KF降压（123微码）以及风扇调教"
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

现在用的电脑CPU是14600kf，记录下CPU降压操作和对风扇的调教。整体调教方向是日常无声音+游戏时散热够用即可。最终效果是

1. 水泵风扇（3pin接口，只能DC调速），常态下4.0v电压，1100转，有轻微声音
2. 冷排风扇轻负载下650转以下，基本听不到声音 
<!--more-->

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

{{< imgx src="/img/fancontrol-auto-detect-speed.png" alt="" width="900px" style="max-width: 100%;">}}

至于转速设置我并没有使用Fan control，而是在BIOS设置的。下图是我BIOS中的风扇转速设置，核心思路有几个点

1. 55度以内都是25%，不超过650转，保证无负载时的安静（对于我的13700kf，大部分内容可以认为是无负载的）
2. 60度以内不超过1000转，保证日常轻负载的安静
3. 70度以内，不超过2000转。
3. 80度开始，全速运行。在我的散热条件下，基本不会达到80度，所以这个设置基本不会生效。

{{< imgx src="/img/bios-cpu-fan-control.jpg" alt="" width="600px" style="max-width: 100%;">}}

另外fan step up可以设置一定延迟，比如0.3s，防止突发高负载导致风扇突增fan step down可以灵敏点。

我的思路和Macbook Pro的风扇调教很像，在腾讯lemon cleaner中看到在50度以下mac的风扇都是不转的：

{{< imgx src="/img/mac-lemon-cleaner-fan-stop-under-50.png" alt="" width="400px" style="max-width: 100%;">}}

## BIOS降压

从12代Intel CPUk开始，都有加入了CEP功能，导致CPU电压过高，温度过高，功耗过高。这里参考[【调调BIOS CPU就能暴降30度？！微星B板Z板新微码降压教程 + TRYX全球首款曲面屏水冷测试 【翼王工作室】】 【精准空降到 08:19】](https://www.bilibili.com/video/BV1sZ421Y7H1/?share_source=copy_web&vd_source=38a28c20d917b5ddaf8230ed27e499ff&t=499)给我的14600kf+b760迫击炮2代的组合做到性能无损的情况下降低功耗，降低CPU温度，效果非常显著，下面是我的bios配置：


- AC Loadline: [Auto]->[10]
- IA CEP Support For 14th: [允许]->[禁止]
- 扩展内存预设技术(XMP)：[禁止]->[预设文件1]
- CPU Lite Load Control: [Normal]->[高级]
- CPU AC Loadline: [Auto]->[10]
- CPU重载线校准控制：[自动]->[Mode 7]

> 参考视频下的评论：刚手动调完参数，不是给得很极限，可以给做参考。14600kf，微星b760迫击炮2代，123h微码，AC10，DC110，防降压mode7，R23跑分功耗从200-205W下降到150-155W，降幅接近25%；；FPU烤机功耗从180W峰值下降到145W不到，降幅20%。电压方面，R23烤机从1.286V下降到1.166V，FPU烤机则是从1.268V下降到1.142V，均过了R23烤机30分钟测试和10分钟以上的FPU烤机。单看效果来说只能说非常明显，全程没有蓝过一次屏，甚至感觉还能再降，不知道手头这颗的体制怎么样。

后面我又增加了 PL1=180w PL2=180w ICC_MAX=240 的限制