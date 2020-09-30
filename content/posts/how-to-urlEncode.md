---
title: "如何正确地urlEncode？空格被urlEncode成+"
date: 2020-08-18T21:57:41+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

Java里面进行urlEncode很简单：
<!--more-->

```java
    public static void main(String[] args) {
        String string = "+ +";
        try {
            string = URLEncoder.encode(string, "UTF-8");
            System.out.println(string);
            String res = URLDecoder.decode(string,"UTF-8");
            System.out.println(res);
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }
    }
```

就是这一段简单的代码藏了一个坑：`URLEncoder.encode`适用于`application/x-www-form-urlencoded`。在POST请求时，`x-www-form-urlencoded`在请求体中；GET请求时，则跟随在url的path后，被称为为queryString。由于历史原因，`x-www-form-urlencoded`要求将空格编码为加号（+）
<!--more-->

而另一份规范(RFC 2396，定义URI)里, URI里的保留字符都需转义成%HH格式(Section 3.4 Query Component)，因此空格会被编码成%20，加号+本身也作为保留字而被编成%2B，对于某些遵循RFC 2396标准的应用来说，它可能不接受查询字符串中出现加号+，认为它是非法字符。所以一个安全的举措是URL中统一使用%20来编码空格字符。

如果我们用UrlEncoder来encode url的path部分就会掉到一个坑里：

> UrlEncoder将path中的空格encode成了+，然后就会出现404错误。

避免这个坑很简单：手动将+替换会"%20"(空格的ASCII码的双16进制表示，等于32)即可。当我们对url中path的部分进行urlEncode时应该这样写：

```java
    public static void main(String[] args) {
        String url = "+ +";
        try {
            url = URLEncoder.encode(url, "UTF-8");
            url = url.replaceAll("\\+", "%20");
            System.out.println(url);
            String res = URLDecoder.decode(url,"UTF-8");
            System.out.println(res);
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }
    }
```

这时候有朋友要问了，那里面原来就存在的“+”都变成%20了？不会的，因为在encode时，所有的“+”都变成%2B(ASCII 43)，已经不存在“+”了。

另外一个问题：做了这个替换后，URLDecoder还能正常decode吗？答案是能。我们摘录java Doc中关于URLDecode的decode规则：

1. a-z A-Z 0-9保持不变
2. 特殊字符".", "-", "*", and "_" 保持不变
3. +被转变为 空格
4. %xy这种百分号编码的序列会作为双16进制表示，以特定的编码（如UTF-8）找到对应的字

我们的%20命中第4条规则，计算得出是ASCII码的32，也就是+。注意，ASCII码是最早的编码方式，之后的所有编码方式都兼容ASCCII码，所以任何编码方式中，32都是+。（在此感谢zhaojunhui给我扫盲字符编码）。而%2B也能正确地转变为+。因此，在Java环境中，手动将+替换为%20是安全的。

对应地摘录UrlEncoder的java doc:

0. converting a String to the application/x-www-form-urlencoded MIME format.
1. 字母数字字符 "a" 到 "z"、"A" 到 "Z" 和 "0" 到 "9" 保持不变。
2. 特殊字符 "."、"-"、"*" 和 "_" 保持不变。
3. 空格字符 " " 转换为一个加号 "+"。
4. 所有其他字符都是不安全的，因此首先使用一些编码机制将它们转换为一个或多个字节。然后每个字节用一个包含 3 个字符的字符串 "%xy" 表示，其中 xy 为该字节的两位十六进制表示形式。推荐的编码机制是 UTF-8。但是，出于兼容性考虑，如果未指定一种编码，则使用相应平台的默认编码。

最后一个问题，如果在用于`x-www-form-urlencoded`的encode代码中不小心加了这个替换会有问题吗？初步测了下，感觉没啥问题。如下的Controller，各种curl来测一下

```java
    @GetMapping("/ api")//有个空格在这里
    @ResponseBody
    public String test(@RequestParam String param){
        return param;
    }
```

```
curl "http://localhost:8080/%20api?param=a+a"  //a a
curl "http://localhost:8080/%20api?param=a%20a"  //a a
curl "http://localhost:8080/+api?param=a%20a"  //404 not found
```

从这个看，基本能确定，这个手动替换是安全的，当然与非java进程交互是否有问题还需要谨慎点。

