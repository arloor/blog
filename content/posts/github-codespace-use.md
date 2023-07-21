---
title: "使用Github Codespaces"
date: 2022-05-16T16:14:54+08:00
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

## codespaces能做什么

现在各行各业都在卷，ide这行也都卷到了远程开发这个领域，codespaces也是远程开发的一个解决方案。可以认为Github给你开了一个docker容器，里面运行着一个vscode，vscode打开着你的项目文件，你可以进行代码编辑，并依托vscode进行调试等等。

在更早的时候[github.dev](https://github.dev/)就实现了在线编辑的功能，在你的github项目里按下`.`键，就会自动地跳转到Github提供的网页版VS code，参见[https://github.dev/github/dev](https://github.dev/github/dev)。

可以将codespaces认为是github.dev的扩展和延申。github.dev只具备代码编辑的能力，codespaces则给你提供了一个docker容器，拿到docker容器的shell后，你能做的事情就海了去了。毕竟docker就是一个linux，你相当于白嫖了一个4核8G的VPS。

## codespaces的计费规则

目前只对组织和企业组织收费，**不对个人收费**，这就意味着可以白嫖了。具体收费政策见[about-billing-for-codespaces](https://docs.github.com/en/billing/managing-billing-for-github-codespaces/about-billing-for-codespaces)

## 新建codespaces

1. 访问[https://github.com/codespaces](https://github.com/codespaces)
2. 访问[https://github.com/codespaces/new](https://github.com/codespaces/new)创建你的codespace，，输入项目名、分支、地区。地区我选的是美西。因为大陆局域网的原因，想要流畅的使用codespace肯定要科学上网的，我的科学上网途径在美西所以选择了美西。
3. 创建完毕后会自动跳转到codespaces的页面，等待docker容器创建完成后，你就可以看到一个vscode的页面。不同于github.dev，这是一个全功能的vs code，你可以使用docker的shell。

## 使用codespaces

我探索到的有三种使用途径:

1. 浏览器打开codespace。新建完codespaces后会自动地在浏览器打开。
2. vscode通过Remote Explorer连接codespaces。需要安装`GitHub Codespaces`插件，并登录Github账号，会自动地展示你地Codespaces。
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

## 加速访问

由于大陆局域网的问题，上述三种方式都会面临访问速度慢的问题，但不是不可以解决的。

对于本地vs code，可以搜索proxy的设置，设置代理即可。对于浏览器打开，我整理了codespaces需要访问的域名如下，配置这些域名走代理即可

```bash
*.vscode-cdn.net
*.github.com
*.github.dev
*.trafficmanager.net
*.gallerycdn.vsassets.io
default.exp-tas.com
github.vscode-unpkg.net
*.visualstudio.com
raw.githubusercontent.com
vortex.data.microsoft.com
*.azureedge.net
*.servicebus.windows.net
```