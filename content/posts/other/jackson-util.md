---
title: "Jackson Util"
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

    public static <T> T fromJson(String json, TypeReference valueTypeRef) throws IOException {
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
        ImmutableMap map = ImmutableMap.of("a", "b", "c", "d");
        String s = JsonUtil.toJson(map);
        System.out.println(s);
        Object o = JsonUtil.fromJson(s, new TypeReference<Map>() {
        });
        System.out.println(o);
    }
}
```