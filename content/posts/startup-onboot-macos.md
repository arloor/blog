---
title: "MacOS开机自启动、资源限制、定时任务"
subtitle:
tags:
  - undefined
date: 2025-12-16T19:31:51+08:00
lastmod: 2025-12-16T19:31:51+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
---

本文介绍使用 MacOS 的 LaunchAgents 和 LaunchDaemons 实现开机自启动、资源限制和定时任务的配置方法。

<!--more-->

## 前言

在 MacOS 上的“登陆项与扩展”中有两种开机自启方式：

1. 登录项（Login Items）：适用于图形界面应用程序
2. 启动代理与守护进程（LaunchAgents 和 LaunchDaemons）：适用于后台服务和命令行工具

{{<img macos-startup.png 600 >}}

本文介绍如何使用使用 LaunchAgents 和 LaunchDaemons 来实现开机自启动、资源限制和定时任务。

## 编写 Agent/Daemon 配置文件（plist 文件）

LaunchAgents 和 LaunchDaemons 的配置文件使用 plist 格式，通常以 `.plist` 作为文件扩展名。根据不同的使用场景，plist 文件应放置在不同的目录中：

| plist 目录              | domain-target | 说明                                            |
| ----------------------- | ------------- | ----------------------------------------------- |
| /Library/LaunchDaemons/ | system        | 系统级守护进程。系统启动时加载                  |
| /Library/LaunchAgents/  | gui/<uid>     | 所有用户的图形界面代理。任何用户 GUI 登录时加载 |
| ~/Library/LaunchAgents/ | gui/<uid>     | 当前用户的图形界面代理。本用户 GUI 登录时加载   |

参考：

