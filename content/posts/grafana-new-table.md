---
title: "Grafana表格Pannel配置"
date: 2023-11-18T15:24:33+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

忘记了怎么在Grafana中配置表格，今天来记录下。

![Alt text](/img/grafana-table-pannel.png)
<!--more-->

将分几个部份讲


| 要点 | 说明 |
|---|---|
| Datasource变量 | 用于动态选取数据源，方便切换不同的Prometheus、ES、Clickhouse等 |
| Query变量 | 使用查询结果作为变量，例如label_names、label_values查询的结果 |
| Pannel Query | **before查询：** 定义Promql和查询option例如：legend名称、Min step、Format和type（Range、Instant） |
| Pannel Transform | **after查询：** 对Pannel query的查询结果进行一些修改 |
| Overrides | **when渲染：** 渲染图表时的配置 |

回忆[Grafana查询抽象](https://www.arloor.com/posts/grafana-docs/#grafana%E6%9F%A5%E8%AF%A2%E6%8A%BD%E8%B1%A1)中的内容，实际上要点234就是在控制Grafana的各个流程：

> After the data is sourced, queried, and transformed, it passes to a panel, which is the final gate in the journey to a Grafana visualization.

## Datasource变量

> 参考文档[dashboards variables](https://grafana.com/docs/grafana/latest/dashboards/variables/add-template-variables/)

![Alt text](/img/grafana-datasource_param.png)

## Query变量

> 以 `label_values` 查询为例。

**老版本UI**

需要自己写查询语句，而且这个查询语句不是Promql，只是长得像Promql。需要单独看文档，有学习成本，使用体验差。

![Alt text](/img/grafana-query_param_old.png)

**新版本UI(Grafana 10.0.3)**

![Alt text](/img/grafana-query_param_new.png)

## Panel query

> 参考文档：[prometheus query-editor](https://grafana.com/docs/grafana/latest/datasources/prometheus/query-editor/)

![Alt text](/img/grafana-query-option.png)

## Pannel Transform

![Alt text](/img/grafana-transforms.png)


## Overrides

> 参考文档[visualizations table](https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/table/)

设置展示单位、展示精度、单元格样式、阈值、链接、不在表格中展示等。

![Alt text](/img/grafana-overrides.png)

### 设置datalink

![Alt text](/img/grafana-datalink-param.png)

核心是pannel中的变量如何传递，详见参考文档[https://grafana.com/docs/grafana/latest/panels-visualizations/configure-data-links/](https://grafana.com/docs/grafana/latest/panels-visualizations/configure-data-links/)

### 表格中的列禁止adhoc filterable

这个adhoc filterable对应的是这种[ad hoc filters](https://grafana.com/docs/grafana/latest/dashboards/variables/add-template-variables/#add-ad-hoc-filters)这种变量

![Alt text](/img/adhoc-filter-false.png)

### 给Pannel单独设置时间范围为Today

![Alt text](/img/grafana-pannel-relative-time-today.png)

**Relative time：**

覆盖dashboard右上角的relative time（对绝对时间不生效）。主要有两种格式：

- now-5m或者5m：都表示last 5min
- now/d: 表示today so far。 `/d`可以理解为整除day，进而可以理解为对齐到day的开始，也就是当天0点了。
- now-5d/d: 表示从5天前的00:00到现在。`/d`对齐到了00:00

**Time shift：**

time shift是将relative time的开始时间和结束时间都往前偏移一段时间，也只在时间选择框是相对时间时生效。例如：

- 1d/d或者1d：开始时间和结束时间都偏移一天
- 0d/d: 将开始时间和结束时间都对齐到00:00。**这样也就是实现了today。**包括1m/d=0d/d，因为1m整除d就是0d整除d

总的来讲，关键要理解，`/d`、`/w`、`/y`都是整除，整除就可以理解为对齐到整day、整week、整year。可以自己到[Playground: Time range override.](https://play.grafana.org/d/000000041/)修改试试看。

参考：

1. [set-dashboard-time-range](https://grafana.com/docs/grafana/latest/dashboards/use-dashboards/#set-dashboard-time-range) 
2. [use-relative-time-with-this-year](https://community.grafana.com/t/use-relative-time-with-this-year/59910/5)
3. [#query-options](https://grafana.com/docs/grafana/latest/panels-visualizations/query-transform-data/#query-options)
