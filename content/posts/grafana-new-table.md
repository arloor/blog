---
title: "Grafana表格Pannel配置"
date: 2023-11-18T15:24:33+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
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

![Alt text](/img/grafana-datasource_param.png)

## Query变量

> 以 `label_values` 查询为例。

**老版本UI**

需要自己写查询语句，而且这个查询语句不是Promql，只是长得像Promql。需要单独看文档，有学习成本，使用体验差。

![Alt text](/img/grafana-query_param_old.png)

**新版本UI(Grafana 10.0.3)**

![Alt text](/img/grafana-query_param_new.png)

## Panel query

![Alt text](/img/grafana-query-option.png)

## Pannel Transform

![Alt text](/img/grafana-transforms.png)


## Overrides

设置展示单位、展示精度、单元格样式、阈值、链接、不在表格中展示等。

![Alt text](/img/grafana-overrides.png)