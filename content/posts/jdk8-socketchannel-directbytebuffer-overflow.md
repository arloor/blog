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

1. NIO的socketChannel的read/write会从threadlocal的BufferCache中获取DirectByteBuffer。
2. 老版本线程退出时，不会调用directByteBuffer的Cleaner方法释放直接内存。
3. 加上应用一直没有FullGC，导致直接内存一直不会被回收，导致OOM

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

## 参考文档

- [https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released](https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released)
- [https://www.evanjones.ca/java-bytebuffer-leak.html](https://www.evanjones.ca/java-bytebuffer-leak.html)
- [https://cloud.tencent.com/developer/article/2240063](https://cloud.tencent.com/developer/article/2240063)
