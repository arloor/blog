---
title: "还IDEA一个整洁的滚动条高亮提示"
date: 2024-01-05T11:36:23+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

深刻怀疑IDEA在硬卷，滚动条的highlight提示越来越多了，颜色丰富的像彩虹，还很密集。这样根本就达不到highlight的目的了。

## 真正需要的highlight

- git的diff
- 语法错误(需要每个文件单独设置，无法全局设置)
![Alt text](/img/idea-inspecting-syntax-error.png)
- 拼写错误 
![Alt text](/img/idea-inspecting-typo.png)

## 不需要的是

- Highlight on caret movement.（光标移动时的高亮）

![Alt text](/img/disable-highlight-on-caret-movement.png)

- 以及Java中很多的提示

cmd+6 或者在edit中进行quicck fix，可以快速关闭这些提示

![Alt text](/img/quick-fixes-highlight-problem.png)
![Alt text](/img/quick-fixes-highlight-problem2.png)


## 在Git diff中不显示其他的高亮

![Alt text](/img/idea-git-diff-highlight.png)
