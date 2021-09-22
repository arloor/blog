---
title: "Rust学习路径"
date: 2021-09-22T13:57:38+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## rust简介

- 无GC
- 所有权 -> 不需要显式free
- async/await 类似nodejs的异步编程范式
- tokio 异步运行时、非阻塞IO框架

<!--more-->

## 入门路径

rust的网站这样描述自己：我们喜欢写document。rust确实提供了很多不错的文档（go的文档也很好

- [rust book](https://doc.rust-lang.org/stable/book/) 了解rust设计、语法
- [rust book中文版](https://kaisery.github.io/trpl-zh-cn/title-page.html) 
- [rust标准库文档](https://doc.rust-lang.org/std/)
    - std::* modules
    - Primitive types
    - Standard macros
    - The Rust Prelude
- [tokio文档](https://tokio.rs/tokio/tutorial)
- [async/await原理](https://tokio.rs/tokio/tutorial/async)

[rust book](https://doc.rust-lang.org/stable/book/)是一定需要看的，可以看[rust book中文版](https://kaisery.github.io/trpl-zh-cn/title-page.html)。第一次看的时候看的英文版，今年看的是中文版，感觉翻译还不错。[rust标准库文档](https://doc.rust-lang.org/std/)当成工具书吧，类似java doc的那种存在。现在的软件开发可以说一切都是基于网络，所以一个网络编程框架是肯定要学习的。tokio是目前最火的网络编程框架吧。[tokio文档](https://tokio.rs/tokio/tutorial)这个文档以一个简单redis的client/server实现为例子，逐渐深入地介绍tokio。tokio对自己的定位不是网络编程框架，而是异步运行时。


## 安装

**MacOS、Linux**
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**WINDOWS**

使用rust-init程序，需要额外下载visual studio 2019的安装器，并安装visual c++ 生成工具、windows 10 sdk、英文语言包

**集成开发环境**

我使用的是Intellij ide+[rust插件](https://plugins.jetbrains.com/plugin/8182-rust)

其他开发环境有[https://www.rust-lang.org/zh-CN/tools](https://www.rust-lang.org/zh-CN/tools)

除了官方的插件，rust-analyzer使用更加广泛，支持vscode等ide。

## rust基础——理解怎么做到内存安全的

rust是内存安全的，这是rust最重要的特点。为了实现这一点，rust增加了很多限制，这些限制是rust与其他语言最大的不同，也是rust学习路径陡峭的根本原因。

### 变量是默认不可变的

```
let x = 5;
x = 6; //编译器此时报错
```

需要增加mut：

```
let mut x = 5;
x = 6;
```

### 基础数据类型

- 整型
- 浮点型
- 布尔
- 字符型
- 元组
- 数组 

以上类型的size都固定，可以放在栈上

### 所有权系统

所有权系统解决什么？rust号称是内存安全的，其内存安全的保证机制其实就是通过一些规范将运行时内存安全问题变成编译期问题，在编译时就暴露这些问题。这些规范就是所有权系统。

栈上数据：压栈=申请空间，出栈=释放空间。而压栈出栈是自动的，所有不需要手动申请和释放。
堆上数据：C/C++需要手动申请和释放。java使用new关键字，垃圾收集器负责回收不再使用的空间。在rust中，既不存在GC，也不需要手动释放空间，原因就是所有权系统。

所有权规则的简单介绍：

> 1. Rust 中的每一个值都有一个被称为其 所有者（owner）的变量。  
> 2. 值在任一时刻有且只有一个所有者。
> 3. 当所有者（变量）离开作用域，这个值将被丢弃。

owner可以简单理解为指向堆上数据的指针。那么，所有权系统的思想就是“当指针离开作用域时，释放该指针指向的堆上空间”。但是这件事没有这么简单，否则为什么C不去实现“当指针离开作用域时，释放该指针指向的堆上空间”。

在实现上，rust提供了Move、Copy、Drop、和生命周期注解参数。

在C中，经常讨论传参是值传递的还是引用传递的，java中也有java只使用值传递的说法。在rust中没有值传递还是引用传递的说法，rust说的是Move和Copy。Move是指不进行深拷贝，直接把指针/引用传递过去，“所有权”也相应地移动到了目标作用域里——适用于堆上数据，因为堆上数据拷贝成本高，同时堆上数据需要进行释放。Copy主要用于基础数据类型（size编译器确定，可以放在栈上的数据）。Move和Copy其实是想保证规则“2. 值在任一时刻有且只有一个所有者”。

> 对于Move trait的类型，可以使用`.clone`深拷贝出一个对象，进行传参。

那什么是Drop呢？回忆一下java8的try-with-resource语法：

```
        try(InputStream in=new ByteArrayInputStream("aaaa".getBytes(StandardCharsets.UTF_8))){
            // doSomeThing...
        }catch (Throwable e){
            e.printStackTrace();
        }
```
try-with-resource会自动帮我们在finnal语句中调用资源的close方法，实现资源的自动释放。Drop的实现方式类似。被标记为Drop的类型，在离开作用域时编译器会“织入”drop代码，以自动地释放空间。

到这里还没有介绍生命周期注解参数的作用，等到介绍“引用和借用”的时候再说生命周期注解参数解决的是什么问题。

### 引用和借用

上面我们介绍了所有权系统，堆上数据一般都是Move trait的，传递这些参数将会移动所有权到新的作用域中。问题来了：

```
fn main(){
    let s = String::from("string");
    println!{"{}",s}; //这里将报错

}

fn useString(s: String){
    // s的所有权移动到这里
}
```

上面的代码报错是符合所有权系统的原则的。如果我们还想使用`s`,需要改成这样：

```
fn main(){
    let s = String::from("string");
    let s=useString(s);
    println!{"{}",s};

}

fn useString(s: String) -> String{
    s // = return s;
}
```

也即是再把s的所有权返回回去。这种代码很傻逼，于是借用的概念就出来了，用引用（&）来表达借用。

借用允许不获取所有权的情况下使用变量。我们可以这样改造代码：

```
fn main() {
    let s = String::from("string");
    useString(&s);
    println! {"use {} again", s};
}

fn useString(s: &String) {
    println! {"use {}", s};
}
```

但是借用又有一些问题需要解决：前面讲了rust是默认不可变的，引用也有可变的和不可变的，分别为`& mut`和`&`，这里就有两个规则：

> 1. 在任意给定时间，要么 只能有一个可变引用，要么 只能有多个不可变引用。
> 2. 引用必须总是有效的。

为什么"引用必须总是有效的"？因为引用所指向的数据如果已经被释放，那么就会导致一些错误，这就是“悬垂指针”。“悬垂指针”也是内存安全问题的一种，rust也致力于在编译器暴露这种问题，他的解决方案就是“生命周期注解参数”：

```
fn main() {
    let s = String::from("string");
    let sl = String::from("longer string");
    println! {"longer is {}", longest(&s,&sl)};
}

fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}
```

'a表示一种生命周期，还可以有'b,'c来表示不同的生命周期。被相同生命周期注解的参数拥有相同的生命周期。

rust的编译器能自动地判断一些引用的生命周期，所以不是所有情况都需要显式使用生命周期注解参数。不要畏惧生命周期注解参数，你只需要在编译器提醒你的时候加上他们。生命周期注解参数不会改变生命周期。

