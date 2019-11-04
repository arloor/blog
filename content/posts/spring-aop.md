---
title: "Spring Aop使用"
date: 2019-11-04T19:05:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

来记一下spring aop的使用
<!--more-->

## 概念：
- 方面（Aspect）： 一个关注点的模块化，这个关注点实现可能另外横切多个对象。事务
管理是 J2EE 应用中一个很好的横切关注点例子。方面用 Spring 的 Advisor 或拦截器
实现。
- 连接点（Joinpoint）: 程序执行过程中明确的点，如方法的调 用或特定的异常被抛出。
- 通知（Advice）: 在特定的连接点，AOP 框架执行的动作。各种类 型的通知括“around”、“before”和“throws”通知。通知类型将在下面讨论。许多 AOP 框架 包括 Spring 都是以拦截器做通知模型，维护一个“围绕”连接点的拦截器链。
- 切入点（Pointcut）: 指定一个通知将被引发的一系列连接点 的集合。AOP 框架必须允许开发者指定切入点：例如，使用正则表达式。
- 引入（Introduction）: 添加方法或字段到被通知的类。 Spring 允许引入新的接口到任何被通知的对象。例如，你可以使用一个引入使任何对象实现 IsModified 接口，来简化缓存。
- 目标对象（Target Object）: 包含连接点的对象。也被称作 被通知或被代理对象。
- AOP 代理（AOP Proxy）: AOP 框架创建的对象，包含通知。 在 Spring 中，AOP 代理可以是 JDK 动态代理或者 CGLIB 代理。
- 织入（Weaving）: 组装方面来创建一个被通知对象。这可以在编译时 完成（例如使用AspectJ 编译器），也可以在运行时完成。Spring 和其他纯 Java AOP 框架一样， 在运行时完成织入。

## 代理实现：
使用 jdk 动态代理和 CGlib 代理实现。对接口使用 jdk 动态代理，对只有实现的类提供CGlib代理。Spring 文档推荐对业务类增加接口，然后对接口使用 jdk 动态代理。

> 不要在Controller上使用AOP，因为spring默认使用jdk代理，对controller不生效

## 应用

在实际应用spring aop时，仅仅需要写好@Aspect、@PointCut以及Advice(@Before、@Around等)。下面上一段代码实例；

**切面定义**

```java
//切面实现
@Component
@Aspect
@CommonsLog
public class TestAspect {

    //切点定义：指定被SomeAnnotation注解的方法
    @Pointcut("@annotation(xx.xx.xx.SomeAnnotation)")
    public void test() {
    }

    //Around上面的切点
    @Around("test()")
    public Object around(ProceedingJoinPoint jp) throws Throwable {
        log.error("join point!");
        return jp.proceed();// 指定被代理对象的原方法
    }
}
```

**注解**

```java
@Target(ElementType.METHOD)// 只能注解到方法上
@Retention(RetentionPolicy.RUNTIME) //运行时生效
public @interface SomeAnnotation {
    String value() default "";
}
```

**被注解从而加入切面的方法**

```java
    @SomeAnnotation
    public SomeObject someThing(Vo o) {
        return .........
    }
```

这样，有`@SomeAnnotation`注解的方法都会执行around方法。

关于`@Pointcut`的定义还可以使用其他形式。

