---
title: "Vmware Fusion Macos Sonoma"
date: 2023-12-03T23:20:46+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## vmware fusion player下载及密钥获取

在[VMware Fusion Player – Personal Use License](https://customerconnect.vmware.com/en/evalcenter?p=fusion-player-personal-13)注册账号，可以下载并获得密钥。

## 在App Store下载“安装Macos Sonoma”的应用

[直达Apple Store链接](https://apps.apple.com/us/app/macos-sonoma/id6450717509?mt=12)

之后，会在应用程序中看到

![Alt text](/img/install-macos-sonoma.png)

## 制作ISO

```bash
$ sudo hdiutil create -o /tmp/Sonoma -size 16000m -volname Sonoma -layout SPUD -fs HFS+J
created: /tmp/Sonoma.dmg
$ sudo hdiutil attach /tmp/Sonoma.dmg -noverify -mountpoint /Volumes/Sonoma
/dev/disk5          	Apple_partition_scheme         	
/dev/disk5s1        	Apple_partition_map            	
/dev/disk5s2        	Apple_HFS
$ sudo /Applications/Install\ macOS\ Sonoma.app/Contents/Resources/createinstallmedia --volume /Volumes/Sonoma --nointeraction
Erasing disk: 0%... 10%... 20%... 30%... 100%
Copying essential files...
Copying the macOS RecoveryOS...
Making disk bootable...
Copying to disk: 0%... 10%... 20%... 100%
Install media now available at "/Volumes/Install macOS Sonoma"
# 当命令执行完成后，从“访达”中将 "Install macOS Sonoma" 推出，否则后续会报错

$ sudo hdiutil convert /tmp/Sonoma.dmg -format UDTO -o ~/Sonoma.iso
正在读取Driver Descriptor Map（DDM：0）…
正在读取Apple（Apple_partition_map：1）…
正在读取（Apple_Free：2）…
正在读取disk image（Apple_HFS：3）…
..........................................................................................................
已耗时：30.124s
速度：531.1MB/秒
节省：0.0%
created: /var/root/Sonoma.iso.cdr

## 可以自行把cdr的后缀去掉
```