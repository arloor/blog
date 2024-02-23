---
title: "Java wait/notify和condition"
date: 2020-06-11T10:59:36+08:00
draft: false
categories: [ "undefined"]
tags: ["java"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

以下全部来自jdk8的javaDoc。
<!--more-->

## Object

## 前置知识-monitor

线程获取对象的monitor的三种方式

1. 调用对象的synchronized实例方法
2. 调用synchronized(obj)内的方法
3. For objects of type Class, by executing a synchronized static method of that class.

在某一时间，只能有一个线程持有对象的monitor

## notify

线程在已经获取对象monitor的前提下调用，唤醒一个或者所有在该对象monitor上等待的线程（notifyall）。

被唤醒的线程在调用notify的线程放弃对象的锁之后才能继续执行，并且公平地和其他想要在该对象上同步的线程竞争。

从以上描述，一种合理的notify：

```java
public void send(){
  synchronsized(this){
    // send something;
    this.notify();
  }
}
```

## wait

使当前线程等待其他线程调用该对象的notify或notifyall。当前线程必须要持有对象的monitor。

wait方法会将当前线程放到对象的等待集合（在对象头中？）然后放弃对该对象的所有同步声明（？所有）。最后该线程会被禁止线程调度。

在被notify选中被wakeup时，该线程会移出对象等待集合，重新加入线程调度。然后和其他线程公平竞争来在该对象上同步。一旦获得该对象的控制，线程将恢复所有同步声明，也就是恢复到wait调用前的状态，然后从wait方法返回。

因为线程会在没有被notify、被中断、超时的情况下被唤醒（称为可疑唤醒）。所以wait调用需要在while（不满足唤醒的条件）中来防止可疑唤醒。

所以，wait的典型调用如下：

```java
      synchronized (obj) {
         while (<condition does not hold>){
             obj.wait(timeout);
        }
         ... // Perform action appropriate to condition
     }
```

## Condition

跟object的wait、 notify的主要区别是：

1. condition依赖显式锁
2. 一个显示锁可以有多个conditon: 一个对象可以有多个等待队列

用lock代替synchronized，用condition代替monitor（实现多个等待集）。

可疑唤醒依然会出现，所以await需要在while（test）中

典型调用

```java
 class BoundedBuffer {
   final Lock lock = new ReentrantLock();
   final Condition notFull  = lock.newCondition(); 
   final Condition notEmpty = lock.newCondition(); 

   final Object[] items = new Object[100];
   int putptr, takeptr, count;

   public void put(Object x) throws InterruptedException {
     lock.lock();
     try {
       while (count == items.length)
         notFull.await();
       items[putptr] = x;
       if (++putptr == items.length) putptr = 0;
       ++count;
       notEmpty.signal();
     } finally {
       lock.unlock();
     }
   }

   public Object take() throws InterruptedException {
     lock.lock();
     try {
       while (count == 0)
         notEmpty.await();
       Object x = items[takeptr];
       if (++takeptr == items.length) takeptr = 0;
       --count;
       notFull.signal();
       return x;
     } finally {
       lock.unlock();
     }
   }
 }
```






