---
title: "在springboot之外使用thymeleaf渲染text"
date: 2020-08-06T16:33:52+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

thymeleaf是springboot默认的模版引擎，最近需要“渲染模版”这个功能，想到了thymeleaf，记一下怎么用。
<!--more-->

## 依赖

```xml
        <!-- https://mvnrepository.com/artifact/org.thymeleaf/thymeleaf -->
        <dependency>
            <groupId>org.thymeleaf</groupId>
            <artifactId>thymeleaf</artifactId>
            <version>3.0.11.RELEASE</version>
        </dependency>
        <!-- https://mvnrepository.com/artifact/com.google.guava/guava -->
        <dependency>
            <groupId>com.google.guava</groupId>
            <artifactId>guava</artifactId>
            <version>29.0-jre</version>
        </dependency>
```

## 代码

```java
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.Lists;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.StringTemplateResolver;

import java.util.Map;

public class RenderUtil {
    private final static TemplateEngine textEngine = new TemplateEngine();
    private final static TemplateEngine htmlEngine = new TemplateEngine();

    static {
        StringTemplateResolver textResolver = new StringTemplateResolver();
        textResolver.setOrder(1);
        textResolver.setTemplateMode(TemplateMode.TEXT);
        // TODO Cacheable or Not ?
        textResolver.setCacheable(true);
        textEngine.setTemplateResolver(textResolver);

        StringTemplateResolver templateResolver = new StringTemplateResolver();
        templateResolver.setOrder(1);
        templateResolver.setTemplateMode(TemplateMode.HTML);
        // TODO Cacheable or Not ?
        templateResolver.setCacheable(true);
        htmlEngine.setTemplateResolver(templateResolver);
    }

    /**
     * 使用 Thymeleaf 渲染 Text模版
     * Text模版语法见：https://www.thymeleaf.org/doc/tutorials/3.0/usingthymeleaf.html#textual-syntax
     *
     * @param template 模版
     * @param params   参数
     * @return 渲染后的Text
     */
    public static String text(String template, Map<String, Object> params) {

        Context context = new Context();
        context.setVariables(params);
        return textEngine.process(template, context);
    }

    /**
     * 使用 Thymeleaf 渲染 Html模版
     *
     * @param template Html模版
     * @param params   参数
     * @return 渲染后的html
     */
    public static String html(String template, Map<String, Object> params) {
        Context context = new Context();
        context.setVariables(params);
        return htmlEngine.process(template, context);
    }

    /**
     * 测试用，展示如何使用
     *
     * @param args
     */
    public static void main(String[] args) {
        // 渲染String
        String string_template = "这是[(${name.toString()})]"; // 直接name其实就行了，这里就是展示能调用java对象的方法
        String value = RenderUtil.text(string_template, ImmutableMap.of("name", "ARLOOR"));
        System.out.println(value);

        // 渲染List
        /**
         * [# th:each="item : ${items}"]
         *   - [(${item})]
         * [/]
         */
        String list_template = "[# th:each=\"item : ${items}\"]\n" +
                "  - [(${item})]\n" +
                "[/]";
        String value1 = RenderUtil.text(list_template, ImmutableMap.of("items", Lists.newArrayList("第一个", "第二个")));
        System.out.println(value1);

        // 渲染Map
        /**
         * [# th:each="key : ${map.keySet()}"]
         *   - [(${map.get(key)})]
         * [/]
         */
        String map_template = "[# th:each=\"key : ${map.keySet()}\"]\n" +
                " 这是 - [(${map.get(key)})]\n" +
                "[/]";
        String value2 = RenderUtil.text(map_template, ImmutableMap.of("map", ImmutableMap.of("a", "甲", "b", "乙")));
        System.out.println(value2);

        String html_template = "这是<span th:text=\"${name}\"></span>";
        System.out.println(RenderUtil.html(html_template, ImmutableMap.of("name", "ARLOOR")));

    }
}
```

thymeleaf渲染非标记语言（没有tag）时，需要在外面包上自己的tag，例如：详情可见[textual语法](https://www.thymeleaf.org/doc/tutorials/3.0/usingthymeleaf.html#textual-syntax)

```
[# th:each="item : ${items}"]
  - [(${item})]
/]
```

## 其他

如果是在Springboot应用中，有一个`ThymeleafAutoConfiguration`，如果thymeleaf的TemplateMode.class在classpath则会激活这个autoconfiguration。我们在最上面加入了thymeleaf的依赖，但是不是thymeleaf-springboot-starter这种包，会导致应用起不来。

解决方案，在`@SpringBootApplication`下加上：

```
@EnableAutoConfiguration(exclude={ThymeleafAutoConfiguration.class})
```

或者引入thymeleaf的springboot-starter包