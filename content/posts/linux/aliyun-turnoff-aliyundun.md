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

首先关闭客户端的自保护功能，需要在[阿里云云安全中心](https://yundun.console.aliyun.com/?spm=a2c4g.11186623.0.0.33d52fa0MAUoc3&p=sas#/assetHost/cn-hangzhou)关闭，具体操作如下：

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

## 卸载云助手（命令执行工具）

```bash
# 停止并卸载云助手守护进程
/usr/local/share/assist-daemon/assist_daemon --stop
/usr/local/share/assist-daemon/assist_daemon --delete
rm -rf /usr/local/share/assist-daemon
# 停止云助手服务
systemctl stop aliyun.service
# 删除文件
rm -rf /usr/local/share/aliyun-assist
```

## 一键脚本

```bash
bash <(curl -SsLf https://us.arloor.dev/https://gist.githubusercontent.com/arloor/f1414882b9bcb003c15f58e92be43606/raw/uninstall_aliyundun.sh)
```

注意，仍然需要在阿里云云安全中心关闭自保护功能。

## 参考文档

- [卸载阿里云盾Agent客户端](https://help.aliyun.com/zh/security-center/user-guide/uninstall-the-security-center-agent)
- [卸载云监控C++版本插件](https://help.aliyun.com/zh/cms/user-guide/install-and-uninstall-the-cloudmonitor-agent-for-cpp?spm=a2c4g.11186623.0.0.4d3551beCEhTI8#section-hdw-doi-fv4)
- [卸载云助手Agent（Linux实例）](https://help.aliyun.com/zh/ecs/user-guide/start-stop-or-uninstall-the-cloud-assistant-agent?spm=a2c4g.11186623.0.0.6f5055e0LThgs9#section-o45-6j5-x5m)