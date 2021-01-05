---
title: "Springboot Boot Time"
date: 2021-01-05T15:43:39+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

内存缓存是减少查存储次数的一般方案，一般使用`implements InitializingBean`或`@PostConstruct`在bean加载完毕后初始化内存缓存。在数据量大的情况下，会造成应用启动慢。这个文章是一种lazy加载的思路。

## 首先，排查加载慢的bean

```java
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@Slf4j
public class BeanInitCostTimePostProcessor implements BeanPostProcessor, Ordered {

    private Map<String, Long> start = new ConcurrentHashMap<>();

    private Map<String, Long> end = new ConcurrentHashMap<>();

    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        start.put(beanName, System.currentTimeMillis());
        return bean;
    }

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        end.put(beanName, System.currentTimeMillis());
        log.info("bean init time " + beanName + ":" + initializationTime(beanName) + " ms");
        return bean;
    }

    @Override
    public int getOrder() {
        return Integer.MAX_VALUE;
    }

    //this method returns initialization time of the bean.
    public String initializationTime(String beanName) {
        try {
            Long aLong = end.get(beanName);
            return aLong == null ? "error" : String.valueOf(aLong - start.get(beanName));
        } catch (Exception e) {
            return "error";
        }
    }
}
```

## 其次，增加LazyInitializer

```java
import java.util.concurrent.atomic.AtomicBoolean;

public abstract class LazyInitializer {
    private AtomicBoolean inited = new AtomicBoolean(false);

    /**
     * 不需要再显式调用
     * 由
     * @see LazyInitAspect 去处理
     */
    public void checkInit() {
        if (!inited.get()) {
            synchronized (this) {
                if (! inited.get()) {
                    lazyInit();
                    finishInitFlag();
                }
            }
        }
    }

    public boolean isInited() {
        return inited.get();
    }

    protected void finishInitFlag() {
        inited.compareAndSet(false, true);
    }

    protected abstract void lazyInit();
}

## 切面，在方法调用前调用init方法

```java
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.stereotype.Component;

import com.sankuai.raptor.service.LazyInitializer;

@Aspect
@Component
public class LazyInitAspect {
	/**
	 * 所有public方法
	 */
	@Pointcut("execution(public * *.*(..))")
	public void allPublic(){}

	/**
	 * 继承了LazyInitializer，方法不是checkInit()、afterPropertiesSet()、isInited()中的一个
	 */
	@Pointcut("target(com.sankuai.raptor.service.LazyInitializer) && !execution(* checkInit()) && !execution(* afterPropertiesSet()) && !execution(* isInited())")
	private void lazyInit(){}

	/**
	 * 未被Scheduled和SkipInit注解
	 */
	@Pointcut("!@annotation(org.springframework.scheduling.annotation.Scheduled) && !@annotation(SkipInit)")
	public void skipAnnotation(){}


	@Before("allPublic() && lazyInit() && skipAnnotation()")
	public void beforeMethod(JoinPoint joinPoint) {
		((LazyInitializer) joinPoint.getThis()).checkInit();
	}

}
```

## 内存缓存bean的使用

```java
@Component
@Lazy
@Slf4j
public class SomeManager extends LazyInitializer implements InitializingBean {
    // 定时刷新用的线程池
    private ScheduledThreadPoolExecutor loop=new ScheduledThreadPoolExecutor(1);

    @Override
    public void afterPropertiesSet() {
        final SomeManager manager = this;
        loop.scheduleWithFixedDelay(
                () -> {
                    synchronized (manager) {
                        if (isInited()) {
                            lazyInit();
                            finishInitFlag();
                        }
                    }
                },
                0, 60, TimeUnit.SECONDS
        );
    }

    private void refresh() {
        
    }

    @Override
    protected void lazyInit() {
        refresh();
    }
}
```