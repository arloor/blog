---
title: "Ubuntu Desktop Entry Example"
date: 2018-12-31T23:52:22+08:00
author: "刘港欢"
categories: [ "ubuntu"]
tags: ["linux"]
weight: 10
---
steam.desktop的内容，可以仿照<!--more-->
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