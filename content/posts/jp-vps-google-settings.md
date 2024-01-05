---
title: "谷歌日本搜索结果显示日文的解决方案"
date: 2023-08-12T21:19:01+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

说到日本的服务器，最早用过一段时间的沪日iplc，现在在用[DMIT的PVM.TYO.Pro.Shinagawa](https://www.dmit.io/aff.php?aff=7132)，他们在延迟速率方面的表现都很好。有一点比较难受的是日本的google搜索结果总是有日文内容，这里说下解决方案。

谷歌提供了“搜索设置”的功能，允许用户调整“搜索结果语言过滤器”，这个设置将会设置到cookie中，具体来说是NID这个cookie，过期时间是6个月。如果在6个月中有登出再登陆，这个cookie也会丢失，需要重新设置。

## 设置搜索结果语言过滤器

[搜索设置页面](https://www.google.com/preferences?lang=1)，设置成如下:

> 注意，**搜索结果区域**一定不要是**当前所在区域**，日本ip所在地也就是日本，推荐选美国这种英语语言国家。经过我的测试，可能这个才是主要影响日文内容是否出现的主要因素。

![Alt text](/img/google-preference-setting.png)

设置完可以F12看NID这个cookie：

![Alt text](/img/google-nid-cookie.png)

## 通过Surge Mac的http rewrite永久修改NID cookie

参考文档1中介绍了google是使用NID这个cookie来存储搜索过滤器配置的，我们就用Surge Mac的http rewrite功能将这个cookie永久生效。我们先用正则替换来替换存在的nid，而后为放置nid cookie的缺失，再增加一个cookie的header

```toml
[Header Rewrite]
https://.*google.com.* header-replace-regex Cookie ^NID.* NID=换成你的
https://.*google.com.* header-add Cookie NID=换成你的


[MITM]
skip-server-cert-verify = true
tcp-connection = true
h2 = true
hostname = *.google.com # Http解密google的请求
ca-passphrase = xxx
ca-p12 = xxxx
```

随后可以在Surge请求查看器中看到google.com的请求被Https解密并修改了cookie的请求头：

![Alt text](/img/surge-dashboard-nid-cookie-google.png)

## 参考文档

1. [google types-of-cookies](https://policies.google.com/technologies/cookies?hl=en-US#types-of-cookies)
2. [有啥方法可以设置谷歌搜索结果始终按照某语言习惯输出？](https://www.v2ex.com/t/964653#reply7)