---
title: "响应式iframe 16:9—hugo博客嵌入youtube视频"
date: 2019-04-10T01:10:48+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
---

其实只是博客中想嵌入16：9的youtube视频，但youtube官方的嵌入代码是固定宽度1280，高度720，在手机上表现十分不好。因此有了这个偏前端的主题。
<!--more-->

## 先上效果

随意放大，缩小网页，下面的iframe都会保持100%宽度，高度保持9/16*宽度。

要翻墙才能看到下面的视频哦。是一个物理学家弹吉他吟唱《将进酒》,超级得劲 :）

<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/DBC5x8Mv5OE?list=PLoZEEVUrMkMSIkfSbEXNQFubB4yOjMz2a" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## 插入的html如下

```html
<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/DBC5x8Mv5OE?list=PLoZEEVUrMkMSIkfSbEXNQFubB4yOjMz2a" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>
```

## 实现原理

放上[原博客](https://benmarshall.me/responsive-iframes/)。

这个博客说到，使用js来实现响应式iframe是不对的，应该使用css。

```css
.iframe-container {
	overflow: hidden;
	padding-top: 56.25%;
	width: 100%;
	position: relative;
  }
   
.iframe-container iframe {
	 border: 0;
	 height: 100%;
	 left: 0;
	 position: absolute;
	 top: 0;
	 width: 100%;
}
```

.iframe-container 的 padding-top: 56.25%属性，就决定着 高度是宽度的9/16。

那么hugo怎么使用这个css？

我在主题下的scss文件夹中的_base.scss中加入了上面的css，发现就能生效，还是较为简单方便的。

至于另一种html5的vedio标签，只需要宽度和高度都设为100%即可实现响应式，如下：

```shell
<video controls="" width="100%" height="100%"><source src="http://cdn.moontell.cn/robot.mp4" type="video/mp4"></video>
```


## 番外：其他本博客使用的前端小技巧

这是一个偏前端的博客，估计很久不会有其他前端文章，所以把这个小东西也放在这。

### 对hyde-hyde主题的小改动

对高分屏的宽度适配。下面这个是我自己提的issue，自己找到的方法

>this theme is a very good theme except that when I use a 1080p display, the article tag elemets' size is fixed at 630. I want to make this value bigger or reponsive. Can I get some Help? Thanks!

>I have solved this issue by edit "themes/hyde-hyde/assets/scss/hyde-hyde/_variables.scss" -> $content-max-width: 70rem;

### 对博客中出现的图片宽度进行定制

一般我们在markdown中插入图片就是：

```shell
![](/img/ssnodes.png)
```

![](/img/ssnodes.png)

这个在大多数情况表现良好，图片宽度会取min(100%父容器宽度, 图片像素px)。但是有一种情况让人很头疼：手机截图。现在手机的像素都很高，{图片像素px}至少会是1080，而且屏幕截图很长。上面的这个图片不长，想象一下一个好几屏的长截图🤢，这种情况下截图占满屏幕，并且需要拉很久，看到就会很难受吧。归根结底，还是因为手机截图的像素宽度太大，导致min(100%父容器宽度, 图片像素px)的值还是很大。

为了避免这个问题。使用下面的方式：

```
<img src="/img/ssnodes.png" alt="" width="850px" style="max-width: 100%;">
```
这样，图片的宽度，取得就是 min(850px,100%)了。850px这个值可以自行调整，找到在电脑显示器上合适的宽度

> 有小朋友要问了，能不能直接 img的属性里写 width= "min( 850px, 100%)"。我查了，css3不行，不知道以后css4会不会加进这个min()

<img src="/img/ssnodes.png" alt="" width="600px" style="max-width: 100%;">
