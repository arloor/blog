---
title: "Java8 Direct Bytebuffer Overflow"
date: 2023-12-01T16:44:35+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 前言

Hbase会为每一个region server创建一个IPC client线程来做读写操作，并且该线程空闲两分钟就会被关闭。并且Hbase使用Java NIO的`Socket Channel`和`HeapByteBuffer`来做读写操作。由于JDK内部机制的问题，会导致直接内存泄漏，下面介绍所谓的内部机制来剖析根因。
<!--more-->

## 解释

1. NIO的socketChannel的read/write HeapByteBuffer会从threadlocal的BufferCache中获取DirectByteBuffer。
2. 老版本JDK在IO线程退出时，不会调用directByteBuffer的Cleaner方法**释放threadlocal中BufferCache的直接内存**。
3. 加上应用**一直没有OldGC/FullGC**，导致直接内存一直不会被回收，导致OOM

> sun.nio.ch.SocketChannelImpl#write(java.nio.ByteBuffer)

```java
    public int write(ByteBuffer buf) throws IOException {
        if (buf == null)
            throw new NullPointerException();
        synchronized (writeLock) {
            ensureWriteOpen();
            int n = 0;
            try {
                begin();
                synchronized (stateLock) {
                    if (!isOpen())
                        return 0;
                    writerThread = NativeThread.current();
                }
                for (;;) {
                    n = IOUtil.write(fd, buf, -1, nd);
                    if ((n == IOStatus.INTERRUPTED) && isOpen())
                        continue;
                    return IOStatus.normalize(n);
                }
            } finally {
                writerCleanup();
                end(n > 0 || (n == IOStatus.UNAVAILABLE));
                synchronized (stateLock) {
                    if ((n <= 0) && (!isOutputOpen))
                        throw new AsynchronousCloseException();
                }
                assert IOStatus.check(n);
            }
        }
    }
```

> sun.nio.ch.IOUtil#write(java.io.FileDescriptor, java.nio.ByteBuffer, long, sun.nio.ch.NativeDispatcher)

```java
    static int write(FileDescriptor fd, ByteBuffer src, long position,
                     NativeDispatcher nd)
        throws IOException
    {
        if (src instanceof DirectBuffer)
            return writeFromNativeBuffer(fd, src, position, nd);

        // Substitute a native buffer
        int pos = src.position();
        int lim = src.limit();
        assert (pos <= lim);
        int rem = (pos <= lim ? lim - pos : 0);
        ByteBuffer bb = Util.getTemporaryDirectBuffer(rem);
        try {
            bb.put(src);
            bb.flip();
            // Do not update src until we see how many bytes were written
            src.position(pos);

            int n = writeFromNativeBuffer(fd, bb, position, nd);
            if (n > 0) {
                // now update src
                src.position(pos + n);
            }
            return n;
        } finally {
            Util.offerFirstTemporaryDirectBuffer(bb);
        }
    }
```

> sun.nio.ch.Util#getTemporaryDirectBuffer

```java
    /**
     * Returns a temporary buffer of at least the given size
     */
    public static ByteBuffer getTemporaryDirectBuffer(int size) {
        // If a buffer of this size is too large for the cache, there
        // should not be a buffer in the cache that is at least as
        // large. So we'll just create a new one. Also, we don't have
        // to remove the buffer from the cache (as this method does
        // below) given that we won't put the new buffer in the cache.
        if (isBufferTooLarge(size)) {
            return ByteBuffer.allocateDirect(size);
        }

        BufferCache cache = bufferCache.get();
        ByteBuffer buf = cache.get(size);
        if (buf != null) {
            return buf;
        } else {
            // No suitable buffer in the cache so we need to allocate a new
            // one. To avoid the cache growing then we remove the first
            // buffer from the cache and free it.
            if (!cache.isEmpty()) {
                buf = cache.removeFirst();
                free(buf);
            }
            return ByteBuffer.allocateDirect(size);
        }
    }
```

> sun.nio.ch.Util#bufferCache

新版本：无此问题

```java
    // Per-thread cache of temporary direct buffers
    private static ThreadLocal<BufferCache> bufferCache = new TerminatingThreadLocal<BufferCache>() {
        @Override
        protected BufferCache initialValue() {
            return new BufferCache();
        }
        @Override
        protected void threadTerminated(BufferCache cache) { // will never be null
            while (!cache.isEmpty()) {
                ByteBuffer bb = cache.removeFirst();
                free(bb);
            }
        }
    };
```