1. `man launchd.plist`
2. [Apple Developer Documentation - launchd.plist](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
3. [Launchd.info](https://www.launchd.info/)

下面是一个示例 plist 文件：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
        <dict>
                <key>Label</key>
                <string>com.arloor.sslocal</string>
                <!-- 退出后是否重启 -->
                <key>KeepAlive</key>
                <false />
                <!-- 加载后立即启动，即开机自启。如果设置为false，则bootstrap后还需要kickstart才会启动 -->
                <key>RunAtLoad</key>
                <true />
                <key>WorkingDirectory</key>
                <string>/tmp</string>
                <key>EnvironmentVariables</key>
                <dict>
                        <key>aPATH</key>
                        <string>/bin:/usr/bin:/usr/local/bin</string>
                </dict>
                <key>ProgramArguments</key>
                <array>
                        <string>/Users/bytedance/.cargo/bin/sslocal</string>
                        <string>--local-addr</string>
                        <string>localhost:2080</string>
                        <string>-k</string>
                        <string>xxxxxxxx</string>
                        <string>-m</string>
                        <string>aes-256-gcm</string>
                        <string>-s</string>
                        <string>host:port</string>
                        <string>-v</string>
                </array>
                <!-- 软资源限制 -->
                <key>SoftResourceLimits</key>
                <dict>
                        <key>NumberOfFiles</key>
                        <integer>65536</integer>
                </dict>
                <!-- 硬资源限制 -->
                <key>HardResourceLimits</key>
                <dict>
                        <key>NumberOfFiles</key>
                        <integer>65536</integer>
                </dict>
                <!-- 标准输出路径 -->
                <key>StandardOutPath</key>
                <string>/tmp/sslocal.log</string>
                <!-- 标准错误路径 -->
                <key>StandardErrorPath</key>
                <string>/tmp/sslocal.log</string>
        </dict>
</plist>
```

各字段解释：

| 字段名               | 说明                   | 是否必填 |
| -------------------- | ---------------------- | -------- |
| Label                | 服务的唯一标识符       | 是       |
| ProgramArguments     | 要执行的命令及其参数   | 是       |
| RunAtLoad            | 是否在加载时启动服务   | 否       |
| KeepAlive            | 服务退出后是否自动重启 | 否       |
| WorkingDirectory     | 服务的工作目录         | 否       |
| EnvironmentVariables | 设置服务的环境变量     | 否       |
| SoftResourceLimits   | 设置服务的软资源限制   | 否       |
| HardResourceLimits   | 设置服务的硬资源限制   | 否       |
| StandardOutPath      | 标准输出日志文件路径   | 否       |
| StandardErrorPath    | 标准错误日志文件路径   | 否       |

我们主要通过 `RunAtLoad = True` 实现开机自启，建议任何自定义 plist 都设置 `RunAtLoad = True`。

## 服务管理脚本

这里提供一个脚本用于启动和停止 LaunchAgent/LaunchDaemon 服务，效果类似于 Linux 上的 systemctl：

```bash
#! /bin/bash

sub_command=
service_name=

# 使用while循环读取参数
while [ $# -gt 0 ]; do
    if [ "$1" == "enable" ] || [ "$1" == "disable" ] || [ "$1" == "start" ] || [ "$1" == "stop" ]; then
        sub_command=$1
    else
        service_name=$1
    fi
    shift # 移除第一个参数
done
[ "$service_name" == "" ] && {
    echo "ERROR: need service name"
    exit 1
}

userID=$(id -u)
[ "$userID" = "0" ] && {
    domain_target="system"
    plist_path="/Library/LaunchDaemons/"
}||{
    domain_target="gui/$(id -u)"
    plist_path="$HOME/Library/LaunchAgents/"
}
echo "domain_target=${domain_target}"
echo "plist_path=${plist_path}${service_name}.plist"
echo

echo "sub_command: ${sub_command} [${service_name}]"

[ -f "${plist_path}${service_name}.plist" ] || {
    echo "ERROR: plist file not found: ${plist_path}${service_name}.plist"
    exit 1
}

get_cur_pid() {
    launchctl list | awk -v sn="${service_name}" '$3 == sn {print $1}'
    # launchctl kickstart -p ${domain_target}/${service_name}
}

case "$sub_command" in
    enable)
        launchctl enable ${domain_target}/${service_name}
        launchctl bootstrap ${domain_target} ${plist_path}${service_name}.plist 2>/dev/null
        pid=$(launchctl kickstart -p ${domain_target}/${service_name})
        if [ "$pid" != "" ]; then
            echo 进程ID $pid
        else
            echo 启动失败
        fi
        ;;
    disable)
        launchctl bootout ${domain_target}/${service_name} 2>/dev/null
        launchctl disable ${domain_target}/${service_name}
        ;;
    start)
        pid=$(launchctl kickstart -kp ${domain_target}/${service_name})
        if [ "$pid" != "" ]; then
            echo 新进程 $pid
        else
            echo 启动失败
        fi
        ;;
    stop)
        old_pid=$(get_cur_pid)
        if [ "$old_pid" == "-" ]; then
            # 服务已退出，无PID
            old_pid=""
        fi
        if [ "$old_pid" != "" ]; then
            echo 关闭老进程 $old_pid
            launchctl kill 9 ${domain_target}/${service_name}
        fi
        ;;
    *)
        echo "ERROR: unknown sub_command: $sub_command"
        echo "Usage: $0 {enable|disable|start|stop} service_name"
        exit 1
        ;;
esac
```

把这个脚本命名成 `systemctl`，那你就可以：

```bash
systemctl enable com.arloor.sslocal  # 设置开机自启并立即启动
systemctl disable com.arloor.sslocal # 停止进程并取消开机自启
systemctl start com.arloor.sslocal   # 启动/重启进程（不改变开机自启设置）
systemctl stop com.arloor.sslocal    # 停止进程（不改变开机自启设置）

