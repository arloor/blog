---
title: "安卓手机安装google四件套"
linktitle: java-AES加密后再Base64混淆
author: "刘港欢"
date: 2019-02-26
categories: [ "program"]
tags: ["program"]
weight: 10
---

之前在telegram群里有人问，怎么给安卓手机安装谷歌三件套。他说的谷歌三件套大概就是google service framework(谷歌服务框架)、google play service、google play store。这里介绍一下如何安装这三个软件。
<!--more-->

为了使用上面的谷歌四件套，首先手机需要能翻墙，如果不能翻墙，就没有必要继续看下去了。另外，这个博客仅适用于安卓手机。

# 三个软件各自的作用

- google service framework：谷歌服务框架是使用谷歌服务、谷歌账号的基础。只有安装这个框架，谷歌的各项功能才能正常使用，比如google play service，google play store等等。
- google play service：在google service framework的基础上运行，真正向用户提供功能的软件，提供谷歌用户认证的功能。
- google play store：谷歌官方的应用市场，大量国外需要翻墙的应用软件需要在这个app上下载。

可以这样说，国外有趣的软件需要通过google play store安装；google play store依赖google play service提供对google 账号的访问；google play service又运行在google service framework的基础上。

在国内环境下，有些手机厂商在手机出厂时会删除安卓内置的google service framework，而有些则不会删除。因此，有些手机只需要安装google play service和google play store，而有些三个应用全部需要装。下面会讲到如何判断。

# 安装google play service

上面提到，google play service依赖google service framework，我们先装google play service的目的是为了判断手机是否内置了google service framework。google service framework是没有图标显示的，在手机屏幕看不到他的图标，不意味着手机没有安装，因此我们要用这个方式来判断是否需要安装google service framework。

安装google play service步骤：

1. 访问[apkmirror](https://www.apkmirror.com/)。
2. 搜索'google play service'，找到下图中的apk文件然后下载。

![apkmirror-google-service.png](/img/apkmirror-google-service.png)