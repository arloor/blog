---
title: "vscode"
date: 2023-07-11T19:07:00+08:00
draft: false
categories: ["undefined"]
tags: ["software", "github"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
highlightjslanguages:
  - powershell
---

## 字体配置——使用 JetBrains Mono

1. 下载 Jetbrians Mono 字体：[how-to-install](https://www.jetbrains.com/lp/mono/#how-to-install)
2. 解压缩
3. 安装
   1. Mac 下将 ttf 文件夹下的文件全选，右击选择打开，安装所有字体
   2. Centos9 下， 将 ttf 文件夹下的文件全部移动到 `/usr/share/fonts/${newdir}`下 , `yum install -y fontconfig` 并执行 `fc-cache` 。然后执行 `fc-list` 即可看到新的字体
4. 搜索 font family，改成 `'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace` 。
5. 搜索 font size，改成 13。如果这个字体还不够大，可以 `command + +`来放大 UI。
6. 搜索 line height，改成 1.6。

TIPS：

1. 建议打开 vscode 的配置同步功能。
2. 本地的字体设置对远程开发同样生效。

## 快捷键配置

1. 按 `cmd+k` ，再按 `cmd+s`，进入快捷键设置
2. 点击右上角按钮进入原始文件 `keybindings.json`

![Alt text](/img/vscode-keybindings-setting.png)

3. 修改文件内容如下：

| 快捷键        | 作用                                                      |
| ------------- | --------------------------------------------------------- |
| `cmd+m`       | 用于切换多个终端，特别是在 `cmd+shift+b` 触发构建任务之后 |
| `option+o`    | 用于打开 remote explorer 窗口，在多个远程开发环境中切换   |
| `option+t`    | 用于打开 outline 窗口，用于查看大纲或者函数列表           |
| `cmd+k cmd+g` | 用于查看 git log graph，需要 git graph 插件               |
| `cmd+k cmd+h` | 查看方法的引用路径                                        |

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
  },
  {
    "key": "cmd+j",
    "command": "workbench.action.terminal.toggleTerminal",
    "when": "terminal.active"
  },
  {
    "key": "ctrl+`",
    "command": "-workbench.action.terminal.toggleTerminal",
    "when": "terminal.active"
  },
  {
    "key": "ctrl+shift+alt+`",
    "command": "-workbench.action.terminal.newInNewWindow",
    "when": "terminalHasBeenCreated || terminalProcessSupported"
  },
  {
    "key": "cmd+k cmd+j",
    "command": "workbench.action.createTerminalEditorSide",
    "when": "terminalProcessSupported"
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
  }
]
```

## 其他快捷键

| 作用                                                                                                   | MacOS 快捷键 | Windows 快捷键  | 备注                   |
| ------------------------------------------------------------------------------------------------------ | ------------ | --------------- | ---------------------- |
| Expand / shrink selection                                                                              | ⌃⇧⌘ → / ←    | Shift+Alt+→ / ← |                        |
| Go to Line...                                                                                          | ⌃G           | Ctrl+G          |                        |
| Change language mode                                                                                   | ⌘K M         | Ctrl+K M        |                        |
| Go back / forward                                                                                      | ⌃- / ⌃⇧-     | Alt+ ← / →      |                        |
| Toggle word wrap                                                                                       | ⌥Z           | alt + z         |                        |
| 打开 copilot chat                                                                                      | ⌃⌘I          | ctrl+alt+i      | 需要 copilot chat 插件 |
| 打开[copilot edit](https://code.visualstudio.com/docs/copilot/copilot-edits)，根据 prompt 修改多个文件 | ⇧⌘I          | ctrl+shift+i    | 需要 copilot chat 插件 |
| 新建 copilot chat                                                                                      | ⌃l           | ctrl + l        | 需要 copilot chat 插件 |
| Delete line                                                                                            | ⇧⌘K          | Ctrl+Shift+K    |                        |
| 向下复制一行                                                                                           | ⌥⇧⬇️         | shift+alt+⬇️    |                        |

> 内置快捷键 cheatsheet
>
> 1. [MacOS 快捷键](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf)
> 2. [Windows 快捷键](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-windows.pdf)

## 远程开发

1. 安装 `Remote-ssh` 插件。
2. 使用 ssh 连接到远程服务器。推荐配置是 2C2G 以上。为了让远程服务器流畅连接网络，使用了 clash 做分流，并将 clash 作为系统代理。
   - 也可以在 ssh config 中增加 `RemoteForward 7890 localhost:7890` 使用本地的 clash 作为代理。
3. 历史记录保存在 `~/.ssh/config` 中。

### ssh 到 windows 上使用 WSL 开发

我的 WSL 工作在镜像网络模式下，所以在设置-远程的配置文件中设置不自动端口转发：

```json
{
  "remote.autoForwardPorts": false
}
```

我有时会 ssh 到 windows 上的 WSL 远程开发，不自动转发也不方便，折衷的方式是在 ssh 的配置文件中增加一个端口转发，从而在 ssh 中实现端口转发，在 wsl 中不端口转发。

```bash
LocalForward 7788 192.168.5.127:7788
```

### 使用 socat 作为 ProxyCommand，用 http 代理连接 ssh 服务器

```bash
Host *.arloor.*
  ProxyCommand socat - PROXY:localhost:%h:%p,proxyport=6152