sudo systemctl enable xxxx  # 操作 /Library/LaunchDaemons/下的plist
sudo systemctl disable xxxx
sudo systemctl start xxxx
sudo systemctl stop xxxx
```

| 命令                  | 说明                              | 实现细节                     | 是否影响开机自启 |
| --------------------- | --------------------------------- | ---------------------------- | ---------------- |
| systemctl enable xxx  | 设置开机自启并立即启动进程        | launchctl enable + bootstrap | 是               |
| systemctl disable xxx | 停止进程并取消开机自启            | launchctl bootout + disable  | 是               |
| systemctl start xxx   | 启动/重启进程，不改变开机自启设置 | launchctl kickstart -kp      | 否               |
| systemctl stop xxx    | 停止进程，不改变开机自启设置      | launchctl bootout            | 否               |

如果使用 `sudo` 执行 `systemctl`，则操作的是系统级的 LaunchDaemons;否则操作的是当前用户的 LaunchAgents。

## launchctl 子命令说明

> - `bootstrap` 和 `bootout`相当于老命令 load 和 unload （RunAtLoad 的那个 Load）。只有在 service 是 enable 的状态下才有效。所以上面的脚本中，bootout 在 disable 之前，bootstrap 后 enable 之后。
> - `unload -w` 等同于 `bootout + disable`，停止进程并禁用开机自启动。已废弃。
> - `load -w` 等同于 `enable + bootstrap`，启动进程并设置开机自启动。已废弃。
> - `bootstrap` 需要使用 plist 的路径，而不是 service-name
> - `launchctl kickstart -p` 启动并打印 PID，但不会修改 enable/disable 状态。

## 服务禁用数据库清理

LaunchAgents/LaunchDaemons 是否被 disable 存储在单独的文件中。由于 MacOS 不会自动删除 plist 已经被删除的 LaunchAgents/LaunchDaemons。这导致`launchctl print-disabled gui/$(id -u)`时会看到一些无效的项目。如果想手动删除这些项目，需要先在恢复模式（开机时按住 ⌘R）关闭安全模式，然后才能通过 vim 修改。

```bash
# LaunchAgents
/private/var/db/com.apple.xpc.launchd/disabled.$(id -u).plist
# LaunchDaemons
/private/var/db/com.apple.xpc.launchd/disabled.plist
```

或者直接在恢复模式使用 PlistBuddy 删除

```bash
# 删除 LaunchAgents 禁用项
/usr/libexec/Plistbuddy "/Volumes/{系统卷名称}/var/db/com.apple.xpc.launchd/disabled.{用户ID}.plist" -c Delete:{Label}
# 删除 LaunchDaemons 禁用项
/usr/libexec/Plistbuddy "/Volumes/{系统卷名称}/var/db/com.apple.xpc.launchd/disabled.plist" -c Delete:{Label}
# 示例
# /usr/libexec/Plistbuddy "/Volumes/Macintosh HD/var/db/com.apple.xpc.launchd/disabled.502.plist" -c Delete:local.job
```

## 全局资源限制

unix 系统都限制了可打开文件数，上面的 plist 修改了单个进程的文件描述符数量限制。如何修改全局资源限制呢？

1. 新建 `/Library/LaunchDaemons/limit.maxfiles.plist` 文件，写入

```xml
<?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
         "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
   <dict>
     <key>Label</key>
     <string>limit.maxfiles</string>
     <key>ProgramArguments</key>
     <array>
       <string>launchctl</string>
       <string>limit</string>
       <string>maxfiles</string>
       <string>64000</string>
       <string>524288</string>
     </array>
     <key>RunAtLoad</key>
     <true/>
   </dict>
 </plist>
```

2. 修改文件权限

```bash
sudo chown root:wheel /Library/LaunchDaemons/limit.maxfiles.plist
sudo chmod 644 /Library/LaunchDaemons/limit.maxfiles.plist
```

3. 加载 plist 文件(或重启系统后生效 launchd 在启动时会自动加载该目录的 plist)

```bash
sudo systemctl start limit.maxfiles
```

4. 确认更改后的限制

```bash
launchctl limit maxfiles
```

详见[Mac OS X 下的资源限制](https://zidongwudaijun.com/2017/02/max-osx-ulimit/)

## macOS 定时任务

参考[Scheduling Timed Jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.arloor.job</string>
        <!-- 加载后立即执行一次 -->
        <key>RunAtLoad</key>
        <true />
        <key>WorkingDirectory</key>
        <string>/tmp</string>
        <key>ProgramArguments</key>
        <array>
            <string>/Users/arloor/bin/work</string>
        </array>
        <key>StartCalendarInterval</key>
        <dict>
            <!-- 每天10点执行一次 -->
            <key>Hour</key>
            <integer>10</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <!-- 标准输出路径 -->
        <key>StandardOutPath</key>
        <string>/tmp/work.log</string>
    </dict>
</plist>
```

1. 这样设置后，每天 10 点会执行一次。
2. 如果 10 点刚好 mac 在待机，则唤醒后会执行一次。
3. 如果 10 点是关机的，则开机后不会执行。
4. 还有个 StartInterval 的参数，每多少秒执行一次。这个参数因睡眠导致的错过在唤醒时不会执行的。
