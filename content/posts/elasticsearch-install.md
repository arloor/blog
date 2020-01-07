---
title: "Elasticsearch Install"
date: 2020-01-07T19:45:16+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 环境

- centos 8 1C2G
- jdk8

## 安装

```shell
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.6.2.rpm
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.6.2.rpm.sha512
shasum -a 512 -c elasticsearch-6.6.2.rpm.sha512 
sudo rpm --install elasticsearch-6.6.2.rpm
```

一开始下载tar.gz然后手动起的，一执行报个错说不能用root用户启动，索性直接用rpm安装，帮你把所有事情做好，包括设置systemd服务，这样很爽

贴一下官方文档:[https://www.elastic.co/guide/en/elasticsearch/reference/6.6/rpm.html](https://www.elastic.co/guide/en/elasticsearch/reference/6.6/rpm.html)

使用rpm安装后的es相关文件布局如下:

|Type|Description|Default Location|Setting|
|----|------|------|-----|
| home|Elasticsearch home directory or $ES_HOME | /usr/share/elasticsearch| |
|bin|Binary scripts including elasticsearch to start a node and elasticsearch-plugin to install plugins|/usr/share/elasticsearch/bin | |
|conf|Configuration files including elasticsearch.yml|/etc/elasticsearch|ES_PATH_CONF|
|conf|Environment variables including heap size, file descriptors.|/etc/sysconfig/elasticsearch| |
|data|The location of the data files of each index / shard allocated on the node. Can hold multiple locations.|/var/lib/elasticsearch|path.data|
|logs|Log files location.|/var/log/elasticsearch|path.logs|
|plugins|Plugin files location. Each plugin will be contained in a subdirectory.|/usr/share/elasticsearch/plugins| |
|repo|Shared file system repository locations. Can hold multiple locations. A file system repository can be placed in to any subdirectory of any directory specified here.|Not configured|path.repo|

## 配置

```
# 监听所有网卡
sed -i "s/network.host:.*/network.host: 0.0.0.0/g" /etc/elasticsearch/elasticsearch.yml
# 修改名字
sed -i "s/node.name:.*/node.name: TEST/g" /etc/elasticsearch/elasticsearch.yml
# 重启服务
service elasticsearch restart
```

> 先不设置密码认证了，大胆用


## Elasticsearch-Head使用

这是一个可视化监控es的web工具

直接使用chrome扩展：[https://chrome.google.com/webstore/detail/elasticsearch-head/ffmkiejjmecolpfloofpjologoblkegm/](https://chrome.google.com/webstore/detail/elasticsearch-head/ffmkiejjmecolpfloofpjologoblkegm/)

## 官方文档

[https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/index.html](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/index.html)

或[https://www.elastic.co/guide/en/elasticsearch/reference/6.6/index.html](https://www.elastic.co/guide/en/elasticsearch/reference/6.6/index.html)




