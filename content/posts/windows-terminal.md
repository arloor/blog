---
title: "Windows Terminal"
date: 2020-04-24T14:31:16+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

windows terminal这个终端很好用，这里记一下
<!--more-->

windows terminal需要通过microsoft store下载。

## 将microsoft store从网络沙盒中移除，以便使用代理加速

win+r运行regedit

```
HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Mappings
```

找到name为microsoft store的项目，记下SID，然后在管理员权限的powershell中运行：

```
 CheckNetIsolation.exe loopbackexempt -a -p=S-1-15-2-1609473798-1231923017-684268153-4268514328-882773646-2760585773-1760938157
```

更多请查看[知乎专栏](https://zhuanlan.zhihu.com/p/29989157)

## 安装windows terminal

通过microsoft store安装

## 配置文件

```json
// To view the default settings, hold "alt" while clicking on the "Settings" button.
// For documentation on these settings, see: https://aka.ms/terminal-documentation

// https://www.guidgen.com/
{
    "$schema": "https://aka.ms/terminal-profiles-schema",

    "defaultProfile": "{888d4c00-67f1-4c7b-bd07-fd1e167f8f2e}",
    "copyOnSelect": true,

    "profiles":
    {
        "defaults":
        {
            // Put settings here that you want to apply to all profiles
        },
        "list":
        [
            {
                // Make changes here to the powershell.exe profile
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "name": "Windows PowerShell",
                "commandline": "D:\\PowerShell\\6\\pwsh.exe",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{9ce63606-3fb5-4a74-89cf-0ea048702f82}",
                "name": "华为云4G",
                "commandline" : "ssh root@sh.someme.me",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },

            {
                // Make changes here to the powershell.exe profile
                "guid": "{888d4c00-67f1-4c7b-bd07-fd1e167f8f2e}",
                "name": "广州移动",
                "commandline" : "ssh root@cm.someme.me",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{afe52709-58f1-4d54-9880-454e5ab176a7}",
                "name": "泉州cn2",
                "commandline" : "ssh root@cn22.uovz.com -p 20000",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{560a88df-772b-4ec8-9e39-695a96fa49e6}",
                "name": "新加坡2",
                "commandline" : "ssh root@sg.someme.me",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{fb899ba0-e4ca-49bf-832f-1d63cb2a0e38}",
                "name": "新加坡1",
                "commandline" : "ssh root@sg1.someme.me",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{0f6d0460-17d3-43b4-abcc-b0136bfe29fa}",
                "name": "快车道圣何塞",
                "commandline" : "ssh root@gia.someme.me",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{ec7a0582-c6d7-4d18-83c5-04c33c05591b}",
                "name": "api.arloor.com",
                "commandline" : "ssh root@api.arloor.com",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the powershell.exe profile
                "guid": "{05527b6c-7edc-453e-9beb-e3ceecd379ac}",
                "name": "香港-轻量",
                "commandline" : "ssh root@cm.someme.me -p 2222",
                "hidden": false,
                "fontFace": "Consolas",
                "fontSize": 13,
                "useAcrylic": true,
                "acrylicOpacity": 0.9,
                "colorScheme": "Atom",
                "icon": "E:\\head.jpeg"
            },
            {
                // Make changes here to the cmd.exe profile
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "name": "cmd",
                "commandline": "cmd.exe",
                "hidden": false
            },
            {
                "guid": "{b453ae62-4e3d-5e58-b989-0a998ec441b8}",
                "hidden": false,
                "name": "Azure Cloud Shell",
                "source": "Windows.Terminal.Azure"
            }
        ]
    },

    // Add custom color schemes to this array
    "schemes": [{
        "name": "Atom",
        "black": "#000000",
        "red": "#fd5ff1",
        "green": "#87c38a",
        "yellow": "#ffd7b1",
        "blue": "#85befd",
        "purple": "#b9b6fc",
        "cyan": "#85befd",
        "white": "#e0e0e0",
        "brightBlack": "#000000",
        "brightRed": "#fd5ff1",
        "brightGreen": "#94fa36",
        "brightYellow": "#f5ffa8",
        "brightBlue": "#96cbfe",
        "brightPurple": "#b9b6fc",
        "brightCyan": "#85befd",
        "brightWhite": "#e0e0e0",
        "background": "#161719",
        "foreground": "#c5c8c6"
    }],

    // Add any keybinding overrides to this array.
    // To unbind a default keybinding, set the command to "unbound"
     "keybindings":
    [
        // Copy and paste are bound to Ctrl+Shift+C and Ctrl+Shift+V in your defaults.json.
        // These two lines additionally bind them to Ctrl+C and Ctrl+V.
        // To learn more about selection, visit https://aka.ms/terminal-selection
        { "command": {"action": "copy", "singleLine": false }, "keys": "ctrl+c" },
        { "command": "paste", "keys": "ctrl+v" },

        // Press Ctrl+Shift+F to open the search box
        { "command": "find", "keys": "ctrl+shift+f" },

        // Press Alt+Shift+D to open a new pane.
        // - "split": "auto" makes this pane open in the direction that provides the most surface area.
        // - "splitMode": "duplicate" makes the new pane use the focused pane's profile.
        // To learn more about panes, visit https://aka.ms/terminal-panes
        { "command": { "action": "splitPane", "split": "auto", "splitMode": "duplicate" }, "keys": "alt+shift+d" }
    ]
}
```