老版本：

```java
    // Per-thread cache of temporary direct buffers
    private static ThreadLocal<BufferCache> bufferCache =
        new ThreadLocal<BufferCache>()
    {
        @Override
        protected BufferCache initialValue() {
            return new BufferCache();
        }
    };
```

> sun.nio.ch.Util#free

```java
    /**
     * Frees the memory for the given direct buffer
     */
    private static void free(ByteBuffer buf) {
        ((DirectBuffer)buf).cleaner().clean();
    }
```

## 通过Arthas诊断

Java中直接内存有三种分配方式

| 方式 | 说明 |
| --- | --- |
| java.nio.channels.FileChannel#map | 通过mmap系统调用分配 |
| java.nio.ByteBuffer#allocateDirect | 通过JVM直接内存分配 |
| native code via JNI | 部分JVM实现支持 |

通过Arthas的stack方法追踪这些方法的调用栈就能看出来是哪里分配了直接内存，在这个case里就能看到是 `sun.nio.ch.Util#getTemporaryDirectBuffer` 申请的内存。

```bash
options unsafe true
stack java.nio.ByteBuffer allocateDirect  -n 5
```

## 解决方案

1. 升级JDK到1.8.0_301及以上版本
2. 设置JVM参数`-XX:MaxDirectMemorySize=1g`，限制直接内存的大小，到达限制时触发FullGC，释放直接内存
3. 设置`jdk.nio.maxCachedBufferSize`为0，禁用BufferCache

## 拓展

### DirectByteBuffer的释放

> [https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released](https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released)

不使用finalizer，而是使用了sun.misc.Cleaner API。

DirectByteBuffer does not use old Java finalizers. Instead, it uses internal sun.misc.Cleaner API. It creates new thread and stores a PhantomReference to every DirectByteBuffer created (except duplicates and slices which refer to the primary buffer). When the DirectByteBuffer becomes phantom-reachable (that is, no strong, soft or weak references to the byte buffer exist anymore) and garbage collector sees this, it adds this buffer to the ReferenceQueue which is processed by Cleaner thread. So three events should occur:

DirectByteBuffer becomes phantom-reachable.
Garbage collection is performed (in separate thread), DirectByteBuffer Java object is collected and an entry is added to the ReferenceQueue.
Cleaner thread reaches this entry and runs the registered clean-up action (in this case, it's java.nio.DirectByteBuffer.Deallocator object), this action finally frees the native memory.
So in general you have no guarantee when it's freed. If you have enough memory in the Java heap, garbage collector may not be activated for a long time. Also even when it's phantom-reachable, Cleaner thread may need some time to reach this entry. It might be busy processing previous objects which also used the Cleaner API. Note however that partial work-around is implemented in JDK: if you create new DirectByteBuffer and allocated too much direct memory before, garbage collector might be called explicitly to enforce deallocation of previously abandoned buffers. See Bits.reserveMemory() (called from DirectByteBuffer constructor) for details.

Note that in Java-9 the internal Cleaner API was rectified and published for general use: now it's java.lang.ref.Cleaner. Reading the JavaDoc you may get more details how it works.

对应代码：

```java
    DirectByteBuffer(int cap) {                   // package-private

        super(-1, 0, cap, cap);
        boolean pa = VM.isDirectMemoryPageAligned();
        int ps = Bits.pageSize();
        long size = Math.max(1L, (long)cap + (pa ? ps : 0));
        Bits.reserveMemory(size, cap);

        long base = 0;
        try {
            base = unsafe.allocateMemory(size);
        } catch (OutOfMemoryError x) {
            Bits.unreserveMemory(size, cap);
            throw x;
        }
        unsafe.setMemory(base, size, (byte) 0);
        if (pa && (base % ps != 0)) {
            // Round up to page boundary
            address = base + ps - (base & (ps - 1));
        } else {
            address = base;
        }
        cleaner = Cleaner.create(this, new Deallocator(base, size, cap)); // !!!这里创建了一个Cleaner对象
        att = null;



    }
```

## 参考文档

- [https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released](https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released)
- [https://www.evanjones.ca/java-bytebuffer-leak.html](https://www.evanjones.ca/java-bytebuffer-leak.html)
- [https://cloud.tencent.com/developer/article/2240063](https://cloud.tencent.com/developer/article/2240063)
