---
title: "windows开机自启动"
date: 2020-07-17T19:59:39+08:00
draft: false
categories: ["undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
highlightjslanguages:
  - powershell
---

## 放到启动文件夹

编写`startup.vbs`，放到这个文件夹下（可以使用 `win+r` 输入`shell:Startup`）：

```bash
%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
```

`startup.vbs`内容如下：

```powershell
set forward=WScript.CreateObject("WScript.Shell")
forward.Run "taskkill /f /im forward.exe",0,True
forward.Run "C:\Users\arloor\go\bin\forward.exe -conf D:\bin\caddyfile -log E:\data\var\log\forward.log -socks5conf=D:\bin\socks5.yaml",0
```

1. 先关闭 forward.exe，末尾的`0,True`表示不开启窗口，等待该命令结束再执行下一行
2. 再启动 forward.exe，末尾的`0`表示不开启窗口

具体 Run 命令见[www.vbsedit.com](https://www.vbsedit.com/html/6f28899c-d653-4555-8a59-49640b0e32ea.asp)

## 使用 windows service

安装 shawl：

```bash
cargo install --locked shawl
shawl add --help
```

支持的选项：

```bash
shawl add --help
Add a new service

Usage: shawl.exe add [OPTIONS] --name <NAME> -- <COMMAND>...

Arguments:
  <COMMAND>...
          Command to run as a service

Options:
      --pass <codes>
          Exit codes that should be considered successful (comma-separated) [default: 0]
      --restart
          Always restart the command regardless of the exit code
      --no-restart
          Never restart the command regardless of the exit code
      --restart-if <codes>
          Restart the command if the exit code is one of these (comma-separated)
      --restart-if-not <codes>
          Restart the command if the exit code is not one of these (comma-separated)
      --restart-delay <ms>
          How long to wait before restarting the wrapped process
      --stop-timeout <ms>
          How long to wait in milliseconds between sending the wrapped process a ctrl-C event and
          forcibly killing it [default: 3000]
      --no-log
          Disable all of Shawl's logging
      --no-log-cmd
          Disable logging of output from the command running as a service
      --log-dir <path>
          Write log file to a custom directory. This directory will be created if it doesn't exist
      --log-as <LOG_AS>
          Use a different name for the main log file. Set this to just the desired base name of the
          log file. For example, `--log-as shawl` would result in a log file named
          `shawl_rCURRENT.log` instead of the normal `shawl_for_<name>_rCURRENT.log` pattern
      --log-cmd-as <LOG_CMD_AS>
          Use a separate log file for the wrapped command's stdout and stderr. Set this to just the
          desired base name of the log file. For example, `--log-cmd-as foo` would result in a log
          file named `foo_rCURRENT.log`. The output will be logged as-is without any additional log
          template
      --log-rotate <LOG_ROTATE>
          Threshold for rotating log files. Valid options: `daily`, `hourly`, `bytes=n` (every N
          bytes) [default: bytes=2097152]
      --log-retain <LOG_RETAIN>
          How many old log files to retain [default: 2]
      --pass-start-args
          Append the service start arguments to the command
      --env <ENV>
          Additional environment variable in the format 'KEY=value' (repeatable)
      --path <PATH>
          Additional directory to append to the PATH environment variable (repeatable)
      --path-prepend <path>
          Additional directory to prepend to the PATH environment variable (repeatable)
      --priority <PRIORITY>
          Process priority of the command to run as a service [possible values: realtime, high,
          above-normal, normal, below-normal, idle]
      --cwd <path>
          Working directory in which to run the command. You may provide a relative path, and it
          will be converted to an absolute one
      --dependencies <DEPENDENCIES>
          Other services that must be started first (comma-separated)
      --name <NAME>
          Name of the service to create
  -h, --help
          Print help
```

添加一个服务并且设置为开机自启动：

```powershell
shawl add --name mihomo -- C:\Users\arloor\mihomo\mihomo.exe -d C:\Users\arloor\mihomo -f C:\Users\arloor\mihomo\clash.yaml
## 需要在管理员权限中执行，或者到服务界面自己设置
sc.exe config mihomo start= auto
sc.exe start mihomo
```
