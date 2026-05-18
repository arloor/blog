---
title: "量化介入股票扫描：筛选条件与图表整理"
date: 2026-05-18T22:10:00+08:00
lastmod: 2026-05-18T22:10:00+08:00
draft: false
categories: []
tags: ["A股"]
description: "整理一次 A 股量化介入扫描的筛选口径，以及 output 目录下已经生成的分时图。"
keywords:
- A股
- 量化扫描
- 盘口
- 成交量
---

这篇文章记录一下这个小项目当前使用的 A 股“量化介入”扫描口径，并把 `output` 目录下已经跑出来的分时图统一放进博客，方便后面复盘。这里不重新计算，只做整理。

<!--more-->

> 仅作为个人技术记录和复盘材料，不构成任何投资建议。

## 筛选条件

当前主扫描逻辑是从沪深 A 股里寻找“某一分钟成交量显著放大，并且随后价格继续向上”的形态。核心条件如下：

1. 股票池来自掘金量化接口 `get_symbol_infos(sec_type1=1010, sec_type2=101001, exchanges="SHSE,SZSE")`，覆盖沪深 A 股。
2. 只保留主板 A 股、创业板、科创板：`10100101`、`10100102`、`10100103`。
3. 扫描日内逐只股票拉取 tick 数据，并用 `cum_volume` 差分构建分钟成交量。
4. 只从 `10:00` 及之后的分钟中找最大成交量分钟，并要求这个分钟的最高价高于前一个交易分钟收盘价。
5. 该最大成交量分钟的成交量，需要大于 `10:00` 前最大一分钟成交量的 `2.5` 倍。
6. 将该分钟成交量除以该分钟内五档买卖盘口挂单总量的均值，默认要求比例 `>= 10`。
7. 在最大成交量分钟及之后 `5` 分钟内，价格相对该分钟前一个交易分钟收盘价需要上涨超过 `2%`。
8. 通过 `get_history_symbol.upper_limit` 取当日涨停价，若当日最高价触及涨停价，则排除。

显式参数大致是：

```powershell
.\.venv\Scripts\python.exe gm_quant_intrusion_scan.py `
  --workers 4 `
  --progress-every 100 `
  --volume-scan-start 10:00 `
  --pre-scan-volume-multiple 2.5 `
  --ratio-threshold 10 `
  --book-snapshot mean `
  --spike-threshold 0.02 `
  --spike-window-minutes 5
```

## 产出概览

本次共整理 `output` 目录下的 `96` 张分时图。

| 日期 | 分时图数量 |
|---|---:|
| 2026-05-12 | 22 |
| 2026-05-13 | 24 |
| 2026-05-14 | 16 |
| 2026-05-15 | 18 |
| 2026-05-18 | 16 |

## 图集

### 2026-05-12

#### 东安动力（SHSE.600178）

- 日期：2026-05-12
- 股票名：东安动力
- 股票代码：`SHSE.600178`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.600178_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `9.40`，成交量/盘口比 `11.93`，后续涨幅 `7.33%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.600178_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 信雅达（SHSE.600571）

- 日期：2026-05-12
- 股票名：信雅达
- 股票代码：`SHSE.600571`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.600571_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `7.70`，成交量/盘口比 `15.13`，后续涨幅 `2.65%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.600571_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 迪哲医药-U（SHSE.688192）

- 日期：2026-05-12
- 股票名：迪哲医药-U
- 股票代码：`SHSE.688192`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.688192_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `4.65`，成交量/盘口比 `19.40`，后续涨幅 `2.63%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.688192_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 泽璟制药-U（SHSE.688266）

- 日期：2026-05-12
- 股票名：泽璟制药-U
- 股票代码：`SHSE.688266`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.688266_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `2.86`，成交量/盘口比 `14.98`，后续涨幅 `4.51%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.688266_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 荣昌生物（SHSE.688331）

- 日期：2026-05-12
- 股票名：荣昌生物
- 股票代码：`SHSE.688331`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.688331_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `3.87`，成交量/盘口比 `16.27`，后续涨幅 `3.98%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.688331_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 益方生物-U（SHSE.688382）

- 日期：2026-05-12
- 股票名：益方生物-U
- 股票代码：`SHSE.688382`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.688382_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `5.91`，成交量/盘口比 `15.76`，后续涨幅 `8.21%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.688382_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 诺诚健华（SHSE.688428）

