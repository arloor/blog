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

> 在进行相关配置后，上面的话就是屁话。例如在SpringBoot中约定aop对controller也生效

## 应用

**增加pom依赖**

```
<dependency>
	<groupId>org.springframework.boot</groupId>
	<artifactId>spring-boot-starter-aop</artifactId>
</dependency>
```

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

## aop实现单节点redis分布式锁

```
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface DistLock {

    public String lockPrefix() default "";

    public int lockTime() default 10;

}
```

```
import org.apache.commons.lang3.StringUtils;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import javax.annotation.Resource;
import java.lang.annotation.Annotation;
import java.lang.reflect.Method;

@Aspect
@Component
@Order(10)
public class DistLockAspect {

    @Resource(name = "redisHaCache")
    private RedisHaCache redisHaCache;

    @Pointcut("@annotation(com.cmbchina.ccd.pluto.fulltextmanager.aop.lock.DistLock)")
    public void pointCut(){}

    @Around("pointCut()")
    public Object aroundMethod(ProceedingJoinPoint jp) throws Throwable {

        MethodSignature signature = (MethodSignature) jp.getSignature();
        Method method = signature.getMethod();

        DistLock distLock = method.getAnnotation(DistLock.class);
        if (distLock == null) {
            return jp.proceed();
        }

        Annotation[][] parameterAnnotations = method.getParameterAnnotations();
        Object distLockObj = null;
        Object lockObjAnnotation = null;
        int index = -1;
        for (int i = 0; i < parameterAnnotations.length; i++) {
            for (int j = 0; j < parameterAnnotations[i].length; j++) {
                if (parameterAnnotations[i][j] instanceof DistLockObject) {
                    lockObjAnnotation = parameterAnnotations[i][j];
                    index = i;
                    break;
                }
            }
            if (index != -1) {
                break;
            }
        }

        if (index != -1) {
            distLockObj = jp.getArgs()[index];
        }

        String key = distLock.lockPrefix();
        if (distLockObj != null && lockObjAnnotation != null) {
            String lockField = ((DistLockObject) lockObjAnnotation).objectLockField();
            if (!StringUtils.isEmpty(lockField)) {
                String methodName = "get" + StringUtils.capitalize(lockField);
                Method getObjMethod = distLockObj.getClass().getMethod(methodName);
                Object invoke = getObjMethod.invoke(distLockObj);
                if (invoke != null) {
                    key += invoke.toString();
                }
            } else {
                key += distLockObj.toString();
            }
        }

        if (!"OK".equals(redisHaCache.set(key, key, "NX", "EX", distLock.lockTime()))) {
            throw new FullTextException("This object is already locked!");
        }
        try {
            return jp.proceed();
        } finally {
            redisHaCache.del(key);
        }

    }

}
```

```
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface DistLockObject {

    public String objectLockField() default "";

}
```

```
@DistLock(lockPrefix = DIST_LOCK_WORK_SPACE_OBJECT)
    public int create(@DistLockObject(objectLockField = "objectId") WorkSpaceCreateVo workSpaceCreateVo) {
```

## 其他声明PointCut的方式

上面都是用注解来声明PointCut的，还有一些其他方式：

### execution + args获取方法参数

```java
    private static final String POINT_CUT = "execution(public * com.arloor.test.common.xxx.service.impl.xxxService.someMethod(..)) && args(paramA, paramB, paramC)"

    @Pointcut(POINT_CUT)
    public void pointCut() {
    }

    @Around(value = POINT_CUT)
    public Object doAroundAdvice(ProceedingJoinPoint point, String paramA, List<String> paramB, String paramC) throws Throwable {
        Object result = point.proceed();
        return result;
    }
```

args中指出的参数可以直接在`doAroundAdvice`使用。注意类型需要一致，否则spring会起不起来

### execution ||

```java
    private static final String POINT_CUT = "execution(public * com.xxx.xxx.common.xx.integration.xx.*(..))" +
            "|| execution(public * com.xxx.xxx.common.auth.integration.xx.*(..))" +
            "|| execution(public * com.xx.xxx.xxx.auth.xxx.xxx.*(..))";

    @Pointcut(POINT_CUT)
    public void pointCut() {`
    }

    @Around(value = POINT_CUT)
    public Object doAroundAdvice(ProceedingJoinPoint point) throws Throwable {
        Object result = point.proceed();
        return result;
    }
```
