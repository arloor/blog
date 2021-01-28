---
title: "Prometheus Exporter"
date: 2021-01-27T23:42:59+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

prometheus监控比较火，接入prometheus监控的第一步就是提供expoter，这里就是记录下怎么提供。
<!--more-->

```
    <dependencies>
        <!-- https://mvnrepository.com/artifact/io.prometheus/simpleclient -->
        <dependency>
            <groupId>io.prometheus</groupId>
            <artifactId>simpleclient</artifactId>
            <version>0.10.0</version>
        </dependency>
        <dependency>
            <groupId>io.prometheus</groupId>
            <artifactId>simpleclient_httpserver</artifactId>
            <version>0.10.0</version>
        </dependency>
    </dependencies>
```

```
public class CustomExporter {
    public static void main(String[] args) throws IOException, InterruptedException {
        HTTPServer server = new HTTPServer(8888);
        while (true){
            doCount();
            Thread.sleep(1000);
        }
    }


    public final static Counter httpRequestsTotal = Counter.build()
            .name("testA")
            .help("测试")
            .labelNames("a", "b")
            .register();

    public  static void doCount() {
        //增加
        httpRequestsTotal.labels("a", "b").inc();

    }
}
```


```shell
http://someme.me:8888/metrics
$ curl http://someme.me:8888/metrics
# HELP testA_total 测试
# TYPE testA_total counter
testA_total{a="a",b="b",} 2368.0
# HELP testA_created 测试
# TYPE testA_created gauge
testA_created{a="a",b="b",} 1.61175989861E9
```

实际上，并不需要这么僵硬地引入这些依赖，只要返回的报文跟上面一样就行了。