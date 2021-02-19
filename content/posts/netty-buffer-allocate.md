---
title: "Netty内存池实现"
date: 2021-02-19T17:38:07+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

之前在做netty的java应用监控的时候，看到一个用于监控netty直接内存使用量的属性——`PlatformDependent类的 DIRECT_MEMORY_COUNTER`。每次进行直接内存分配的时候，都会调用

```
io.netty.util.internal.PlatformDependent#incrementMemoryCounter
```

方法增加这个计数器。通过这个看到了netty内存分配的一点东西，特意记录一下。
<!--more-->

debug的时候把断点设在incrementMemoryCounter方法里，就能看到一些有趣的调用栈，如下：

<img src="/img/netty-new-direct-buffer-stack.png" alt="" width="850px" style="max-width: 100%;">

这个调用栈从开始到read的部分，在之前的文章[从register和accept的锁竞争问题到netty的nioEventLoop设计](/posts/netty/select-register-nioeventloop/)已经看过一遍了。现在直接从`PooledByteBufAllocator#newDirectBuffer`看池化的直接内存是怎样分配的。非池化的直接内存也会增加计数，但是这里就不关注了。

## 池化直接内存入口方法

![](/img/PooledByteBufAllocator-newDirectBuffer.png)


