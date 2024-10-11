---
title: "Grafana告警配置"
subtitle:
tags: 
- software
date: 2024-10-11T16:22:26+08:00
lastmod: 2024-10-11T16:22:26+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---
<!--more-->

## 查询和告警条件配置

- 查询时间
- 查询语句
- reduce语句
- 告警阈值

{{<img grafana_query_and_alert_condition.png 800>}}

## 评估行为配置

- 评估间隔
- 触发周期
- nodata行为

{{<img grafana_set_evalutation_behavior.png 500>}}

## 联络点

{{<img grafana_contactor.png  500>}}

其中邮件通知需要在 `grafana.ini` 中[配置smtp服务器](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-email/)：

```ini
[smtp]
enabled = true
host = smtp.vip.163.com:465
user = xxxxxx@163.com
password = xxxxxxx
from_address = xxxxxx@163.com
from_name = Grafana告警
```

## 通知策略

特别注意： Group interval 控制组内通知的间隔。设置5min的话，告警和恢复的通知会间隔5min，即使1min后就恢复了。并且如果5min内多次告警并恢复，后续的告警和恢复通知会被吞没。

{{<img grafana_Edit_notification_policy.png 700>}}

## 其他备忘

- [Configure Grafana HTTPS](https://grafana.com/docs/grafana/latest/setup-grafana/set-up-https/#configure-grafana-https-and-restart-grafana)