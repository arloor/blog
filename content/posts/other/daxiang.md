---
title: "草稿"
date: 2020-08-10T14:33:03+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```
<!-- https://mvnrepository.com/artifact/org.thymeleaf/thymeleaf -->
        <dependency>
            <groupId>org.thymeleaf</groupId>
            <artifactId>thymeleaf</artifactId>
            <version>3.0.11.RELEASE</version>
        </dependency>
        <!-- https://mvnrepository.com/artifact/org.apache.commons/commons-lang3 -->
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-lang3</artifactId>
            <version>3.11</version>
        </dependency>

        <dependency>
            <groupId>com.sankuai.xm</groupId>
            <artifactId>xm-pub-api-client</artifactId>
            <version>1.5.6.1</version>
        </dependency>

        <dependency>
            <groupId>com.sankuai.xm</groupId>
            <artifactId>xm-pub-api-sdk</artifactId>
            <version>2.1.2</version>
        </dependency>
                <dependency>
            <groupId>com.sankuai.it.mail</groupId>
            <artifactId>mail-sdk</artifactId>
            <version>1.1.21</version>
        </dependency>
```

```
package com.sankuai.pcm.console.service.util;

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

```
package com.sankuai.pcm.console.service.thrift;

import com.meituan.service.mobile.mtthrift.proxy.ThriftClientProxy;
import com.sankuai.xm.pubapi.thrift.PushMessageServiceI;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Service;

@Service
public class DxService {

    @Bean
    public PushMessageServiceI.Iface pushMessageServiceI() throws Exception {
        return createClientProxy(PushMessageServiceI.class);
    }

    protected  <T> T createClientProxy(Class serviceInterface) throws Exception{
        ThriftClientProxy proxy = new ThriftClientProxy();
        proxy.setAppKey("com.sankuai.pcm.console"); //应用放appKey
        proxy.setRemoteAppkey("com.sankuai.xm.pubapi");// issue 引擎的appKey
        proxy.setServiceInterface(serviceInterface);
        proxy.setTimeout(60000);
        proxy.setFilterByServiceName(true);
        proxy.setNettyIO(true);

        proxy.setMaxResponseMessageBytes(Integer.MAX_VALUE);
        proxy.afterPropertiesSet();
        return (T) proxy.getObject();
    }
}
```

```
package com.sankuai.pcm.console.service.thrift;

import com.google.common.collect.Lists;
import com.meituan.ones.issue.engine.dto.field.FieldDTO;
import com.sankuai.xm.pubapi.thrift.PushMessageServiceI;
import com.sankuai.xm.pubapi.thrift.PushType;
import com.sankuai.xm.pubapi.thrift.PusherInfo;
import org.apache.thrift.TException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

@Service
@Configuration
public class DxServiceInvoker {
    @Value("${dx.key}")
    String dxKey;

    @Value("${dx.token}")
    String dxToken;

    @Value("${dx.pubId}")
    String dxPubId;

    @Bean
    public PusherInfo pusherInfo(){
        PusherInfo pusher = new PusherInfo();
        pusher.setAppkey(dxKey)
                .setToken(dxToken)
                .setFromUid(Long.parseLong(dxPubId))
                .setChannelId((short) 0);
        return pusher;
    }

    @Autowired
    PusherInfo pusherInfo;

    @Resource
    PushMessageServiceI.Iface pushMessageServiceI;

    public String push() {
        try {
            String s = pushMessageServiceI.pushTextMessage(System.currentTimeMillis(),"aaaa", Lists.newArrayList("liuganghuan"),pusherInfo);
            return s;
        } catch (TException e) {
            e.printStackTrace();
        }
        return null;
    }
}
```

```
package com.sankuai.pcm.console.service;

import com.dianping.cat.Cat;
import com.dianping.cat.message.Transaction;
import com.sankuai.pcm.console.util.JsonUtil;
import com.sankuai.pcm.console.util.RenderUtil;
import com.sankuai.xm.pub.push.Pusher;
import com.sankuai.xm.pub.push.PusherBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Future;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.RejectedExecutionHandler;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

@Service
@Configuration
@Slf4j
public class DxPusher {
    private static final String CAT_TYPE = "daxiang";

    @Value("${dx.key}")
    private String dxKey;

    @Value("${dx.token}")
    private String dxToken;

    @Value("${dx.pubId}")
    private String dxPubId;

    @Value("${dx.url}")
    private String dxUrl;

