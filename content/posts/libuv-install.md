---
title: "Libuv教程"
date: 2019-09-06T21:19:38+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

到目前为止写了挺多网络编程的东西，要么用netty，要么用go。因为网络编程是IO密集的应用，用带gc的语言写，总是因为频繁的gc需求导致cpu占用过高。netty使用unsafepointer的使用堆外内存来避免频繁gc，但是这还是不够，因为你总得生成string这种堆内对象。只有一个办法来避免这种问题，那就是用没有gc的语言来编写网络编程了。

libuv就是c语言的一个异步事件库，这篇博客就是来搞一下。
<!--more-->

## 编译安装libuv
```
wget https://codeload.github.com/libuv/libuv/zip/v1.30.0
unzip libuv-1.30.0.zip
cd libuv-1.30.0
apt install automake libtool autoconf
./configure --prefix=/usr
make
make install
```

## 编写一个简单的例子
```shell
# 使用cat编辑a.c
cat > a.c << EOF
#include <stdio.h>
#include <stdlib.h>
#include <uv.h>

int main() {
    uv_loop_t *loop = malloc(sizeof(uv_loop_t));
    uv_loop_init(loop);

    printf("Now quitting.\n");
    uv_run(loop, UV_RUN_DEFAULT);

    uv_loop_close(loop);
    free(loop);
    return 0;
}
EOF
```

**编译运行**

```
gcc a.c -luv -o a
./a
Now quitting.
```

**说明**

这个例子创建了一个loop，该loop经历了malloc、init、run、close、free五个阶段，其中malloc和free是c语言内存管理，init、run、close则是loop的生命周期。

这个程序会马上退出，因为loop上没有注册监听的事件。


