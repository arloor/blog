---
title: "vscode"
date: 2023-07-11T19:07:00+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 字体配置——使用JetBrains Mono

1. 下载Jetbrians Mono字体：[how-to-install](https://www.jetbrains.com/lp/mono/#how-to-install)
2. 解压缩
3. Mac下将ttf文件夹下的文件全选，右击选择打开，安装所有字体
4. Centos9下， 将ttf文件夹下的文件全部移动到 `/usr/share/fonts/${newdir}`下 , `yum install -y fontconfig` 并执行 `fc-cache` 。然后执行 `fc-list` 即可看到新的字体 
5. 搜索font family，改成 `'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace` 。
6. 搜索font size，改成13。如果这个字体还不够大，可以 `command + +`来放大UI。
7. 搜索line height，改成1.6。

TIPS：

1. 建议打开vscode的配置同步功能。
2. 本地的字体设置对远程开发同样生效。

## 快捷键配置

> 内置快捷键cheatsheet [keyboard-shortcuts-macos.pdf](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf)

1. 按 `cmd+k` ，再按 `cmd+s`，进入快捷键设置
2. 点击右上角按钮进入原始文件 `keybindings.json`

![Alt text](/img/vscode-keybindings-setting.png)

3. 修改文件内容如下：
    1. `cmd+m`： 用于切换多个终端，特别是在 `cmd+shift+b` 触发构建任务之后
    2. `option+o`: 用于打开remote explorer窗口，在多个远程开发环境中切换
    3. `option+t`: 用于打开outline窗口，用于查看大纲或者函数列表

```json
// 将键绑定放在此文件中以覆盖默认值auto[]
[
    {
        "key": "cmd+m",
        "command": "workbench.action.terminal.focusNext"
    },
    {
        "key": "alt+o",
        "command": "workbench.view.remote"
    },
    {
        "key": "alt+t",
        "command": "outline.focus"
    }
]
```


## 设置word wrap

发现在设置中修改不好使，倒是有个快捷键 `option + z` 或 `alt + z`

## 远程开发

1. 安装 `Remote-ssh` 插件。
2. 使用ssh连接到远程服务器。推荐配置是2C2G以上。为了让远程服务器流畅连接网络，使用了clash做分流，并将clash作为系统代理。
3. 历史记录保存在 `~/.ssh/config` 中。

### 卸载远程服务器vscode server

1. 执行命令 `Remote-SSH: Uninstall VS Code Server from Host` ;
2. 或手动执行

```bash
# Kill server processes
kill -9 $(ps aux | grep vscode-server | grep $USER | grep -v grep | awk '{print $2}')
# Delete related files and folder
rm -rf $HOME/.vscode-server # Or ~/.vscode-server-insiders
```

## Rust开发

### 安装四个插件：

| 插件名 | 说明 |
| --- | --- |
| rust-analyzer | rust插件 |
| codelldb | 调试插件 |
| tamasfe.even-better-toml | toml格式化 |
| serayuzgur.crates | crate.io插件 **自动检查依赖有没有更新**|

### 配置默认build任务：`.vscode/tasks.json`

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

### 配置调试任务 `.vscode/launch.json`

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
            "console": "internalConsole",
            "preLaunchTask": "${defaultBuildTask}",
            "env": {"port":"80"}
        }
    ]
}
```

### 按F5开启调试，F5 resume调试。

## Golang开发

1. 安装插件 `golang.go`
2. 安装相关的依赖

参考 [codespaces devcontainers go feature install.sh](https://github.com/devcontainers/features/blob/main/src/go/install.sh#L177)

> The extension depends on go, gopls, dlv and other optional tools. If any of the dependencies are missing, the ⚠️ Analysis Tools Missing warning is displayed. Click on the warning to download dependencies.See the [tools documentation](https://github.com/golang/vscode-go/wiki/tools) for a complete list of tools the extension depends on.

```bash
# Install Go tools that are isImportant && !replacedByGopls based on
# https://github.com/golang/vscode-go/blob/v0.38.0/src/goToolsInformation.ts
GO_TOOLS="\
    golang.org/x/tools/gopls@latest \
    honnef.co/go/tools/cmd/staticcheck@latest \
    golang.org/x/lint/golint@latest \
    github.com/mgechev/revive@latest \
    github.com/go-delve/delve/cmd/dlv@latest \
    github.com/fatih/gomodifytags@latest \
    github.com/haya14busa/goplay/cmd/goplay@latest \
    github.com/cweill/gotests/gotests@latest \ 
    github.com/josharian/impl@latest"