```

这使用了 surge 进行代理连接。注意，每次增加 vscode 的 ssh 服务器列表时，vscode 都会把 `proxyport=6152` 改成 `proxyport 6152`，**需要手动改回来**。

对应的 surge 规则是：`AND,((PROCESS-NAME,*socat*), (DEST-PORT,22), (DOMAIN-KEYWORD,arloor,extended-matching)),家里`

### ssh 到 macOS 上远程开发

要 ssh 到 macOS 上进行远程开发，需要额外的命令：

```bash
xcode-select --install # 安装 LLDB.framework
sudo DevToolsSecurity --enable # 永久允许Developer Tools Access 附加到其他进程上，以进行debug
sudo security authorizationdb write system.privilege.taskport.debug allow # 允许remote-ssh调试进程。解决报错：this is a non-interactive debug session, cannot get permission to debug processes.
```

其实第三个命令就是对第二个命令的补充。他们操作的都是 rights definition for: system.privilege.taskport.debug。可以执行下面两条命令来验证，可以发现就是打印格式不同，内容是一样的。

```bash
sudo DevToolsSecurity -status -verbose
sudo security authorizationdb read system.privilege.taskport.debug
```

参考文档：

1. [Debugging with LLDB-MI on macOS](https://code.visualstudio.com/docs/cpp/lldb-mi)
2. [Unable to debug after connecting to macOS via "Remote - SSH" ](https://github.com/vadimcn/codelldb/issues/1079) 解决报错：this is a non-interactive debug session, cannot get permission to debug processes.

如果每次 ssh 到 macOS 都需要输入密码，设置公钥就行：

```bash
echo ssh-rsa xxxxxxxx not@home > ~/.ssh/authorized_keys
```

## 卸载远程服务器 vscode server

> **这个比想象的更加常用，因为在大型的项目中，符号跳转经常导致 CPU 占用很高并且无响应**

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

## Rust 开发

### 安装四个插件：

| 插件名                   | 说明                                     |
| ------------------------ | ---------------------------------------- |
| rust-analyzer            | rust 插件                                |
| codelldb                 | 调试插件                                 |
| tamasfe.even-better-toml | toml 格式化                              |
| fill-labs.dependi        | crate.io 插件 **自动检查依赖有没有更新** |

### 运行方式 1：使用 codelldb 的 cargo 支持直接 cargo build/test

只需要一个 `launch.json` 文件即可。

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
      "name": "Debug rust_http_proxy",
      "cwd": "${workspaceFolder}",
      "terminal": "integrated",
      // https://github.com/vadimcn/codelldb/blob/v1.10.0/MANUAL.md#rust-language-support
      "cargo": {
        // build/test命令
        "args": [
          "build",
          "--bin=rust_http_proxy",
          "--package=rust_http_proxy"
          // "--features",
          // "bpf",
          // "--features",
          // "jemalloc",
          // "--no-default-features",
          // "--features","aws_lc_rs",
          // "--features","pnet",
        ],
        "env": {
          "RUST_BACKTRACE": "1"
        },
        "problemMatcher": "$rustc", // Problem matcher(s) to apply to cargo output.
        "filter": {
          "kind": "bin",
          "name": "rust_http_proxy"
        }
      },
      "sourceLanguages": ["rust"], // 指定源代码语言为 Rust
      "args": [
        // 传递参数
        "-p",
        "7788"
      ],
      "env": {
        "HOSTNAME": "test"
      }
    }
  ]
}
```

