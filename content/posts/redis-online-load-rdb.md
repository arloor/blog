---
title: "实现redis运行时加载rdb文件"
date: 2019-09-04T23:02:03+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

对redis比较了解的人应该知道redis提供rdb持久化机制。rdb文件其实就是redis在某一时间的一个快照，redis在重启时，可以加载这个快照，从而恢复状态。然而redis没有暴露加载rdb这个接口，因此没有办法在运行时手动地导入rdb快照。

其实，在阅读replicate.c后发现，redis的从节点在接收了rdb全量同步文件后，直接调用了`rdbload`函数——这就意味着：运行时动态加载rdb文件完全可行！毕竟redis自己也是这么做的。但是redis不肯暴露这个接口给用户。

我们上一篇文章要进行redis异地数据中心同步，同样需要加载rdb文件，如果只能重启redis来加载rdb文件，多少有点不舒服。因此探讨一下redis动态加载rdb文件的实现总归有好处的，事实证明我做到了。
<!--more-->

## 实现

参考了修改redis-3.0.7源码以增加该功能的[博客](https://blog.csdn.net/laowxl/article/details/68924510)。

我自己修改了redis-4.0.1的部分代码，暴露出原版redis不想暴露的接口。修改后的redis项目在[redis-4.0.1-feature-online-loadrdb](https://github.com/arloor/redis-4.0.1-feature-online-loadrdb)。所有重要的修改都在[第二次提交](https://github.com/arloor/redis-4.0.1-feature-online-loadrdb/commit/a8c58feb26861106a38b8293180906df9b4a9797)。请一定要访问这个链接，git diff能够直观地展示我在redis源码上增加了哪些东西，所以我就不贴代码了。

效果是redis-cli中可以使用`loadrdb <dumpfile>`命令来热加载rdb文件。该命令的tcp报文是这样的：`loadrdb filename\r\n`。效果展示请看“测试”章节

## 测试

1. clone上面的项目，进入项目文件夹
2. 执行 `make MALLOC=libc`，进行编译
3. 执行`src/redis-server`以默认配置（rdb开启）启动redis
4. 启动另一个bash，执行以下命令：
```shell
src/redis-cli set a test       #设置a
src/redis-cli BGSAVE           #进行rdb持久化
src/redis-cli get a            #获取a，此时为test
sleep 10                       #睡10秒，等待rdb持久化完成
mv -f dump.rdb dump            #移动该dump.rdb文件到新文件dump
src/redis-cli flushall         #删除所有key
src/redis-cli get a            #此时a为nil
src/redis-cli loadrdb dump     #调用loadrdb指令热加载dump文件
# 等同于 (printf "loadrdb dump\r\n";sleep 1)|nc localhost 6379 
src/redis-cli get a            #此时a为test
```

以上测试先写了一个a，然后调用BGSAVE导出rdb文件，然后flushall删除所有key，然后使用`loadrdb`动态导入之前的rdb文件，最后检查a的value。结果能拿到之前设置的a的值，说明`loadrdb`工作正常！

尚未解决的问题：loadrdb指定的文件不能是redis.conf指定的rdbfilename，尚未增加该校验。如果是同一文件，则我们在loadrdb该文件，而同时redis可能正在往这个文件写rdb，这会导致redis崩溃。——以后会增加这个校验的，要查一下c语言字符串比较。。。我忘记了