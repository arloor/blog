---
title: "开发Elasticsearch自定义评分插件-horspool评分"
date: 2020-04-27T14:09:21+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

在[Elasticsearch调研](/posts/elasticsearch-study/)中，已经学习了es的similarity、plugin和在idea中debug启动。有了以上，就可以自己制作es评分插件。这篇博客说下如何自定义script_score实现自己的评分算法。
<!--more-->

老规矩，先上项目地址[es-score-plugin](https://github.com/arloor/es-score-plugin) ——仅适用于elasticsearch6.6.2版本

## es插件项目的代码结构(maven项目)

跟着[Elasticsearch自定义插件开发](https://blog.csdn.net/L253272670/article/details/54141169)这个成功走通。

maven package后会在target中生成.zip压缩文件，把这个zip解压缩到elasticsearch的plugins文件夹，然后重启es即可（集群每个node都需要重启）

## 核心代码

```java
package org.elasticsearch.plugin.score;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.lucene.index.LeafReader;
import org.apache.lucene.index.LeafReaderContext;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.plugins.Plugin;
import org.elasticsearch.plugins.ScriptPlugin;
import org.elasticsearch.script.ScoreScript;
import org.elasticsearch.script.ScoreScript.LeafFactory;
import org.elasticsearch.script.ScriptContext;
import org.elasticsearch.script.ScriptEngine;
import org.elasticsearch.search.lookup.LeafDocLookup;
import org.elasticsearch.search.lookup.SearchLookup;
import org.elasticsearch.search.lookup.SourceLookup;

import java.io.IOException;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * An example script plugin that adds a {@link ScriptEngine} implementing expert scoring.
 */
public class ExpertScriptPlugin extends Plugin implements ScriptPlugin {
    protected static final Logger logger = LogManager.getLogger(ExpertScriptPlugin.class);

    @Override
    public ScriptEngine getScriptEngine(Settings settings, Collection<ScriptContext<?>> contexts) {
        return new MyExpertScriptEngine();
    }

    /**
     * An example {@link ScriptEngine} that uses Lucene segment details to implement pure document frequency scoring.
     */
    // tag::expert_engine
    private static class MyExpertScriptEngine implements ScriptEngine {
        @Override
        public String getType() {
            return "expert_scripts";
        }

        @Override
        public <T> T compile(String scriptName, String scriptSource,
                             ScriptContext<T> context, Map<String, String> params) {
            if (context.equals(ScoreScript.CONTEXT) == false) {
                throw new IllegalArgumentException(getType()
                    + " scripts cannot be used for context ["
                    + context.name + "]");
            }
            // we use the script "source" as the script identifier
            if ("horspool".equals(scriptSource)) {
                ScoreScript.Factory factory = PureDfLeafFactory::new;
                return context.factoryClazz.cast(factory);
            }
            throw new IllegalArgumentException("Unknown script name "
                + scriptSource);
        }

        @Override
        public void close() {
            // optionally close resources
        }

        private static class PureDfLeafFactory implements LeafFactory {
            private final Map<String, Object> params;
            private final SearchLookup lookup;
            private final List<String> fields;
            private final String query;

            private PureDfLeafFactory(
                    Map<String, Object> params, SearchLookup lookup) {
                if (params.containsKey("field") == false) {
                    throw new IllegalArgumentException(
                        "Missing parameter [field]");
                }
                if (params.containsKey("query") == false) {
                    throw new IllegalArgumentException(
                        "Missing parameter [query]");
                }

                this.params = params;
                this.lookup = lookup;
                fields = (List<String>) params.get("field");
                query = params.get("query").toString();
            }

            @Override
            public boolean needs_score() {
                return true;  // Return true if the script needs the score
            }

            @Override
            public ScoreScript newInstance(LeafReaderContext context)
                throws IOException {
                LeafReader reader = context.reader();
                SourceLookup source = lookup.getLeafSearchLookup(context).source();
                LeafDocLookup doc = lookup.getLeafSearchLookup(context).doc();
                return new ScoreScript(params, lookup, context) {
                    int currentDocid = -1;

                    @Override
                    public void setDocument(int docid) {
                        currentDocid = docid;
                    }

                    @Override
                    public double execute() {
                        //获取原来的评分
                        double rawScore = this.get_score();
                        final double[] maxScore = {0.0};
                        fields.forEach(fieldWeight -> {
                            String[] split = fieldWeight.split("\\^");
                            String field = split[0];
                            double weight = split.length == 2 ? Double.parseDouble(split[1]) : 1;
                            source.setSegmentAndDocument(context, currentDocid);
                            String value = "";
                            if (source.containsKey(field)) {
                                value = String.valueOf(source.get(field));
                            } else {
                                return;
                            }
                            double horspool = Horspool.calHorspoolScoreWrapper(value, query);
                            horspool = horspool * weight;
                            if (horspool > maxScore[0]) {
                                maxScore[0] = horspool;
                            }
                        });
                        return maxScore[0];
                    }
                };
            }
        }
    }
    // end::expert_engine
}
```

horspool算法入参就两个文本，不受其他文档的影响，这是与es内置评分算法的主要区别。es的内置评分算法肯定是考虑最周全的，在这里自定义评分参数也许只能对某些场景有一些优化，但至少提供了一种可能，毕竟es自己也出于某种考虑给我们提供了这种expertScriptEngine。

## 使用

```json
{
  "query": {
    "function_score": {
      "query": {
        "match_all": {}
      },
      "boost_mode": "replace",
      "functions": [
        {
          "script_score": {
            "script": {
              "source": "horspool",
              "lang": "expert_scripts",
              "params": {
                "field": ["title^2","body^1"],
                "query": "{{query}}"
              }
            }
          }
        }
      ]
    }
  }
}
```

## 参考文档

[elasticsearch插件的开发--计算特征向量的相似度](https://www.cnblogs.com/whb-20160329/p/10472717.html)

[Advanced scripts using script engines](https://www.elastic.co/guide/en/elasticsearch/reference/6.6/modules-scripting-engine.html)

[elasticsearch6.6.2 javaDoc](https://www.javadoc.io/doc/org.elasticsearch/elasticsearch/6.6.2/index.html) ——专家脚本模式有可能需要查查看

## gist

暂时没有用到但是有些作用的代码：

```
// 打印当前document某field的分词结果（terms）
Terms terms = null;
String temp="";
try {
    terms = reader.terms(field);
    TermsEnum iterator = terms.iterator();
    for (int i = 0; i < terms.size(); i++) {
        BytesRef next = iterator.next();
        if (next==null){
            break;
        }
        temp+="|"+Term.toString(next);
    }
    System.out.println(value+"=="+temp);
} catch (IOException e) {
    e.printStackTrace();
}
```

```
// 获取某字段值（不推荐，推荐使用sourceLookup）
Document document = reader.document(currentDocid);
String doc=new String(document.getBinaryValue("_source").bytes);
JSONObject jsonObject=JSONObject.parseObject(doc);
String value=jsonObject.getString(field);
```