### 运行方式 2：tasks.json + launch.json

#### 配置默认 build 任务：`.vscode/tasks.json`

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "type": "cargo",
      "command": "build",
      "problemMatcher": ["$rustc"],
      "args": [
        // "-p",
        // "rust_http_proxy",
      ],
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "label": "rust: cargo build",
      "presentation": {
        "reveal": "silent"
      }
    }
  ]
}
```

#### 配置调试任务 `.vscode/launch.json`

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
      // 虽然lldb支持cargo build，但是restart debug不会重新编译代码，所以不用。见https://github.com/vadimcn/codelldb/issues/988
      "sourceLanguages": ["rust"],
      // https://code.visualstudio.com/docs/editor/variables-reference
      "program": "${workspaceFolder}/target/debug/${workspaceFolderBasename}",
      "args": [],
      "cwd": "${workspaceFolder}",
      "console": "internalConsole",
      "preLaunchTask": "${defaultBuildTask}",
      "env": { "port": "80" }
    }
  ]
}
```

## Python 开发

### python 插件

| 插件名                   | 说明                                                             |
| ------------------------ | ---------------------------------------------------------------- |
| ms-python.python         | python 插件                                                      |
| ms-python.vscode-pylance | python 语言服务                                                  |
| ms-python.debugpy        | python 调试插件                                                  |
| ms-python.pylint         | python lint 插件 **我没装这个插件，因为 pylance 已经有 lint 了** |

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
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

按`cmd + shift + p`，然后输入`select interpreter`，最后选择 venv 中的 python 解释器地址即可。

### 配置 python 调试任务

{{<imgx src="/img/vscode-add-python-debug-1.png" alt="" width="400px" style="max-width: 100%;">}}

{{<imgx src="/img/vscode-add-python-debug-2.png" alt="" width="400px" style="max-width: 100%;">}}

![alt text](/img/vscode-add-python-debug-3.png)

## integrated terminal