(echo "${GO_TOOLS}" | xargs -n 1 go install -v )2>&1 | tee  ./init_go.log

echo "Installing golangci-lint latest..."
curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | \
    sh -s -- -b "$HOME/go/bin" | tee  -a ./init_go.log
```

3. launch.json

```json
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch Package",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "cwd": "${workspaceFolder}",
            "program": "${workspaceFolder}/cmd/${workspaceFolderBasename}",
            "args": [
                "--addr=localhost:7788",
                "--refer=arloor"
                ,"--tls=true"
            ]
        }
    ]
}
```

## Python开发

### python插件

| 插件名 | 说明 |
| --- | --- |
| ms-python.python | python插件 |
| ms-python.vscode-pylance | python语言服务 |
| ms-python.debugpy | python调试插件 |
| ms-python.pylint | python lint插件 **我没装这个插件，因为pylance已经有lint了**|

### settings

```bash
    "python.analysis.inlayHints.callArgumentNames": "all",
    "python.analysis.inlayHints.functionReturnTypes": true,
    "python.analysis.inlayHints.variableTypes": true,
    "python.analysis.autoFormatStrings": true,
    "python.languageServer": "Pylance"
```

### venv
    
```bash
pip3 install virtualenv&&virtualenv venv #或 python3 -m venv virEnv
source venv/bin/activate
pip3 install -r requirements.txt
```

按`cmd + shift + p`，然后输入`select interpreter`，最后选择venv中的python解释器地址即可。

### 配置python调试任务

{{<imgx src="/img/vscode-add-python-debug-1.png" alt="" width="400px" style="max-width: 100%;">}}

{{<imgx src="/img/vscode-add-python-debug-2.png" alt="" width="400px" style="max-width: 100%;">}}

![alt text](/img/vscode-add-python-debug-3.png)

## 我的vscode配置备份

```json
{
    "files.autoSave": "afterDelay",
    "editor.unicodeHighlight.nonBasicASCII": false,
    "editor.fontSize": 14,
    "editor.fontFamily": "'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace",
    "editor.lineHeight": 1.6,
    "editor.fontLigatures": false,
    "editor.fontVariations": false,
    "terminal.integrated.defaultProfile.linux": "zsh",
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "update.showReleaseNotes": false,
    "editor.minimap.enabled": false,
    "terminal.integrated.enableMultiLinePasteWarning": false,
    "git.autofetch": true,
    "redhat.telemetry.enabled": true,
    "terminal.integrated.fontSize": 13,
    "debug.console.fontSize": 13,
    "workbench.editor.empty.hint": "hidden",
    "files.autoSaveDelay": 200,
    "git.pullTags": false, // 不自动拉取tag，避免github action更新的tag被拉取，导致git pull失败
    "github.copilot.enable": {
        "*": true,
        "plaintext": false,
        "markdown": true,
        "scminput": false
    },
    "python.analysis.inlayHints.callArgumentNames": "all",
    "python.analysis.inlayHints.functionReturnTypes": true,
    "python.analysis.inlayHints.variableTypes": true,
    "python.analysis.autoFormatStrings": true,
    "python.languageServer": "Pylance", // python languageServer插件
    "github-actions.workflows.pinned.refresh.enabled": true, // 自动刷新被pin住的github action的执行状态，可能触发Github API的限制
    "github-actions.workflows.pinned.refresh.interval": 10,
    "remote.SSH.defaultExtensions": [
        "waderyan.gitblame",
        "donjayamanne.githistory",
        "github.copilot", // SSH_PRIVATE
        "github.vscode-github-actions", // github actions
    ],
    "workbench.colorTheme": "Default Dark+",
    "rust-analyzer.check.command": "clippy",
    "window.commandCenter": false,
    "workbench.layoutControl.enabled": false,
}
```


## 其他插件

### Git插件

我没有用[GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)，而是用下面两个插件，因为GitLens功能太多了，还是商业化的。

| 插件名 | 说明 |
| --- | --- |
| [GitHistory](https://marketplace.visualstudio.com/items?itemName=donjayamanne.githistory) | `cmd + shift + p`输入`git log`可以看完整提交历史 |
| [GitBlame](https://marketplace.visualstudio.com/items?itemName=waderyan.gitblame) | 显示每行是谁在什么时候修改的 |

