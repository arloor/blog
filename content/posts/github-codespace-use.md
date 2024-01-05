---
title: "使用Github Codespaces"
date: 2023-12-21T16:14:54+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

前几天Github告诉我说`You're now in the CodeSpaces beta`，今天体验了下，又发现了一个白嫖计算资源的机会啊。

> 2023-12-11更新：目前Codespaces已经正式发布，我个人将Rust开发全部移到了Codespaces上，下文有我的详细配置，欢迎阅读。收费策略上，目前个人免费账户每月有120小时的Core hours per month额度，这就意味着每月可以白嫖2C8G的机器60小时，或4C16G机器30小时。
<!--more-->

## Codespaces能做什么

现在各行各业都在卷，ide这行也都卷到了远程开发这个领域，Codespaces也是远程开发的一个解决方案。可以认为Github给你开了一个docker容器，里面运行着一个vscode，vscode打开着你的项目文件，你可以进行代码编辑，并依托vscode进行调试等等。

在更早的时候[github.dev](https://github.dev/)就实现了在线编辑的功能，在你的github项目里按下`.`键，就会自动地跳转到Github提供的网页版VS code，参见[https://github.dev/github/dev](https://github.dev/github/dev)。

可以将Codespaces认为是github.dev的扩展和延申。github.dev只具备代码编辑的能力，Codespaces则给你提供了一个docker容器，拿到docker容器的shell后，你能做的事情就海了去了。毕竟docker就是一个linux，你相当于白嫖了一个4核8G的VPS。

## Codespaces的计费规则

目前个人免费账户每月有120小时的Core hours per month额度，这就意味着每月可以白嫖2C8G的机器60小时，或4C16G机器30小时。具体收费政策见[about-billing-for-codespaces](https://docs.github.com/en/billing/managing-billing-for-github-codespaces/about-billing-for-codespaces)


## 新建Codespaces

1. 访问[https://github.com/codespaces](https://github.com/codespaces)
2. 访问[https://github.com/codespaces/new](https://github.com/codespaces/new)创建你的codespace，，输入项目名、分支、地区。地区我选的是美西。因为大陆局域网的原因，想要流畅的使用codespace肯定要科学上网的，我的科学上网途径在美西所以选择了美西。
3. 创建完毕后会自动跳转到Codespaces的页面，等待docker容器创建完成后，你就可以看到一个vscode的页面。不同于github.dev，这是一个全功能的vs code，你可以使用docker的shell。

## 使用Codespaces

我探索到的有三种使用途径:

1. 浏览器打开codespace。新建完Codespaces后会自动地在浏览器打开。
2. vscode通过Remote Explorer连接Codespaces。需要安装`GitHub Codespaces`插件，并登录Github账号，会自动地展示你地Codespaces。
3. Chrome通过App模式打开codespace。和第一种一样也是使用浏览器，好处就在用App模式更加原生。

第三种方式我觉得使用最简单，体验也最好。只需要执行如下代码即可：

```bash
chrome.exe --app=https://${user}-${repo}-${id}.github.dev/ --start-maximized
```

windows下可以编写成vbs脚本，实现双击打开。vbs脚本内容如下

```bash
set ws=WScript.CreateObject("WScript.Shell")
ws.Run "chrome.exe --app=https://${user}-${repo}-${id}.github.dev/ --start-maximized",0
```

## 配置Codespaces

> 更改配置后需要rebuild codespace或者删除重建Codespaces才会生效

### 个人账号级别

**1. 环境变量配置**

配置地址：[settings/codespaces](https://github.com/settings/codespaces)

首先是codespace的环境变量设置，参考[此文档](https://docs.github.com/zh/enterprise-cloud@latest/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces)，我设置了Github Token，以在Codespaces中方便地使用Gihub Cli工具，如下图：

![Alt text](/img/codespaces-env-setting.png)

此后在Codespaces中执行 `echo $GH_TOKEN` 就能看到设置的值了，github cli工具也能识别到该token

[Github的文档](https://docs.github.com/zh/enterprise-cloud@latest/codespaces/reference/security-in-github-codespaces)提到这些环境变量是有安全保证，这个大家自行评判

**2. idle timeout设置**

默认情况下，30分钟空闲后，Codespaces才会暂停以及停止计费，这里设置成5分钟：

![Alt text](/img/codespaces-idle-timeout-setting.png)

注意，空闲是指没有鼠标、键盘操作，已经没有标准输入输出变化

注意，此项更改只对后续的Codespaces生效。

### 代码仓库级别

可以在 `.devcontainer`目录下配置 `devcontainer.json` 文件，配置Codespaces初始化的设置，我的Rust调试环境的配置如下，可供参考

```json
{
    // https://mcr.microsoft.com/en-us/catalog?search=devcontainers
    //"image": "mcr.microsoft.com/devcontainers/rust:bookworm", // 自定义镜像
    "postCreateCommand": "make rust", // 容器创建后的初始化命令
    "customizations": {
        "vscode": {
            "extensions": [ // 定义要装哪些插件
                "vadimcn.vscode-lldb", // 调试插件
                "rust-lang.rust-analyzer", // rust语言支持
                "github.copilot", // github的AI代码提示
                "github.vscode-github-actions", // github actions
                "redhat.vscode-yaml", // yaml语言支持
                "ms-python.python" // python语言支持
            ]
        }
    }
}
```

## 加速访问

由于大陆局域网的问题，上述三种方式都会面临访问速度慢的问题，但不是不可以解决的。

我整理了Codespaces需要访问的域名如下：

1. 用于实时交互数据传输的websocket地址：

```plaintext
*.servicebus.windows.net:443
```

这个应该是关乎延迟、决定体验最重要的一个域名，建议一定要配置代理

> vsls-prod-ins-asse-private-relay.servicebus.windows.net

2. 用于端口转发的websocket地址

```text
*.rel.tunnels.api.visualstudio.com
```

> inc1.rel.tunnels.api.visualstudio.com
> inc1-data.rel.tunnels.api.visualstudio.com

3. vscode涉及的资源或静态文件地址

```bash
*.vscode-cdn.net
*.github.com
*.github.dev
*.trafficmanager.net
*.gallerycdn.vsassets.io
default.exp-tas.com
github.vscode-unpkg.net
raw.githubusercontent.com
vortex.data.microsoft.com
*.azureedge.net
```