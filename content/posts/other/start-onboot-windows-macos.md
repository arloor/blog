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

使用Launchd设置开机自启动，仅仅需要编写一个`plist`文件并将其放到`~/Library/LaunchAgents/`。以下是一个java应用开机自启的plist文件。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
        <dict>
                <key>Label</key>
                <string>com.connect</string>
                <key>Disabled</key>          
                <false/>
                <key>KeepAlive</key>
                <false/>
                <key>RunAtLoad</key>
                <true/>
                <key>WorkingDirectory</key>
                <string>/tmp</string>
                <key>EnvironmentVariables</key>
                <dict>
	                <key>aPATH</key>
	                <string>/bin:/usr/bin:/usr/local/bin</string>
                </dict>
                <key>ProgramArguments</key>
                <array>
                        <string>/usr/bin/java</string>
                        <string>-jar</string>
                        <string>-Xmx100m</string>
                        <string>/path/to/your.jar</string>
                </array>
        </dict>
</plist>
```

更多详情可以见[launchd.info](https://www.launchd.info/)

如果想实现类似`systemctl restart xx`的能力，可以使用下面的脚本：

```
#! /bin/sh
launchctl stop com.connect
sleep 1
launchctl unload -w ~/Library/LaunchAgents/com.connect.plist
sleep 1
launchctl load -w ~/Library/LaunchAgents/com.connect.plist
```

## windows开机自启动

编写`startup.vbs`，放到

```
C:\Users\你的用户名\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
```

文件夹下

`startup.vbs`内容如下：

```
set ws=WScript.CreateObject("WScript.Shell")
ws.Run "D:\startup.bat /start",0
```

其中startup.bat的内容就是启动需要的进程，例如`java -jar xx.jar`