    private final ExecutorService pool = new ThreadPoolExecutor(4, 4, 60, TimeUnit.MINUTES, new LinkedBlockingDeque<>(100), new RejectedExecutionHandler() {
        @Override
        public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
            Cat.logEvent(CAT_TYPE, "push_task_reject");
        }
    });


    @Bean
    public Pusher pusher() {
        return PusherBuilder.defaultBuilder()
                .withAppkey(dxKey)
                .withApptoken(dxToken)
                .withTargetUrl(dxUrl)
                .withFromUid(Long.parseLong(dxPubId)).build();
    }

    @Autowired
    private Pusher pusher;

    public void push(String template, Map<String, Object> params, String... receivers) {
        CompletableFuture<List> future = new CompletableFuture<>();
        future.thenAccept((failUids) -> {
            log.info("push fail uids：{}", failUids);
        });


        pool.submit(() -> {
            Transaction transaction = Cat.newTransaction(CAT_TYPE, "push");
            try {
                String msg = RenderUtil.text(template, params);
                LinkedHashMap<String,Object> result = (LinkedHashMap) pusher.push(msg, receivers);
                Map data = Optional.ofNullable((Map) result.get("data")).orElseGet(LinkedHashMap::new);
                List<Long> failUids = (List<Long>) Optional.ofNullable(data.get("failUids")).orElseGet(ArrayList::new);
                future.complete(failUids);
            } catch (Throwable e) {
                transaction.setStatus(e);
                Cat.logError(e);
            }
            transaction.complete();
        });
    }
}
```

```
package com.sankuai.pcm.console.controller;

import com.google.common.collect.ImmutableMap;
import com.sankuai.it.mail.sdk.service.MailThriftService;
import com.sankuai.it.mail.sdk.structs.MailStructDTO;
import com.sankuai.it.mail.sdk.structs.SendMailResultDTO;
import com.sankuai.pcm.console.domain.DemoUser;
import com.sankuai.pcm.console.service.DxPusher;
import com.sankuai.pcm.console.util.RenderUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.Date;

@RestController
@Slf4j
public class TestController {
    @Autowired
    DxPusher dxPusher;
    @Autowired
    private MailThriftService mailThriftService;

//    public void testClientThrift() throws Exception {
//        MailStructDTO mailModel = new MailStructDTO();
//        mailModel.setUseHtml(true);
//        mailModel.setFromName("发件人名称");
//        mailModel.setSendMail("ning.test1@mtdp.com"); //发件邮箱
//        mailModel.setBody("<html><head></head><body>我是测试邮件</body></html>");
//        mailModel.setTo(Arrays.asList("282923101@qq.com")); //收件人
////        mailModel.setCc(Arrays.asList("weixiangling@meituan.com"));  //抄送
////        mailModel.setBcc(Arrays.asList("zhuoyue02@meituan.com"));  //密送
//        mailModel.setSubject("邮件主题");
////        mailModel.setAttachments(getAttachments()); //带附件发送
//
//        SendMailResultDTO resultModel = mailThriftService.sendMail(mailModel);
//        System.out.println(resultModel);
//    }

    @RequestMapping("/")
    public String test() throws Exception {
//        this.testClientThrift();
        String template = "Case状态变更:\nCaseId:[(${caseId})]\n链接：[PCM|[(${url})]]\n时间：[[${date}]]";
        ImmutableMap<String, Object> params = ImmutableMap.of("caseId", "11", "url", "https://casesys.sankuai.com/#/caseList","date",new Date());
        dxPusher.push(template,params, "liuganghuan");
        return "push";
    }
}
```

```
package com.sankuai.pcm.console;

import com.google.common.collect.ImmutableMap;
import com.sankuai.it.mail.sdk.service.MailThriftService;
import com.sankuai.it.mail.sdk.structs.AttachmentDTO;
import com.sankuai.it.mail.sdk.structs.MailStructDTO;
import com.sankuai.it.mail.sdk.structs.SendMailResultDTO;
import com.sankuai.it.mail.sdk.utils.AttachmentUtil;
import com.sankuai.pcm.console.util.RenderUtil;
import junit.framework.TestCase;
import lombok.extern.slf4j.Slf4j;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;

@SpringBootTest
@Slf4j
@RunWith(SpringRunner.class)
public class ClientTests extends TestCase {
    @Autowired
    private MailThriftService mailThriftService;

