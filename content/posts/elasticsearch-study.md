---
title: "Elasticsearch调研"
date: 2020-04-03T15:13:08+08:00
draft: false
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

## 启动debug

es6.6.2需要使用jdk11启动。

```
git clone https://github.com/elastic/elasticsearch.git
git checkout v6.6.2
```

**将项目导入到idea**

1. 到项目根目录: ./gradlew idea
2. Idea create from existing source选择gradle，auto-import

要对项目做几处修改：下面直接复制git修改信息

```
Index: server/build.gradle
IDEA additional info:
Subsystem: com.intellij.openapi.diff.impl.patch.CharsetEP
<+>UTF-8
===================================================================
--- server/build.gradle	(revision 3bd3e59556628bb84c8d53b09b10c9ac8255e251)
+++ server/build.gradle	(date 1585882097224)
@@ -78,7 +78,7 @@
   compile "org.elasticsearch:elasticsearch-secure-sm:${version}"
   compile "org.elasticsearch:elasticsearch-x-content:${version}"
 
-  compileOnly project(':libs:plugin-classloader')
+  compile project(':libs:plugin-classloader')
   testRuntime project(':libs:plugin-classloader')
 
   // lucene
```

设置maven仓库为阿里云镜像
```
Index: build.gradle
IDEA additional info:
Subsystem: com.intellij.openapi.diff.impl.patch.CharsetEP
<+>UTF-8
===================================================================
--- build.gradle	(revision 3bd3e59556628bb84c8d53b09b10c9ac8255e251)
+++ build.gradle	(date 1585878050973)
@@ -48,6 +48,20 @@
   group = 'org.elasticsearch'
   version = VersionProperties.elasticsearch
   description = "Elasticsearch subproject ${project.path}"
+
+  // 增加下面部分
+  repositories {
+      google()
+      jcenter()
+      // maven库
+      def cn = "http://maven.aliyun.com/nexus/content/groups/public/"
+      def abroad = "http://central.maven.org/maven2/"
+      // 先从url中下载jar若没有找到，则在artifactUrls中寻找
+      maven {
+        url cn
+        artifactUrls abroad
+      }
+  }
 }
 
 apply plugin: 'nebula.info-scm'
```

（可选）设置该项目的gradle代理，加速访问

```
Index: gradle.properties
IDEA additional info:
Subsystem: com.intellij.openapi.diff.impl.patch.CharsetEP
<+>GBK
===================================================================
--- gradle.properties	(revision 3bd3e59556628bb84c8d53b09b10c9ac8255e251)
+++ gradle.properties	(date 1585878076127)
@@ -1,3 +1,8 @@
 org.gradle.daemon=true
 org.gradle.jvmargs=-Xmx2g
 options.forkOptions.memoryMaximumSize=2g
+systemProp.http.proxyHost=127.0.0.1
+systemProp.http.proxyPort=1080
+# systemProp.http.proxyUser=userid
+# systemProp.http.proxyPassword=password
+systemProp.http.nonProxyHosts=maven.aliyun.com|localhost
\ No newline at end of file
```

下载es6.6.2的release包[https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.6.2.zip](https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.6.2.zip)

解压到D:\elasticsearch-6.6.2


Idea项目的vm options

```
-Des.path.home=D:\elasticsearch-6.6.2
-Des.path.conf=D:\elasticsearch-6.6.2\config
-Xms1g
-Xmx1g
-Dlog4j2.disable.jmx=true
-Djava.security.policy=D:\es\config\es.policy
```


D:\es\config\es.policy如下

```
grant {
    permission javax.management.MBeanTruePermission "register";
    permission javax.management.MBeanServerPermission "createMBeanServer";
    permission java.lang.RuntimePermission "createClassLoader";
};
```

