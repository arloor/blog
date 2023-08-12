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

说到日本的服务器，最早用过一段时间的沪日iplc，现在在用DMIT的Tokyo PRO，他们在延迟速率方面的表现都很好。有一点比较难受的是日本的google搜索结果总是有日文内容，这里说下解决方案。

谷歌提供了“搜索设置”的功能，允许用户调整“搜索结果语言过滤器”，这个设置将会设置到cookie中，具体来说是NID这个cookie，过期时间是6个月。如果在6个月中有登出再登陆，这个cookie也会丢失，需要重新设置。

## 设置搜索结果语言过滤器

[搜索设置页面](https://www.google.com/preferences?lang=1)，设置成如下：

![Alt text](/img/google-preference-setting.png)

设置完可以F12看NID这个cookie：

![Alt text](/img/image.png)

## 通过Surge Mac的http rewrite永久修改NID cookie

参考文档1中介绍了google是使用NID这个cookie来存储搜索过滤器配置的，我们就用Surge Mac的http rewrite功能将这个cookie永久生效。

```toml
[Header Rewrite]
https://.*google.com.* header-replace-regex Cookie ^NID.* NID=511=khETQ4Rhj6ctYT3HVuxi89NWHRxmYQT-e77CCfvl26iUCwO-BxoOLGWC1cfz42xbZ2wcOtSycsFeMUGq6s9O_5QXsw5Fyo3dJRCGpDA786cnCa33qtSTverklJwC0EXJomv6D_EvD5Np0lntcEOIJxif_mi_E1Kc1D49fxs0SN2qb-YhK1CBYdpQAsGI1x1HS95CmgGwR_2TkRWWHZcuNgZdxt0tX-9DCMcc6TtiEtQYuEcMFbchGCCUDwjwMDd81umQkZgpWuYYGkIOCYZEsyK1hRIPFm5A5iidpH1oXGdXVMF30KGmi-JasipqL2MV-3c8h9MvwwrauUIScJz5ojSwzZXcOWRhYsIUx7n0UkQodVeES1gCRNGH7629ogctJSGgryA
https://.*google.com.* header-add Cookie NID=511=khETQ4Rhj6ctYT3HVuxi89NWHRxmYQT-e77CCfvl26iUCwO-BxoOLGWC1cfz42xbZ2wcOtSycsFeMUGq6s9O_5QXsw5Fyo3dJRCGpDA786cnCa33qtSTverklJwC0EXJomv6D_EvD5Np0lntcEOIJxif_mi_E1Kc1D49fxs0SN2qb-YhK1CBYdpQAsGI1x1HS95CmgGwR_2TkRWWHZcuNgZdxt0tX-9DCMcc6TtiEtQYuEcMFbchGCCUDwjwMDd81umQkZgpWuYYGkIOCYZEsyK1hRIPFm5A5iidpH1oXGdXVMF30KGmi-JasipqL2MV-3c8h9MvwwrauUIScJz5ojSwzZXcOWRhYsIUx7n0UkQodVeES1gCRNGH7629ogctJSGgryA


[MITM]
skip-server-cert-verify = true
tcp-connection = true
h2 = true
hostname = *.google.com
ca-passphrase = xxx
ca-p12 = xxxx
```

## 参考文档

1. [google types-of-cookies](https://policies.google.com/technologies/cookies?hl=en-US#types-of-cookies)
2. [有啥方法可以设置谷歌搜索结果始终按照某语言习惯输出？](https://www.v2ex.com/t/964653#reply7)