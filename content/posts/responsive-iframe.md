---
title: "响应式iframe"
date: 2019-04-10T01:10:48+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
---

其实只是博客中想嵌入16：9的youtube视频，但youtube官方的嵌入代码是固定宽度1280，高度720，在手机上表现十分不好。因此有了这个偏前端的主题。

先上效果：随意放大，缩小网页，下面的iframe都会保持100%宽度，高度保持9/16*宽度。
<!--more-->

<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/bhPTBy2ekN8?list=PLoZEEVUrMkMSIkfSbEXNQFubB4yOjMz2a" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

插入的html如下

```html
<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/bhPTBy2ekN8?list=PLoZEEVUrMkMSIkfSbEXNQFubB4yOjMz2a" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>
```

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
