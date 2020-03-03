---
title: "Netty源码阅读"
date: 2020-03-03T20:49:47+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 搭建netty源码阅读环境

克隆项目，并切换到指定的tag：4.1.46.Final版本

```
git clone https://github.com/netty/netty.git
git checkout 4.1
git reset --hard netty-4.1.46.Final
```

**1.** 设置jdk等级（common模块pom.xml）

末尾增加`maven-compiler-plugin`的jdk等级配置
```
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <configuration>
                <source>8</source>
                <target>8</target>
            </configuration>
        </plugin>
    </plugins>
  </build>
</project>
```

**2.** 增加netty-tcnative相关的依赖（根目录pom.xml）

这些依赖是openssl相关的，因为example中的代码需要，所以添加依赖

`<dependencies>`中添加，注意不是dependencyManagement中的dependencies

```
        <!-- 如果使用openssl,需要添加下面两个jar，如果只用jdk 提供的ssl，可以不导入-->
        <dependency>
            <groupId>io.netty</groupId>
            <artifactId>netty-tcnative</artifactId>
            <version>2.0.25.Final</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.netty</groupId>
            <artifactId>netty-tcnative-boringssl-static</artifactId>
            <version>2.0.25.Final</version>
            <scope>runtime</scope>
        </dependency>
```

**3.** skip单侧和checkStyle（根目录pom.xml）

都在`<build>`下`<plugins>`中

配置surefire-plugin跳过运行测试代码

```
            <plugin>
                <artifactId>maven-surefire-plugin</artifactId>
                <configuration>
                    <skipTests>true</skipTests>
```

设置跳过style检查

```
            <plugin>
                <artifactId>maven-checkstyle-plugin</artifactId>
                <configuration>
                    <skip>true</skip>
                </configuration>
```

**4.** mvn install Dev-Tools

在idea的maven工具栏install Dev-Tools模块

这个模块被其他模块依赖，所以需要

**5.** mvn compile common

编译common模块。该模块使用groovy脚本来生成class类，主要是一些容器类，需要编译后，才会生成相关的类，所以需要compile

**6.** 运行example中的例子

如果运行报错，说有些sun.unsafe之类的包找不到，请打开Project Structure中的Project SDK设置，设置成jdk8

至此环境搭建完毕，在example中运行代码可以debug进去了。

