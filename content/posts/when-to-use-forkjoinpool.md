---
title: "ForkJoinPool使用场景"
date: 2020-10-28T21:41:39+08:00
draft: false
categories: [ "undefined"]
tags: ["java"]
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

## 一个具体的使用场景
 
 接下来，就到我的场景下：

```
仅使用1个ThreadPool
Main线程提交4个父任务，每个父任务都会拆分出4个子任务，并且等待所有子任务都完成（使用countDownLatch等待）
```

第一个问题，如果threadPool的线程数为4，能正常执行完所有父任务吗？答案是不行，因为4个父任务就占满了所有的线程，没有空余线程可执行子任务，但父任务需要等待子任务都完成。(——线程饥饿死锁《java并发编程实战》8.1.1)

所以，threadpool的线程数需要大于4才能保证顺利执行，比如5个线程。这种情况下：在一开始，只有一个线程在工作，其余的4个线程拿着父任务就在当监工了，这就是你们经常嘲讽的“一核有难，多核围观”，真的是太low了。

在这里的Main提交的是4个任务，在Web服务，消息队列消费者这种应用中，提交父任务数量大于线程池数量的情况是很常见的。因此绝对不可以将这样的父子任务（父等待所有子）提交到同一个线程池！

那使用两个线程池呢？第一个问题：线程利用率仍然不高；第二个问题：如果是递归的，不知道需要多少层，搞动态数量的线程池吗？

结合以上，在父任务依赖（等待）子任务的场景下，不适合在threadpool中再次提交到threadpool（即使是不同的threadPool）

代码如下：耗时16秒（下有日志）

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

ThreadPoolTest日志如下：最夸张的是，刚好能看到`thread-4`全程在围观

```java
22:20:28.114 [pool-1-thread-4] INFO  - ParentRunnable 3 start
22:20:28.114 [pool-1-thread-3] INFO  - ParentRunnable 2 start
22:20:28.114 [pool-1-thread-2] INFO  - ParentRunnable 1 start
22:20:28.114 [pool-1-thread-1] INFO  - ParentRunnable 0 start
22:20:29.123 [pool-1-thread-5] INFO  - SonRunnable 0/0 start
22:20:30.127 [pool-1-thread-5] INFO  - SonRunnable 0/0 done
22:20:30.127 [pool-1-thread-5] INFO  - SonRunnable 2/0 start
22:20:31.131 [pool-1-thread-5] INFO  - SonRunnable 2/0 done
22:20:31.131 [pool-1-thread-5] INFO  - SonRunnable 1/0 start
22:20:32.145 [pool-1-thread-5] INFO  - SonRunnable 1/0 done
22:20:32.145 [pool-1-thread-5] INFO  - SonRunnable 1/1 start
22:20:33.147 [pool-1-thread-5] INFO  - SonRunnable 1/1 done
22:20:33.147 [pool-1-thread-5] INFO  - SonRunnable 3/0 start
22:20:34.151 [pool-1-thread-5] INFO  - SonRunnable 3/0 done
22:20:34.151 [pool-1-thread-5] INFO  - SonRunnable 2/1 start
22:20:35.155 [pool-1-thread-5] INFO  - SonRunnable 2/1 done
22:20:35.155 [pool-1-thread-5] INFO  - SonRunnable 2/2 start
22:20:36.159 [pool-1-thread-5] INFO  - SonRunnable 2/2 done
22:20:36.159 [pool-1-thread-5] INFO  - SonRunnable 1/2 start
22:20:37.162 [pool-1-thread-5] INFO  - SonRunnable 1/2 done
22:20:37.162 [pool-1-thread-5] INFO  - SonRunnable 3/1 start
22:20:38.164 [pool-1-thread-5] INFO  - SonRunnable 3/1 done
22:20:38.164 [pool-1-thread-5] INFO  - SonRunnable 0/1 start
22:20:39.177 [pool-1-thread-5] INFO  - SonRunnable 0/1 done
22:20:39.177 [pool-1-thread-5] INFO  - SonRunnable 2/3 start
22:20:40.192 [pool-1-thread-5] INFO  - SonRunnable 2/3 done
22:20:40.192 [pool-1-thread-5] INFO  - SonRunnable 1/3 start
22:20:41.206 [pool-1-thread-3] INFO  - ParentRunnable 2 done
22:20:41.206 [pool-1-thread-5] INFO  - SonRunnable 1/3 done
22:20:41.206 [pool-1-thread-3] INFO  - SonRunnable 3/2 start
22:20:41.206 [pool-1-thread-5] INFO  - SonRunnable 0/2 start
22:20:42.213 [pool-1-thread-5] INFO  - SonRunnable 0/2 done
22:20:42.213 [pool-1-thread-2] INFO  - ParentRunnable 1 done
22:20:42.213 [pool-1-thread-3] INFO  - SonRunnable 3/2 done
22:20:42.213 [pool-1-thread-5] INFO  - SonRunnable 0/3 start
22:20:42.213 [pool-1-thread-2] INFO  - SonRunnable 3/3 start
22:20:43.228 [pool-1-thread-2] INFO  - SonRunnable 3/3 done
22:20:43.228 [pool-1-thread-5] INFO  - SonRunnable 0/3 done
22:20:44.231 [pool-1-thread-1] INFO  - ParentRunnable 0 done
22:20:44.231 [pool-1-thread-4] INFO  - ParentRunnable 3 done
22:20:44.231 [main] INFO  - 耗时:16123
```

