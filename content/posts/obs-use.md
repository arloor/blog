---
title: "obs使用"
date: 2024-09-07T19:18:49+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 设置obs以管理员权限运行，以开启Nvenc硬件编码

{{< imgx src="/img/Snipaste_2024-09-07_23-30-29.png" alt="" width="400px" style="max-width: 100%;">}}

## 直播设置

{{< imgx src="/img/obs-settings-zhibo.png" alt="" width="700px" style="max-width: 100%;">}}

## 录像设置

{{< imgx src="/img/Snipaste_2024-09-08_00-31-00.png" alt="" width="700px" style="max-width: 100%;">}}

## 视频设置

{{< imgx src="/img/obs-settings-video.png" alt="" width="700px" style="max-width: 100%;">}}

## 音频设置

{{< imgx src="/img/obs-settings-yinpin.png" alt="" width="700px" style="max-width: 100%;">}}

## 高级设置

{{< imgx src="/img/obs-settings-advanced.png" alt="" width="700px" style="max-width: 100%;">}}

## 给OBS设置高性能的显卡电源模式

{{< imgx src="/img/obs-settings-high-performance.png" alt="" width="700px" style="max-width: 100%;">}}

## 剪影导出4K视频，用于B站

{{< imgx src="/img/剪影-导出4K.png" alt="" width="700px" style="max-width: 100%;">}}

## B站4K稿件的具体要求

{{< imgx src="/img/bilibili-4k.png" alt="" width="700px" style="max-width: 100%;">}}

## Youtube 4K稿件

[YouTube 推荐的上传编码设置 - YouTube帮助 (google.com)](https://support.google.com/youtube/answer/1722171?hl=zh-Hans#zippy=%2C%E5%AE%B9%E5%99%A8mp%2C%E9%9F%B3%E9%A2%91%E7%BC%96%E8%A7%A3%E7%A0%81%E5%99%A8aac-lc%2C%E8%A7%86%E9%A2%91%E7%BC%96%E8%A7%A3%E7%A0%81%E5%99%A8h%2C%E5%B8%A7%E9%80%9F%E7%8E%87%2C%E6%AF%94%E7%89%B9%E7%8E%87%2C%E8%A7%86%E9%A2%91%E5%88%86%E8%BE%A8%E7%8E%87%E5%92%8C%E5%AE%BD%E9%AB%98%E6%AF%94%2C%E9%A2%9C%E8%89%B2%E7%A9%BA%E9%97%B4)

| 类型 | 视频比特率（标准帧速率）（24、25、30） | 视频比特率（高帧速率）（48、50、60） |
| --- | --- | --- |
| 2160p (4K) | 35 - 45 Mbps | **53 - 68 Mbps** |

## OBS Notifier 插件

设置了OBS的开启录制和结束录制的快捷键，但是没有桌面通知。这需要使用OBS Notifier插件。

首先开启OBS的websocket服务，并复制密码：

{{< imgx src="/img/websockets.png" alt="" width="700px" style="max-width: 100%;">}}

然后下载OBSNotifier，下载地址：[OBSNotifier](https://github.com/DmitriySalnikov/OBSNotifier/releases)

最后设置OBSNotifier：

{{< imgx src="/img/obs-notifier.png" alt="" width="400px" style="max-width: 100%;">}}

其中，上下左右偏移量可以调整通知位置，在屏幕有缩放的情况下应该需要手动设置，否则不会显示在屏幕上。，参考[Can you move the offset? Maybe a window outside the screen..](https://github.com/DmitriySalnikov/OBSNotifier/issues/16)

