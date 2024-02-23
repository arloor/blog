---
title: "Elasticsearch简单入门"
date: 2020-01-07T19:45:16+08:00
draft: false
categories: [ "undefined"]
tags: ["elasticsearch"]
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

一开始下载tar.gz然后手动起的，一执行报个错说不能用root用户启动，索性直接用rpm安装，帮你把所有事情做好，包括设置systemd服务，这样很爽
<!--more-->

```bash
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.6.2.rpm
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.6.2.rpm.sha512
shasum -a 512 -c elasticsearch-6.6.2.rpm.sha512 
sudo rpm --install elasticsearch-6.6.2.rpm
```

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


## 简单操作

### 新建索引

以下操作在`elasticsearch-head`操作

```
put /users

{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "user": {
      "properties": {
        "name": {
          "type": "text"
        }
      }
    }
  }
}
```

- index_name只能是小写，且不能出现一些特殊字符
- `number_of_replicas`副本数量在这里设置成0.因为是单节点的es，设置大于0的副本数不起作用，且在head中会看到`unassigned`。

### 增加document

```
PUT users/user/1
{
  "name":"刘港欢"
}
```

## ES领域特定查询语言

- json格式
- 可以看做是一个抽象语法树，包含两种query语句
  - 叶query语句——查询特定field的指定value{match、term、range}
  - 组合query语句。wrap other leaf or compound queries。

> 查询语句在query上下文和filter上下文中的表现不同


### query上下文

回答“该文档与查询有多相关”(how much)的问题

当查询语句被传递给“query”参数时生效

会计算相关度打分`_score`

### filter上下文

回答"是不是与该查询相关"(is or no)的问题，用于过滤。

为了提高性能，ES把常用的filters自动缓存。

In effect whenever a query clause is passed to a filter parameter,

1. `filter` or `must_not` parameters in the bool query,
2. the `filter` parameter in the `constant_score` query
3. the `filter` aggregation.

```json
{
  "query": { //query上下文
    "bool": { //bool查询下可以有must/should/filter/must_not
      "must": [
        { "match": { "title":   "Search"        }}, 
        { "match": { "content": "Elasticsearch" }}  
      ],
      "filter": [ //filter上下文
        { "term":  { "status": "published" }}, 
        { "range": { "publish_date": { "gte": "2015-01-01" }}} 
      ]
    }
  }
}
```

### 三种查询方式

```
http://<server>/_search
查询所有index、type
http://<server>/<index_name(s)>/_search
查询多个index,逗号分隔
http://<server>/<index_name(s)>/<type_name(s)>/_search
查询多个index,多个type，逗号分隔
```
index_name可以使用别名

### match_all查询

返回所有的文档

```
curl -X GET "localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": {
        "match_all": {}
    }
}
'
```

### full text queries

1. [match](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/query-dsl-match-query.html#query-dsl-match-query)
2. [match_phrase](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/query-dsl-match-query-phrase.html)
3. [match_phrase_prefix](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/query-dsl-match-query-phrase-prefix.html)
4. [multi_match](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/query-dsl-multi-match-query.html)
5. [common](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/query-dsl-common-terms-query.html)
6. [query_string](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/query-dsl-query-string-query.html)

### Term Lavel Queries

[term-level-queries.html](https://esdoc.arloor.com/guide/en/elasticsearch/reference/6.6/term-level-queries.html)
