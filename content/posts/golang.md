---
title: "Golang笔记"
subtitle:
tags: 
- golang
date: 2024-10-13T01:14:37+08:00
lastmod: 2024-10-13T01:14:37+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

以后可能以golang谋生一段时间了，开个golang的笔记

<!--more-->

## 安装golang (linux-amd64)

```bash
version=1.22.6
curl https://go.dev/dl/go${version}.linux-amd64.tar.gz -Lf -o /tmp/golang.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/golang.tar.gz
if ! grep "go/bin" ~/.zshrc;then
  export PATH=$PATH:/usr/local/go/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
fi
```

或者到[https://go.dev/dl/](https://go.dev/dl/)下载安装包安装

## 设置go test的快捷命令

```bash
mkdir -p ~/bin
if ! grep "PATH=~/bin" ~/.zshrc;then
  export PATH=~/bin:$PATH
  echo 'export PATH=~/bin:$PATH' >> ~/.zshrc
fi
cat > ~/bin/testgo <<\EOF                    
go test -gcflags='all=-N -l' -v "$@"
EOF
chmod +x ~/bin/testgo
```

## vscode设置

首先安装插件 `golang.go`。然后参考 [codespaces devcontainers go feature install.sh](https://github.com/devcontainers/features/blob/main/src/go/install.sh#L177)，安装相关的依赖：

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

> The extension depends on go, gopls, dlv and other optional tools. If any of the dependencies are missing, the ⚠️ Analysis Tools Missing warning is displayed. Click on the warning to download dependencies.See the [tools documentation](https://github.com/golang/vscode-go/wiki/tools) for a complete list of tools the extension depends on.

最后配置 `launch.json`:

**注意**：golang debug不能正确处理软链接，所以最好不要把项目放在软链接的文件夹中，或者配置 `substitutePath`，见[Debug symlink directories](https://github.com/golang/vscode-go/wiki/debugging#debug-symlink-directories)和[go.delveConfig settings](https://github.com/golang/vscode-go/wiki/debugging#settings)(用于CodeLens里的debug test按钮)。其他高级配置可以见 [vscode-go debugging](https://github.com/golang/vscode-go/wiki/debugging)

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

也需要注意 `settings.json` 中golang相关配置

```json
{
    "go.lintTool": "golangci-lint",
    "go.toolsManagement.autoUpdate": true,
    "go.formatTool": "gofmt",
    "go.testExplorer.showOutput": true,
    "[go]": {
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": "always"
        }
    },
    "go.testFlags": [
        "-gcflags=all=-l", // 针对run test禁用内联优化，使gomonkey可以成功打桩。对debug test不生效，因为golang插件针对debug test自行设置了-gcflags="all=-l -N"
        "-v", // 使run test可以输出t.Logf的日志。对debug test不生效，只在test fail的时候才会打印t.Logf的日志
    ],
    "go.formatFlags": [
        "-w"
    ],
}
```

这样的配置下仍有一个棘手的问题难以解决：CodeLens的debug test难以打印 `t.Logf` 的日志，除非test fail，万般尝试都失败，最终放弃吧。

## golangci-lint使用

参考文档：

- [Configuration](https://golangci-lint.run/usage/configuration/)
- [Linters](https://golangci-lint.run/usage/linters/)
- [False Positives](https://golangci-lint.run/usage/false-positives/)
- [Nolint Directive](https://golangci-lint.run/usage/false-positives/#nolint-directive)

需要在某些地方忽略某个 `linter` 时，可以注释 `//nolint:xx,xx`，这个注释可以用在go文件开头、行末、函数、结构体，分别代表不同的作用域。

`.golangci.yml` 内容如下：

```yaml
# This file contains all available configuration options with their default values.
# https://github.com/golangci/golangci-lint#configuration

# options for analysis running
run:
  # default concurrency is a available CPU number
  #concurrency: 4

  # timeout for analysis, e.g. 30s, 5m, default is 1m
  #deadline: 1m

  # exit code when at least one issue was found, default is 1
  issues-exit-code: 1

  # include test files or not, default is true
  tests: true

# all available settings of specific linters
linters-settings:
  # errcheck 检查 "unchecked errors", 如: 类型断言没有接收err, 没有接收函数返回的err, 用匿名变量接收err ......
  errcheck:
    # report about not checking of errors in type assetions: `a := b.(MyStruct)`;
    # default is false: such cases aren't reported by default.
    check-type-assertions: true

    # report about assignment of errors to blank identifier: `num, _ := strconv.Atoi(numStr)`;
    # default is false: such cases aren't reported by default.
    check-blank: true

    # path to a file containing a list of functions to exclude from checking
    # see https://github.com/kisielk/errcheck#excluding-functions for details
    #exclude: /path/to/file.txt

  govet:
    enable:
    - shadow
    settings: # settings per analyzer
      printf: # analyzer name, run `go tool vet help` to see all analyzers
        funcs: # run `go tool vet help printf` to see available settings for `printf` analyzer
          - (github.com/golangci/golangci-lint/pkg/logutils.Log).Infof
          - (github.com/golangci/golangci-lint/pkg/logutils.Log).Warnf
          - (github.com/golangci/golangci-lint/pkg/logutils.Log).Errorf
          - (github.com/golangci/golangci-lint/pkg/logutils.Log).Fatalf

  # gofmt 格式检查 format check
  gofmt:
    simplify: true # simplify code: gofmt with `-s` option, true by default

  # goimports gofmt检查 + import检查
  goimports:
    # put imports beginning with prefix after 3rd-party packages;
    # it's a comma-separated list of prefixes
    local-prefixes: code.byted.org/bytertc/schedule

  revive:
    rules:
    - name: var-naming
      arguments:
        - [] # AllowList
        - ['SDN'] # DenyList

  # gosimple #提供信息，帮助了解哪些代码可以简化
  #gosimple:

  # staticcheck #提供了巨多的静态检查, detect bugs, suggest code simplifications, point out dead code, and much more.
  #staticcheck:

  # ineffassign 检查只赋值而未被使用的变量
  # https://github.com/gordonklaus/ineffassign
  #ineffassign:

  # typecheck #Like the front-end of a Go compiler, parses and type-checks Go code
  #typecheck:

  #bodyclose: # 检查是否关闭http response body

  #stylecheck: # replacement for golint

  #gosec: 检查安全问题,  https://github.com/securego/gosec

  #unconvert: # 检测不必要的类型转换

  #gochecknoinits: 检查是否有使用init()

  #gochecknoglobals: 检查是否有使用全局变量

  # gocyclo 检查函数的复杂度 https://github.com/alecthomas/gocyclo
  gocyclo:
    min-complexity: 10 # minimal code complexity to report, 30 by default (but we recommend 10-20)

  # dupl 检测可疑的代码复制
  dupl:
    threshold: 100 # tokens count to trigger issue, 150 by default

  # 查找重复的字符串，可以抽取成常量
  goconst:
    min-len: 3 # minimal length of string constant, 3 by default
    min-occurrences: 3 # minimal occurrences count to trigger, 3 by default

  # misspell 拼写检查
  misspell:
    # Correct spellings using locale preferences for US or UK.
    # Default is to use a neutral variety of English.
    # Setting locale to US will correct the British spelling of 'colour' to 'color'.
    locale: US
    #ignore-words:
    #  - someword

  # lll 检测函数行数, 文件行数
  lll:
    line-length: 140 # max line length, lines longer will be reported. Default is 120.
    #tab-width: 1 # tab width in spaces. Default to 1.

  # unparam 检查未被使用的函数参数
  unparam:
    # Inspect exported functions, default is false. Set to true if no external program/library imports your code.
    # XXX: if you enable this setting, unparam will report a lot of false-positives in text editors:
    # if it's called for subdir of a project it can't find external interfaces. All text editor integrations
    # with golangci-lint call it on a directory with the changed file.
    check-exported: false

  # nakedret 检查当函数行数操作一定数量时的 naked return, 用以降低风险
  nakedret:
    # make an issue if func has more lines of code than this setting and it has naked returns; default is 30
    max-func-lines: 30

  # prealloc 检测可以提前分配缓存的slice
  prealloc:
    # XXX: we don't recommend using this linter before doing performance profiling.
    # For most programs usage of prealloc will be a premature optimization.

    # Report preallocation suggestions only on simple loops that have no returns/breaks/continues/gotos in them.
    # True by default.
    simple: true
    range-loops: true # Report preallocation suggestions on range loops, true by default
    for-loops: false # Report preallocation suggestions on for loops, false by default

  # https://github.com/go-critic/go-critic
  # https://go-critic.github.io/overview
  gocritic:
    # Which checks should be enabled; can't be combined with 'disabled-checks';
    # See https://go-critic.github.io/overview#checks-overview
    # To check which checks are enabled run `GL_DEBUG=gocritic golangci-lint run`
    # By default list of stable checks is used.
    #enabled-checks:
    #  - rangeValCopy

    # Which checks should be disabled; can't be combined with 'enabled-checks'; default is empty
    disabled-checks:
      - wrapperFunc
    # Enable multiple checks by tags, run `GL_DEBUG=gocritic golangci-lint` run to see all tags and checks.
    # Empty list by default. See https://github.com/go-critic/go-critic#usage -> section "Tags".
    enabled-tags:
      - performance
      - style
      - experimental
    #settings: # settings passed to gocritic
    #  captLocal: # must be valid enabled check name
    #    paramsOnly: true
    #  rangeValCopy:
    #    sizeThreshold: 32

linters:
  enable-all: false # true: 启用除了disable部分的其他所有linters. 不能与disable_all字段同时设置为true
  # 0, 可以通过命令golangci-lint help linters查看默认enable和disable的lingters
  # 1, 带有[default enable]标记的linter是全部的默认enable的linter, 在这里重复列出是为了方便直观查看
  # 2, golangci-lint默认enable的linters全部都已经在此列出
  # 3, 并且额外enable了bodyclose, unconvert, nakedret, unparam这几个原本默认disable的linters
  # 4, 不在enable列表中的linters都会被disable( 这些原本就属于默认的disable linters)

  enable:
    - errcheck    # [default enable] 检查 "unchecked errors", 如: 类型断言没有接收err, 没有接收函数返回的err, 用匿名变量接收err ......
    - gosimple    # [default enable] 提供信息，帮助了解哪些代码可以简化
    - govet       # [default enable] 检查作用域内变量相互覆盖等风险
    - ineffassign # [default enable] 检查只赋值而未被使用的变量
    - staticcheck # [default enable] 提供了巨多的静态检查, detect bugs, suggest code simplifications, point out dead code, and much more.
    - typecheck   # [default enable] Like the front-end of a Go compiler, parses and type-checks Go code
    - unused      # [default enable] 检查未被使用的常量, 变量, 函数, 和类型
    - bodyclose   # [default disable] 检查是否关闭http response body
    - unconvert   # [default disable] 检测不必要的类型转换
    - nakedret    # [default disable] 检查当函数行数操作一定数量时的 naked return, 用以降低风险
    - unparam     # [default disable] 检查未被使用的函数参数
    - gofmt       # [default disable] 格式检查 format check
    - goimports   # [default disable] gofmt检查 + import检查
    - exportloopref
    - revive

  disable-all: false # true: 关闭除了enbale列表中之外的所有linters. 不能与enable_all字段同时为true
  disable:
    - gochecknoglobals  # [default disable] 检查是否有使用全局变量
    - gochecknoinits    # [default disable] 检查是否有使用init()
    - depguard    # [default disable] 用来检查是否使用了"允许/禁止list"上的package
    - dupl        # [default disable] 检测可疑的代码复制
    - goconst     # [default disable] 查找重复的字符串，可以抽取成常量
    - gocritic    # [default disable]
    - gocyclo     # [default disable] 检查函数的复杂度
    - gosec       # [default disable] 检查安全问题
    - lll         # [default disable] 检测函数行数, 文件行数
    - misspell    # [default disable] 拼写检查
    - prealloc    # [default disable] 检测可以提前分配缓存的slice
    - stylecheck  # [default disable] replacement for golint

  #presets:
  #  - bugs
  #  - unused

issues:

  # Which dirs to exclude: issues from them won't be reported.
  # Can use regexp here: `generated.*`, regexp is applied on full path,
  # including the path prefix if one is set.
  # Default dirs are skipped independently of this option's value (see exclude-dirs-use-default).
  # "/" will be replaced by current OS file path separator to properly work on Windows.
  # Default: []
  exclude-dirs:
    - api/kitex_gen/
    - api/proto_gen/
    - api/hertz_gen/
    - test/mocks/

  # Which files to exclude: they will be analyzed, but issues from them won't be reported.
  # There is no need to include all autogenerated files,
  # we confidently recognize autogenerated files.
  # If it's not, please let us know.
  # "/" will be replaced by current OS file path separator to properly work on Windows.
  # Default: []
  exclude-files:
    - internal/pkg/dsrpc/media_server.autogen.go
    - internal/pkg/dsrpc/schedule_client.autogen.go
    - internal/pkg/dsrpc/media_client.autogen.go
    - internal/pkg/dsrpc/schedule_server.autogen.go

  # Maximum issues count per one linter.
  # Set to 0 to disable.
  # Default: 50
  max-issues-per-linter: 0

  # Maximum count of issues with the same text.
  # Set to 0 to disable.
  # Default: 3
  max-same-issues: 0

  # Show only new issues: if there are unstaged changes or untracked files,
  # only those changes are analyzed, else only changes in HEAD~ are analyzed.
  # It's a super-useful option for integration of golangci-lint into existing
  # large codebase. It's not practical to fix all existing issues at the moment
  # of integration: much better don't allow issues in new code.
  # Default is false.
  new: false
```