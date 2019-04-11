---
title: "Go语言的内存池实现"
date: 2019-04-11T20:03:30+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
---

今天发现一个问题，在代理的网速达到50M时，cpu占用变得非常高，原因想想很简单，没有复用`[]byte`，每次需要`[]byte`都去make新的，导致内存回收频繁。这一篇就要来想想怎么去实现一个`[]byte`的内存池。其中会涉及到一些go语言基础的内容，下面开始
<!--more-->