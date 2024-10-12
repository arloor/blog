---
title: "阿里云vps关闭阿里云盾和云监控c++插件"
date: 2024-10-12T16:46:54+08:00
draft: false
categories: [ "undefined"]
tags: ["linux"]
weight: 10
---

<!--more-->

## 卸载阿里云盾Agent客户端

首先关闭客户端的自保护功能，需要在阿里云云安全中心关闭，具体操作如下：

**资产中心-主机资产**

![alt text](/img/aliyun-host-assets.png)

**基本信息-防御状态**

![alt text](/img/aliyun-close-client-self-protection.png)

然后在机器上执行以下命令：

```bash
wget "http://update2.aegis.aliyun.com/download/uninstall.sh" && chmod +x uninstall.sh && ./uninstall.sh
```

## 卸载云监控C++版本插件

```bash
bash /usr/local/cloudmonitor/cloudmonitorCtl.sh stop
bash /usr/local/cloudmonitor/cloudmonitorCtl.sh uninstall
rm -rf /usr/local/cloudmonitor
```

## 参考文档

- [卸载阿里云盾Agent客户端](https://help.aliyun.com/zh/security-center/user-guide/uninstall-the-security-center-agent)
- [卸载云监控C++版本插件](https://help.aliyun.com/zh/cms/user-guide/install-and-uninstall-the-cloudmonitor-agent-for-cpp?spm=a2c4g.11186623.0.0.4d3551beCEhTI8#section-hdw-doi-fv4)
