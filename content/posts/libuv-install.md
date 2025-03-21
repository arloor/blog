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
wget https://codeload.github.com/libuv/libuv/zip/v1.30.0 -O libuv-1.30.0.zip
unzip libuv-1.30.0.zip
cd libuv-1.30.0
apt install automake libtool autoconf
bash autogen.sh
./configure --prefix=/usr
make
make install
```

## 一个没有handle的loop
```bash
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
gcc a.c -luv -o a&&./a

# Now quitting.
```

**说明**

这个例子创建了一个loop，该loop经历了malloc、init、run、close、free五个阶段，其中malloc和free是c语言内存管理，init、run、close则是loop的生命周期。

这个程序会马上退出，因为loop上没有注册监听的事件。

## 带有idle handle的loop

这个例子给loop增加一个idle handle，可以认为这是cpu进入空闲的事件。

下面这个例子使用`uv_default_loop()`代替了上个例子的malloc和init，同时也没有显式得free这个default loop。

 这个例子的重点是创建了一个名为“idler”的handle，并将其注册到loop中，然后启动loop。代码如下：

 ```c
     uv_idle_t idler;

    uv_idle_init(uv_default_loop(), &idler);
    uv_idle_start(&idler, count_check_stop);
```
1. uv_idle_t idler;——在栈上分配一个idle handle
2. uv_idle_init(uv_default_loop(), &idler);——注册该handle到default loop
3. uv_idle_start(&idler, count_check_stop);——注册该handle的回调为count_check_stop函数
4. uv_run(uv_default_loop(), UV_RUN_DEFAULT);——loop开始循环
5. ......

uv_run执行后，每当idle事件发生时，都会调用count_check_stop函数，会对计数器加一，如果计数器大于5000000，则会uv_idle_stop这个handle（移除该handle）。这导致loop中没有handle等待触发，所以loop也会退出整个进程退出。

总结一下，在loop的malloc、init后，需要注册handle，完成handle的内存分配、init（注册到loop）、start（注册回调函数）。需要移除该handle时对该handle执行stop。


```c
#include <stdio.h>
#include <uv.h>

int64_t counter = 0;

void count_check_stop(uv_idle_t* handle) {
    counter++;

    if(counter%1000000==0){
        printf("%ld idle\n",counter/1000000);

    }

    if (counter >= 5000000) {
        printf("Idle stop!");
        uv_idle_stop(handle);
    }
}

int main() {
    uv_idle_t idler;

    uv_idle_init(uv_default_loop(), &idler);
    uv_idle_start(&idler, count_check_stop);

    printf("Idling...\n");
    uv_run(uv_default_loop(), UV_RUN_DEFAULT);

    uv_loop_close(uv_default_loop());
    return 0;
}
```

输出

```bash
Idling...
1 idle
2 idle
3 idle
4 idle
5 idle
Idle stop!
```


## echoserver的实现

```
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#define DEFAULT_PORT 7000
#define DEFAULT_BACKLOG 128

uv_loop_t *loop;
struct sockaddr_in addr;
const char *ENTER = "请输入任意文字：\n";
const char *echo = "ECHO: ";

typedef struct {
    uv_write_t req;
    uv_buf_t buf;
} write_req_t;

void free_write_req(uv_write_t *req) {
    write_req_t *wr = (write_req_t *) req;
    free(wr->buf.base);
    free(wr);
}

void alloc_buffer(uv_handle_t *handle, size_t suggested_size, uv_buf_t *buf) {
    buf->base = (char *) malloc(suggested_size);
    buf->len = suggested_size;
}

void echo_write(uv_write_t *req, int status) {
    if (status) {
        fprintf(stderr, "Write error %s\n", uv_strerror(status));
    }
    free_write_req(req);
}

void first_write(uv_write_t *req, int status) {
    if (status) {
        fprintf(stderr, "Write error %s\n", uv_strerror(status));
    } else {
        fprintf(stderr, "提示发送成功\n");
    }

    write_req_t *wr = (write_req_t *) req;
    free(wr);
}

void echo_read(uv_stream_t *client, ssize_t nread, const uv_buf_t *buf) {

    if (nread > 0) {
        //截取char*，增加\0，仅仅是为了打印的时候不多打，如果用于业务不要加这个，这是数组越界
        buf->base[nread] = 0;
        fprintf(stderr, "%ld:%s", nread, buf->base);
        // 创建写buf，增加ECHO提示
        int length = strlen(echo) + nread;
        char *buff = (char *) calloc(length, sizeof(char));
        int i;
        for (i = 0; i < strlen(echo); i++) {
            buff[i] = echo[i];
        }
        for (int j = 0; j <nread ; ++j) {
            buff[j+i]=buf->base[j];
        }
        // 释放读到的buf
        free(buf->base);
        write_req_t *req = (write_req_t *) malloc(sizeof(write_req_t));
        req->buf = uv_buf_init(buff, length);// 写的buff需要在写回调中才能free，否则报错
        uv_write((uv_write_t *) req, client, &req->buf, 1, echo_write);
        return;
    }
    if (nread < 0) {
        if (nread != UV_EOF)
            fprintf(stderr, "Read error %s\n", uv_err_name(nread));
        uv_close((uv_handle_t *) client, NULL);
    }

    free(buf->base);
}

void on_new_connection(uv_stream_t *server, int status) {
    if (status < 0) {
        fprintf(stderr, "New connection error %s\n", uv_strerror(status));
        // error!
        return;
    }

    uv_tcp_t *client = (uv_tcp_t *) malloc(sizeof(uv_tcp_t));
    uv_tcp_init(loop, client);
    if (uv_accept(server, (uv_stream_t *) client) == 0) {
        //发送提示信息
        write_req_t *req = (write_req_t *) malloc(sizeof(write_req_t));
        req->buf = uv_buf_init((char *) ENTER, strlen(ENTER));
        uv_write((uv_write_t *) req, (uv_stream_t *) client, &req->buf, 1, first_write);

        uv_read_start((uv_stream_t *) client, alloc_buffer, echo_read);
    } else {
        uv_close((uv_handle_t *) client, NULL);
    }
}

int main() {
    loop = uv_default_loop();

    uv_tcp_t server;
    uv_tcp_init(loop, &server);

    uv_ip4_addr("0.0.0.0", DEFAULT_PORT, &addr);

    uv_tcp_bind(&server, (const struct sockaddr *) &addr, 0);
    fprintf(stderr, "开始监听%d，请新开命令行输入：nc localhost %d\n", DEFAULT_PORT, DEFAULT_PORT);
    int r = uv_listen((uv_stream_t *) &server, DEFAULT_BACKLOG, on_new_connection);
    if (r) {
        fprintf(stderr, "Listen error %s\n", uv_strerror(r));
        return 1;
    }
    return uv_run(loop, UV_RUN_DEFAULT);
}
```

```
nc localhost 7000
# 输入一些东西
# echo 你输入的东西
```