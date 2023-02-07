---
title: "acme.sh签发dnspod(腾讯云)和阿里云ssl野卡证书并自动续签"
date: 2020-04-19T13:20:07+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

用一下acme.sh，实现自动签发野卡证书的需求
<!--more-->

## 下载安装acme.sh

```
curl https://get.acme.sh | sh
```

## 注册账号

```
acme.sh --register-account -m xxxx@qq.com
```

主要用于acme给你通知，例如某些证书被吊销之类的

## 腾讯云

https://www.dnspod.cn/console/user/security


```
# vim /etc/profile.d/dnspod.sh
export DP_Id="API Token 的 ID"
export DP_Key="API Token"
```

```
acme.sh --issue --dns dns_dp -d example.com -d *.example.com -k 2048
```

## 阿里云

https://ak-console.aliyun.com/#/accesskey


```
# vim /etc/profile.d/dns_ali.sh
export Ali_Key="xxx"
export Ali_Secret="xxxx"
```

```
acme.sh --issue --dns dns_ali -d example.com -d *.example.com 
```

```
[2020年 04月 19日 星期日 13:17:00 CST] Your cert is in  /root/.acme.sh/xxx.com/xxx.com.cer
[2020年 04月 19日 星期日 13:17:00 CST] Your cert key is in  /root/.acme.sh/xxx.com/xxx.com.key
[2020年 04月 19日 星期日 13:17:00 CST] The intermediate CA cert is in  /root/.acme.sh/xxx.com/ca.cer
[2020年 04月 19日 星期日 13:17:00 CST] And the full chain certs is there:  /root/.acme.sh/xxx.com/fullchain.cer 
```

## 会进行自动续签

安装时有自动配置定时任务进行续签

注意，所谓续签是将原证书失效，重新签发。

要停止续签某域名的话，手动执行

```shell
acme.sh --remove -d example.com
```

## 更新acme.sh

acme变得挺快的，更新就用这个

```
acme.sh --upgrade
```

```
# 自动更新
acme.sh  --upgrade  --auto-upgrade
# 关闭自动更新
acme.sh  --upgrade  --auto-upgrade 0
```

## 文档

https://github.com/acmesh-official/acme.sh/wiki/%E8%AF%B4%E6%98%8E

