---
title: "Macos安装Libuv"
date: 2020-11-13T23:33:14+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```
# macos include path
/Library/Developer/CommandLineTools/SDKs/MacOSX10.15.sdk/usr/include/pthread.h
# cmakelist
target_link_libraries(untitled /usr/local/lib/libuv.dylib)


brew install libuv
ln -fs /usr/local/include/uv.h /Library/Developer/CommandLineTools/SDKs/MacOSX10.15.sdk/usr/include/uv.h
ln -fs /usr/local/include/uv /Library/Developer/CommandLineTools/SDKs/MacOSX10.15.sdk/usr/include/uv
```