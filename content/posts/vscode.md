---
title: "vscode"
date: 2023-07-11T19:07:00+08:00
draft: false
categories: [ "undefined"]
tags: ["software","github"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 字体配置——使用JetBrains Mono

1. 下载Jetbrians Mono字体：[how-to-install](https://www.jetbrains.com/lp/mono/#how-to-install)
2. 解压缩
3. 安装
    1. Mac下将ttf文件夹下的文件全选，右击选择打开，安装所有字体
    2. Centos9下， 将ttf文件夹下的文件全部移动到 `/usr/share/fonts/${newdir}`下 , `yum install -y fontconfig` 并执行 `fc-cache` 。然后执行 `fc-list` 即可看到新的字体 
4. 搜索font family，改成 `'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace` 。
5. 搜索font size，改成13。如果这个字体还不够大，可以 `command + +`来放大UI。
6. 搜索line height，改成1.6。

TIPS：

1. 建议打开vscode的配置同步功能。
2. 本地的字体设置对远程开发同样生效。

## 快捷键配置

1. 按 `cmd+k` ，再按 `cmd+s`，进入快捷键设置
2. 点击右上角按钮进入原始文件 `keybindings.json`

![Alt text](/img/vscode-keybindings-setting.png)

3. 修改文件内容如下：

| 快捷键 | 作用 |
| --- | --- |
| `cmd+m` | 用于切换多个终端，特别是在 `cmd+shift+b` 触发构建任务之后 |
| `option+o` | 用于打开remote explorer窗口，在多个远程开发环境中切换 |
| `option+t` | 用于打开outline窗口，用于查看大纲或者函数列表 |
| `cmd+k cmd+g` | 用于查看git log graph，需要git graph插件 |
| `cmd+k cmd+h` | 查看方法的引用路径 |

**macOS**:

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
    },
    {
        "key": "cmd+k cmd+g",
        "command": "git-graph.view" // 需要git-graph插件
    },
    {
        "key": "cmd+k cmd+h",
        "command": "references-view.showCallHierarchy",
        "when": "editorHasCallHierarchyProvider"
    },
    {
        "key": "shift+alt+h",
        "command": "-references-view.showCallHierarchy",
        "when": "editorHasCallHierarchyProvider"
    }
]
```

**windows**:

```json
// 将键绑定放在此文件中以覆盖默认值
[
    {
        "key": "ctrl+m",
        "command": "workbench.action.terminal.focusNext"
    },
    {
        "key": "alt+o",
        "command": "workbench.view.remote"
    },
    {
        "key": "alt+t",
        "command": "outline.focus"
    },
    {
        "key": "ctrl+k ctrl+g",
        "command": "git-graph.view" // 需要git-graph插件
    },
    {
        "key": "ctrl+k ctrl+h",
        "command": "references-view.showCallHierarchy",
        "when": "editorHasCallHierarchyProvider"
    },
    {
        "key": "shift+alt+h",
        "command": "-references-view.showCallHierarchy",
        "when": "editorHasCallHierarchyProvider"
    },
]
```

## 其他快捷键

| 作用 | MacOS快捷键 | Windows快捷键 | 备注 |
| --- | --- | --- | --- |
| Expand / shrink selection | ⌃⇧⌘ → / ← | Shift+Alt+→ / ← |  |
| Go to Line... | ⌃G | Ctrl+G |  |
| Change language mode | ⌘K M | Ctrl+K M |  |
| Go back / forward | ⌃- / ⌃⇧- | Alt+ ← / → |  |
| Toggle word wrap | ⌥Z | alt + z |  |
| 打开copilot chat | ctrl+cmd+i | ctrl+alt+i | 需要copilot chat插件 |
| 新建copilot chat | ⌃l | ctrl + l | 需要copilot chat插件 |
| Delete line | ⇧⌘K | Ctrl+Shift+K |  |
| 向下复制一行 | ⌥⇧⬇️ | shift+alt+⬇️ |  |

> 内置快捷键cheatsheet 
> 1. [MacOS快捷键](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf)
> 2. [Windows快捷键](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-windows.pdf)

## 远程开发

1. 安装 `Remote-ssh` 插件。
2. 使用ssh连接到远程服务器。推荐配置是2C2G以上。为了让远程服务器流畅连接网络，使用了clash做分流，并将clash作为系统代理。
    - 也可以在ssh config中增加 `RemoteForward 7890 localhost:7890` 使用本地的clash作为代理。
3. 历史记录保存在 `~/.ssh/config` 中。

## 卸载远程服务器vscode server

> **这个比想象的更加常用，因为在大型的项目中，符号跳转经常导致CPU占用很高并且无响应**

1. 执行命令 `Remote-SSH: Uninstall VS Code Server from Host` **不推荐，实测没有卸载干净**
2. 或手动执行

```bash
cat > /usr/local/bin/killcode <<\EOF
# Kill server processes
kill -9 $(ps aux | grep vscode-server | grep $USER | grep -v grep | awk '{print $2}')
# Delete related files and folder
rm -rf $HOME/.vscode-server # Or ~/.vscode-server-insiders
EOF
chmod +x /usr/local/bin/killcode
killcode
```

## Rust开发

### 安装四个插件：

| 插件名 | 说明 |
| --- | --- |
| rust-analyzer | rust插件 |
| codelldb | 调试插件 |
| tamasfe.even-better-toml | toml格式化 |
| fill-labs.dependi | crate.io插件 **自动检查依赖有没有更新**|

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
		    "label": "rust: cargo build",
			"presentation": {
				"reveal": "silent",
			}
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
            // https://github.com/vadimcn/codelldb/blob/v1.10.0/MANUAL.md#rust-language-support
            "sourceLanguages": [
                "rust"
            ],
            // https://code.visualstudio.com/docs/editor/variables-reference
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

## Golang开发

1. 安装golang

```bash
curl https://go.dev/dl/go1.21.11.linux-amd64.tar.gz -Lf -o /tmp/golang.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/golang.tar.gz
if ! grep "go/bin" ~/.zshrc;then
  export PATH=$PATH:/usr/local/go/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
