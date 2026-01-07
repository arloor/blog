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

以后可能以 golang 谋生一段时间了，开个 golang 的笔记

<!--more-->

## 安装 golang

### linux-amd64

```bash
version=1.22.12
curl "https://go.dev/dl/go${version}.linux-amd64.tar.gz" -Lf -o /tmp/golang.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/golang.tar.gz
if ! grep "go/bin" ~/.zshrc;then
  export PATH=$PATH:/usr/local/go/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
fi
```

### darwin-arm64

```bash
version=1.22.12
sudo rm -f /tmp/golang.tar.gz
curl "https://go.dev/dl/go${version}.darwin-arm64.tar.gz" -Lf -o /tmp/golang.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/golang.tar.gz
if ! grep "go/bin" ~/.zshrc;then
  export PATH=$PATH:/usr/local/go/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
fi
```

或者到[https://go.dev/dl/](https://go.dev/dl/)下载安装包安装

### 安装多版本

```bash
go install golang.org/dl/go1.24.3@latest
go1.24.3 download
go1.24.3 version

which go1.24.3
go1.24.3 env GOROOT # GOROOT=~/sdk/go1.24.3
ls -lh ~/go/bin/go1.24.3
```

## 设置私有仓库等 golang 环境变量

```bash
go env -w GOPROXY="https://goproxy.cn,https://proxy.golang.org,direct"
go env -w GOPRIVATE="*.xxxx.xxx,*.xxxxx.cn,git.xxxxxx.com"
go env -w GOSUMDB="sum.golang.google.cn"
```

## 设置 go test 的快捷命令

```bash
mkdir -p ~/bin
if ! grep "PATH=~/bin" ~/.zshrc;then
  export PATH=~/bin:$PATH
  echo 'export PATH=~/bin:$PATH' >> ~/.zshrc
fi
cat > ~/bin/testgo <<\EOF
go test -gcflags='all=-N -l' -v --count=1 "$@"
EOF
chmod +x ~/bin/testgo
```

## vscode 设置

1. 首先安装插件 `golang.go`。

2. 然后使用 `cmd + shift + p` 输入"Go Install/Update Packages"，安装/升级依赖的包，参考[tools](https://github.com/golang/vscode-go/wiki/tools)和[/extension/src/goToolsInformation.ts](https://github.com/golang/vscode-go/blob/master/extension/src/goToolsInformation.ts)。

> The extension depends on go, gopls, dlv and other optional tools. If any of the dependencies are missing, the ⚠️ Analysis Tools Missing warning is displayed. Click on the warning to download dependencies.See the [tools documentation](https://github.com/golang/vscode-go/wiki/tools) for a complete list of tools the extension depends on.

3. 配置 `launch.json`:

**注意**：golang debug 不能正确处理软链接，所以最好不要把项目放在软链接的文件夹中，或者配置 `substitutePath`，见[Debug symlink directories](https://github.com/golang/vscode-go/wiki/debugging#debug-symlink-directories)和[go.delveConfig settings](https://github.com/golang/vscode-go/wiki/debugging#settings)(用于 CodeLens 里的 debug test 按钮)。其他高级配置可以见 [vscode-go debugging](https://github.com/golang/vscode-go/wiki/debugging)，也可以见 [delve 的调试命令 ˝](https://github.com/go-delve/delve/blob/master/Documentation/cli/README.md)。

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
      "args": ["--addr=localhost:7788", "--refer=arloor", "--tls=true"]
    },
    {
      // 参考 https://blog.csdn.net/passenger12234/article/details/122930124
      "name": "Test Debug", // debug 单测
      "type": "go",
      "mode": "test",
      "request": "launch",
      "buildFlags": [
        "-a" // force rebuilding of packages that are already up-to-date.
      ],
      // "program": "${relativeFileDirname}", // 当前打开的目录
      "program": "./internal/app",
      "output": "__debug_bin_test",
      "args": [
        "-test.v" // 使t.Log()输出到console
        // "-test.run",
        // "^TestGetLlamAccessPoint$"
        // "-test.bench",
        // "BenchmarkTranslateWithFallback",
        // "-test.benchmem"
      ]
    }
  ]
}
```

其中 `Test debug` 相当于：

```bash
go test -c github.com/arloor/xxxx/internal/app -o __debug_bin_test -gcflags='all=-N -l' # -gcflags是vscode自动加入的，用于关闭优化，使得可以断点调试
./__debug_bin_test -test.v -test.run="^TestGetRTMPAccessPoint$" -test.bench="BenchmarkTranslateWithFallback" -test.benchmem
# 可以参考 go help test, go help testflag
```

4. 配置 settings.json:

```json
{
  "go.lintTool": "golangci-lint-v2",
  "go.lintFlags": ["-n", "-v"],
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
    "--count=1" // 不缓存go test的结果
  ],
  "go.formatFlags": ["-w"]
}
```

> 这样的配置下仍有一个棘手的问题难以解决：CodeLens 的 debug test 难以打印 `t.Logf` 的日志，除非 test fail，万般尝试都失败，最终放弃吧。

## golangci-lint v2 使用

安装：

```bash
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.7.2
```

- [golangci-lint v2 文档](https://golangci-lint.run/docs/configuration/)

下载本站的配置文件:

```bash
curl https://www.arloor.com/golangci/v2/.golangci.yml -f -o ~/.golangci.yml
```

## golangci-lint v1 使用

安装

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.64.8
```

