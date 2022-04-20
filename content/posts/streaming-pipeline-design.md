---
title: "pipeline模式的一种实现"
date: 2022-04-20T11:42:56+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

一种流式编程的代码
<!--more-->

![](/img/processTree.png)

## 使用示例

```java
ProcessTree<ThriftSpanList> processTree = new ProcessTree<>();

final Node<ThriftSpanList, Set<DependencyCell>> firstNode = processTree.setFirstNode(sceneProcessor);
final Node<Set<DependencyCell>, Void> sceneDependencyNode = firstNode.addNext(sceneDependencyProcessor);

processTree.handle(list);
```

## 具体代码

```java
public class ProcessTree<INPUT> {
    private Way<INPUT> entryWay;

    public <OUTPUT> Node<INPUT, OUTPUT> setFirstNode(NodeProcessor<INPUT, OUTPUT> firstNodeProcessor) {
        final Node<INPUT, OUTPUT> firstNode = new Node<>(firstNodeProcessor);
        this.entryWay = new Way<>(firstNode);
        return firstNode;
    }

    public void handle(INPUT input) {
        if (entryWay != null) {
            entryWay.consume(input);
        }
    }
}
```

```java
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

public final class Node<INPUT, OUTPUT> {
    NodeProcessor<INPUT, OUTPUT> nodeProcessor;
    List<Way<OUTPUT>> ways = new CopyOnWriteArrayList<>();

    public Node(NodeProcessor<INPUT, OUTPUT> nodeProcessor) {
        this.nodeProcessor = nodeProcessor;
    }


    public void process(INPUT input) {
        final OUTPUT output = nodeProcessor.doProcess(input);
        for (Way<OUTPUT> way : ways) {
            way.consume(output);
        }
    }

    public <NEW_OUTPUT> Node<OUTPUT, NEW_OUTPUT> addNext(NodeProcessor<OUTPUT, NEW_OUTPUT> nextNodeProcessor) {
        final Node<OUTPUT, NEW_OUTPUT> nextNode = new Node<>(nextNodeProcessor);
        ways.add(new Way<>(nextNode));
        return nextNode;
    }

    public <NEW_OUTPUT> Node<OUTPUT, NEW_OUTPUT> addAsyncNext(NodeProcessor<OUTPUT, NEW_OUTPUT> nextNodeProcessor,
                                                              int threadNum, int queueSize, String tag) {
        final Node<OUTPUT, NEW_OUTPUT> nextNode = new Node<>(nextNodeProcessor);
        ways.add(new AsyncWay<>(nextNode, threadNum, queueSize, tag));
        return nextNode;
    }
}
```

```java
public interface NodeProcessor<INPUT, OUTPUT> {
    OUTPUT doProcess(INPUT input);
}
```

```java
public class Way<INPUT> {
    private Node<INPUT, ?> destination;

    public Node<INPUT, ?> getDestination() {
        return destination;
    }

    public Way(Node<INPUT, ?> destination) {
        this.destination = destination;
    }

    public void consume(INPUT input) {
        if (input != null) {
            destination.process(input);
        }
    }
}
```

```java
import com.google.common.collect.ImmutableMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.concurrent.ThreadPoolExecutor;

public class AsyncWay<INPUT> extends Way<INPUT> {
    private static final Logger LOGGER = LoggerFactory.getLogger(AsyncWay.class);

    private ThreadPoolExecutor executorService;

    public AsyncWay(Node<INPUT, ?> destination, int threadNum, int queueSize, String tag) {
        super(destination);
        executorService = ThreadPoolUtil.create(threadNum, threadNum, 1, queueSize, tag);
    }

    @Override
    public void consume(INPUT input) {
        if (input != null)
            executorService.execute(() -> {
                getDestination().process(input);
            });
    }
}
```

## 局限性

相比java的stream，只支持map（一转一），不支持flatMap（一转多）

## 参考文档

- [链路追踪 SkyWalking 源码分析 —— Collector Streaming Computing 流式处理（一）](https://cloud.tencent.com/developer/article/1440508)