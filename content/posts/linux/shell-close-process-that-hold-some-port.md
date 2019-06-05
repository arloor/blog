---
title: "Shell关闭占用某端口的应用"
author: "刘港欢"
date: 2018-12-30
categories: [ "Shell"]
tags: ["linux"]
weight: 10
---

现在在自己的centos7上跑了应用，有个需求：重启该应用。实现如下 <!--more-->

# shell关闭占用某端口应用，并重启

```
#! /bin/bash
#set path to support crontab
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/go/bin:/root/bin
# shutdown the pre process
name=$(lsof -i:8080|tail -1|awk '$1!=""{print $1}')
if [ -z $name ]
then
        echo "No process can be used to killed!"
else
        id=$(lsof -i:8080|tail -1|awk '$1!=""{print $2}')
        kill -9 $id
        echo "Process name=$name($id) kill!"
fi
(./proxygo &>> proxy_$(date '+%Y%m%d%H%M%S').log &)
echo 成功启动@$(date)
exit 0

```

`lsof -i:8080|tail -1|awk '$1!=""{print $2}'`列出占用8080端口的应用；只打印一行；如果那一行第一个字段不为空，打印第二个字段（pid）。最后pid被赋值给了name

## shell关闭某进程

```shell
#! /bin/bash
pname=proxy
#set path to support crontab
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/go/bin:/root/bin
# shutdown the pre process
name=$(ps -aux|grep $pname |grep -v "grep"|awk '$1!=""{print $11}')
if [ -z $name ]
then
        echo "No process can be used to killed!"
else
        id=$(ps -aux|grep $pname|grep -v "grep"|awk '$1!=""{print $2}')
        kill -9 $id
        echo "Process name=$name($id) kill!"
fi
exit 0
```

## 知识点

1. name=$(表达式) 将表达式产生的值赋给name
2. tail -n somefile 打印最后n行
3. awk '$1!=""{print $2}'  第一个词不为空，则打印第二个词
4. if [ -z $name ]  字符串不为空
