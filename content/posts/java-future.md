---
title: "Java异步任务中Future的实现"
date: 2020-02-09T21:34:41+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

从netty中学习，首先截取netty中关于Promise和Future的继承关系图，如下。本文首先剖析下图中的四个类，然后自己设计Future。

![](/img/netty-future-promise-uml.png)

<!--more-->

## java Future

```java
public interface Future<V> {
    boolean cancel(boolean var1);
    boolean isCancelled();
    boolean isDone();
    V get() throws InterruptedException, ExecutionException;
    V get(long var1, TimeUnit var3) throws InterruptedException, ExecutionException, TimeoutException;
}
```

java的Future接口很简单，取消、阻塞等待完成、检查是否被取消或者完成。java中对Future最直接的实现是FutureTask，如下是一段代码展示如何使用FutureTask。

```java
        ExecutorService pool=Executors.newFixedThreadPool(4);
        Callable<String> callable=()->{
            System.out.println("run");
            return new String("done");
        };
        //由callable创建FutureTask
        FutureTask<String> task=new FutureTask(callable);
        //线程池执行任务
        pool.execute(task);
        //等待执行完毕
        System.out.println(task.get()); //"done"
        System.out.println(task.isDone()); //true
```

因为java的future本身很简单，Netty中的Future继承java Future后增加了几个方法，我比较关注的是`addListener`这个方法。在使用Java Future时，我们使用Excutors框架提交任务后，只能get()来阻塞等待，或get(timeout)来轮询等待。如果增加了`addListener`方法，那么就可以在task执行完毕后，自动地调用Listener的方法，真正实现异步性。

下面就来看看的Future怎么实现`addListener`。

## addListener

[Github地址](https://github.com/arloor/Future)

测试类

```java
public class Main {
    public static void main(String[] args) {
        ExecutorService pool = Executors.newFixedThreadPool(1);
        FutureListener listener = (someFutureTask -> {
            System.out.println("任务完成");
            System.out.println("结果是："+someFutureTask.get0());
        });
        SomeFutureTask<String> someFutureTask =
                new SomeFutureTask<String>(() -> "done").addListener(listener); // 增加listener
        pool.execute(someFutureTask);
        pool.execute(someFutureTask);
        pool.execute(someFutureTask);
        // 关闭线程池
//        pool.shutdownNow();
    }
}
```

