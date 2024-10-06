---
title: "一键关闭WeGame和LOL客户端，避免浪费时间"
subtitle:
tags: 
- windows
- bat
date: 2024-10-01T00:42:03+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

如何快速关闭WeGame和LOL客户端？恶心的wegame总是在关闭游戏的时候浪费我时间，所以写了一个批处理文件，一键关闭wegame和LOL客户端。

<!--more-->

```bat
@echo off
:: 检查是否以管理员身份运行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo restart with admin    
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    timeout /t 1 /nobreak
    exit
)

taskkill /F /IM WeGame.exe
taskkill /F /IM LeagueClientUx.exe
taskkill /F /IM "League of Legends.exe"
```