fi
```

2. 安装插件 `golang.go`。
3. 安装相关的依赖

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

**注意**：vscode好像不能正确处理软链接，所以最好不好把项目放在软链接的项目中，或者配置 `substitutePath`。其他高级功能可以见 [vscode-go debugging](https://github.com/golang/vscode-go/wiki/debugging)

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
            "output": "__debug_bin_main",
            "args": [
                "--addr=localhost:7788",
                "--refer=arloor"
                ,"--tls=true"
            ]
        },        
        {// 参考 https://blog.csdn.net/passenger12234/article/details/122930124
            "name": "Test Debug", // debug 单测
            "type": "go",
            "mode": "test",
            "request": "launch",
            "buildFlags": [
                "-a", // force rebuilding of packages that are already up-to-date. 
            ],
            // "program": "${relativeFileDirname}", // 当前打开的目录
            "program": "./internal/app",
            "output": "__debug_bin_test",
            "args": [
                "-test.v", // 使t.Log()输出到console
                // "-test.run",
                // "^TestGetLlamAccessPoint$"
                // "-test.bench",
                // "BenchmarkTranslateWithFallback",
                // "-test.benchmem"
            ],
        },
    ]
}
```

其中 `Test debug` 相当于：

```bash
go test -c github.com/arloor/xxxx/internal/app -o __debug_bin_test -gcflags='all=-N -l' # -gcflags是vscode自动加入的，用于关闭优化，使得可以断点调试
./__debug_bin_test -test.v -test.run="^TestGetRTMPAccessPoint$" -test.bench="BenchmarkTranslateWithFallback" -test.benchmem
# 可以参考 go help test, go help testflag
```

4. settings.json中golang相关配置

```json
{
    "go.lintTool": "golangci-lint",
    "go.toolsManagement.autoUpdate": true,
    "go.formatTool": "gofmt",
    "[go]": {
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": "always"
        }
    },
    "go.testFlags": [ // 只对TestXXXX方法上的run按钮生效
        "-v", // 使t.Log()输出到console
    ],
    "go.formatFlags": [
        "-w"
    ],
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

## integrated terminal

我在远程开发时经常遇到重新连接远程机器时，集成terminal没有正常初始化，表现为shell标记旁边出现黄色感叹号。参考[Terminal Shell Integration](https://code.visualstudio.com/docs/terminal/shell-integration)，发现需要关闭“自动脚本注入”，选择手动开启。具体操作是：

1. 按 `cmd + ,` 打开设置，不勾选下面的选项。对应 settings.json 中的配置是`"terminal.integrated.shellIntegration.enabled": false`

![alt text](/img/disable-vscode-integeted-terminal.png)

2. 在 zshrc 中手动开启集成terminal

Linux上

```bash
if ! grep TERM_PROGRAM ~/.zshrc;then
  echo '[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"' >> ~/.zshrc
fi
```


MacOS上：

```bash
if ! grep TERM_PROGRAM ~/.zshrc;then
  echo '[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code --locate-shell-integration-path zsh)"' >> ~/.zshrc