这种场景比较适合`ForkJoinPool`，代码如下: 耗时6秒，简单计算下每个父任务完成都需要6秒，这说明4个线程都在饱和的工作（下有日志）

运行一下这段代码，就会发现，`pool-2`这个线程在打出`ParentAction 1 start`后，还能处理`SonAction 1/0 start`之类的子任务，而不是在`ParentAction 1 done`前啥都不做。

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

日志如下：这里可以看到`pool-2`一刻都没有闲着，他在处理子任务

```java
22:22:25.797 [pool-2] INFO  - ParentAction 1 start
22:22:25.797 [pool-3] INFO  - ParentAction 3 start
22:22:25.797 [pool-0] INFO  - ParentAction 2 start
22:22:25.797 [pool-1] INFO  - ParentAction 0 start
22:22:26.818 [pool-3] INFO  - SonAction 3/0 start
22:22:26.818 [pool-1] INFO  - SonAction 0/0 start
22:22:26.818 [pool-2] INFO  - SonAction 1/0 start
22:22:26.818 [pool-0] INFO  - SonAction 2/0 start
22:22:27.831 [pool-0] INFO  - SonAction 2/0 done
22:22:27.831 [pool-3] INFO  - SonAction 3/0 done
22:22:27.831 [pool-1] INFO  - SonAction 0/0 done
22:22:27.831 [pool-2] INFO  - SonAction 1/0 done
22:22:27.831 [pool-3] INFO  - SonAction 3/1 start
22:22:27.831 [pool-0] INFO  - SonAction 2/1 start
22:22:27.831 [pool-2] INFO  - SonAction 1/1 start
22:22:27.831 [pool-1] INFO  - SonAction 0/1 start
22:22:28.834 [pool-0] INFO  - SonAction 2/1 done
22:22:28.834 [pool-2] INFO  - SonAction 1/1 done
22:22:28.834 [pool-1] INFO  - SonAction 0/1 done
22:22:28.834 [pool-2] INFO  - SonAction 1/2 start
22:22:28.834 [pool-3] INFO  - SonAction 3/1 done
22:22:28.834 [pool-1] INFO  - SonAction 0/2 start
22:22:28.834 [pool-0] INFO  - SonAction 2/2 start
22:22:28.834 [pool-3] INFO  - SonAction 3/2 start
22:22:29.843 [pool-2] INFO  - SonAction 1/2 done
22:22:29.843 [pool-0] INFO  - SonAction 2/2 done
22:22:29.843 [pool-3] INFO  - SonAction 3/2 done
22:22:29.843 [pool-2] INFO  - SonAction 1/3 start
22:22:29.843 [pool-1] INFO  - SonAction 0/2 done
22:22:29.843 [pool-0] INFO  - SonAction 2/3 start
22:22:29.843 [pool-1] INFO  - SonAction 0/3 start
22:22:29.843 [pool-3] INFO  - SonAction 3/3 start
22:22:30.857 [pool-1] INFO  - SonAction 0/3 done
22:22:30.857 [pool-0] INFO  - SonAction 2/3 done
22:22:30.857 [pool-2] INFO  - SonAction 1/3 done
22:22:30.857 [pool-3] INFO  - SonAction 3/3 done
22:22:31.871 [pool-2] INFO  - ParentAction 1 done
22:22:31.871 [pool-3] INFO  - ParentAction 3 done
22:22:31.871 [pool-1] INFO  - ParentAction 0 done
22:22:31.871 [pool-0] INFO  - ParentAction 2 done
22:22:31.871 [main] INFO  - 耗时:6082
```

