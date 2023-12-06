---
title: "Visual Studio Code配置"
date: 2023-07-11T19:07:00+08:00
draft: false
categories: [ "undefined"]
tags: ["tools"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 安装并配置Jetbrains Mono字体

1. 下载Jetbrians Mono字体：[how-to-install](https://www.jetbrains.com/lp/mono/#how-to-install)
2. 解压缩
3. Mac下将ttf文件夹下的文件全选，右击选择打开，安装所有字体
4. Centos9下， 将ttf文件夹下的文件全部移动到 `/usr/share/fonts/${newdir}`下 , `yum install -y fontconfig` 并执行 `fc-cache` 。然后执行 `fc-list` 即可看到新的字体 

## 配置VS code

1. 打开vscode的设置
    1. 搜索font family，改成 `'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace` 。
    2. 搜索font size，改成13。如果这个字体还不够大，可以 `command + +`来放大UI。
    3. 搜索line height，改成1.6。
    4. 对应的vscode settings.json如下：

```json
{
    "workbench.colorTheme": "Default Dark+",
    "files.autoSave": "onFocusChange",
    "window.zoomLevel": 1,
    "editor.unicodeHighlight.nonBasicASCII": false,
    "editor.fontSize": 13,
    "editor.fontFamily": "'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace",
    "editor.lineHeight": 1.6,
    "editor.fontLigatures": false,
    "editor.fontVariations": false,
    "terminal.integrated.defaultProfile.linux": "zsh",
    "git.enableSmartCommit": true
}
```

TIPS：

1. 建议打开vscode的配置同步功能。
2. 本地的字体设置对远程开发同样生效。

## 配置键盘快捷键

1. 按 `cmd+k` ，再按 `cmd+s`，进入快捷键设置
2. 点击右上角按钮进入原始文件 `keybindings.json`

![Alt text](/img/vscode-keybindings-setting.png)

3. 修改文件内容如下：
    1. `cmd+m`： 用于切换多个终端，特别是用于有build任务的终端时

```json
// 将键绑定放在此文件中以覆盖默认值auto[]
[
    {
        "key": "cmd+m",
        "command": "workbench.action.terminal.focusNext"
    }
]
```

## 远程开发

1. 安装 `Remote-ssh` 插件。
2. 使用ssh连接到远程服务器。推荐配置是2C2G以上。为了让远程服务器流畅连接网络，使用了clash做分流，并将clash作为系统代理。
3. 历史记录保存在 `~/.ssh/config` 中。

## Rust开发

1. 安装两个插件：rust-analyzer、codelldb
2. 配置默认build任务：`.vscode/tasks.json`

```json
{
	"version": "2.0.0",
	"tasks": [
		{
			"type": "cargo",
			"command": "build",
			"problemMatcher": [
				"$rustc"
			],
			"group": {
				"kind": "build",
				"isDefault": true
			},
			"label": "rust: cargo build"
		}
	]
}
```

3. 配置调试任务 `.vscode/launch.json`

```json
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lldb",
            "request": "launch",
            "name": "Debug",
            "program": "${workspaceFolder}/target/debug/${workspaceFolderBasename}",
            "args": [],
            "cwd": "${workspaceFolder}",
            "preLaunchTask": "${defaultBuildTask}",
            "env": {"port":"80"}
        }
    ]
}
```

4. 按F5开启调试，F5 resume调试。

## 设置word wrap

发现在设置中修改不好使，倒是有个快捷键 `option + z` 或 `alt + z`