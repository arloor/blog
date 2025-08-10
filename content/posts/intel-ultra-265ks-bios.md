---
title: "Ultra 265k BIOS/风扇设置"
subtitle:
tags:
  - undefined
date: 2025-07-27T14:41:54+08:00
lastmod: 2025-07-27T14:41:54+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
---

<!--more-->

## 系统配置

2024 年 12 月 15 日更新：换了硬件，老硬件只保留了电源、显卡、内存

| 组件   | 型号                                                  |
| ------ | ----------------------------------------------------- |
| CPU    | Intel Ultra 265k                                      |
| 主板   | MSI z890 carbon wifi                                  |
| 显卡   | 七彩虹 5070 ti 战斧豪华版 16GB (原价 6299 购入，血赚) |
| 内存   | 威刚 D500G 8800 频率 24Gx2 海力士 M-die               |
| 机箱   | 恩杰 H5 flow                                          |
| 散热器 | 猫头鹰 D15 g2                                         |
| 风扇   | 6x 猫头鹰 `NF-A12X25` + 2x 猫头鹰 `NF-A14`                |
| 电源   | 海韵 GX850                                            |

## 风扇转速

目前用了 CPU 风扇、系统风扇 3 和 4（显卡下方风扇）、系统风扇 5（使用风扇集线器控制其他所有），都使用了下面的风扇转速曲线：

{{<img Snipaste_2024-12-15_01-14-53.png 800>}}

## 大小核心

跟以往不同的是，Ultra 200s 的大小核交替排列。针对 265k 来说，大核是 CPU1、2、7、8、9、10、19、20，如下图所示：

{{<img 265k-cpu-sort.png 450>}}

## BIOS 设置

- 内存直接用了`Memory Try It`的在`DDR5-8600 CL42`下，再往上 8800 的话，TM5 测试就报错了。不知道是 IMC 控制器的问题还是主板的瓶颈。
- 性能预设选了 `MSI Extreme Settings`
- 开启 Wake on LAN：进入`Advanced`页面，找到`Wake Up Event Setup`，然后打开 `Resume by PCIE/Networking Device`。BIOS 还会自动关闭`Erp Ready`选项。`ErP Ready` 是指系统在关机状态下会减少待机功耗，例如关闭所有的待机设备电源，从而使整机的待机功耗降低到 1 瓦以下（通常这是 ErP 的最低要求）

{{<img bios_screenshot.png 800>}}
