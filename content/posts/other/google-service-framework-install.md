---
title: "安卓手机安装google三件套"
linktitle: 安卓手机安装google三件套
author: "刘港欢"
date: 2022-10-26
categories: [ "program"]
tags: ["program"]
weight: 10
---

之前在telegram群里有人问，怎么给安卓手机安装谷歌三件套。他说的谷歌三件套大概就是google service framework(谷歌服务框架)、google play service、google play store。这里介绍一下如何安装这三个软件。**对华为手机可能无效，请谨慎尝试**
<!--more-->

为了使用上面的谷歌三件套，首先手机需要能翻墙，如果不能翻墙，就没有必要继续看下去了。

## 三个软件各自的作用

| 软件 | 作用 |
| :--- | :--- |
| google service framework | 谷歌服务框架是使用谷歌服务、谷歌账号的基础。只有安装这个框架，谷歌的各项功能才能正常使用，比如google play service，google play store等等。 |
| google play service | 在google service framework的基础上运行，真正向用户提供功能的软件，提供谷歌用户认证的功能。 |
| google play store | 谷歌官方的应用市场，大量国外需要翻墙的应用软件需要在这个app上下载。 |

可以这样说
1. 国外有趣的软件需要通过google play store安装；
2. google play store依赖google play service提供对google 账号的访问；
3. google play service又运行在google service framework的基础上。

在国内环境下，有些手机厂商在手机出厂时会删除安卓内置的google service framework，而有些则不会删除。因此，有些手机不需要自行安装google service framework。

## 下载apk格式，而不是bundle格式

> 2023.12.13更新

现在apkmirror上有两种格式的安装包，一种是传统的apk，一种是新的bundle。我们认准apk格式安装包，不要下载bundle格式的安装包，因为bundle格式的安装包不能直接安装，需要通过APKMirror Installer (Official) 这个app来安装。

![Alt text](/img/apk-yes-apkm-no.png)

## 安装google service framework

1. 访问[apkmirror](https://www.apkmirror.com/)（需要翻墙）

2. 搜索`google service framework`，可以看到下面所列的不同版本的apk，根据安卓系统的版本，点开对应的链接

![](/img/gsf-version.png)

3. 下载页面中出现的apk。

![](/img/gsf-download.png)

4. 安装页面如下：

![](/img/gsf-install.jpg)

google service framework是没有图标的，所以安装成功之后也是看不到google service framework的图标的，不要误以为是安装失败了。

仙人指路，直达链接：

- [安卓14版本google service framework](https://www.apkmirror.com/apk/google-inc/google-services-framework/google-services-framework-14-release/#downloads)
- [安卓13版本google service framework](https://www.apkmirror.com/apk/google-inc/google-services-framework/google-services-framework-13-release/#downloads)
- [安卓12版本google service framework](https://www.apkmirror.com/apk/google-inc/google-services-framework/google-services-framework-12-release/#downloads)
- [安卓11版本google service framework](https://www.apkmirror.com/apk/google-inc/google-services-framework/google-services-framework-11-release/#downloads)


## 安装google play service

1. 访问[apkmirror](https://www.apkmirror.com/)。

2. 搜索`google play service`，或者点这个[直达链接](https://www.apkmirror.com/?post_type=app_release&searchtype=apk&s=google+play+service),可以看到下面所列的不同版本的apk，选择图中标识的版本，点开

![apkmirror-google-service.png](/img/apkmirror-google-service.png)

3. 现在可以看到这个版本的apk有好多的variables，对应不同cpu架构、系统版本、屏幕分辨率的手机，如下图。

![](/img/google-play-service-variables.png)

一般来说，选择cpu架构为arm64-v8a + armeabi-v7a，屏幕分辨率为nodpi，你的手机是安卓8.0，则使用Android 8.0+，是安卓8.1，则使用Android 8.1+。根据这个选择对应的variable下载，然后在手机上安装。

注意google play service是没有图标的，所以安装成功之后也是看不到google play service的图标的，不要误以为是安装失败了。

## 安装google play store

跟上面的操作一样，在apkmirror搜索google play store，或者点此[直达链接](https://www.apkmirror.com/?post_type=app_release&searchtype=apk&s=google+play+store)，然后下载apk安装即可，注意下载带`[0]`的apk，其他版本是给手表和电视用的。

```shell
App Notes:
[0] - For all devices.
[5] - For Android Wear devices
[8] - For Android TV devices.
```

## 通过google play store下载应用一直“等待中”

有些手机安装google play store之后，下载应用一直“等待中”。

原因参见[Google Play 商店能访问无限等待下载
](https://www.ohyee.cc/post/note_google_play_store)：

> 尽管很多国行手机支持直接安装谷歌框架，但往往安装的是国行谷歌框架，其对应的地址是 services.googleapis.cn，在国内该地址会被解析到不支持 Play 商店的 IP 上（因为域名以 .cn 结尾，因此大部分规则都会让该地址走直连

解决方案也比较简单，让`services.googleapis.cn`走代理即可，比如clash规则中添加：

```yaml
- DOMAIN-SUFFIX,services.googleapis.cn
```

## 其他

为了更好地使用谷歌的各项服务，有个谷歌账号还是很必要的，如何注册在谷歌账号，不在这个博客中介绍了。
