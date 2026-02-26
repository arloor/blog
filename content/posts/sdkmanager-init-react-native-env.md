---
title: "使用SDKManager命令行工具在 Windows 上搭建 React Native Android 开发环境"
subtitle:
tags: 
- undefined
date: 2026-02-26T22:41:57+08:00
lastmod: 2026-02-26T22:41:57+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
- powershell
---

很多人使用 React Native 时会默认安装 Android Studio，但在某些场景（服务器环境、轻量级开发机、CI 环境、网络受限环境）下，我们更希望使用纯命令行方式安装 Android SDK。

本文完整介绍在 Windows 环境下，如何：

* 手动安装 Android SDK
* 使用 sdkmanager 安装构建组件
* 配置 Java 21
* 处理 Gradle 代理问题
* 连接 Android 真机（USB / WLAN 调试）
* 成功运行 React Native Android 项目

---

## 一、Android SDK 安装（命令行模式）

### 1. 创建 SDK 目录

建议使用默认路径：

```powershell
mkdir "$env:LOCALAPPDATA\Android\Sdk" -Force
```

默认推荐目录：

```
C:\Users\<用户名>\AppData\Local\Android\Sdk
```

后续我们会将其设置为 `ANDROID_HOME`。

---

### 2. 下载 Command Line Tools

访问 Android 官方页面下载：

> [https://developer.android.com/studio#command-line-tools-only](https://developer.android.com/studio#command-line-tools-only)

下载 **Command Line Tools for Windows**，解压后得到：

```
cmdline-tools
```

---

### 3. 正确整理目录结构（关键步骤）

Android SDK 对目录结构要求非常严格。

最终目录结构必须是：

```
Android\Sdk
└── cmdline-tools
    └── latest
        ├── bin
        ├── lib
        ├── source.properties
        └── NOTICE.txt
```

步骤如下：

1. 在 `cmdline-tools` 下新建 `latest` 目录
2. 将原 `cmdline-tools` 里的所有内容移动到 `latest` 目录中

很多人卡在这里，是因为没有创建 `latest` 子目录。

---

## 二、安装 Java 21

React Native 最新 Android Gradle Plugin 版本已经要求较新的 JDK。

推荐安装：

> JDK 21

官方下载地址：

[https://www.oracle.com/cn/java/technologies/downloads/#jdk21-windows](https://www.oracle.com/cn/java/technologies/downloads/#jdk21-windows)

安装后建议配置：

```
JAVA_HOME
```

并加入：

```
%JAVA_HOME%\bin
```

到 PATH。

---

## 三、安装 Android SDK 组件

进入：

```
Android\Sdk\cmdline-tools\latest\bin
```

先查看可用组件：

```bash
.\sdkmanager.bat --list
```

然后安装必要组件：

```bash
.\sdkmanager.bat "platforms;android-36.1" "build-tools;36.1.0" "platform-tools"
```

说明：

* `platforms`：指定 Android API 版本
* `build-tools`：构建工具版本
* `platform-tools`：adb 等核心工具

React Native 项目必须有对应 API level，否则会报错：

```
SDK location not found
```

---

## 四、配置环境变量

推荐设置为系统环境变量：

```powershell
$env:ANDROID_HOME="C:\Users\<用户名>\AppData\Local\Android\Sdk"
```

长期使用建议写入系统环境变量。

验证：

```bash
adb --version
```

如果正常输出版本号说明配置成功。

---

## 五、Gradle 下载失败的代理问题（国内常见）

很多人执行：

```bash
npm run android
```

卡在：

```
Downloading https://services.gradle.org/distributions/gradle-8.x.x-bin.zip
```

这是因为 Gradle 下载被墙。

可以临时设置代理：

```powershell
$env:GRADLE_OPTS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7890 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7890"
```

⚠ 该变量只影响当前终端会话。

如果你使用 Clash / v2ray 等代理工具，确保端口正确。

---

## 六、运行 React Native 项目

准备完成后：

```bash
npm run android
```

内部流程实际是：

1. 触发 Gradle 构建
2. 编译 Java / Kotlin
3. 打包 APK
4. 通过 adb 安装到设备

如果报错：

```
SDK location not found
```

说明：

* 没设置 ANDROID_HOME
* 或 android/local.properties 未生成

可手动创建：

```
android/local.properties
```

写入：

```
sdk.dir=C:\\Users\\<用户名>\\AppData\\Local\\Android\\Sdk
```

注意：路径分隔符需要使用 `\\`

---

## 七、补充：连接 Android 真机调试（USB / WLAN）

上面命令链路配置完成后，`npm run android` 还需要至少一个可用设备（模拟器或真机）。

这里补充 Android 官方文档中与真机连接相关的关键步骤（Windows 环境）：

> [在硬件设备上运行应用（Android 官方）](https://developer.android.com/studio/run/device?hl=zh-cn)

### 1. USB 真机调试（Windows）

先在手机上完成：

1. 开启开发者选项
2. 开启 `USB 调试`
3. 使用支持数据传输的 USB 线连接电脑（不是仅充电线）

Windows 额外注意：

* 如果电脑无法识别设备，安装手机厂商提供的 USB 驱动（Google 设备可使用 Google USB Driver）
* 首次连接时，手机会弹出 USB 调试授权（RSA 指纹确认），需要点击允许

命令行验证设备是否连通：

```bash
adb kill-server
adb start-server
adb devices
```

常见状态说明：

* `device`：已连接成功，可直接运行 `npm run android`
* `unauthorized`：手机未确认授权弹窗，重新插拔后在手机上点允许
* `offline` 或空列表：优先检查数据线、驱动、USB 模式（文件传输）、是否被其他工具占用

如果你同时连接了多个设备，先用 `adb devices` 查看序列号，再使用：

```bash
adb -s <设备序列号> reverse tcp:8081 tcp:8081
```

这样可以明确把 Metro 端口映射到指定真机。

### 2. WLAN（无线）调试（可选）

Android 官方也支持通过 WLAN 调试连接真机，适合不想长期插线的场景。

前提条件（官方文档要点）：

* 设备与电脑连接到同一局域网
* 设备为 Android 11 及以上（使用“无线调试”功能）
* `platform-tools` 使用较新版本（本文前面已安装）

手机侧操作：

1. 开启开发者选项
2. 开启 `无线调试`

如果你安装了 Android Studio，可以按官方文档使用 Device Manager 的配对入口（Pair Devices Using Wi-Fi）。

如果你坚持纯命令行，也可以用 `adb` 配对和连接（手机会显示配对码、IP 和端口）：

```bash
adb pair <设备IP>:<配对端口>
adb connect <设备IP>:<调试端口>
adb devices
```

连接成功后再执行：

```bash
npm run android
```

---

## 八、整个体系的底层逻辑

理解 React Native Android 构建链条：

```
React Native CLI
        ↓
Gradle
        ↓
Android Gradle Plugin
        ↓
Android SDK (build-tools + platform-tools)
        ↓
JDK
```

只要其中一个版本不兼容，就会构建失败。

---

## 九、常见坑总结

| 问题                     | 根因               |
| ---------------------- | ---------------- |
| SDK location not found | ANDROID_HOME 未设置 |
| cmdline-tools 找不到      | 没创建 latest 目录    |
| Gradle 下载卡死            | 未配置代理            |
| 构建失败 JDK 版本错误          | 未使用 Java 17/21   |



