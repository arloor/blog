---
title: "Windows11仅以大核启动以解决部分游戏大小核心调度不佳导致帧率不稳定的问题"
date: 2024-06-28T21:25:52+08:00
draft: false
categories: [ "undefined"]
tags: 
- windows
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

大小核调度横空出世后，游戏需要额外做优化来让大小核架构发挥最大潜力。而没有正确优化的游戏比如老头环就会出现帧率抖动，伴随着显卡占用率抖动的现象。之前我使用 process lasso这个软件来设置cpu亲和性来解决该问题。该方案最大的问题是需要屏蔽小懒熊防作弊后，process lasso 才能生效。而屏蔽小懒熊会导致无法使用联机模式。

现在我找到了最适合我的方式：仅以大核启动windows。这里介绍的方式不需要每次进BIOS操作，只需要点击bat文件运行即可。

## 页面操作介绍

首先介绍页面操作，这是后续脚本的基础，让大家感受下下面的脚本到底做了啥

1. `win` + `r`，然后输入 `msconfig`，打开**系统配置**(也可以在开始菜单直接搜索打开)
2. 按下图设置后续启动时的处理器核心数量。我的CPU是6个大核，算上超线程是12个虚拟大核，所以我写了12。如果你的CPU是8个大核，算上超线程是16个虚拟大核，那么你就写16。

![alt text](/img/msconfig-procnum.png)

3. 重启后就是只有大核在工作了。这个更改是一直生效的，后续都将是只有大核在工作。
4. 如果后面需要以全核心启动了，需要再改回去。

## 上脚本

我自己使用了下面的脚本，要玩埃尔登法环的时候就运行 `仅以大核启动.bat`，退出游戏后就用 `全核心启动.bat`。具体来说，下面的脚本做了几件事

1. 自动获取管理员权限
2. 调用 `bcdedit` 修改启动核心数的配置
3. 显示启动核心数的配置用于核对
4. 询问是否重启电脑

注意，要把12改成你的CPU对应的数值。

### 仅以大核启动

```bash
@echo off
:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------
echo Running with elevated privileges...

bcdedit /set {current} numproc 12
setlocal

:: 执行 bcdedit /enum 并查找 numproc
bcdedit /enum | findstr /i "numproc" >nul

:: 检查 findstr 命令的错误级别（ERRORLEVEL）
if %ERRORLEVEL%==0 (
    echo enable 12 cores
) else (
    echo enable all cores
)

endlocal

@echo off
set /p confirm=Do you want to restart the computer? (Y/N): 
if /i "%confirm%"=="Y" (
    shutdown /r /t 0
) else (
    echo Restart canceled.
)
```

### 全核心启动

```bash
@echo off
:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------
echo Running with elevated privileges...

bcdedit /deletevalue {current} numproc
setlocal

:: 执行 bcdedit /enum 并查找 numproc
bcdedit /enum | findstr /i "numproc" >nul

:: 检查 findstr 命令的错误级别（ERRORLEVEL）
if %ERRORLEVEL%==0 (
    echo enable 12 cores
) else (
    echo enable all cores
)

endlocal

@echo off
set /p confirm=Do you want to restart the computer? (Y/N): 
if /i "%confirm%"=="Y" (
    shutdown /r /t 0
) else (
    echo Restart canceled.
)
```


### 显示当前核心数配置

```bash
@echo off
:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------
echo Running with elevated privileges...

setlocal

:: 执行 bcdedit /enum 并查找 numproc
bcdedit /enum | findstr /i "numproc" >nul

:: 检查 findstr 命令的错误级别（ERRORLEVEL）
if %ERRORLEVEL%==0 (
    echo enable 12 cores
) else (
    echo enable all cores
)

endlocal
timeout /t 5 /nobreak
```