---
title: "Clickhoust使用学习"
date: 2020-08-14T14:37:51+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

- 机器环境：centos7 2G内存
<!--more-->

## 安装

参考文档： https://clickhouse.tech/docs/en/getting-started/install/

```shell
# 需要cpu支持 SSE 4.2
grep -q sse4_2 /proc/cpuinfo &&{
echo "SSE 4.2 supported" 
yum install -y yum-utils
rpm --import https://repo.clickhouse.tech/CLICKHOUSE-KEY.GPG
yum-config-manager --add-repo https://repo.clickhouse.tech/rpm/stable/x86_64
yum install clickhouse-server clickhouse-client
service clickhouse-server start
service clickhouse-server status
echo "config @ /etc/clickhouse-server/config.xml"
echo 
} || echo "SSE 4.2 not supported"
```

注：clickhouse的服务是用的`/etc/init.d`下的启动脚本

**测试安装是否成功**

```
clickhouse-client
select 1
```

效果如下图
<img src="/img/clickhouse-client.png" alt="" width="600px" style="max-width: 100%;">