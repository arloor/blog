---
title: "Proxyme-基于javaNIO的http代理"
date: 2018-08-14
author: "刘港欢"
categories: ["java", "网络编程"]
tags: ["Program"]
weight: 10
---

# proxyme 一个 http 代理

使用 java NIO 的 http 代理。支持 https。不建议再 chrome 上使用本代理，因为 chrome 本身会请求很多谷歌的 api，结果被墙住了，又只有两个线程，导致其他都被阻塞，很尴尬。

之前也打算做过这个东西，结果做出来的有点缺陷（现在想可能是 selector 中锁的问题，忘记了）。这大概隔了半年，这个项目的 http 代理功能实现了。

## 源码地址

[https://github.com/arloor/proxyme](https://github.com/arloor/proxyme)

## 运行日志

```
11:23:08.883 [main] INFO com.arloor.proxyme.HttpProxyBootStrap - 在8080端口启动了代理服务
11:23:12.208 [localSelector] INFO com.arloor.proxyme.LocalSelector - 接收浏览器连接: /127.0.0.1:50317
11:23:12.210 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 请求—— CONNECT cn.bing.com:443 HTTP/1.1
11:23:12.291 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 创建远程连接: cn.bing.com/202.89.233.100:443
11:23:12.291 [remoteSlector] INFO com.arloor.proxyme.RemoteSelector - 注册remoteChannel到remoteSelector。remoteChannel: cn.bing.com/202.89.233.100:443
11:23:12.298 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 发送请求517 -->cn.bing.com/202.89.233.100:443
11:23:12.365 [remoteSlector] INFO com.arloor.proxyme.ChannalBridge - 接收响应2720 <--cn.bing.com/202.89.233.100:443
11:23:12.365 [remoteSlector] INFO com.arloor.proxyme.ChannalBridge - 接收响应1360 <--cn.bing.com/202.89.233.100:443
11:23:12.366 [remoteSlector] INFO com.arloor.proxyme.ChannalBridge - 接收响应1360 <--cn.bing.com/202.89.233.100:443
11:23:12.369 [remoteSlector] INFO com.arloor.proxyme.ChannalBridge - 接收响应1360 <--cn.bing.com/202.89.233.100:443
11:23:12.369 [remoteSlector] INFO com.arloor.proxyme.ChannalBridge - 接收响应1 <--cn.bing.com/202.89.233.100:443
11:23:12.378 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 发送请求93 -->cn.bing.com/202.89.233.100:443
11:23:12.382 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 发送请求1022 -->cn.bing.com/202.89.233.100:443
...
...
11:23:13.281 [localSelector] INFO com.arloor.proxyme.LocalSelector - 接收浏览器连接: /127.0.0.1:50319
11:23:13.282 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 请求—— GET http://s.cn.bing.net/th?id=OSA.xiipvhS2Pp2bEg&w=80&h=80&c=8&rs=1&pid=SatAns HTTP/1.1
11:23:13.382 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 创建远程连接: s.cn.bing.net/112.84.133.11:80
11:23:13.383 [remoteSlector] INFO com.arloor.proxyme.RemoteSelector - 注册remoteChannel到remoteSelector。remoteChannel: s.cn.bing.net/112.84.133.11:80
11:23:13.383 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 发送请求340 -->s.cn.bing.net/112.84.133.11:80
11:23:13.383 [localSelector] INFO com.arloor.proxyme.ChannalBridge - 发送请求409 -->s.cn.bing.net/112.84.133.11:80
```

## 性能与内存

占用 cpu 不到 1%

内存最大 35m（不含 jvm 自身）。GC 次数和时间很少

总的来说，性能可以了吧。

## 思路

两个线程，每个线程一个 selector。

localSelector 线程，负责接收本地浏览器的连接请求和读写浏览器到代理的 socketChannel

remoteSelector 线程，负责读写 web 服务器到代理的 socketChannel。

ChannelBridge 类,持有 localSocketChannel 和 remoteSocketChannel。职责是处理请求和响应，并转发。

RequestHeader 类，职责是格式化请求行和请求头。

## 实现中的注意点

首先是健壮性！每一个 try 块都是很重要的！都解决了一个问题

其次是锁的问题：

selector.select()会占有锁，channel.register(selector)需要持有同样的锁。

如果调用上面的两个方法的语句在两个线程中，会让 channel.regiter 等很久很久，导致响应难以及时得到。

而在实现中，这是一个生产者消费者问题。localSelector 线程根据本地浏览器请求产生了一个从代理到 web 服务器的 remoteChannel。而 remoteSelector 要接收这个 remoteChannel,这也就是消费了。

很自然的，避免上面锁等待最好的方法：localSelector 生成 remoteChannel，将其放入队列。remoteSelector 线程从队列中取。再结合 selector.wakeup()使其从阻塞中返回，可以快速地接收（register）这个 remoteChannel。

这两点，就是最最重要的两点了。

另外还有，因为代理而需要改变的请求头了，参见：

```
com.arloor.proxyme.RequestHeader.reform()
```

最后，https 代理实现中的坑。http 代理传输的内容是明文，字节肯定大于 0，而 https 传输的字节可能小于 0。因为这个，传输 https 数据的 bybebuff 时，要特意指定 bytebuff 的 limit 为实际大小。

还有一个小问题，向 remoteChannel 写的时候，有时候会写 0 个字节，原因是底层 tcp 缓冲满了，我的处理是等 0.1 秒，再继续传。当然设置 OP_WRITE 这个监听选项的目的就是处理这种情况。

http 代理不神秘。

## 可以改进的地方

对 channel 的读写可以加入更多的线程来进行。

其实这就是要加入 reactor 模式了。reactor 模式可以看：[java 设计模式](https://github.com/iluwatar/java-design-patterns/tree/master/reactor)
