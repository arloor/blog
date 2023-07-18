---
title: "Java Memory Monitor"
date: 2023-07-18T17:17:03+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

给一个Java内存监控的代码，具体监控：

- Netty直接内存使用
- 堆内存使用量
- 非堆内存使用量
- bufferPool内存使用量，主要有nio direct buffer和Mapped buffer
<!--more-->

```java
import io.netty.util.internal.PlatformDependent;

import java.lang.management.BufferPoolMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

public class MemoryMonitorTest {
    public static void main(String[] args) {
        Map<String, Long> map = new TreeMap<>();
        map.put("direct_netty", PlatformDependent.usedDirectMemory());
        map.put("heap", memoryMXBean.getHeapMemoryUsage().getUsed());
        map.put("non_heap", memoryMXBean.getNonHeapMemoryUsage().getUsed());
        for (BufferPoolMXBean bufferPool : bufferPoolMXBeans) {
            map.put("buffer_pool_" + fixName(bufferPool.getName()), bufferPool.getMemoryUsed());
        }
        System.out.println(map);
    }

    private static String fixName(String name) {
        return name.replaceAll(" ", "_").replaceAll("'", "").replaceAll("-", "_");
    }

    private static MemoryMXBean memoryMXBean = ManagementFactory.getMemoryMXBean();
    private static List<BufferPoolMXBean> bufferPoolMXBeans = ManagementFactory.getPlatformMXBeans(BufferPoolMXBean.class);
}
```

## netty直接内存监控在JDK9+的使用

在JDK9+需要增加vm options：

```shell
-Dio.netty.tryReflectionSetAccessible=true --add-opens java.base/java.nio=ALL-UNNAMED
```

## Netty直接内存泄漏排查

有三种方式：可参见[reference-counted-objects.html](https://netty.io/wiki/reference-counted-objects.html)

1. 设置vm options：

```shell
-Dio.netty.leakDetectionLevel=paranoid
```

2. 调用 `ResourceLeakDetector.setLevel()`

3. springboot的Netty AutoConfigure：

```shell
spring:
  netty:
    leak-detection: paranoid
```

这个auto configure会通过方法2来设置探测登记。注意，如果用了springboot，一定要通过方法3来配置，因为这个autoconfigure是默认开启的，并且默认设置为simple登记。
