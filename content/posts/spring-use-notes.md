---
title: "Spring随用随记"
date: 2019-11-09T22:13:53+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

在工作之前大概有一年半没有写过spring的东西了，有些东西忘了，用这个记一下。
<!--more-->

## @Controller和@RestContoller

@RestController可以认为是@Controller+@ResponseBody。

被@Controller注解的方法可以返回String、ModelAndView等类型的对象，他指定的是返回MVC中的M和V，会寻找一个对应的页面，并把Model设置进去。

@RestController方法返回的对象会被Spring自动地转换为json，返回给浏览器。

以上就是两者的不同。

## 拦截器HandlerInterceptor 

原生的Servlet API提供了Filter过滤器，可以对请求作出一些修改   
Spring则提供拦截器这种东西。[官方文档](https://docs.spring.io/spring/docs/5.2.1.RELEASE/spring-framework-reference/web.html#mvc-handlermapping-interceptor)


拦截器用于在Controller处理请求前，“拦截”请求并修改。拦截器提供三种方法：

- preHandle(..): Before the actual handler is executed
- postHandle(..): After the handler is executed
- afterCompletion(..): After the complete request has finished

要实现自己的拦截器，需要实现HandlerInterceptor接口或者继承HandlerInterceptorAdapter类，并实现（重载）相关方法。例如：

```java
public class GetCcmsUserInfo extends HandlerInterceptorAdapter {
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
         //.........对request作出修改，比如request.setAttribute(....)等。
         return true;//继续执行该请求
         //return false;//拦截该请求
    }
}
```

**注意1**：postHandle对于@RestController和@ResponseBody和ResponseEntity的修改是无效的，因为已经提前返回给浏览器了。要修改他们，请使用`ResponseBodyAdvice`或者使用@ControllerAdvice。

**注意2**： 需要进行一些配置拦截器才会生效。配置方法是：

```java
@Configuration
public class InterceptorConfigure implements WebMvcConfigurer {

    public void addInterceptors(InterceptorRegistry registry){
        registry.addInterceptor(new MineTestInterceptor())
                .addPathPatterns("/test/**")//生效路径
                .excludePathPatterns("/login")
                .excludePathPatterns("/loginPost");
    }
}
```

## @ModelAttribute

这里说的Model就是MVC里的那个M。SpringMVC会生成这个Model，并且Controller可以是用Model model来作为方法参数。

先给一个@ModelAttribute的使用示例：

```java
@RestController
public class TestInterceptorController {

    @ModelAttribute("interceptorAdd")
    public String getInterceptorAdd(HttpServletRequest request){
        return (String) request.getAttribute("interceptorAdd");
    }

    @RequestMapping("/test/interceptor")
    public String test(@ModelAttribute("interceptorAdd")String interceptorAdd){
        return interceptorAdd;
    }
}
```

被@ModelAttribute注解的方法，会在Controller的任何@RequestMapping方法执行前被调用，并设置Model的属性。在这里就是设置model的interceptorAdd属性。

在@RequestMapping方法中，可以使用该属性。

**使用场景**：结合拦截器和@ModelAttribute可以方便在Controller方法前设置一些需要用到的属性。


## springboot设置ssl


```
keytool -genkey -alias myhostname -storetype PKCS12 -keyalg RSA -keysize 2048 -keystore keystore.p12
# 输入密码123456，其他直接按enter
```

创建名为keystore.p12的密钥库，并将它移动到main/resources下。

application.properties如下

server.port= 8443
server.ssl.key-store= classpath:keystore.p12
server.ssl.key-store-password= 123456
server.ssl.keyStoreType= PKCS12
server.ssl.keyAlias= myhostname

## 上传文件

[参见](https://blog.csdn.net/gnail_oug/article/details/80324120)

Controller:

```java
@Controller
@CommonsLog
public class UploadController {

    @GetMapping("/")
    public String upload() {
        return "upload";
    }

    @PostMapping("/uploadfile")
    @ResponseBody
    public String upload(@RequestParam("file") MultipartFile file) {
        if (file.isEmpty()) {
            return "上传失败，请选择文件";
        }

        String fileName = file.getOriginalFilename();

        String userHome=System.getProperty("user.home");
        String parentDirPath =String.format( "%s/upload/",userHome);
        File parentDir = new File(parentDirPath);
        if (!parentDir.exists()) {
            parentDir.mkdirs();
        }

        String filePath = parentDirPath + fileName;
        File target = new File(filePath);
        String absolutePath = target.getAbsolutePath();
        try {
            //复制文件，如果存在则覆盖
            Files.copy(file.getInputStream(), Paths.get(absolutePath),REPLACE_EXISTING);
            String msg=String.format("success: to %s",absolutePath);
            log.info(msg);
            return msg;
        } catch (IOException e) {
            log.error(e.toString(), e);
            return e.toString();
        }
    }
}
```

upload.html:

```html
<div style="line-height: 3em;width: 50%;font-family: 'Microsoft YaHei UI'">
    <form  method="post" action="/uploadfile" enctype="multipart/form-data">
        <input style="margin: auto;width: 100%;font-size: 1.5rem" type="file" name="file"><br>
        <input style="margin: auto;font-size: 1.5rem" type="submit" value="确定">
    </form>
</div>
```
