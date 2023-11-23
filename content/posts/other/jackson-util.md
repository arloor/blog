---
title: "JsonUtil代码(基于Jackson)"
date: 2020-08-06T17:17:42+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

Jackson Util:
<!--more-->

```
        <dependency>
            <groupId>com.google.guava</groupId>
            <artifactId>guava</artifactId>
            <version>29.0-jre</version>
        </dependency>
        <!--Jackson required包-->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-core</artifactId>
            <version>2.11.2</version>
        </dependency>
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>2.11.2</version>
        </dependency>
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-annotations</artifactId>
            <version>2.11.2</version>
        </dependency>
```

```java
import com.fasterxml.jackson.annotation.JsonInclude.Include;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.common.collect.ImmutableMap;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.Map;

public class JsonUtil {
    private static ObjectMapper MAPPER;

    private JsonUtil() {
    }

    public static <T> T fromJson(String json, Class<T> clazz) throws IOException {
        return MAPPER.readValue(json, clazz);
    }

    public static <T> T fromJson(String json, TypeReference<T> valueTypeRef) throws IOException {
        return MAPPER.readValue(json, valueTypeRef);
    }

    public static <T> List<T> fromJson(String json, Class collection, Class<T> clazz) throws IOException {
        return (List) MAPPER.readValue(json, getCollectionType(MAPPER, collection, clazz));
    }

    public static <T> String toJson(T src) throws IOException {
        return src instanceof String ? (String) src : MAPPER.writeValueAsString(src);
    }

    public static <T> String toJson(T src, Include inclusion) throws IOException {
        if (src instanceof String) {
            return (String) src;
        } else {
            ObjectMapper customMapper = generateMapper(inclusion);
            return customMapper.writeValueAsString(src);
        }
    }

    public static <T> String toJson(T src, ObjectMapper mapper) throws IOException {
        if (null != mapper) {
            return src instanceof String ? (String) src : mapper.writeValueAsString(src);
        } else {
            return null;
        }
    }

    private static ObjectMapper generateMapper(Include include) {
        ObjectMapper customMapper = new ObjectMapper();
        customMapper.setSerializationInclusion(include);
        customMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        customMapper.configure(DeserializationFeature.FAIL_ON_NUMBERS_FOR_ENUMS, true);
        customMapper.setDateFormat(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss"));
        return customMapper;
    }

    private static JavaType getCollectionType(ObjectMapper mapper, Class<?> collectionClass, Class<?>... elementClasses) {
        return mapper.getTypeFactory().constructParametricType(collectionClass, elementClasses);
    }

    static {
        MAPPER = generateMapper(Include.ALWAYS);
    }

    public static void main(String[] args) throws IOException {
        ImmutableMap map = ImmutableMap.of("a", Some.A, "b", Some.B);
        String s = JsonUtil.toJson(map);
        System.out.println(s);
        Map<String,Some> result = JsonUtil.fromJson(s, new TypeReference<Map<String,Some>>() {
        });
        System.out.println(result);
        System.out.println("Class: "+result.get("a").getClass().getName());
    }

    public enum Some {
        A("a", 1), B("b", 2);

        private String name;
        private int id;

        Some(String name, int id) {
            this.name = name;
            this.id = id;
        }

        public String getName() {
            return name;
        }

        public int getId() {
            return id;
        }
    }
}
```

输出：

```
{"a":"A","b":"B"}
{a=A, b=B}
Class: JsonUtil$Some
```

反序列化的时候，推荐使用`TypeReference<T>`，这样可以保留范型信息，上面的例子能体现。

```
Map<String,Some> result = JsonUtil.fromJson(s, new TypeReference<Map<String,Some>>({});
```