---
title: "安卓手机安装google三件套"
linktitle: 安卓手机安装google三件套
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

在国内环境下，有些手机厂商在手机出厂时会删除安卓内置的google service framework，而有些则不会删除。因此，有些手机只需要安装google play service和google play store，而有些三个应用全部需要装。

# 安装google service framework

1. 访问[apkmirror](https://www.apkmirror.com/)（需要翻墙）
2. 搜索'google service framework'，可以看到下面所列的不同版本的apk，根据安卓系统的版本，点开对应的链接
![](/img/gsf-version.png)
3. 下载页面中出现的apk。
![](/img/gsf-download.png)
4. 安装页面如下：
![](/img/gsf-install.jpg)

注意google service framework是没有图标的，所以安装成功之后也是看不到google service framework的图标的。

# 安装google play service

1. 访问[apkmirror](https://www.apkmirror.com/)。
2. 搜索'google play service'，可以看到下面所列的不同版本的apk，选择图中标识的版本，点开
![apkmirror-google-service.png](/img/apkmirror-google-service.png)
3. 现在可以看到这个版本的apk有好多的variables，对应不同cpu架构、系统版本、屏幕分辨率的手机，如下图。
![](/img/google-play-service-variables.png)
一般来说，选择cpu架构为arm64-v8a + armeabi-v7a，屏幕分辨率为nodpi，你的手机是安卓8.0，则使用Android 8.0+，是安卓8.1，则使用Android 8.1+。根据这个选择对应的variable下载，然后在手机上安装。

注意google play service是没有图标的，所以安装成功之后也是看不到google play service的图标的。

# 安装google play store

有了上面两个app，已经可以正常使用google的各项服务了，为了使用正统谷歌应用市场上的app，首先下个google play store吧。

跟上面的操作一样，在apkmirror搜索google play store，下载对应的apk，然后在手机上安装。

安装完成之后，就可以通过google play store安装其他应用了，也就不需要在apkmirror上下载apk来安装了。

# 其他

为了更好地使用谷歌的各项服务，有个谷歌账号还是很必要的，如何注册在谷歌账号，不在这个博客中介绍了。

另外，使用谷歌各项服务和在apkmirror上下载apk，都需要翻墙。

**Telegram讨论组** https://t.me/popstary 欢迎进群讨论