至此我可以成功启动，如果遇到其他问题，请先refer [https://blog.csdn.net/weixin_38380858/article/details/84258372](https://blog.csdn.net/weixin_38380858/article/details/84258372)

## es 评分模块

[https://www.elastic.co/guide/en/elasticsearch/reference/6.6/index-modules-similarity.html](https://www.elastic.co/guide/en/elasticsearch/reference/6.6/index-modules-similarity.html)

es索引的评分规则在创建或更新索引setting的时候设定，用户可以配置es内置评分算法（如BM25）的参数或创建自己的scripted similarity。

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

注意：


While scripted similarities provide a lot of flexibility, there is a set of rules that they need to satisfy. Failing to do so could make Elasticsearch silently return wrong top hits or fail with internal errors at search time:

- 返回分值必须是正的
- 当所有其他变量不变时，当doc.freq上升，socre不能下降
- 当所有其他变量不变时，当doc.length上升，score不能上升

上面例子中的script similarity计算方式中包含跟文档无关的部分：query.boost * idf。这一部分可以放在`weight_script`。如下:

```
    "similarity": {
      "scripted_tfidf": {
        "type": "scripted",
        "weight_script": {
          "source": "double idf = Math.log((field.docCount+1.0)/(term.docFreq+1.0)) + 1.0; return query.boost * idf;"
        },
        "script": {
          "source": "double tf = Math.sqrt(doc.freq); double norm = 1/Math.sqrt(doc.length); return weight * tf * norm;"
        }
    }
```

## es索引修改使用的评分算法

es提供多个评分算法，并且用户可以自行扩展，那么在检索时，使用哪套评分算法？

**1.** 创建/更新mapping时按字段设置

```
PUT /index/_mapping/_doc
{
  "properties" : {
    "title" : { "type" : "text", "similarity" : "my_similarity" }
  }
}
```

**2.** 设置默认评分算法

```
POST /index/_close

PUT /index/_settings
{
  "index": {
    "similarity": {
      "default": {
        "type": "boolean"
      }
    }
  }
}

POST /index/_open
```

## es插件模块

[https://www.elastic.co/guide/en/elasticsearch/plugins/6.6/index.html](https://www.elastic.co/guide/en/elasticsearch/plugins/6.6/index.html)

插件包含：jar包、脚本和配置文件。插件必须在集群中的每个节点安装，安装后必须重启节点，插件才可用（动态加载的实现看起来较困难。涉及到集群元数据的插件，需要整个集群的重启

[插件编写指南](https://www.elastic.co/guide/en/elasticsearch/plugins/6.6/plugin-authors.html)


**开发调试插件**

es可以从classpath加载插件，但是在发行版的代码中，隐藏了这个这个功能。稍微改下代码，把这个东西放出来

```
Index: server/src/main/java/org/elasticsearch/node/Node.java
IDEA additional info:
Subsystem: com.intellij.openapi.diff.impl.patch.CharsetEP
<+>UTF-8
===================================================================
--- server/src/main/java/org/elasticsearch/node/Node.java	(revision 1c439191c30172708dceae79ce3125822f8d6e12)
+++ server/src/main/java/org/elasticsearch/node/Node.java	(date 1586246418270)
@@ -265,6 +265,10 @@
         this(environment, Collections.emptyList(), true);
     }
 
+    public Node(Environment environment,Collection<Class<? extends Plugin>> classpathPlugins) {
+        this(environment, classpathPlugins, true);
+    }
+
     /**
      * Constructs a node
      *
```

然后，修改BootStrap中的Node创建代码

```
Index: server/src/main/java/org/elasticsearch/bootstrap/Bootstrap.java
IDEA additional info:
Subsystem: com.intellij.openapi.diff.impl.patch.CharsetEP
<+>UTF-8
===================================================================
--- server/src/main/java/org/elasticsearch/bootstrap/Bootstrap.java	(revision 1c439191c30172708dceae79ce3125822f8d6e12)
+++ server/src/main/java/org/elasticsearch/bootstrap/Bootstrap.java	(date 1586246418279)
@@ -214,22 +214,9 @@
             throw new BootstrapException(e);
         }

-        node = new Node(environment) {
+        Collection plugins = new ArrayList<>();
+        Collections.addAll(plugins, MBM25SimilarityPlugin.class);
+        node = new Node(environment,plugins) {
             @Override
             protected void validateNodeBeforeAcceptingRequests(
                 final BootstrapContext context,
```

下面是一个简单的插件（修改了BM25算法的参数）（这个插件没什么意义，修改BM25参数不需要搞插件）

```
package org.elasticsearch.plugin;

import org.apache.lucene.search.similarities.BM25Similarity;
import org.elasticsearch.index.IndexModule;
import org.elasticsearch.plugins.Plugin;


public class MBM25SimilarityPlugin extends Plugin {
    public String name() {
        return "elasticsearch-position-similarity";
    }

    public String description() {
        return "Elasticsearch scoring plugin based on matching a term or a phrase relative to a position of the term in a searched field.";
    }

    public void onIndexModule(IndexModule indexModule) {
        indexModule.addSimilarity("position", (settings, version, scriptService)->{
            String DISCOUNT_OVERLAPS="discount_overlaps";
            // BM25的k1默认是1.2 b默认是0.75
            float k1 = settings.getAsFloat("k1", 1.4f);
            float b = settings.getAsFloat("b", 0.8f);
            boolean discountOverlaps = settings.getAsBoolean(DISCOUNT_OVERLAPS, true);

            BM25Similarity similarity = new BM25Similarity(k1, b);
            similarity.setDiscountOverlaps(discountOverlaps);
            return similarity;
        });
    }
}
```

核心是indexModule.addXXXX方法，提供了扩展es各个功能的方法。

similarity插件化调研的初步结果是意义不大，因为scripted_similarity基本可以代替插件化了

[Github地址](https://github.com/arloor/elasticsearch/tree/LGH-test)


## 再看scripted_similarity

上文见识了scripted_weight的实例，但是没有看用于script的参数的含义，这里再来看下。

各项参数定义的java类，是org.elasticsearch.index.similarity.ScriptedSimilarity类的私有静态内部类。elasticsearch的文档把这些参数写在了painless context中，链接：[painless-similarity-context.html](https://www.elastic.co/guide/en/elasticsearch/painless/6.6/painless-similarity-context.html)

参数：

- params (Map, read-only) 
  - User-defined parameters passed in at query-time.
  - (提供查询时传参能力，但是7.6版本**已移除**)
- weight (float, read-only)
  - The weight as calculated by a weight script
  - 如果没有weight_script则为1
- query.boost (float, read-only)
  - The boost value if provided by the query. If this is not provided the value is 1.0f.
  - 查询时传的参数，会乘一下
- field.docCount (long, read-only)
  - The number of documents that have a value for the current field.
  - **分片shard**中该字段有值的文档数量
- field.sumDocFreq (long, read-only)
  - The sum of all terms that exist for the current field. If this is not available the value is -1.
- field.sumTotalTermFreq (long, read-only)
  - The sum of occurrences in the index for all the terms that exist in the current field. If this is not available the value is -1.
- term.docFreq (long, read-only)
  - The number of documents that contain the current term in the index.
  - **分片shard中**包含该term的文档数量
- term.totalTermFreq (long, read-only)
  - The total occurrences of the current term in the index.
  - index中该term的总出现次数
- doc.length (long, read-only)
  - The number of tokens the current document has in the current field. This is decoded from the stored norms and may be approximate for long fields
  - 该字段的token数量
- doc.freq (long, read-only)
  - The number of occurrences of the current term in the current document for the current field.
  - 该term在该doc的该field中出现的次数

有点抽象，尤其是field.sumDocFreq是Σterm.docFreq, field.sumTotalTermFreq是Σterm.totalTermFreq。他们到底有啥用？

可以从一个博客[文本相似度-bm25算法原理及实现](https://www.jianshu.com/p/1e498888f505)寻找bm25是如何使用这些参数的（很值得一看，理解es是怎么对每个field评分的）

这里不详细说里面的内容，大概介绍下使用这些参数的方式。field的评分是Σ语素（分词后的token）的评分。token的评分由weight(加权)\*token的分数得出。weight最一般的实现是idf，上述script的idf是Math.log((field.docCount+1.0)/(term.docFreq+1.0)) + 1.0 ——field.docCount是总文档数，term.docFreq是该term出现的次数。

另一篇介绍BM25算法的文章[https://www.jianshu.com/p/0b372804ff45](https://www.jianshu.com/p/0b372804ff45)