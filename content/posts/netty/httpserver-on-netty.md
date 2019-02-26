---
title: "基于netty的http服务器实现"
date: 2019-01-10
author: "刘港欢"
categories: [ "java","网络编程","netty"]
tags: ["Program"]
weight: 10
---

现在发现自己代理的一个问题，准备将代理的http请求解析改用netty自带的一些组件，所以来研究一下netty源码中http服务器的实现。<!--more-->

# 先说发现的问题

自己的代理对http请求接受完整的判断是依靠ChannelInboundHandlerAdapter的channelReadComplete方法：触发channelReadComplete则认为拿到了一个完整的请求。而channelReadComplete的判断标准是读到0字节或者没有填满缓冲区。这是原因一。

在我的实现中，入站事件首先经过解密的hanndler，之后再经过上面说的那个ChannelInboundHandlerAdapter。这是原因二。

原因三：AES加密较为耗时，导致连续到来的http请求的分块，因加密耗时而在时间上不再连续。这就导致了ChannelInboundHandlerAdapter错误的判断为channelReadComplete。最后的结果就是请求被截断，转发给web服务器之后，会响应错误的请求等等

归根截底，根据channelReadComplete截断请求的健壮性不行（也许将解密和ChannelInboundHandlerAdapter换顺序，就能解决这个问题，但终究不够健壮）。于是准备看看，netty或者其他http服务器是怎么解析http请求的。本文所研究的是，netty源码中自带的HttpCorsServer例子。

# 代码实现

ChannelPipeline
```
pipeline.addLast(new HttpResponseEncoder());  //出站
pipeline.addLast(new HttpRequestDecoder());     //入站
pipeline.addLast(new HttpObjectAggregator(65536));  //入站
pipeline.addLast(new ChunkedWriteHandler());   //出站和入站
pipeline.addLast(new CorsHandler(corsConfig)); //出站和入站
pipeline.addLast(new OkResponseHandler());      //入站——真正处理请求
```

上面的handler只有OkResponseHandler是自定义的，其他都是netty4.1提供的。

类OkResponseHandler
```
public class OkResponseHandler extends SimpleChannelInboundHandler<Object> {
    @Override
    public void channelRead0(ChannelHandlerContext ctx, Object msg) {
        final FullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.OK);
        response.headers().set("custom-response-header", "Some value");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
    }
}
```

# 分析这些handler做了什么

下面按照调用的时间顺序来分析这些handler的功能

## HttpRequestDecoder与父类HttpObectDecoder

![HttpRequestDecoder](/img/2019-01-10 23-31-03 的屏幕截图.png)

继承自ByteToMessageDecoder，说明它将一开始收到的ByteBuf转成了某一种对象。具体是什么对象我们进HttpObjectDecoder和HttpRequestDecoder看一下。

先看HttpObectDecoder。通过阅读[javaDoc](https://netty.io/4.1/api/index.html),摘取下面信息。

这个类“Decodes ByteBufs into HttpMessages and HttpContents.”从这个描述，大概看出会产生两种、多个object，等会留意一下。

有三个属性：

|名字|含义|
|------|-----------|
| maxInitialLineLength                   |        The maximum length of the initial line (e.g. "GET / HTTP/1.0" or "HTTP/1.0 200 OK")  超出抛TooLongFrameException|
|   maxHeaderSize                     |         The maximum length of all headers.  超出抛TooLongFrameException|
|    maxChunkSize            |       The maximum length of the content or each chunk. If the content length (or the length of each chunk) exceeds this value, the content or chunk will be split into multiple HttpContents whose length is maxChunkSize at maximum.|

看maxChunkSize的含义，我们能看到，如果一个请求的请求体很长，就会切分成多个HttpContent。这种请求体很长的情况大概只会在上传这个场景中出现。注意，这里尽管用到了chunk这个词，并不意味着只会在Transfer-Encoding: chunked才切分成HttpContent，如下：

If the content of an HTTP message is greater than maxChunkSize or the transfer encoding of the HTTP message is 'chunked', this decoder generates one HttpMessage instance and its following HttpContents per single HTTP message to avoid excessive memory consumption. 

看javaDoc举的例子：一个chunked编码的请求（chunked：下一行的字节数\r\n下一行的内容x字节\r\n）
```
 GET / HTTP/1.1
 Transfer-Encoding: chunked

 1a
 abcdefghijklmnopqrstuvwxyz
 10
 1234567890abcdef
 0
 Content-MD5: ...
 [blank line]
```
面对这个请求，HttpObectDecoder会产生三个对象：

1. 一个HttpRequest（在这里只包含request line和请求头了）
2. 第一个`HttpContent`， 内容是 'abcdefghijklmnopqrstuvwxyz',
3. 第二个`LastHttpContent`, 内容是 '1234567890abcdef'。注意是`LastHttpContent`类的对象，用于标记请求的最后一个分块

javaDoc提到，如果不想手动的处理这些HttpContents，可以在这个handler后面加入HttpObjectAggregator。但这会让内存的处理不是十分高效。我们下一个将要看的handler就是HttpObjectAggregator，现在先将目光留在HttpObjectDecoder上。

## HttpObectDecoder怎么解析http请求

查看代码得知，HttpRequestDecoder的方法的实现基本都在HttpObectDecoder中，我们现在看一下HttpObectDecoder的实现。

首先注意到，在HttpObectDecoder中定义了State的内部枚举类。看到state基本就知道，接下来是用状态机，在这几个状态之间转来转去了。回忆编译原理的课程，状态机是词法解析的核心：移动指针，读取字符，查看状态机的变化规则，转换状态。

```
    private enum State {
        SKIP_CONTROL_CHARS,
        READ_INITIAL,
        READ_HEADER,
        READ_VARIABLE_LENGTH_CONTENT,
        READ_FIXED_LENGTH_CONTENT,
        READ_CHUNK_SIZE,
        READ_CHUNKED_CONTENT,
        READ_CHUNK_DELIMITER,
        READ_CHUNK_FOOTER,
        BAD_MESSAGE,
        UPGRADED
    }
```

最初的状态是：

```
private State currentState = State.SKIP_CONTROL_CHARS;
```