参考文档：[编译Netty源码遇到的一些问题-缺少io.netty.util.collection包](https://www.cnblogs.com/ibigboy/p/11777066.html)——着重说明为什么要skip checkStyle和compile common模块

## 收获一：netty使用openssl优化ssl握手性能

jdk的ssl实现比较慢，比openssl慢好多，所以这一点还是很重要的。并且ssl在netty的场景中还挺多的，因为https场景多嘛

参考博文：[https://www.cnblogs.com/wade-luffy/p/6019743.html](https://www.cnblogs.com/wade-luffy/p/6019743.html)

```
//SelfSignedCertificate（自签名证书） netty说明仅方便测试使用，绝对不要在生产用。当然可以从这个方法去看看怎么自签名证书
SelfSignedCertificate ssc = new SelfSignedCertificate();
//非JDK8
SslContext sslContext = SslContextBuilder.forServer(ssc.certificate(), ssc.privateKey())  .sslProvider( SslProvider. OPENSSL).build();
//如果是JDK8，他的原生GCM加密很慢。请不要开GCM，那把ReferenceCountedOpenSslContext里面的DEFAULT_CIPHERS抄出来，删掉两个GCM的。
List<String> ciphers = Arrays.asList("ECDHE - RSA - AES128 - SHA", "ECDHE - RSA - AES256 - SHA", "AES128 - SHA", "AES256 - SHA", "DES - CBC3 - SHA");
SslContext sslContext = SslContextBuilder.forServer(ssc.certificate(), ssc.privateKey()).sslProvider( SslProvider.OPENSSL).ciphers(ciphers).build();
```

## 收获二：netty 编解码请求和响应

两种方式：

```
//1，example/http/hellowold中使用
p.addLast(new HttpServerCodec());
//2. example/http/cos中使用
pipeline.addLast(new HttpResponseEncoder());
pipeline.addLast(new HttpRequestDecoder());
pipeline.addLast(new HttpObjectAggregator(65536));
```

HttpServerCodec = HttpResponseEncoder + HttpRequestDecoder

HttpRequestDecoder这个Decoder处理一个http request会产生三种类型的Object：

1. 1个HttpRequest: 包含init line和请求头
2. n或0个HttpContent：存放请求体，当Transfer-Encoding: chunked时，会产生多个HttpContent
3. 1个LastHttpContent: 存放请求体，并标志该请求解析完毕。如果内容为空，则返回LastHttpContent.EMPTY_LAST_CONTENT

详细见：[https://netty.io/4.1/api/io/netty/handler/codec/http/HttpObjectDecoder.html](https://netty.io/4.1/api/io/netty/handler/codec/http/HttpObjectDecoder.html)

说实话，以前就看过这个，今天最终来记一下

HttpObjectAggregator起聚合作用，将上面Decoder解析出来的多个对象聚合成一个完整对象

[https://netty.io/4.1/api/io/netty/handler/codec/http/HttpObjectAggregator.html](https://netty.io/4.1/api/io/netty/handler/codec/http/HttpObjectAggregator.html)

```
A ChannelHandler that aggregates an HttpMessage and its following HttpContents into a single FullHttpRequest or FullHttpResponse (depending on if it used to handle requests or responses) with no following HttpContents. It is useful when you don't want to take care of HTTP messages whose transfer encoding is 'chunked'. Insert this handler after HttpResponseDecoder in the ChannelPipeline if being used to handle responses, or after HttpRequestDecoder and HttpResponseEncoder in the ChannelPipeline if being used to handle requests.
  ChannelPipeline p = ...;
  ...
  p.addLast("decoder", new HttpRequestDecoder());
  p.addLast("encoder", new HttpResponseEncoder());
  p.addLast("aggregator", new HttpObjectAggregator(1048576));
  ...
  p.addLast("handler", new HttpRequestHandler());
  
For convenience, consider putting a HttpServerCodec before the HttpObjectAggregator as it functions as both a HttpRequestDecoder and a HttpResponseEncoder.
```

看到这些，觉得我的HttpProxy可以重写了，站在netty的头上（之前在肩膀上），直接利用HttpCodec来解析请求、编码相应，netty Yes！

## 收获三：http1.1 keepAlive的netty代码

example/http/hellowold中

```
    @Override
    public void channelRead0(ChannelHandlerContext ctx, HttpObject msg) {
        if (msg instanceof HttpRequest) {//仅处理init line和请求头，请求体不看
            HttpRequest req = (HttpRequest) msg;

            boolean keepAlive = HttpUtil.isKeepAlive(req); //这里面的逻辑是http1.0需要显示connection：keepAlive,http1.1默认keepALive除非connection:close
            FullHttpResponse response = new DefaultFullHttpResponse(req.protocolVersion(), OK,
                                                                    Unpooled.wrappedBuffer(CONTENT));
            response.headers()
                    .set(CONTENT_TYPE, TEXT_PLAIN)
                    .setInt(CONTENT_LENGTH, response.content().readableBytes());

            if (keepAlive) {
                if (!req.protocolVersion().isKeepAliveDefault()) {
                    response.headers().set(CONNECTION, KEEP_ALIVE);
                }
            } else {
                // Tell the client we're going to close the connection.
                response.headers().set(CONNECTION, CLOSE);
            }

            ChannelFuture f = ctx.write(response);

            if (!keepAlive) {//如果不是长连接，写完成就Close Socket
                f.addListener(ChannelFutureListener.CLOSE);
            }
        }
    }
```



