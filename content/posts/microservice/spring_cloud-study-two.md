---
author: "刘港欢"
date: 2018-06-22
linktitle: spring cloud学习（二）
title: spring cloud学习（二）
categories: [ "微服务","java"]
tags: ["program"]
weight: 10
---



spring cloud学习（一）中已经了有了注册与发现、服务消费、负载均衡、断路器。但是这不是完整的微服务架构。

在微服务架构中，需要几个基础的服务治理组件，包括服务注册与发现、服务消费、负载均衡、断路器、智能路由、配置管理等，由这几个基础组件相互协作，共同组建了一个简单的微服务系统。<!--more-->

## 模块 4-service-zuul

zuul的主要功能是路由转发和过滤器。路由功能是微服务的一部分，比如／api/user转发到到user服务，/api/shop转发到到shop服务。zuul默认和Ribbon结合实现了负载均衡的功能。

### 服务路由功能

Main类:@EnableZuulProxy

```
@EnableZuulProxy//开启zuul路由
@EnableEurekaClient
@SpringBootApplication
public class ServiceZuulApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServiceZuulApplication.class, args);
    }
}
```

application.yml
```
eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:8761/eureka/
server:
  port: 8769
spring:
  application:
    name: service-zuul
zuul:
  routes:
    api-a:
      path: /api-a/**
      serviceId: service-ribbon
    api-b:
      path: /api-b/**
      serviceId: service-feign
```

application.yml还是有几个比较传统的配置：注册中心地址、端口、服务名。最后zuul.routes.*定义了路由配置。也就是：`/api-a/**`的走`service-ribbon`,`/api-b/**`的走`service-feign`。

测试：把所有模块都跑起来，然后输入`http://localhost:8769/api-a/hi?name=moontell`，`http://localhost:8769/api-b/hi?name=moontell`，都能成功显示`hi moontell,i am from port:8763/2`

### 服务过滤功能

首先讲一下这个服务过滤功能是啥。

看代码就知道，实现服务过滤功能就是加了一个filter。看其实现和java web开发的过滤器也是很像的，就是对请求、响应进行修改。

看代码：

```java
@Component
public class MyFilter extends ZuulFilter {

    private static Logger log = LoggerFactory.getLogger(MyFilter.class);
    @Override
    public String filterType() {
        return "pre";
    }

    @Override
    public int filterOrder() {
        return 0;
    }

    @Override
    public boolean shouldFilter() {
        return true;
    }

    @Override
    public Object run() {
        RequestContext ctx = RequestContext.getCurrentContext();
        //获取当前请求
        HttpServletRequest request = ctx.getRequest();
        log.info(String.format("%s >>> %s", request.getMethod(), request.getRequestURL().toString()));
        //如果token为空，那么就写response。
        Object accessToken = request.getParameter("token");
        if(accessToken == null) {
            log.warn("token is empty");
            ctx.setSendZuulResponse(false);
            ctx.setResponseStatusCode(401);
            try {
                ctx.getResponse().getWriter().write("token is empty");
            }catch (Exception e){}

            return null;
        }
        log.info("token permit");
        return null;
    }
}
```

通过这段代码，就实现了一个验证token的功能。这个应该是以后Oauth2也会用到。

filterType：返回一个字符串代表过滤器的类型，在zuul中定义了四种不同生命周期的过滤器类型，具体如下： 
- pre：路由之前
- routing：路由之时
- post： 路由之后
- error：发送错误调用

filterOrder：过滤的顺序

shouldFilter：这里可以写逻辑判断，是否要过滤，本文true,永远过滤。

run：过滤器的具体逻辑。可用很复杂，包括查sql，nosql去判断该请求到底有没有权限访问。

## 模块 5-config-server

主类：@EnableConfigServer

```
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}
```

application.properties

```
spring.application.name=config-server
server.port=8888
        
spring.cloud.config.server.git.uri=https://github.com/arloor/cloud/ #就是本项目了
spring.cloud.config.server.git.searchPaths=config#仓库下的路径
spring.cloud.config.label=master
spring.cloud.config.server.git.username=your username#如果是公开项目不需要设置
spring.cloud.config.server.git.password=your password##如果是公开项目不需要设置
```

主类依然只需要加上一个注解@EnableConfigServer，然后在application.propertities上加上git仓库的配置。spring cloud config是查询git仓库内容进行配置的。

