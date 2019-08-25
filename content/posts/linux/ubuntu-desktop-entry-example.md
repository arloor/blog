---
title: "添加Ubuntu桌面图标"
date: 2018-12-31T23:52:22+08:00
author: "刘港欢"
categories: [ "ubuntu"]
tags: ["linux"]
weight: 10
---

ubuntu的应用图标文件都在

```
/usr/share/applications
```

文件下

一个比较普遍的问题，在ubuntu安装了jetbrains家的IDE后，在菜单中找不到应用图标，下面自己写一个：


## Clion
```
[Desktop Entry]
Version=1.0
Type=Application
Name=CLion
Icon=/opt/clion-2018.3.2/bin/clion.svg
Exec="/opt/clion-2018.3.2/bin/clion.sh" %f
Comment=A cross-platform IDE for C and C++
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-clion

```

## Goland

```
[Desktop Entry]
Version=1.0
Type=Application
Name=Goland
Icon=/opt/GoLand-2018.3.3/bin/goland.svg
Exec="/opt/GoLand-2018.3.3/bin/goland.sh" %f
Comment=A cross-platform IDE for golang
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-golang
```

## IDEA

```
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA Ultimate Edition
Icon=/opt/idea-IU-183.4886.37/bin/idea.svg
Exec="/opt/idea-IU-183.4886.37/bin/idea.sh" %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea
```

其他jetbrains家的ide完全仿照以上的desktop文件书写即可，仅需要替换Icon和Exec的路径即可。StartupWMClass字段是给gnome在任务栏分组应用的标志，问题不大。



另一个steam.desktop的内容，可以仿照
```
[Desktop Entry]
Name=Steam
Comment=Application for managing and playing games on Steam
Comment[zh_CN]=管理和进行 Steam 游戏的应用程序
Exec=/usr/bin/steam %U
Icon=steam
Terminal=false
Type=Application
Categories=Network;FileTransfer;Game;
MimeType=x-scheme-handler/steam;
Actions=Store;Community;Library;Servers;Screenshots;News;Settings;BigPicture;Friends;

[Desktop Action Store]
Name=Store
Name[zh_CN]=商店
Exec=steam steam://store

[Desktop Action Community]
Name=Community
Name[zh_CN]=社区
Exec=steam steam://url/SteamIDControlPage

[Desktop Action Library]
Name=Library
Name[zh_CN]=库
Exec=steam steam://open/games

[Desktop Action Servers]
Name=Servers
Name[zh_CN]=服务器
Exec=steam steam://open/servers

[Desktop Action Screenshots]
Name=Screenshots
Name[zh_CN]=截图
Exec=steam steam://open/screenshots

[Desktop Action News]
Name=News
Name[zh_CN]=新闻
Exec=steam steam://open/news

[Desktop Action Settings]
Name=Settings
Name[zh_CN]=设置
Exec=steam steam://open/settings

[Desktop Action BigPicture]
Name=Big Picture
Exec=steam steam://open/bigpicture

[Desktop Action Friends]
Name=Friends
Name[zh_CN]=好友
Exec=steam steam://open/friends
```