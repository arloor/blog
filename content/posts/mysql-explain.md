---
title: "Mysql索引及explain使用"
date: 2020-10-16T19:49:15+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

首先放参考文档

1. [MySQL索引原理及慢查询优化-美团技术博客](https://tech.meituan.com/2014/06/30/mysql-index.html)
2. [explain_mysql文档](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html)
<!--more-->

## 索引创建原则

1. 尽量使用联合索引，尽量扩展联合索引，而非新建索引
2. 最左前缀匹配原则，
    1. where语句中会一直向右匹配到范围查询(>,<,between,like>)
    2. 索引(a,b,c,d)——where中仅含有（b,c）不能使用索引，含(a,b,c)才能使用
3. mysql有查询优化器，会调整你的where语句以尽可能地使用索引——如果有(a,b,c)这个索引，where a = 1 and b = 2 and c = 3中的a、b、c也可以使用到上述索引。
4. 尽量使用区分度高的列作为索引，例如性别(0,1)的区分度没有姓名的区分度高
5. 不要对索引column做function，例如：禁止from_unixtime(create_time) = ’2014-05-29’
6. 尽量扩展索引，不要新建索引
7. order by部分也可以使用到索引


## EXPLAIN使用


```
EXPLAIN
SELECT *
from table
WHERE project_id IN ('a', 'b', 'c')
  and project_type = 'xxx_type'
  and user_type = 'xxx_user'
  and user_id = '11111'
```
<img src="/img/mysql_explain.png" alt="" width="600px" style="max-width: 100%;">

以上就是一个简单的EXPALIN使用的例子，接下来看看mysql官方文档怎么解释这些字段的。

<img src="/img/explain_columns.png" alt="" width="600px" style="max-width: 100%;">

- id: 查询标识符，标示union联合查询这种有多个子查询
- select_type: 查询类型
- table: 查询的表
- partitions：查询的分区
- type: join类型，后面细讲
- possible_keys: 可以使用的索引
- key: 真实使用的索引
- key_len: 使用的索引的长度，确定使用了联合索引的几个部分


TBD.



