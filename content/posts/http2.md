---
title: "http2是什么"
date: 2020-08-23T20:33:12+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

HTTP/2标准于2015年5月以RFC 7540正式发表，到今天已经有五年多了，已经不能称之为新东西了。今天来学习一下。
<!--more-->

## 开始

直接上概念和实现

http1.1的拆包是基于`\r\n`分割符的，而http2将报文分成不同的帧(frame)。并抽象出流(stream)的概念。

1. 若干个frame组成一个完整的http请求：header帧，body帧组成一个完整的请求
2. http请求或者响应被称为message。
2. message在stream上。
3. 一个tcp连接上可以有多个stream，以此完成tcp连接复用，也就是一个tcp链接上可以并行多个http请求。

上面是实现中较为高层的抽象，下面直接到二进制帧的报文结构。

二进制帧是http2传输中的最小单元。每一个帧都有一个固定9字节的头部，通过这个头部定义帧类型、帧长度、控制用的flag，以及streamId。在9字节头部的后面才是该帧的payload（有效载荷），如下图所示。

<img src="/img/http2-frame-first-9-bytes.svg" alt="" width="700px" style="max-width: 100%;">


{{<imgx src="/img/http2-frame-first-9-bytes.svg" alt="" width="700px" style="max-width: 100%;">}}


1. 24位表示payload长度
2. 8位表示帧类型
3. 8位flag，用于控制
4. 1位保留，总是为0
5. 31位标示streamId

有了上面的表头定义，给出处理http2帧的伪代码：

```
loop
read 9 byte
payload_Length=first 3 bytes
read payload
swith type:
Take action
end loop
```

说到这里，可能会蒙了，那http1里的request method, url, header, request body都到哪里去了？

把Http1.1的完整请求看成header和body，http2用header帧承载header，用data帧承载body。相应地，处理http2请求时，上面伪代码的`Take action`才能拼接出真正的http请求。

“协议就是对报文的定义”，上面是http2对报文的定义，但是到这里还没有定义http请求和响应（他们在frame的定义中）。如果我们使用http2的9字节帧头部，但是在帧的payload中放上自己的东西，那么http2协议完全可以承载非http请求，grpc就是这样的产物。

我们再看看http2网络分层：

<img src="/img/http2-layer.svg" alt="" width="700px" style="max-width: 100%;">

其实http2引入了一个二进制分帧层，至于分出来的帧是不是http消息，其实完全可以由开发者定义。结合http2引入的一些新特性：拥塞控制，多路复用，server push，总有一种tcp over tcp的感觉，在应用层再做一遍tcp做好了的事情，更好地利用单条tcp连接。这里自然而然的有了一个问题，为什么不把拥塞控制，多路复用，server push用在udp上，实现一个tcp over udp。

再细细的想，http2可能是计算机届真正消灭tcp的第一步（现在已经有了第二步了，quic）。我们试想，http2底层使用udp，那么可以称http2为new tcp over udp。然后grpc这样的应用层协议再over http2。那么相当于http2是在传输层和应用层之间的中间层，仅仅用于实现稳定的udp传输。从这个角度看，http2背后是一个巨大的野心，也是计算机网络这么多年发展以来的一个大变革。


## 参考文档

[高性能浏览器网络·Http2简介](https://hpbn.co/http2/)   
[谷歌开发者·HTTP/2 简介](https://developers.google.com/web/fundamentals/performance/http2?hl=zh-cn)    
[http2的二进制帧定义](https://halfrost.com/http2-http-frames-definitions/)    
