---
title: "Elasticsearch节点创建流程"
date: 2020-04-03T15:13:08+08:00
draft: true
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

首先，关于es启动流程的大体介绍[lanffy.github.io](https://lanffy.github.io/2019/04/09/ElasticSearch-Start-Up-Process)。在这片文章中，将会主要关注加载插件的部分。

org/elasticsearch/node/Node.java

SimilarityProviders.java

## es 评分模块

[https://www.elastic.co/guide/en/elasticsearch/reference/6.6/index-modules-similarity.html](https://www.elastic.co/guide/en/elasticsearch/reference/6.6/index-modules-similarity.html)

可以使用scripted similarity
```
PUT /index
{
  "settings": {
    "number_of_shards": 1,
    "similarity": {
      "scripted_tfidf": {
        "type": "scripted",
        "script": {
          "source": "double tf = Math.sqrt(doc.freq); double idf = Math.log((field.docCount+1.0)/(term.docFreq+1.0)) + 1.0; double norm = 1/Math.sqrt(doc.length); return query.boost * tf * idf * norm;"
        }
      }
    }
  },
  "mappings": {
    "_doc": {
      "properties": {
        "field": {
          "type": "text",
          "similarity": "scripted_tfidf"
        }
      }
    }
  }
}

PUT /index/_doc/1
{
  "field": "foo bar foo"
}

PUT /index/_doc/2
{
  "field": "bar baz"
}

POST /index/_refresh

GET /index/_search?explain=true
{
  "query": {
    "query_string": {
      "query": "foo^1.7",
      "default_field": "field"
    }
  }
}
```

参数: 

- doc.freq
- field.docCount
- term.docFreq
- doc.length