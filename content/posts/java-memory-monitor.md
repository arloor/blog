---
title: "Java内存监控"
date: 2023-07-18T17:17:03+08:00
draft: false
categories: [ "undefined"]
tags: ["java"]
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
        for (Map.Entry<String, Long> entry : map.entrySet()) {
            System.out.println(String.format("%18s    %s",entry.getKey(),entry.getValue()));
        }
    }

    private static String fixName(String name) {
        return name.replaceAll(" ", "_").replaceAll("'", "").replaceAll("-", "_");
    }

    private static MemoryMXBean memoryMXBean = ManagementFactory.getMemoryMXBean();
    private static List<BufferPoolMXBean> bufferPoolMXBeans = ManagementFactory.getPlatformMXBeans(BufferPoolMXBean.class);
}
```

```bash
buffer_pool_direct    8193
buffer_pool_mapped    0
buffer_pool_mapped___non_volatile_memory    0
      direct_netty    -1
              heap    18083112
          non_heap    16355616
```

## jdk9以上设置 `-Dio.netty.tryReflectionSetAccessible=true` 的说明

> JDK的directByteBuffer使用Cleaner机制和幻引用来释放内存，依赖GC的发生才会释放。Netty为了更及时地释放直接内存，自己池化管理了直接内存（PoolArena），也负责直接内存的释放，即显示调用Delocate方法，这个被称为allocateDirectNocleaner。这需要反射获取DirectByteBuffer的构造方法。在JDK9版本以上，JDK反射的限制被加强了，所以Netty在JDK9以上版本，需要设置-Dio.netty.tryReflectionSetAccessible=true来打开反射获取DirectByteBuffer的构造方法的权限。

要统计netty直接内存使用量，实际使用的是netty中PlatformDependent类的`DIRECT_MEMORY_COUNTER`变量。

netty在初始化这个变量前，会检查时候能反射拿到DirectByteBuffer的构造方法。

在jdk9以上，拿构造方法被认为是`illegal reflective access`会看到这样的警告信息：

```bash
WARNING: An illegal reflective access operation has occurred
WARNING: Illegal reflective access by io.netty.util.internal.ReflectionUtil (file:/C:/Users/arloor/.m2/repository/io/netty/netty-all/4.1.53.Final/netty-all-4.1.53.Final.jar) to constructor java.nio.DirectByteBuffer(long,int)
WARNING: Please consider reporting this to the maintainers of io.netty.util.internal.ReflectionUtil
WARNING: Use --illegal-access=warn to enable warnings of further illegal reflective access operations
WARNING: All illegal access operations will be denied in a future release
```

所以有人就在github上提issue了：[https://github.com/netty/netty/pull/7650](https://github.com/netty/netty/pull/7650)

netty的解决方案是：默认关闭这个反射拿构造方法的操作，相关代码：

```java
    // PlatformDependent0.java
private static boolean explicitTryReflectionSetAccessible0(){
        // we disable reflective access
        return SystemPropertyUtil.getBoolean("io.netty.tryReflectionSetAccessible",javaVersion()< 9);
        }
```

我们为了统计直接内存使用量，所以需要把这个打开

> 对于GRPC的用户，需要设置-Dio.grpc.netty.shaded.io.netty.tryReflectionSetAccessible=true，因为GRPC对netty做了shaded，所以需要用shaded的包名。

## jdk16以上设置 `--add-opens java.base/java.nio=ALL-UNNAMED` 的说明

如果不设置，则统计netty直接内存使用量时，会在反射获取 `DirectByteBuffer` 的构造函数 `private java.nio.DirectByteBuffer(long,int)` 的时候抛出下面的异常，导致无法获取：

```bash
java.lang.reflect.InaccessibleObjectException: 
Unable to make private java.nio.DirectByteBuffer(long,int) accessible: 
module java.base does not "opens java.nio" to unnamed module @5a4aa2f2
```

![](/directByteBufferConstructor.png)

相关的一些issue：[renaissance-benchmarks的issue](https://github.com/renaissance-benchmarks/renaissance/issues/241)


## Netty直接内存泄漏排查

有三种方式：可参见[reference-counted-objects.html](https://netty.io/wiki/reference-counted-objects.html)

1. 设置vm options：

```bash
-Dio.netty.leakDetectionLevel=paranoid
```

2. 调用 `ResourceLeakDetector.setLevel()`

3. springboot的Netty AutoConfigure：

```bash
spring:
  netty:
    leak-detection: paranoid
```

这个auto configure会通过方法2来设置探测登记。注意，如果用了springboot，一定要通过方法3来配置，因为这个autoconfigure是默认开启的，并且默认设置为simple登记。
