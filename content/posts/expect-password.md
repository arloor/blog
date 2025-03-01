---
title: "Expect Password"
date: 2024-06-19T11:05:37+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


对于需要输入密码的命令，通常我们不能简单地通过重定向输入（如使用 `<` 或 `<<` ）来避免手动输入密码。这是因为这些命令通常会直接从终端读取密码，以确保密码的安全性，不会从标准输入（stdin）读取。但是我们可以使用expect工具来自动输入密码。下面是自动实现kinit认证的步骤。
<!--more-->

## 安装homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# 然后设置环境变量
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 安装expect

```bash
brew install expect
```

## 编写expect脚本

```bash
cat > ~/bin/work <\EOF
#!/usr/bin/expect -f

set username "user@EXAMPLE.COM"
set password "passwd"

spawn kinit --keychain -l 100d  $username
expect {
    "password:" {
        send "$password\r"
    }
    timeout {
        puts "Error: Timeout waiting for password prompt."
        exit 1
    }
    eof {
        puts "kinit command end."
        exit 0
    }
}
interact
EOF
chmod +x ~/bin/work
```

## 配置MacOS快捷指令

可以配置快捷指令，并固定到菜单栏

![alt text](/img/macos-shortcode-expect-passwd.md)

## 配置launchd定时任务

每天10点自动执行该命令

文件地址：`~/Library/LaunchAgents/com.arloor.kinit.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
        <dict>
                <key>Label</key>
                <string>com.arloor.kinit</string>
                <!-- 加载后立即启动，即开机自启 -->
                <key>RunAtLoad</key>
                <true />
                <key>WorkingDirectory</key>
                <string>/tmp</string>
                <key>ProgramArguments</key>
                <array>
                        <string>/Users/xxxx/bin/work</string>
                </array>
                <key>StartCalendarInterval</key>
                <dict>
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

因为macOS有keychain来保存kinit的密码，所以也可以改成：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
        <dict>
                <key>Label</key>
                <string>com.arloor.kinit</string>
                <!-- 加载后立即启动，即开机自启 -->
                <key>RunAtLoad</key>
                <true />
                <key>WorkingDirectory</key>
                <string>/tmp</string>
                <key>ProgramArguments</key>
                <array>
                        <string>kinit</string>
                        <string>--keychain</string>
                        <string>-l</string>
                        <string>100d</string>
                        <string>liuganghuan@BYTEDANCE.COM</string>
                </array>
                <key>StartCalendarInterval</key>
                <dict>
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