- 日期：2026-05-12
- 股票名：诺诚健华
- 股票代码：`SHSE.688428`
- 图片类型：分时图
- 来源：`output/20260512/charts/SHSE.688428_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `2.68`，成交量/盘口比 `12.00`，后续涨幅 `3.25%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SHSE.688428_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 三变科技（SZSE.002112）

- 日期：2026-05-12
- 股票名：三变科技
- 股票代码：`SZSE.002112`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.002112_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `4.92`，成交量/盘口比 `14.00`，后续涨幅 `5.07%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.002112_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 建设工业（SZSE.002265）

- 日期：2026-05-12
- 股票名：建设工业
- 股票代码：`SZSE.002265`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.002265_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `4.89`，成交量/盘口比 `10.09`，后续涨幅 `3.81%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.002265_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 万润科技（SZSE.002654）

- 日期：2026-05-12
- 股票名：万润科技
- 股票代码：`SZSE.002654`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.002654_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `5.50`，成交量/盘口比 `29.15`，后续涨幅 `3.42%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.002654_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 金时科技（SZSE.002951）

- 日期：2026-05-12
- 股票名：金时科技
- 股票代码：`SZSE.002951`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.002951_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `3.71`，成交量/盘口比 `11.25`，后续涨幅 `3.93%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.002951_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 朝阳科技（SZSE.002981）

- 日期：2026-05-12
- 股票名：朝阳科技
- 股票代码：`SZSE.002981`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.002981_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `3.92`，成交量/盘口比 `15.39`，后续涨幅 `2.56%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.002981_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 顺网科技（SZSE.300113）

- 日期：2026-05-12
- 股票名：顺网科技
- 股票代码：`SZSE.300113`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300113_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `3.95`，成交量/盘口比 `30.22`，后续涨幅 `2.70%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300113_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 赢合科技（SZSE.300457）

- 日期：2026-05-12
- 股票名：赢合科技
- 股票代码：`SZSE.300457`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300457_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `5.71`，成交量/盘口比 `13.78`，后续涨幅 `2.42%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300457_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 启迪设计（SZSE.300500）

- 日期：2026-05-12
- 股票名：启迪设计
- 股票代码：`SZSE.300500`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300500_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `6.97`，成交量/盘口比 `17.38`，后续涨幅 `2.86%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300500_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 晨曦航空（SZSE.300581）

- 日期：2026-05-12
- 股票名：晨曦航空
- 股票代码：`SZSE.300581`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300581_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `4.86`，成交量/盘口比 `13.05`，后续涨幅 `2.74%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300581_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 必创科技（SZSE.300667）

- 日期：2026-05-12
- 股票名：必创科技
- 股票代码：`SZSE.300667`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300667_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `4.01`，成交量/盘口比 `13.07`，后续涨幅 `3.08%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300667_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 中科信息（SZSE.300678）

- 日期：2026-05-12
- 股票名：中科信息
- 股票代码：`SZSE.300678`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300678_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `5.54`，成交量/盘口比 `19.75`，后续涨幅 `2.70%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300678_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 捷强装备（SZSE.300875）

- 日期：2026-05-12
- 股票名：捷强装备
- 股票代码：`SZSE.300875`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.300875_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `6.84`，成交量/盘口比 `16.12`，后续涨幅 `2.30%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.300875_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 北方长龙（SZSE.301357）

- 日期：2026-05-12
- 股票名：北方长龙
- 股票代码：`SZSE.301357`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.301357_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `6.07`，成交量/盘口比 `15.24`，后续涨幅 `4.57%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.301357_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 博苑新材（SZSE.301617）

- 日期：2026-05-12
- 股票名：博苑新材
- 股票代码：`SZSE.301617`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.301617_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `2.54`，成交量/盘口比 `12.50`，后续涨幅 `2.27%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.301617_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 中航成飞（SZSE.302132）

- 日期：2026-05-12
- 股票名：中航成飞
- 股票代码：`SZSE.302132`
- 图片类型：分时图
- 来源：`output/20260512/charts/SZSE.302132_20260512_intraday.png`
- 关键指标：10:00 后/前量比 `6.23`，成交量/盘口比 `19.83`，后续涨幅 `2.00%`

