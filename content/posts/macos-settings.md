---
title: "macOS一些配置"
date: 2024-09-22T18:17:18+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

## 切换option和command键

设置 -> 键盘 -> 键盘快捷键 -> 修饰键

<!-- ![](/img/Snipaste_2024-09-22_18-16-08.png) -->
{{<img Snipaste_2024-09-22_18-16-08.png 700 >}}

## 关闭鼠标加速

<!-- ![alt text](/img/shubiao-settings-macos.png) -->
{{<img shubiao-settings-macos.png 700 >}}

## macOS 解除F11的快捷键的占用（vscode debug StepIn）

设置 -> 键盘 -> 键盘快捷键

{{<img macOS-diable-F11.png 700 >}}

## 打开文稿时首选标签页——关闭

{{<img Snipaste_2024-09-22_23-18-36.png 700>}}

## 使用外界显示器供电时合盖使用而不睡眠

{{<img close-monitor-but-not-sleep.png 700 >}}

可以顺便把这个也设置下：这样使用kvm控制器切换到其他电脑时，macOS就不会停止输出DP、HDMI等显示信号了，也就是不用按键盘来让显示器显示了。

{{<img never-close-monitor.png 700 >}}

## ssh到macOS上远程开发

除了要开远程登录外，要ssh到macOS上进行远程开发，需要额外的命令：

```bash
xcode-select --install # 安装 LLDB.framework
sudo DevToolsSecurity --enable # 永久允许Developer Tools Access 附加到其他进程上，以进行debug
sudo security authorizationdb write system.privilege.taskport.debug allow # 允许remote-ssh调试进程。解决报错：this is a non-interactive debug session, cannot get permission to debug processes.
```

其实第三个命令就是对第二个命令的补充。他们操作的都是rights definition for: system.privilege.taskport.debug。可以执行下面两条命令来验证，可以发现就是打印格式不同，内容是一样的。

```bash
sudo DevToolsSecurity -status -verbose
sudo security authorizationdb read system.privilege.taskport.debug
```

参考文档：

1. [Debugging with LLDB-MI on macOS](https://code.visualstudio.com/docs/cpp/lldb-mi)
2. [Unable to debug after connecting to macOS via "Remote - SSH" ](https://github.com/vadimcn/codelldb/issues/1079) 解决报错：this is a non-interactive debug session, cannot get permission to debug processes.

如果每次ssh到macOS都需要输入密码，设置公钥就行：

```bash
echo ssh-rsa xxxxxxxx not@home > ~/.ssh/authorized_keys
```

## 隐私与安全中的开发者工具 

[gatekeeper](https://nexte.st/docs/installation/macos/#gatekeeper)

将终端加到开发者工具 `sudo spctl developer-mode enable-terminal`

{{< img img_v3_02pr_5877f420-a7fb-468a-b680-3100f183279g.jpg 600 >}}

{{< img img_v3_02pr_7007b65b-1cfa-4a31-a7e0-9679699bb86g.jpg 400 >}}