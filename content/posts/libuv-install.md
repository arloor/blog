---
title: "Libuv安装"
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

试试看libuv
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

/*
 * a.c
 * empty msg loop
 * 这个例子新建了一个消息队列，但队列里没有任何消息，程序直接退出
 * Created on 2016/9/10
 */
#include <stdio.h>
#include <stdlib.h>
#include "uv.h"

int main(int argc, char *argv[])
{
    uv_loop_t *loop = uv_loop_new();  // 可以理解为新建一个消息队列
    uv_run(loop, UV_RUN_DEFAULT);     // 启动消息队列，UV_RUN_DEFAULT模式下，当消息数为0时，就会退出消息循环。
    printf("hello, world\n");
    return 0;
}
EOF
```

## 编译运行

```
gcc a.c -luv -o a
./a
# hello,world
```