另一个注意点：有人说，多个子任务不要挨个`.fork()`，需要`ForkJoinTask .invokeAll(..)`，他们说，`.fork()`不能充分利用线程，说有线程会当监工，我实测并没有这个问题。

`.fork()`和`ForkJoinTask .invokeAll(..)`区别在于：

1. `.fork()`是异步的，需要`.join()`或者`.get(timeout,timeunit)`来获取结果
2. `.invokeAll()`则是同步的，当其返回时所有的任务都完成了

所以，当需要进行超时处理时，使用`.fork()`，不需要则可以使用`invokeAll`


## ForkjoinPool的帮助类

由于Forkjoinpool的模型和其他线程池不太一样，使用上还是比较麻烦的，这里写了一个ForkjoinHelper类。


```java
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.tuple.Pair;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;
import java.util.function.Supplier;

@Slf4j
public class ForkJoinHelper {

    /**
     * 获取结果
     * @param tasks
     * @param timeout
     * @param <T>
     * @return
     */
    public static <T> Pair<Boolean, List<T>> get(List<? extends ForkJoinTask<T>> tasks, long timeout) {
        List<T> result = new ArrayList<>();
        for (ForkJoinTask<T> task : tasks) {
            long time = System.currentTimeMillis();
            try {
                T t = task.get(timeout, TimeUnit.MILLISECONDS);
                result.add(t);
            } catch (InterruptedException | ExecutionException | TimeoutException e) {
                // 有一个异常，其他的任务就没有执行的必要了
                for (ForkJoinTask<T> cell : tasks) {
                    cell.cancel(true);
                }
                log.error("excute_forkjoin_task_error", e);
                return Pair.of(false, result);
            } finally {
                time = System.currentTimeMillis() - time;
                timeout = timeout - time <= 0 ? 1 : timeout - time;
            }
        }
        return Pair.of(true, result);
    }
    
    public static <T> List<ForkJoinTask<T>> submit(List<Supplier<T>> tasks) {
        List<ForkJoinTask<T>> futures = new ArrayList<>();
        for (Supplier<T> task : tasks) {
            ForkJoinTask<T> future = new ForkableTask<T>(task).fork();
            futures.add(future);
        }
        return futures;
    }

    public static List<ForkJoinTask<Void>> execute(List<Runnable> tasks) {
        List<ForkJoinTask<Void>> futures = new ArrayList<>();
        for (Runnable task : tasks) {
            ForkJoinTask<Void> future = new ForkableAction(task).fork();
            futures.add(future);
        }
        return futures;
    }

    public static List<ForkJoinTask<Void>> execute(List<Runnable> tasks, ForkJoinPool pool) {
        List<ForkJoinTask<Void>> futures = new ArrayList<>();
        for (Runnable task : tasks) {
            ForkableAction action = new ForkableAction(task);
            if (Thread.currentThread() instanceof ForkJoinWorkerThread) {
                ForkJoinTask<Void> future = action.fork();
                futures.add(future);
            } else {
                ForkJoinTask<Void> future = pool.submit(action);
                futures.add(future);
            }
        }
        return futures;
    }
}
```

```java
import java.util.concurrent.RecursiveTask;
import java.util.function.Supplier;

public class ForkableTask<V> extends RecursiveTask<V> {

    private Supplier<V> supplier;

    public ForkableTask(Supplier<V> supplier) {
        super();
        this.supplier = supplier;
    }

    @Override
    protected V compute() {
        return supplier.get();
    }
}
```

```java
import java.util.concurrent.RecursiveAction;

public class ForkableAction extends RecursiveAction {
    private Runnable runnable;

    public ForkableAction(Runnable runnable) {
        super();
        this.runnable = runnable;
    }

    @Override
    protected void compute() {
        runnable.run();
    }
}
```