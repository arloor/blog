---
title: "Hyde-Hyde主题修改"
date: 2022-04-17T20:22:35+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

本博客用的是hugo的hyde-hyde主题，在其基础上做了一些改进，具体如下：

## 对高分屏的宽度适配

下面这个是我自己提的issue

>this theme is a very good theme except that when I use a 1080p display, the article tag elemets' size is fixed at 630. I want to make this value bigger or reponsive. Can I get some Help? Thanks!

解决方案是：

```
vim themes/hyde-hyde/assets/scss/hyde-hyde/_variables.scss"
# 下面的一行从38rem改成70rem
$content-max-width: 70rem;
```

## 使用本地静态资源而非cdn静态资源

中国访问国外静态资源太慢了，于是改为使用本地静态资源，具体修改在此commit: [2dc3c6401d934f1435201d9f4f92cf68ea5d3b3d](https://github.com/arloor/blog/commit/2dc3c6401d934f1435201d9f4f92cf68ea5d3b3d)

以后升级hyde-hyde时，应该还要进行此修改，具体的静态资源文件有：

```shell
themes/hyde-hyde/static/all.js
themes/hyde-hyde/static/github.min.css
themes/hyde-hyde/static/highlight.min.js
themes/hyde-hyde/static/img/head.jpeg
```

## 移动设备的menu增加作者图片并链接到首页

移动设备上缺失了一个回到首页的链接，增加该链接，具体commitid为[156c16c8b0a237a3c5a7c98bf20d5ebb4dac1d28](https://github.com/arloor/blog/commit/156c16c8b0a237a3c5a7c98bf20d5ebb4dac1d28)

修改文件：

```shell
themes/hyde-hyde/layouts/partials/sidebar.html
themes/hyde-hyde/assets/scss/hyde-hyde/_responsive.scss
```
