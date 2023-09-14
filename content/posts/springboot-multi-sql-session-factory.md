---
title: "Springboot配置多个Mybatis的sqlSessionFactory"
date: 2023-09-14T15:26:56+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

本文首先介绍Springboot的单数据源配置方式，并介绍其中的Springboot自动装配细节；其次介绍如何配置多数据源。
<!--more-->

## 单数据源配置

得益于Springboot的自动装配，在Springboot中使用Mybatis连接mysql等数据库非常方便，大概只需要两步：

1. 在yaml文件中配置 `spring.datasource.xx` ，用来定义datasource，包括driver class、url、用户名、密码等
2. 在yaml文件中配置 `mybatis.xx` ，用来修改Mybatis的默认参数。下面是一个例子：

```yaml
spring:
    datasource:
        url: jdbc:mysql://xxxxxx:3306/database?useUnicode=true&characterEncoding=utf-8&useSSL=true&autoReconnect=true
        username: xxx
        password: xxxxx
        driver-class-name: com.mysql.jdbc.Driver

mybatis:
    configuration:
        map-underscore-to-camel-case: true # 将数据库下划线字段，映射为Java的驼峰式Field。很方便，这样就省去了ResultMap中字段映射
    type-handlers-package: com.arloor.mybatis.typehandler # 数据库类型到Java类型的映射
```

### 自动装配

自动装配的核心类是 `MybatisAutoConfiguration`，先看这个类上重要的三个注解：

```java
@ConditionalOnSingleCandidate(DataSource.class)
@EnableConfigurationProperties(MybatisProperties.class)
@AutoConfigureAfter({ DataSourceAutoConfiguration.class, MybatisLanguageDriverAutoConfiguration.class })
```

| 注解 | 含义 |
| :---: | :--- |
| @ConditionalOnSingleCandidate(DataSource.class) | 当只有一个DataSource的bean时生效。如果有多个Datasource的bean，但其中一个被@Primary注解时，同样认为生效 |
| @EnableConfigurationProperties(MybatisProperties.class) | 启用MybatisProperties，读取 `mybatis.xxx` 的配置 |
| @AutoConfigureAfter({ DataSourceAutoConfiguration.class, MybatisLanguageDriverAutoConfiguration.class }) | 触发Datasource的自动装配，从 `spring.datasource.xx` 读取配置 |