{{< imgx src="/img/quant-intrusion-scan/output/20260512/charts/SZSE.302132_20260512_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

### 2026-05-13

#### 永安期货（SHSE.600927）

- 日期：2026-05-13
- 股票名：永安期货
- 股票代码：`SHSE.600927`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.600927_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `9.93`，成交量/盘口比 `10.03`，后续涨幅 `2.88%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.600927_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 富佳股份（SHSE.603219）

- 日期：2026-05-13
- 股票名：富佳股份
- 股票代码：`SHSE.603219`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.603219_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `6.01`，成交量/盘口比 `11.17`，后续涨幅 `3.38%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.603219_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 微导纳米（SHSE.688147）

- 日期：2026-05-13
- 股票名：微导纳米
- 股票代码：`SHSE.688147`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.688147_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.50`，成交量/盘口比 `27.89`，后续涨幅 `2.57%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.688147_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 美迪西（SHSE.688202）

- 日期：2026-05-13
- 股票名：美迪西
- 股票代码：`SHSE.688202`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.688202_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.38`，成交量/盘口比 `20.02`，后续涨幅 `2.05%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.688202_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 浙海德曼（SHSE.688577）

- 日期：2026-05-13
- 股票名：浙海德曼
- 股票代码：`SHSE.688577`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.688577_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `4.46`，成交量/盘口比 `10.68`，后续涨幅 `5.25%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.688577_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 金博股份（SHSE.688598）

- 日期：2026-05-13
- 股票名：金博股份
- 股票代码：`SHSE.688598`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.688598_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.30`，成交量/盘口比 `12.09`，后续涨幅 `2.98%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.688598_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 中邮科技（SHSE.688648）

- 日期：2026-05-13
- 股票名：中邮科技
- 股票代码：`SHSE.688648`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.688648_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.50`，成交量/盘口比 `11.47`，后续涨幅 `3.19%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.688648_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 福立旺（SHSE.688678）

- 日期：2026-05-13
- 股票名：福立旺
- 股票代码：`SHSE.688678`
- 图片类型：分时图
- 来源：`output/20260513/charts/SHSE.688678_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `4.20`，成交量/盘口比 `11.83`，后续涨幅 `4.39%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SHSE.688678_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 平潭发展（SZSE.000592）

- 日期：2026-05-13
- 股票名：平潭发展
- 股票代码：`SZSE.000592`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.000592_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.36`，成交量/盘口比 `12.72`，后续涨幅 `2.89%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.000592_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 千味央厨（SZSE.001215）

- 日期：2026-05-13
- 股票名：千味央厨
- 股票代码：`SZSE.001215`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.001215_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `9.64`，成交量/盘口比 `25.14`，后续涨幅 `2.06%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.001215_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 富岭股份（SZSE.001356）

- 日期：2026-05-13
- 股票名：富岭股份
- 股票代码：`SZSE.001356`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.001356_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `10.51`，成交量/盘口比 `10.72`，后续涨幅 `2.72%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.001356_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 国轩高科（SZSE.002074）

- 日期：2026-05-13
- 股票名：国轩高科
- 股票代码：`SZSE.002074`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.002074_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `7.14`，成交量/盘口比 `30.00`，后续涨幅 `3.87%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.002074_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 全聚德（SZSE.002186）

- 日期：2026-05-13
- 股票名：全聚德
- 股票代码：`SZSE.002186`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.002186_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `5.90`，成交量/盘口比 `18.92`，后续涨幅 `3.89%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.002186_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 启明信息（SZSE.002232）

- 日期：2026-05-13
- 股票名：启明信息
- 股票代码：`SZSE.002232`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.002232_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `8.61`，成交量/盘口比 `16.53`，后续涨幅 `2.99%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.002232_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 蔚蓝锂芯（SZSE.002245）

- 日期：2026-05-13
- 股票名：蔚蓝锂芯
- 股票代码：`SZSE.002245`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.002245_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `2.55`，成交量/盘口比 `15.82`，后续涨幅 `2.34%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.002245_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 九安医疗（SZSE.002432）

- 日期：2026-05-13
- 股票名：九安医疗
- 股票代码：`SZSE.002432`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.002432_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `2.77`，成交量/盘口比 `37.89`，后续涨幅 `2.20%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.002432_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 启明星辰（SZSE.002439）

- 日期：2026-05-13
- 股票名：启明星辰
- 股票代码：`SZSE.002439`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.002439_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.43`，成交量/盘口比 `13.78`，后续涨幅 `2.33%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.002439_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 航宇微（SZSE.300053）

- 日期：2026-05-13
- 股票名：航宇微
- 股票代码：`SZSE.300053`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.300053_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.05`，成交量/盘口比 `26.60`，后续涨幅 `2.41%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.300053_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 海峡创新（SZSE.300300）

- 日期：2026-05-13
- 股票名：海峡创新
- 股票代码：`SZSE.300300`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.300300_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `4.54`，成交量/盘口比 `14.62`，后续涨幅 `3.82%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.300300_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 思特奇（SZSE.300608）

- 日期：2026-05-13
- 股票名：思特奇
- 股票代码：`SZSE.300608`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.300608_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `5.75`，成交量/盘口比 `14.45`，后续涨幅 `2.02%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.300608_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 广和通（SZSE.300638）

- 日期：2026-05-13
- 股票名：广和通
- 股票代码：`SZSE.300638`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.300638_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `4.91`，成交量/盘口比 `18.29`，后续涨幅 `2.44%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.300638_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 安克创新（SZSE.300866）

- 日期：2026-05-13
- 股票名：安克创新
- 股票代码：`SZSE.300866`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.300866_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `2.86`，成交量/盘口比 `17.57`，后续涨幅 `2.04%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.300866_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 海力风电（SZSE.301155）

- 日期：2026-05-13
- 股票名：海力风电
- 股票代码：`SZSE.301155`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.301155_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `11.94`，成交量/盘口比 `10.23`，后续涨幅 `5.15%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.301155_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 壹连科技（SZSE.301631）

- 日期：2026-05-13
- 股票名：壹连科技
- 股票代码：`SZSE.301631`
- 图片类型：分时图
- 来源：`output/20260513/charts/SZSE.301631_20260513_intraday.png`
- 关键指标：10:00 后/前量比 `3.16`，成交量/盘口比 `15.45`，后续涨幅 `5.12%`

{{< imgx src="/img/quant-intrusion-scan/output/20260513/charts/SZSE.301631_20260513_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

### 2026-05-14

#### 小商品城（SHSE.600415）

- 日期：2026-05-14
- 股票名：小商品城
- 股票代码：`SHSE.600415`
- 图片类型：分时图
- 来源：`output/20260514/charts/SHSE.600415_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `2.69`，成交量/盘口比 `19.53`，后续涨幅 `3.05%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SHSE.600415_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 先导基电（SHSE.600641）

- 日期：2026-05-14
- 股票名：先导基电
- 股票代码：`SHSE.600641`
- 图片类型：分时图
- 来源：`output/20260514/charts/SHSE.600641_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `2.61`，成交量/盘口比 `19.73`，后续涨幅 `2.15%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SHSE.600641_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 中马传动（SHSE.603767）

- 日期：2026-05-14
- 股票名：中马传动
- 股票代码：`SHSE.603767`
- 图片类型：分时图
- 来源：`output/20260514/charts/SHSE.603767_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `5.77`，成交量/盘口比 `11.19`，后续涨幅 `2.03%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SHSE.603767_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 鼎阳科技（SHSE.688112）

- 日期：2026-05-14
- 股票名：鼎阳科技
- 股票代码：`SHSE.688112`
- 图片类型：分时图
- 来源：`output/20260514/charts/SHSE.688112_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `2.58`，成交量/盘口比 `17.61`，后续涨幅 `2.56%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SHSE.688112_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 慧智微-U（SHSE.688512）

- 日期：2026-05-14
- 股票名：慧智微-U
- 股票代码：`SHSE.688512`
- 图片类型：分时图
- 来源：`output/20260514/charts/SHSE.688512_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `5.35`，成交量/盘口比 `12.60`，后续涨幅 `6.09%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SHSE.688512_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 高新发展（SZSE.000628）

- 日期：2026-05-14
- 股票名：高新发展
- 股票代码：`SZSE.000628`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.000628_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `3.17`，成交量/盘口比 `30.91`，后续涨幅 `4.56%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.000628_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 盈方微（SZSE.000670）

- 日期：2026-05-14
- 股票名：盈方微
- 股票代码：`SZSE.000670`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.000670_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `5.03`，成交量/盘口比 `10.64`，后续涨幅 `5.93%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.000670_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 维信诺（SZSE.002387）

- 日期：2026-05-14
- 股票名：维信诺
- 股票代码：`SZSE.002387`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.002387_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `3.81`，成交量/盘口比 `13.17`，后续涨幅 `4.02%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.002387_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 亚世光电（SZSE.002952）

- 日期：2026-05-14
- 股票名：亚世光电
- 股票代码：`SZSE.002952`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.002952_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `7.32`，成交量/盘口比 `20.00`，后续涨幅 `4.82%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.002952_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 竞业达（SZSE.003005）

- 日期：2026-05-14
- 股票名：竞业达
- 股票代码：`SZSE.003005`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.003005_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `9.64`，成交量/盘口比 `14.74`，后续涨幅 `3.66%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.003005_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 旗天科技（SZSE.300061）

- 日期：2026-05-14
- 股票名：旗天科技
- 股票代码：`SZSE.300061`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.300061_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `2.96`，成交量/盘口比 `10.75`，后续涨幅 `3.30%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.300061_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 昌红科技（SZSE.300151）

- 日期：2026-05-14
- 股票名：昌红科技
- 股票代码：`SZSE.300151`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.300151_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `5.67`，成交量/盘口比 `17.13`，后续涨幅 `2.11%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.300151_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 劲拓股份（SZSE.300400）

- 日期：2026-05-14
- 股票名：劲拓股份
- 股票代码：`SZSE.300400`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.300400_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `4.01`，成交量/盘口比 `17.99`，后续涨幅 `2.71%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.300400_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 宏达电子（SZSE.300726）

- 日期：2026-05-14
- 股票名：宏达电子
- 股票代码：`SZSE.300726`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.300726_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `2.98`，成交量/盘口比 `19.87`，后续涨幅 `2.99%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.300726_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 创益通（SZSE.300991）

- 日期：2026-05-14
- 股票名：创益通
- 股票代码：`SZSE.300991`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.300991_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `3.81`，成交量/盘口比 `15.35`，后续涨幅 `3.02%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.300991_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 欧圣电气（SZSE.301187）

- 日期：2026-05-14
- 股票名：欧圣电气
- 股票代码：`SZSE.301187`
- 图片类型：分时图
- 来源：`output/20260514/charts/SZSE.301187_20260514_intraday.png`
- 关键指标：10:00 后/前量比 `11.14`，成交量/盘口比 `11.31`，后续涨幅 `2.40%`

{{< imgx src="/img/quant-intrusion-scan/output/20260514/charts/SZSE.301187_20260514_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

### 2026-05-15

#### 迪贝电气（SHSE.603320）

- 日期：2026-05-15
- 股票名：迪贝电气
- 股票代码：`SHSE.603320`
- 图片类型：分时图
- 来源：`output/20260515/charts/SHSE.603320_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `2.63`，成交量/盘口比 `11.54`，后续涨幅 `3.14%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SHSE.603320_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 蔚蓝生物（SHSE.603739）

- 日期：2026-05-15
- 股票名：蔚蓝生物
- 股票代码：`SHSE.603739`
- 图片类型：分时图
- 来源：`output/20260515/charts/SHSE.603739_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `7.47`，成交量/盘口比 `10.69`，后续涨幅 `2.02%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SHSE.603739_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 能科科技（SHSE.603859）

- 日期：2026-05-15
- 股票名：能科科技
- 股票代码：`SHSE.603859`
- 图片类型：分时图
- 来源：`output/20260515/charts/SHSE.603859_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `6.06`，成交量/盘口比 `11.54`，后续涨幅 `2.38%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SHSE.603859_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 禾川科技（SHSE.688320）

- 日期：2026-05-15
- 股票名：禾川科技
- 股票代码：`SHSE.688320`
- 图片类型：分时图
- 来源：`output/20260515/charts/SHSE.688320_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `2.84`，成交量/盘口比 `13.17`，后续涨幅 `3.24%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SHSE.688320_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 南芯科技（SHSE.688484）

- 日期：2026-05-15
- 股票名：南芯科技
- 股票代码：`SHSE.688484`
- 图片类型：分时图
- 来源：`output/20260515/charts/SHSE.688484_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `2.64`，成交量/盘口比 `15.82`，后续涨幅 `2.52%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SHSE.688484_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 中控技术（SHSE.688777）

- 日期：2026-05-15
- 股票名：中控技术
- 股票代码：`SHSE.688777`
- 图片类型：分时图
- 来源：`output/20260515/charts/SHSE.688777_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `3.05`，成交量/盘口比 `14.43`，后续涨幅 `2.26%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SHSE.688777_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 正泰电源（SZSE.002150）

- 日期：2026-05-15
- 股票名：正泰电源
- 股票代码：`SZSE.002150`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.002150_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `4.99`，成交量/盘口比 `22.51`，后续涨幅 `2.01%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.002150_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 成飞集成（SZSE.002190）

- 日期：2026-05-15
- 股票名：成飞集成
- 股票代码：`SZSE.002190`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.002190_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `3.34`，成交量/盘口比 `20.20`，后续涨幅 `2.74%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.002190_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 环球印务（SZSE.002799）

- 日期：2026-05-15
- 股票名：环球印务
- 股票代码：`SZSE.002799`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.002799_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `6.91`，成交量/盘口比 `13.55`，后续涨幅 `3.58%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.002799_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 比音勒芬（SZSE.002832）

- 日期：2026-05-15
- 股票名：比音勒芬
- 股票代码：`SZSE.002832`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.002832_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `2.90`，成交量/盘口比 `12.45`，后续涨幅 `2.03%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.002832_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 阳光电源（SZSE.300274）

- 日期：2026-05-15
- 股票名：阳光电源
- 股票代码：`SZSE.300274`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.300274_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `3.11`，成交量/盘口比 `72.50`，后续涨幅 `6.86%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.300274_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 汉宇集团（SZSE.300403）

- 日期：2026-05-15
- 股票名：汉宇集团
- 股票代码：`SZSE.300403`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.300403_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `10.46`，成交量/盘口比 `10.46`，后续涨幅 `2.34%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.300403_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 华辰装备（SZSE.300809）

- 日期：2026-05-15
- 股票名：华辰装备
- 股票代码：`SZSE.300809`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.300809_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `16.01`，成交量/盘口比 `25.89`，后续涨幅 `7.79%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.300809_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 恒辉安防（SZSE.300952）

- 日期：2026-05-15
- 股票名：恒辉安防
- 股票代码：`SZSE.300952`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.300952_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `3.48`，成交量/盘口比 `10.37`，后续涨幅 `2.15%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.300952_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 鼎熔岩（SZSE.301028）

- 日期：2026-05-15
- 股票名：鼎熔岩
- 股票代码：`SZSE.301028`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.301028_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `4.63`，成交量/盘口比 `10.15`，后续涨幅 `2.97%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.301028_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 恒工精密（SZSE.301261）

- 日期：2026-05-15
- 股票名：恒工精密
- 股票代码：`SZSE.301261`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.301261_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `3.72`，成交量/盘口比 `10.38`，后续涨幅 `2.87%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.301261_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 福赛科技（SZSE.301529）

- 日期：2026-05-15
- 股票名：福赛科技
- 股票代码：`SZSE.301529`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.301529_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `3.69`，成交量/盘口比 `19.72`，后续涨幅 `2.64%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.301529_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 首航新能（SZSE.301658）

- 日期：2026-05-15
- 股票名：首航新能
- 股票代码：`SZSE.301658`
- 图片类型：分时图
- 来源：`output/20260515/charts/SZSE.301658_20260515_intraday.png`
- 关键指标：10:00 后/前量比 `5.86`，成交量/盘口比 `34.11`，后续涨幅 `3.31%`

{{< imgx src="/img/quant-intrusion-scan/output/20260515/charts/SZSE.301658_20260515_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

### 2026-05-18

#### 中望软件（SHSE.688083）

- 日期：2026-05-18
- 股票名：中望软件
- 股票代码：`SHSE.688083`
- 图片类型：分时图
- 来源：`output/20260518/charts/SHSE.688083_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `2.51`，成交量/盘口比 `11.64`，后续涨幅 `2.80%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SHSE.688083_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 南网科技（SHSE.688248）

- 日期：2026-05-18
- 股票名：南网科技
- 股票代码：`SHSE.688248`
- 图片类型：分时图
- 来源：`output/20260518/charts/SHSE.688248_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `3.07`，成交量/盘口比 `18.31`，后续涨幅 `3.49%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SHSE.688248_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 财富趋势（SHSE.688318）

- 日期：2026-05-18
- 股票名：财富趋势
- 股票代码：`SHSE.688318`
- 图片类型：分时图
- 来源：`output/20260518/charts/SHSE.688318_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `2.67`，成交量/盘口比 `20.25`，后续涨幅 `2.08%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SHSE.688318_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 孚能科技（SHSE.688567）

- 日期：2026-05-18
- 股票名：孚能科技
- 股票代码：`SHSE.688567`
- 图片类型：分时图
- 来源：`output/20260518/charts/SHSE.688567_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `5.10`，成交量/盘口比 `13.44`，后续涨幅 `3.11%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SHSE.688567_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 新致软件（SHSE.688590）

- 日期：2026-05-18
- 股票名：新致软件
- 股票代码：`SHSE.688590`
- 图片类型：分时图
- 来源：`output/20260518/charts/SHSE.688590_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `8.01`，成交量/盘口比 `13.28`，后续涨幅 `2.00%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SHSE.688590_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 星网宇达（SZSE.002829）

- 日期：2026-05-18
- 股票名：星网宇达
- 股票代码：`SZSE.002829`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.002829_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `3.16`，成交量/盘口比 `10.24`，后续涨幅 `4.15%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.002829_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 鼎捷数智（SZSE.300378）

- 日期：2026-05-18
- 股票名：鼎捷数智
- 股票代码：`SZSE.300378`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.300378_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `5.30`，成交量/盘口比 `17.98`，后续涨幅 `2.15%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.300378_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 丝路视觉（SZSE.300556）

- 日期：2026-05-18
- 股票名：丝路视觉
- 股票代码：`SZSE.300556`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.300556_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `3.10`，成交量/盘口比 `10.64`，后续涨幅 `2.22%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.300556_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 广和通（SZSE.300638）

- 日期：2026-05-18
- 股票名：广和通
- 股票代码：`SZSE.300638`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.300638_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `2.88`，成交量/盘口比 `22.72`，后续涨幅 `4.45%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.300638_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 申昊科技（SZSE.300853）

- 日期：2026-05-18
- 股票名：申昊科技
- 股票代码：`SZSE.300853`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.300853_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `3.18`，成交量/盘口比 `18.67`，后续涨幅 `3.20%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.300853_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 国安达（SZSE.300902）

- 日期：2026-05-18
- 股票名：国安达
- 股票代码：`SZSE.300902`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.300902_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `11.51`，成交量/盘口比 `14.92`，后续涨幅 `9.07%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.300902_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 国能日新（SZSE.301162）

- 日期：2026-05-18
- 股票名：国能日新
- 股票代码：`SZSE.301162`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.301162_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `2.60`，成交量/盘口比 `12.62`，后续涨幅 `2.35%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.301162_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 软通动力（SZSE.301236）

- 日期：2026-05-18
- 股票名：软通动力
- 股票代码：`SZSE.301236`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.301236_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `3.16`，成交量/盘口比 `15.41`，后续涨幅 `3.39%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.301236_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 汉朔科技（SZSE.301275）

- 日期：2026-05-18
- 股票名：汉朔科技
- 股票代码：`SZSE.301275`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.301275_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `3.39`，成交量/盘口比 `23.12`，后续涨幅 `3.06%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.301275_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 蓝箭电子（SZSE.301348）

- 日期：2026-05-18
- 股票名：蓝箭电子
- 股票代码：`SZSE.301348`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.301348_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `7.46`，成交量/盘口比 `30.88`，后续涨幅 `2.17%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.301348_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}

#### 盘古智能（SZSE.301456）

- 日期：2026-05-18
- 股票名：盘古智能
- 股票代码：`SZSE.301456`
- 图片类型：分时图
- 来源：`output/20260518/charts/SZSE.301456_20260518_intraday.png`
- 关键指标：10:00 后/前量比 `7.88`，成交量/盘口比 `17.14`，后续涨幅 `3.27%`

{{< imgx src="/img/quant-intrusion-scan/output/20260518/charts/SZSE.301456_20260518_intraday.png" alt="" width="900px" style="max-width: 100%;" >}}