fi
```

## 文件自动保存+自动格式化

> files.autoSave设置成延迟时，自动format无效

```json
{
    "editor.formatOnSave": true,
    "files.autoSave": "onFocusChange",
}
```

## 操作系统设置

### macOS 解除F11的快捷键的占用

设置 -> 键盘 -> 键盘快捷键

{{<imgx src="/img/macOS-diable-F11.png" alt="" width="550px" style="max-width: 100%;">}}

### Windows 关闭简体中文输入法的简体繁体切换

不然会占用 `ctrl  + shift  + F`

{{<imgx src="/img/windows-disable-jianfan-qiehuan.png" alt="" width="550px" style="max-width: 100%;">}}

## 其他插件

### Git插件

我没有用[GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)，而是参考[VSCode 或许不需要 GitLens](https://juejin.cn/post/7316097536547700775)用了下面的插件

| 插件名 | 说明 |
| --- | --- |
| [Git Graph](https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph) | `cmd + shift + p`输入`git log`可以看完整提交历史 |
| [GitBlame](https://marketplace.visualstudio.com/items?itemName=waderyan.gitblame) | 显示每行是谁在什么时候修改的 |

并且为这些插件做了些配置变更：

```json
{
    "gitblame.inlineMessageEnabled": true,
    "gitblame.inlineMessageFormat": "${author.name}, (${time.ago}) · ${commit.summary}",
    "git-graph.commitDetailsView.location": "Docked to Bottom",
    "git-graph.date.format": "ISO Date & Time",
}
```

## 我的vscode配置备份

```json
{
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
    "git.autofetch": true,
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
        "mhutchie.git-graph",
        "github.copilot",
        "github.vscode-github-actions", // github actions
        "rust-analyzer", // rust-analyzer
        "codelldb",
        "tamasfe.even-better-toml",
        "golang.go",
        "ms-python.vscode-pylance",
        "ms-python.python"
    ],
    "workbench.colorTheme": "Default Dark+",
    "rust-analyzer.check.command": "clippy",
    "window.commandCenter": false,
    "workbench.layoutControl.enabled": false,
    "go.lintTool": "golangci-lint",
    "remote.SSH.remotePlatform": {
        "bi.arloor.com": "linux",
        "pl.arloor.com": "linux"
    },
    "go.toolsManagement.autoUpdate": true,
    "diffEditor.ignoreTrimWhitespace": true,
    "debug.onTaskErrors": "showErrors",
    "diffEditor.renderSideBySide": true,
    "github.copilot.editor.enableAutoCompletions": true,
    "terminal.integrated.shellIntegration.enabled": false,
    "go.formatTool": "gofmt",
    "editor.formatOnSave": true,
    "files.autoSave": "afterDelay",
    "terminal.integrated.defaultProfile.osx": "zsh",
    "[go]": {
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": "always"
        }
    },
    "go.testFlags": [ // 只对TestXXXX方法上的run按钮生效
        "-v", // 使t.Log()输出到console
    ],
    "go.formatFlags": [
        "-w"
    ],
    "security.workspace.trust.untrustedFiles": "open",
    "go.testExplorer.showOutput": false,
    "gitblame.inlineMessageEnabled": true,
    "gitblame.inlineMessageFormat": "${author.name}, (${time.ago}) · ${commit.summary}",
    "github.copilot.advanced": {
        "authProvider": "github"
    },
    "files.associations": {
        "*.json": "jsonc"
    },
    "diffEditor.hideUnchangedRegions.enabled": true,
    "terminal.integrated.profiles.windows": {
        "PowerShell": {
            "source": "PowerShell",
            "icon": "terminal-powershell"
        },
        "Command Prompt": {
            "path": [
                "${env:windir}\\Sysnative\\cmd.exe",
                "${env:windir}\\System32\\cmd.exe"
            ],
            "args": [],
            "icon": "terminal-cmd"
        },
        "Git Bash": {
            "source": "Git Bash"
        },
        "Debian (WSL)": {
            "path": "C:\\Windows\\System32\\wsl.exe",
            "args": [
                "-d",
                "Debian"
            ]
        },
        "Windows PowerShell": {
            "path": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        }
    },
    "terminal.integrated.defaultProfile.windows": "Windows PowerShell",
    "dev.containers.executeInWSL": true,
    "diffEditor.experimental.showMoves": true,
    "git-graph.commitDetailsView.location": "Docked to Bottom",
    "git-graph.date.format": "ISO Date & Time",
}
```