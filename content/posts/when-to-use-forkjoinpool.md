---
title: "ForkJoinPool使用场景"
date: 2020-10-28T21:41:39+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

这篇博客不是科普什么是`ForkJoinPool`，不是介绍他的原理，而是结合一个具体的场景来说什么时候应该使用他。

我们先看javaDoc中关于`RecursiveTask`使用的例子：(如果不知道`RecursiveTask`，可以先去查一下)
<!--more-->

```
 class Fibonacci extends RecursiveTask<Integer> {
   final int n;
   Fibonacci(int n) { this.n = n; }
   Integer compute() {
     if (n <= 1)
       return n;
     Fibonacci f1 = new Fibonacci(n - 1);
     f1.fork();
     Fibonacci f2 = new Fibonacci(n - 2);
     return f2.compute() + f1.join();
   }
 }
 ```

 这是一个用`ForkJoinPool`计算`Fibonacci`数列的例子。JDK不管从`RecursiveTask`这个命名，还是`Fibonacci`这个例子都在告诉我们，`ForkJoinPool`比较适用于递归拆分任务的场景，或者说递归分治的场景。

 接下来，就到我的场景下：

```
仅使用1个ThreadPool
Main线程提交4个父任务，每个父任务都会拆分出4个子任务，并且等待所有子任务都完成（使用countDownLatch等待）
```

第一个问题，如果threadPool的线程数为4，能正常执行完所有父任务吗？答案是不行，因为4个父任务就占满了所有的线程，没有空余线程可执行子任务，但父任务需要等待子任务都完成。

所以，threadpool的线程数需要大于4才能保证顺利执行，比如5个线程。这种情况下：在一开始，只有一个线程在工作，其余的4个线程拿着父任务就在当监工了，这就是你们经常嘲讽的“一核有难，多核围观”，真的是太low了。

在这里的Main提交的是4个任务，在Web服务，消息队列消费者这种应用中，提交父任务数量大于线程池数量的情况是很常见的。因此绝对不可以这样的父子任务（父等待所有子）提交到同一个线程池！

那使用两个线程池呢？第一个问题：线程利用率仍然不高；第二个问题：如果是递归的，不知道需要多少层，搞动态数量的线程池吗？

结合以上，在父任务依赖（等待）子任务的场景下，不适合在threadpool中再次提交到threadpool（即使是不同的threadPool）

代码如下：耗时13秒

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.*;

/**
 * 场景：
 * 大任务拆小任务，并且需要等待小任务都完成，才完成（使用countdownLatch）
 * <p>
 * 现象：
 * 1. 拿到大任务的线程，必须等待其他执行小任务的线程完成任务。这期间不做任何事情。
 * 2. 一次提交的的大任务数大于线程数量时，直接死锁，不能完成
 * <p>
 * 将小任务提交到另一个线程池能解决第二个问题，但是如果大任务拆小任务是多层的，甚至是递归的（不确定多少层），就没好办法了
 * 第一个问题则怎么都不能解决
 */
public class ThreadPoolTest {
    private static final Logger log = LoggerFactory.getLogger("");
    // 如果numFork >= numThreads 则会观察到无法执行子任务
    private static final int numFork = 4;
    private static final int numThreads = 5;
    private static ThreadPoolExecutor pool = new ThreadPoolExecutor(numThreads, numThreads, 3, TimeUnit.MINUTES, new ArrayBlockingQueue<Runnable>(100));
    private static final int time2work = 1000;