参考文档：

- [Configuration](https://golangci.github.io/legacy-v1-doc/usage/configuration/)

需要在某些地方忽略某个 `linter` 时，可以注释 `//nolint:xx,xx`，这个注释可以用在 go 文件开头、行末、函数、结构体，分别代表不同的作用域。

下载本站的配置文件:

```bash
curl https://www.arloor.com/golangci/v1/.golangci.yml -f -o ~/.golangci.yml
```

## defer

1. defer 匿名函数中“**捕获**”的参数是**执行时**的最新值。而“**传递**”的参数是声明 defer 时确定的。
2. defer 函数可以修改返回值，只要返回值是“**捕获**”的
3. 探讨 defer 和 for、if 一起使用的情况(这个有点坑的)： [Golang Defer: From Basic To Traps](https://victoriametrics.com/blog/defer-in-go/)

```go
package main

import "fmt"

func main() {
	i := 0
	defer func(n int) {
		fmt.Println("// catch", i)
		fmt.Println("// param", n)
	}(i)
	i = 1
	defer func(n int) {
		fmt.Println("// catch", i)
		fmt.Println("// param", n)
	}(i)
	i = 2
	defer func(n int) {
		fmt.Println("// catch", i)
		fmt.Println("// param", n)
	}(i)

	fmt.Println(deferModReturn())
	fmt.Println()
}

func deferModReturn() (str string) {
	str = "# raw"
	defer func() {
		str = "// defer modified"
	}()
	return str
}

// defer modified

// catch 2
// param 2
// catch 2
// param 1
// catch 2
// param 0
```

## 类型转换

[go 之 4 种类型转换-腾讯云开发者社区-腾讯云 (tencent.com)](https://cloud.tencent.com/developer/article/2358351)

1. **显式转换： T(x)**
2. **隐式转换：不需要开发人员编写转换代码，由编译器自动完成。**
3. **类型断言：newT, ok := x.(T)**
4. **unsafe.Pointer 强制转换**

## Golang 枚举

> 垃圾的一笔，连个原生的枚举都没

```bash
go get -u github.com/dmarkham/enumer
```

```golang
package main

//go:generate go run github.com/dmarkham/enumer -type=Strategy -output=enumer_autogen.go
type Strategy int

// 使用常量定义枚举值
const (
	Default Strategy = iota
)
```

## 引入开发分支作为依赖

```bash
go get github.com/arloor/xxxx@feature/xxxx
```

## context 的 key 不要使用内置类型

```golang
type action struct{} // 自定义类型作为key。空struct不占内存

    // 1. 设置value
	tmp := context.WithValue(context.Background(), action{}, "someAction")
    // 2. 读取value
	fmt.Printf("%s", tmp.Value(action{}).(string))
```