在如上的配置中，我项目的`{dir_root}\config\config-client-dev.properties`文件内容如下：

```
foo = foo version 5
```

启动服务，访问[http://localhost:8888/foo/dev](http://localhost:8888/foo/dev)可以看到

```
{"name":"foo","profiles":["dev"],"label":"master","version":"213f32d6d577237186e71a9ae17aa52cd3a55ac0","state":null,"propertySources":[]}
```

## 模块 6-config-client

主类：

```
@SpringBootApplication
@RestController
public class ConfigClientApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigClientApplication.class, args);
    }

    @Value("${foo}")
    String foo;
    @RequestMapping(value = "/hi")
    public String hi(){
        return foo;
    }
}
```

bootstrap.properties

```
spring.application.name=config-client
spring.cloud.config.label=master
spring.cloud.config.profile=dev
spring.cloud.config.uri= http://localhost:8888/
server.port=8881
```

注意！是bootstrap.application。最初虽然没有看懂spring cloud的文档，但是了解到有一个叫bootstrap的context上下文。这个context早于application的context启动。作为配置信息，确实需要在应用启动之前被加载好。

可以看到主类中的`@Value("${foo}")String foo;`其实就是`config-server`所指定的git仓库中的`config-client-dev.properties`中定义的foo。这应该就是配置服务中心的一般使用方法，将本来在application.propertitis中的属性放到统一的git仓库中，允许不同微服务使用同一个值。

启动服务，访问[http://localhost:8881/hi](http://localhost:8881/hi)，显示

```
foo version 5
```

另外，为什么配置文件命名为`config-client-dev.properties`？

因为http请求地址和资源文件映射如下:

- /{application}/{profile}[/{label}]
- /{application}-{profile}.yml
- /{label}/{application}-{profile}.yml
- /{application}-{profile}.properties
- /{label}/{application}-{profile}.properties

在`6-config-client`中，有

```
spring.application.name=config-client
spring.cloud.config.label=master
spring.cloud.config.profile=dev
```

因此是`config-client-dev.properties`

## 高可用的配置中心

所谓高可用的配置服务中心，我感觉就是配置中心做一个冗余然后通过负载均衡，平衡压力。

具体怎么操作，就是将配置中心服务纳入服务注册中心的管理，然后通过配置中心的服务名来调用配置中心的服务。

下面来介绍一下怎么操作。

### 创建/启动一个服务注册中心

学习博客中，单独创建了一个新的服务注册中心，我觉得没有必要，就直接使用`0-eureka-server`这个服务注册中心。

首先在@8761启动`0-eureka-server`实例，作为服务注册中心。

### 改造模块 5-config-server 将其改成eureka client

所做的工作如下：

1. pom增加eureka的依赖
2. 在application.yml中配置eureka server的地址
3. 增加@EnableEurekaClient注解（学习博客上写的是@EnableEureka，应该是错的）

就是这么简单，说到底就是将配置中心注册一下。

或者时候打开[http://localhost:8761](http://localhost:8761)就能看到名为`config-server`的服务

### 改造模块 6-config-client 将其改造成eureka client

所作工作如下:

1. pom增加eureka的依赖
2. 在bootstrap.porperties中配置eureka server的地址
3. 将以url使用config-server改为使用服务名的方式
4. 增加@EnableEurekaClient注解（学习博客上没有这一步、不知道是不是必须，反正加上）

第三步所做的事就是改变`bootstrap.porperties`的如下几行：

```
### 服务配置中心地址——这种没有被纳入服务注册中心的管理
#spring.cloud.config.uri= http://localhost:8888/

### 将配置中心纳入服务注册中心管理，以实现高可用
eureka.client.serviceUrl.defaultZone=http://localhost:8761/eureka/
spring.cloud.config.discovery.enabled=true
spring.cloud.config.discovery.serviceId=config-server
```

这样改造之后，就通过服务注册中心的方式使用了config-server。也就允许了冗余。

学习博客中这样说：

```
这时发现，在读取配置文件不再写ip地址，而是服务名，这时如果配置服务部署多份，通过负载均衡，从而高可用。
```

不知道负载均衡需不需要单独配置。想来是不需要的，但还是提出这个疑问先。毕竟在config-client中没有引入ribbon这个负责负载均衡的包。。。先留个疑问在这吧。

