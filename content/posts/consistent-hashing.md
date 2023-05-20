---
title: "一致性hash"
date: 2021-08-23T11:02:16+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


给出一致性hash的代码
<!--more-->

```java
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

import lombok.extern.slf4j.Slf4j;

/**
 * 带虚拟节点的一致性Hash算法
 */
@Slf4j
public class ShardHelper {
    private ConcurrentSkipListMap<String, Set<Integer>> nodeHash = new ConcurrentSkipListMap<>();
    private SortedMap<Integer, String> hashNode = new ConcurrentSkipListMap<>();
    private static final int VIRTUAL_NODES = 32;


    public synchronized void addRealNode(String name) {
        for (int i = 0; i < VIRTUAL_NODES; i++) {
            String virtualNodeName = name + "&&VN" + i;
            int hash = getHash(virtualNodeName);
//            log.info("{} {}", virtualNodeName, hash);
            hashNode.put(hash, name);
            nodeHash.computeIfAbsent(name, k -> ConcurrentHashMap.newKeySet())
                    .add(hash);
        }
    }

    public synchronized void removeRealNode(String name) {
        Set<Integer> hashes = nodeHash.remove(name);
        for (Integer hash : hashes) {
            hashNode.remove(hash);
        }
    }

    //使用FNV1_32_HASH算法计算服务器的Hash值,这里不使用重写hashCode的方法，最终效果没区别
    private int getHash(String str) {
//        return Math.abs(str.hashCode());
        final int p = 16777619;
        int hash = (int) 2166136261L;
        for (int i = 0; i < str.length(); i++)
            hash = (hash ^ str.charAt(i)) * p;
        hash += hash << 13;
        hash ^= hash >> 7;
        hash += hash << 3;
        hash ^= hash >> 17;
        hash += hash << 5;

        // 如果算出来的值为负数则取其绝对值
        if (hash < 0)
            hash = Math.abs(hash);
        return hash;
    }

    //得到应当路由到的结点
    public String getServer(String key) {
        //得到该key的hash值
        int hash = getHash(key);
        // 得到大于该Hash值的所有Map
        SortedMap<Integer, String> subMap = hashNode.tailMap(hash);
        String nodeName;
        if (subMap.isEmpty()) {
            //如果没有比该key的hash值大的，则从第一个node开始
            Integer i = hashNode.firstKey();
            //返回对应的服务器
            nodeName = hashNode.get(i);
        } else {
            //第一个Key就是顺时针过去离node最近的那个结点
            Integer i = subMap.firstKey();
            //返回对应的服务器
            nodeName = subMap.get(i);
        }
        return nodeName;
    }

    public static void main(String[] args) {
        final ShardHelper shardHelper = new ShardHelper();
        IntStream.range(1,100).forEach(
                i->shardHelper.addRealNode(String.valueOf(i))
        );
        Map<String, AtomicInteger> counter=new HashMap<>();
        for (int i = 0; i < 1000000; i++) {
            final String server = shardHelper.getServer(String.valueOf(i));
            counter.computeIfAbsent(String.valueOf(server),k->new AtomicInteger(0))
                    .incrementAndGet();
        }
        System.out.println(counter);
    }
}
```