我在远程开发时经常遇到重新连接远程机器时，集成 terminal 没有正常初始化，表现为 shell 标记旁边出现黄色感叹号。参考[Terminal Shell Integration](https://code.visualstudio.com/docs/terminal/shell-integration)，发现需要关闭“自动脚本注入”，选择手动开启。具体操作是：

1. 按 `cmd + ,` 打开设置，不勾选下面的选项。对应 settings.json 中的配置是`"terminal.integrated.shellIntegration.enabled": false`

![alt text](/img/disable-vscode-integeted-terminal.png)

2. 在 zshrc 中手动开启集成 terminal

Linux 上

```bash
if ! grep TERM_PROGRAM ~/.zshrc;then
  echo '[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"' >> ~/.zshrc
fi
```

MacOS 上：

```bash
if ! grep TERM_PROGRAM ~/.zshrc;then
  echo '[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code --locate-shell-integration-path zsh)"' >> ~/.zshrc
fi
```

3. 在 windows pwsh 上手动开启集成 terminal

```powershell
if ($env:TERM_PROGRAM -eq "vscode") { . "$(code --locate-shell-integration-path pwsh)" }
```

## 文件自动保存+自动格式化

> files.autoSave 设置成延迟时，自动 format 无效

```json
{
  "editor.formatOnSave": true,
  "files.autoSave": "onFocusChange"
}
```

## 操作系统设置

### macOS 解除 F11 的快捷键的占用

设置 -> 键盘 -> 键盘快捷键

{{<imgx src="/img/macOS-diable-F11.png" alt="" width="550px" style="max-width: 100%;">}}

### Windows 关闭简体中文输入法的简体繁体切换

不然会占用 `ctrl  + shift  + F`

{{<imgx src="/img/windows-disable-jianfan-qiehuan.png" alt="" width="550px" style="max-width: 100%;">}}

## 其他插件

### Git 插件

我没有用[GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)，而是参考[VSCode 或许不需要 GitLens](https://juejin.cn/post/7316097536547700775)用了下面的插件

| 插件名                                                                                | 说明                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Git Graph](https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph)   | `cmd + shift + p`输入`git log`可以看完整提交历史                                                                                                                                                   |
| [Git Graph 新版](https://marketplace.visualstudio.com/items?itemName=Gxl.git-graph-3) | `cmd + shift + p`输入`git log`可以看完整提交历史                                                                                                                                                   |
| [GitBlame](https://marketplace.visualstudio.com/items?itemName=waderyan.gitblame)     | 显示每行是谁在什么时候修改的。PS：vscode 1.96 内置了 git blame 的能力，这个插件可以卸载了，启用方式见：[November 2024 (version 1.96)](https://code.visualstudio.com/updates/v1_96#_source-control) |

并且为这些插件做了些配置变更：

```json
{
  "gitblame.inlineMessageEnabled": true,
  "gitblame.inlineMessageFormat": "${author.name}, (${time.ago}) · ${commit.summary}",
  "git-graph.commitDetailsView.location": "Docked to Bottom",
  "git-graph.date.format": "ISO Date & Time"
}
```

## 我的 vscode 配置备份

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
    "plaintext": true,
    "markdown": true,
    "scminput": false,
    "ini": false
  },
  "python.analysis.inlayHints.callArgumentNames": "all",
  "python.analysis.inlayHints.functionReturnTypes": true,
  "python.analysis.inlayHints.variableTypes": true,
  "python.analysis.autoFormatStrings": true,
  "python.languageServer": "Pylance", // python languageServer插件
  "github-actions.workflows.pinned.refresh.enabled": true, // 自动刷新被pin住的github action的执行状态，可能触发Github API的限制
  "github-actions.workflows.pinned.refresh.interval": 10,
  "remote.SSH.defaultExtensions": [
    "gxl.git-graph-3",
    "github.copilot",
    "github.vscode-github-actions", // github actions
    "rust-lang.rust-analyzer", // rust-analyzer
    "vadimcn.vscode-lldb",
    "tamasfe.even-better-toml",
    "golang.go",
    "ms-python.vscode-pylance",
    "ms-python.python",
    "fill-labs.dependi"
  ],
  "workbench.colorTheme": "Default Dark+",
  "rust-analyzer.check.command": "clippy",
  "rust-analyzer.completion.autoimport.exclude": [
    {
      "path": "anyhow::Ok",
      "type": "always"
    },
    {
      "path": "prometheus_client::metrics::info",
      "type": "always"
    }
  ],
  "window.commandCenter": false,
  "workbench.layoutControl.enabled": false,
  "go.lintTool": "golangci-lint-v2",
  "go.lintFlags": [
    // "-c=~/.golangci.yml", // 会逐层寻找配置文件，所以不需要指定
    // "-n", // 仅lint新代码
    "-v",
    "--fast-only" // 快速模式，跳过一些耗时的检查
    // "--tests=false", // 不lint测试代码
    // "--fix", // 自动修复问题
  ],
  "remote.SSH.remotePlatform": {
    "windows": "windows",
    "wsl": "linux",
    "mac": "macOS",
    "station": "linux",
    "windows.arloor.com": "windows",
    "devbox": "linux"
  },
  "go.toolsManagement.autoUpdate": true,
  "diffEditor.ignoreTrimWhitespace": false,
  "debug.onTaskErrors": "showErrors",
  "diffEditor.renderSideBySide": false,
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
  "go.testFlags": [
    "-gcflags=all=-l", // 针对run test禁用内联优化，使gomonkey可以成功打桩。对debug test不生效，因为golang插件针对debug test自行设置了-gcflags="all=-l -N"
    "-v", // 使run test可以输出t.Logf的日志。对debug test不生效，只在test fail的时候才会打印t.Logf的日志
    "--count=1" // 不缓存go test的结果
  ],
  "go.formatFlags": ["-w"],
  "security.workspace.trust.untrustedFiles": "open",
  "go.testExplorer.showOutput": true,
  "files.associations": {
    "*.json": "jsonc"
  },
  "terminal.integrated.profiles.windows": {
    "PowerShell": {
      "path": "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
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
      "source": "Git Bash",
      "icon": "terminal-git-bash"
    },
    "Debian (WSL)": {
      "path": "C:\\Windows\\System32\\wsl.exe",
      "args": ["-d", "Debian"]
    },
    "Windows PowerShell": {
      "path": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    }
  },
  "terminal.integrated.defaultProfile.windows": "PowerShell",
  "dev.containers.executeInWSL": true,
  "diffEditor.experimental.showMoves": true,
  "git-graph.commitDetailsView.location": "Docked to Bottom",
  "git-graph.date.format": "ISO Date & Time",
  "git.blame.editorDecoration.enabled": true,
  "git.blame.statusBarItem.enabled": true,
  "git.blame.editorDecoration.template": "${authorName} (${authorDateAgo}), ${subject}",
  "remote.SSH.localServerDownload": "off",
  "[json]": {
    "editor.defaultFormatter": "vscode.json-language-features"
  },
  "typescript.updateImportsOnFileMove.enabled": "always",
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[dockerfile]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  "[jsonc]": {
    "editor.defaultFormatter": "vscode.json-language-features"
  },
  "chat.agent.enabled": true,
  "editor.largeFileOptimizations": false,
  "editor.accessibilitySupport": "off",
  "redhat.telemetry.enabled": true,
  "github.copilot.nextEditSuggestions.enabled": false,
  "[typescript]": {
    "editor.defaultFormatter": "vscode.typescript-language-features"
  },
  "terminal.integrated.shellIntegration.enabled": false,
  "[dockercompose]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 2,
    "editor.autoIndent": "advanced",
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },
  "[github-actions-workflow]": {
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },
  "workbench.panel.defaultLocation": "bottom",
  "terminal.integrated.enableMultiLinePasteWarning": "never",
  "claudeCode.useTerminal": true,
  "claudeCode.environmentVariables": [
    {
      "name": "ANTHROPIC_BASE_URL",
      "value": "https://api.burn.hair"
    },
    {
      "name": "ANTHROPIC_API_KEY",
      "value": "sk-M4vTPwc745UT1HtyJJZpd2YAWcKiYHRH9PAsmOIJWPmt1tb7"
    }
    // {
    //   "name": "ANTHROPIC_AUTH_TOKEN",
    //   "value": "sk-M4vTPwc745UT1HtyJJZpd2YAWcKiYHRH9PAsmOIJWPmt1tb7"
    // }
  ],
  "chat.tools.terminal.autoApprove": {
    "cargo build": true,
    "/^cargo check -p rust_http_proxy$/": {
      "approve": true,
      "matchCommandLine": true
    }
  },
  "claudeCode.preferredLocation": "panel",
  "chat.mcp.gallery.enabled": true,
  "[markdown]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "chat.viewSessions.orientation": "stacked",
  "[yaml]": {
    "diffEditor.ignoreTrimWhitespace": false
  }
}
```