    @Test
    public void testClientThrift() throws Exception{
        MailStructDTO mailModel = new MailStructDTO();
        mailModel.setUseHtml(true);
        mailModel.setFromName("发件人名称");
        mailModel.setSendMail("ning.test1@mtdp.com"); //发件邮箱
        mailModel.setBody("<html><head></head><body>我是测试邮件</body></html>");
        mailModel.setTo(Arrays.asList("1293181335@qq.com")); //收件人
//        mailModel.setCc(Arrays.asList("weixiangling@meituan.com"));  //抄送
//        mailModel.setBcc(Arrays.asList("zhuoyue02@meituan.com"));  //密送
        mailModel.setSubject("测试邮件");
        String template = "<h1>Case状态变更:</h1><p>CaseId:<span th:text=\"${caseId}\"></span></p><p>链接<a th:href=\"${url}\">bb</a></p>";
        ImmutableMap<String, Object> params = ImmutableMap.of("caseId", "11", "url", "https://casesys.sankuai.com/#/caseList","date",new Date());
        String body = RenderUtil.html(template,params);
        mailModel.setBody(body);
//        mailModel.setAttachments(getAttachments()); //带附件发送

        SendMailResultDTO resultModel = mailThriftService.sendMail(mailModel);
        System.out.println(resultModel);
    }


    private List<AttachmentDTO> getAttachments() throws IOException {
        List<AttachmentDTO> attachmentDTOS = new ArrayList<>();
        AttachmentDTO attachmentDTO = new AttachmentDTO();
        String path = "/Desktop/others/resume.pdf";
        File file = new File(path);
        String base64Str = AttachmentUtil.base64Encode(file);
        String contentType = "application/pdf;charset=utf-8"; //需设置标准的content-Type类型，参考http://tool.oschina.net/commons
        attachmentDTO.setFilename("resume.pdf");
        attachmentDTO.setContentType(contentType);
        attachmentDTO.setBase64Bytes(base64Str);
        attachmentDTOS.add(attachmentDTO);
        return attachmentDTOS;
    }
}
```

```
#线下公众号配置
#dx.key=258L0q1011340002
#dx.token=a5e5cdee674097bbe5c8c2f906fef2f8
#dx.pubId=137439016463
#dx.url=http://api.xm.test.sankuai.com/api/pub/push

spring.flyway.enabled=false

#dx.key=258L0q1011340002
#dx.token=a5e5cdee674097bbe5c8c2f906fef2f8
#dx.pubId=137439016463

#线上公众号配置
dx.key=05220011G34980e0
dx.token=df8ef27b758ba78b9cd94ca7c00a20c7
dx.pubId=137456346688
dx.url=https://xmapi.vip.sankuai.com/api/pub/push
```

```
package com.sankuai.pcm.console.configuration;
 
import org.springframework.beans.factory.config.ConfigurableBeanFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.ImportResource;
import org.springframework.context.annotation.Scope;
 
@Configuration
@ImportResource("classpath:mailsdk.xml")
public class MTMailConfig {
 
    @Bean
    @Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)
    public String localAppKey(){
        return "5aceaf26df";//开放平台申请的appkey
    }
 
    @Bean
    @Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)
    public String mailServiceSecret(){
        return "425fce0b12364b8cbf6ff0bfb239fc5d";//开放平台申请的secret
    }
}
```

```
package com.sankuai.pcm.module.notice;

import com.google.common.collect.Lists;
import com.sankuai.pcm.module.notice.NoticeModuleImpl;
import com.sankuai.pcm.module.notice.event.DeliveInEvent;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.thymeleaf.ThymeleafAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;

import javax.annotation.Resource;

@SpringBootTest
// 因为引入了Thymeleaf的包，但是不需要使用thymeleaf，所以把这个autoconfiguration禁用
@SpringBootApplication(
        scanBasePackages = "com.sankuai.pcm",
        exclude = {ThymeleafAutoConfiguration.class}
)
@RunWith(SpringRunner.class)
public class NoticeTest {

    @Resource
    NoticeModuleImpl noticeModule;

    @Test
    public void NoticeTest() {
        DeliveInEvent deliveInEvent = new DeliveInEvent("刘港欢", "liuganghuan", "PCM做的真好", "基础研发平台", "ch处理中", "youwenti", "https://arloor.com");
        noticeModule.noticeByDaxiang(deliveInEvent, Lists.newArrayList("liuganghuan"));
    }
}
```