    public static void main(String[] args) {
        long now = System.currentTimeMillis();
        CountDownLatch latch = new CountDownLatch(numFork);
        for (int i = 0; i < numFork; i++) {
            pool.submit(new ParentRunnable(String.valueOf(i), latch));
        }
        try {
            latch.await();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        // 执行完毕，关闭线程池
        pool.shutdown();
        log.info("耗时:{}", System.currentTimeMillis() - now);
    }

    private static abstract class MyRunnable implements Runnable {
        protected String name;
        protected CountDownLatch latch;

        public MyRunnable(String name, CountDownLatch latch) {
            this.name = name;
            this.latch = latch;
        }

        protected abstract void doRun() throws InterruptedException;

        @Override
        public void run() {
            log.info("{} {} start", this.getClass().getSimpleName(), name);
            try {
                doRun();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                latch.countDown();
            }
            log.info("{} {} done", this.getClass().getSimpleName(), name);
        }
    }

    private static final class SonRunnable extends MyRunnable {

        public SonRunnable(String name, CountDownLatch latch) {
            super(name, latch);
        }

        @Override
        protected void doRun() throws InterruptedException {
            Thread.sleep(time2work);
        }
    }

    private static final class ParentRunnable extends MyRunnable {

        public ParentRunnable(String name, CountDownLatch latch) {
            super(name, latch);
        }

        @Override
        protected void doRun() throws InterruptedException {
            Thread.sleep(time2work);
            CountDownLatch latch = new CountDownLatch(numFork);
            for (int i = 0; i < numFork; i++) {
                pool.submit(new SonRunnable(name + "/" + i, latch));
            }
            // 等待所有子任务完成，以便进行聚合操作
            latch.await();
            // 模拟做些操作
            Thread.sleep(time2work);
        }
    }

}
```

这种场景比较适合`ForkJoinPool`，代码如下: 耗时6秒

运行一下这段代码，就会发现，`pool-1`这个线程在打出`parent 0 start`后，还能处理`son 0/1 start`之类的子任务，而不是在`parent 0 done`前啥都不做。

这归功于`.join()`方法的特殊机制，它不等同于`CountDownLatch`的`await`，具体原理我暂时也不懂。但是可以记住，在`ForkJoinPool`中使用`CountDownLatch`是愚蠢的做法。

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ForkJoinPool;
import java.util.concurrent.ForkJoinTask;
import java.util.concurrent.ForkJoinWorkerThread;
import java.util.concurrent.RecursiveAction;

/**
 * 解决ThreadPool在上述场景问题的原理：
 * 线程不做父任务的监工，而是直接去做子任务
 * 这样就能提升并法度了
 */
public class ForkJoinPoolTest {
    private static int numThread = 4;
    private static int numFork = numThread;
    private static ForkJoinPool pool = new ForkJoinPool(numThread, pool -> {
        final ForkJoinWorkerThread worker = ForkJoinPool.defaultForkJoinWorkerThreadFactory.newThread(pool);
        worker.setName("pool-" + worker.getPoolIndex());
        return worker;
    }, null, false);
    private static final int time2work = 1000;
    private static final Logger log = LoggerFactory.getLogger("");

    public static void main(String[] args) {
        long now = System.currentTimeMillis();
        List<Action> actions = new ArrayList<>();
        for (int i = 0; i < numFork; i++) {
            ParentAction parentAction = new ParentAction(String.valueOf(i));
            actions.add(parentAction);
            pool.submit(parentAction);
        }
        for (Action action : actions) {
            action.join();
        }
        pool.shutdown();
        log.info("耗时:{}", System.currentTimeMillis() - now);
    }

    private static abstract class Action extends RecursiveAction {
        private String name;

        public String getName() {
            return name;
        }

        public Action(String name) {
            this.name = name;
        }

        protected abstract void doCompute() throws InterruptedException;

        @Override
        protected void compute() {
            log.info("{} {} start", this.getClass().getSimpleName(), this.getName());
            try {
                doCompute();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            log.info("{} {} done", this.getClass().getSimpleName(), this.getName());
        }
    }

    private static final class ParentAction extends Action {

        public ParentAction(String name) {
            super(name);
        }

        @Override
        protected void doCompute() throws InterruptedException {
            Thread.sleep(time2work);
            List<Action> actions = new ArrayList<>();
            for (int i = 0; i < numFork; i++) {
                SonAction son = new SonAction(getName() + "/" + String.valueOf(i));
                actions.add(son);
            }
            // 或者for action.fork()；推荐多任务时使用invokeAll()
            ForkJoinTask.invokeAll(actions);
            for (Action action : actions) {
                action.join();
            }
            Thread.sleep(time2work);
        }
    }

    private static final class SonAction extends Action {

        public SonAction(String name) {
            super(name);
        }

        @Override
        protected void doCompute() throws InterruptedException {
            Thread.sleep(time2work);
        }
    }

}
```


