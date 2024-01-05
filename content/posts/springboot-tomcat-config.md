---
title: "Springboot内置Tomcat的配置"
date: 2021-09-27T17:21:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

背景：需要提供一个配置服务给60w+机器，没台机器每分钟请求一次拉取最新配置。springboot的默认tomcat配置是不行的，研究下tomcat有哪些配置项，以及如何在springboot中配置。

## 如何在springboot中修改tomcat的配置

[springboot官方文档](https://docs.spring.io/spring-boot/docs/2.2.0.RELEASE/reference/html/howto.html#howto-configure-webserver)告诉我们可以在`application.yml`里做一些配置，这些配置都以`server.tomcat.`开头，但这些仅仅覆盖了常见的配置，全部配置需要我们使用如下代码：

```java
@Component
public class MyTomcatWebServerCustomizer
        implements WebServerFactoryCustomizer<TomcatServletWebServerFactory> {

    @Override
    public void customize(ConfigurableWebServerFactory webServerFactory) {
        //使用工厂类定制tomcat connector
        TomcatServletWebServerFactory factory = ((TomcatServletWebServerFactory) webServerFactory);
        factory.addConnectorCustomizers(new TomcatConnectorCustomizer() {
            @Override
            // 详见tomcat官方文档：//https://tomcat.apache.org/tomcat-8.5-doc/config/http.html#Common_Attributes
            public void customize(Connector connector) {
                Http11NioProtocol protocol = (Http11NioProtocol) connector.getProtocolHandler();
                // 长连接配置
                protocol.setKeepAliveTimeout(90000);
                protocol.setMaxKeepAliveRequests(600);
                // backlog
                protocol.setAcceptCount(10000);
                // 最大连接数
                protocol.setMaxConnections(10000);
                // 最大线程数
                protocol.setMaxThreads(1000);
            }
        });
    }
}
```

connector组件在tomcat的整体架构中是处理tcp连接的部分，我们需要优化connector配置让tomcat能承载更多的请求。上面的代码我进行了5项配置，这些配置在[tomcat的配置文档](https://tomcat.apache.org/tomcat-9.0-doc/config/http.html#Standard_Implementation)里都有介绍。

```java
protocol.setKeepAliveTimeout(90000); //表示90秒没有新的请求则断开连接
protocol.setMaxKeepAliveRequests(600); // 表示一个socket连接处理600次请求后主动断开
```

剩下的三个参数主要控制 tomcat的连接池、线程池和accept queue大小。引用[tomcat的配置文档](https://tomcat.apache.org/tomcat-9.0-doc/config/http.html#Standard_Implementation)的一句话介绍：

> Each incoming, non-asynchronous request requires a thread for the duration of that request. If more simultaneous requests are received than can be handled by the currently available request processing threads, additional threads will be created up to the configured maximum (the value of the maxThreads attribute). If still more simultaneous requests are received, Tomcat will accept new connections until the current number of connections reaches maxConnections. Connections are queued inside the server socket created by the Connector until a thread becomes avaialble to process the connection. Once maxConnections has been reached the operating system will queue further connections. The size of the operating system provided connection queue may be controlled by the acceptCount attribute. If the operating system queue fills, further connection requests may be refused or may time out.

大意就是：最多`maxThreads`个线程并行处理`maxConnections`个socket连接。操作系统最多接受`acceptCount`个连接。这三个参数控制了一个tomcat应用在一个时刻能处理多少请求(`maxThreads`),tomcat能监听多少个连接（`maxConnections`），和操作系统能同时queue多少个已完成三次握手的连接等待应用处理（`acceptCount`）。

## acceptCount是个啥玩意

用于控制全连接队列的长度，详见[TCP 半连接队列和全连接队列满了会发生什么？又该如何应对？](https://cloud.tencent.com/developer/article/1638042)
![](/img/accept-queue.png)

## http客户端代码

客户端因为是以jar包的方式提供sdk，所以直接使用jdk的UrlConnection类，代码如下：

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStreamWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.Charset;

public class HttpUtil {
    private static final Logger LOG = LoggerFactory.getLogger(HttpUtil.class);

    private HttpUtil() {
    }

    private static void get(String url) {
        HttpURLConnection connection = null;
        InputStream response = null;
        int code = -1;
        try {

            connection = (HttpURLConnection) (new URL(url)).openConnection();
            if (connection != null) {
                connection.setRequestMethod("POST");
                connection.setRequestProperty("content-type", "application/json; charset=utf-8");
                connection.setRequestProperty("connection", "close"); // 使用短连接
                writeContent(connection, JsonUtil.serialize(new Object()));
                // InputStream inputStream = connection.getInputStream(); 读inputStream;
                code = connection.getResponseCode();
                LOG.debug("post {} {} {}", new Object[]{url, connection.getResponseCode(), response});
            } else {
                LOG.debug("can't connect to {}" + url);
            }
        } catch (Exception e) {
            LOG.debug("post {} failed {} {}", new Object[]{url, Integer.valueOf(code), e});
        } finally {
            if (connection != null) {
                try {
                    connection.getInputStream().close();
                    // disconnect可能释放底层连接，长连接场景下不需要调用下面的代码
                    connection.disconnect();
                } catch (Exception e) {
                    LOG.debug("close connection failed... " + url, e);
                }
            }
        }
    }

    private static void writeContent(HttpURLConnection connection, String content) {
        OutputStreamWriter out = null;

        try {
            connection.setDoOutput(true);
            out = new OutputStreamWriter(connection.getOutputStream(), Charset.forName("utf-8"));
            out.write(content);
        } catch (Exception e) {
            LOG.debug("write content to {} failed {}", new Object[]{connection.getURL(), e});
        } finally {
            if (out != null) {
                try {
                    out.close();
                } catch (IOException e) {
                    LOG.debug("close connection failed... " + connection.getURL(), e);
                }
            }

        }

    }
}
```

几个注意点：

- 短连接需要增加： `connection.setRequestProperty("connection", "close");`
- 长连接不要有`connection.disconnect();`，只需要将connection的inputStream和outputStream关闭即可。调用该代码可能导致socket断开，达不到长连接的效果。