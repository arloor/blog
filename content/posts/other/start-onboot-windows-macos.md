---
title: "MacOS和windows开机自启动"
date: 2020-07-17T19:59:39+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

linux上的开机自启动很简单，通过systemd就能搞定。对于macos和windows的开机自启动则没有记录过，这里记录下。
<!--more-->

## MacOS开机自启动

Macos提供三种开机自启动的方式，详情可以看这里[三种方式配置Mac OS X的启动项](https://blog.csdn.net/abby_sheen/article/details/7817198)。这是一篇12年的老文章了。

这里挑选一种和linux上的systemd很像的方式，使用launchd来进行开机自启动。和systemd一样，launchd也是MacOS上的第一个进程，并且提供和systemctl很类似的launchctl工具。

### plist文件

使用Launchd设置开机自启动，仅仅需要编写一个`plist`文件并将其放到`~/Library/LaunchAgents/`。以下是一个应用开机自启的plist文件。

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
                <!-- 加载后立即启动，即开机自启 -->
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

如果需要其他字段来自定义能力，可以参考 `man launchd.plist`，或者看[launchd.info](https://www.launchd.info/) 

### 启动和停止

如果想实现类似`systemctl restart xx`的能力，可以使用下面的脚本：

```
#! /bin/sh
launchctl unload -w ~/Library/LaunchAgents/com.arloor.sslocal.plist
if [ "$1" != "stop" ]; then
    sleep 1
    launchctl load -w ~/Library/LaunchAgents/com.arloor.sslocal.plist
fi
```

如果执行过程中报下面的错，是因为 `launchctl unload`（卸载服务） 时该服务还没运行，所以 `launchctl unload` 失败。可以忽略这个错误。

```bash
Unload failed: 5: Input/output error
Try running `launchctl bootout` as root for richer errors.
```

#### 新命令（可以但没必要）

unload和load是老旧的launchctl命令，`man launchctl`能看到，官方推荐我们使用 bootstrap | bootout | enable | disable
> - `unload -w` 等同于 `bootout + disable`，停止进程并禁用开机自启动。
> - `load -w` 等同于 `enable + bootstrap`，启动进程并设置开机自启动。 
> - `bootstrap` 和 `bootout` 只有在service是enable的状态下才有效。所以下面的脚本中，bootout在disable之前，bootstrap后enable之后。
> - `bootstrap` 需要使用plist的路径，而不是service-name
> - `launchctl kickstart -p` 用于打印当前进程的pid

使用新命令来达成上面的效果就是：

```bash
#! /bin/bash

service_name="com.arloor.sslocal"

get_cur_pid() {
    launchctl list | grep ${service_name} | awk '{print $1}'
}

old_pid=$(get_cur_pid)
if [ "$old_pid" != "" ]; then
    echo 关闭老进程 $old_pid
    launchctl bootout gui/$(id -u)/${service_name}
    launchctl disable gui/$(id -u)/${service_name}
fi
if [ "$1" != "stop" ]; then
    launchctl enable gui/$(id -u)/${service_name}
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/${service_name}.plist
    pid=$(get_cur_pid)
    if [ "$pid" != "" ]; then
        echo 新进程 $pid
    else
        echo 启动失败
    fi
fi

```

service是否被disable的db文件地址如下。MacOS不会自动删除db文件中无效的service，这导致执行`launchctl print-disabled gui/$(id -u)`时会看到一些无效的service。如果想手动删除这些无效的service，需要先在恢复模式关闭安全模式，然后才能通过vim修改。

```bash
/private/var/db/com.apple.xpc.launchd/disabled.$(id -u).plist 
```

### 全局资源限制

unix系统都限制了可打开文件数，上面的plist修改了单个进程的文件描述符数量限制。如何修改全局资源限制呢？

1. 新建/Library/LaunchDaemons/limit.maxfiles.plist文件，写入

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
     <key>ServiceIPC</key>
     <false/>
   </dict>
 </plist>
```

2. 修改文件权限

```bash
 sudo chown root:wheel /Library/LaunchDaemons/limit.maxfiles.plist
 sudo chmod 644 /Library/LaunchDaemons/limit.maxfiles.plist
```

3. 加载plist文件(或重启系统后生效 launchd在启动时会自动加载该目录的plist)

```bash
sudo launchctl load -w /Library/LaunchDaemons/limit.maxfiles.plist
```

4. 确认更改后的限制

```bash
 launchctl limit maxfiles
```

详见[Mac OS X下的资源限制](https://zidongwudaijun.com/2017/02/max-osx-ulimit/)

## windows开机自启动

编写`startup.vbs`，放到

```
C:\Users\你的用户名\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
```

文件夹下

`startup.vbs`内容如下：

```
set forward=WScript.CreateObject("WScript.Shell")
forward.Run "taskkill /f /im forward.exe",0,True
forward.Run "C:\Users\arloor\go\bin\forward.exe -conf D:\bin\caddyfile -log E:\data\var\log\forward.log -socks5conf=D:\bin\socks5.yaml",0
```

1. 先关闭forward.exe，末尾的`0,True`表示不开启窗口，等待该命令结束再执行下一行
2. 再启动forward.exe，末尾的`0`表示不开启窗口

具体Run命令见[www.vbsedit.com](https://www.vbsedit.com/html/6f28899c-d653-4555-8a59-49640b0e32ea.asp)