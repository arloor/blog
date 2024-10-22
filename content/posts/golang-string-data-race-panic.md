---
title: "Golang的string数据争用导致的panic"
subtitle:
tags: 
- golang
date: 2024-10-11T10:43:56+08:00
lastmod: 2024-10-11T10:43:56+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

简单说下问题：多个goroutine并发读写string，读取string（`fmt.Println`和`json.Marshal`）的goroutine会panic。根因是string是一个胖指针，除了pointer字段之外还有一个len字段的元数据。在给string变量赋值（拷贝）时，会逐个设置pointer和len字段，这个过程不是原子的。在有并发修改时，pointer和len就不一致了，这时就回发生问题：当len不为0，pointer为nil(0x0)时，就会`panic: runtime error: invalid memory address or nil pointer dereference`。

本文首先探究下为什么golang string有这个问题，然后对比下java的string为什么没这个问题，最后介绍数据争用(data race)问题以及Golang和Rust如何避免该问题。

<!--more-->

## golang string data race的panic复现及分析

### 最简复现：

```go
package main

// go run main/string_data_race_panic.go

import (
	"fmt"
	"time"
)

// 并发读写string，会panic
func main() {
	fullPath := "init"
	go func() { // goroutine 不断读取fullpath
		for i := 1; i < 10000; i++ {
			request(fullPath)
		}
	}()

	for { // main goroutine会不断修改fullPath.
		fullPath = ""
		time.Sleep(10 * time.Nanosecond)
		fullPath = "/test/test/test"
		time.Sleep(10 * time.Nanosecond)
	}

}

func request(c string) { // 这里传参，有一次拷贝，会做feild（string的poiner和len）的赋值
	fmt.Printf("fullPath: %s\n", c)
	// 或者下面的json Marshal，也会panic
	// _, _ = json.Marshal(c)
}
```

### panic内容：

```bash
panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x2 addr=0x0 pc=0x102310388]

goroutine 18 [running]:
fmt.(*buffer).writeString(...)
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/print.go:108
fmt.(*fmt).padString(0x1400011a1c0?, {0x0, 0xf})
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/format.go:110 +0x23c
fmt.(*fmt).fmtS(0x14000104da8?, {0x0?, 0xd0?})
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/format.go:359 +0x40
fmt.(*pp).fmtString(0x0?, {0x0?, 0x14000104da8?}, 0x232fb58?)
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/print.go:497 +0xe4
fmt.(*pp).printArg(0x1400007c000, {0x102367ae0, 0x14000010b60}, 0x73)
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/print.go:741 +0x314
fmt.(*pp).doPrintf(0x1400007c000, {0x10233b9e5, 0xd}, {0x14000104fb0, 0x1, 0x1})
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/print.go:1075 +0x2d8
fmt.Fprintf({0x10237c568, 0x14000116008}, {0x10233b9e5, 0xd}, {0x14000104fb0, 0x1, 0x1})
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/print.go:224 +0x54
fmt.Printf(...)
        /opt/homebrew/Cellar/go/1.22.6/libexec/src/fmt/print.go:233
main.request(...)
        /Users/arloor/go-actions/main/string_data_race_panic.go:31
main.main.func1()
        /Users/arloor/go-actions/main/string_data_race_panic.go:15 +0x80
created by main.main in goroutine 1
        /Users/arloor/go-actions/main/string_data_race_panic.go:13 +0x7c
exit status 2
```

关注panic信息中的这一行：

```bash
fmt.(*fmt).padString(0x1400011a1c0?, {0x0, 0xf}) // 0x0是指针地址nil，0xf是长度（15，即/test/test/test的长度）
```

0x0是指针地址nil，0xf是长度（15，即/test/test/test的长度）。发现len是15，尝试解引用nil指针来读底层数据，就会panic

### 根因分析：

为了分析这个panic的根因，先看string的定义：

```go
// go/src/reflect/value.go

// StringHeader is the runtime representation of a string.
// ...
type StringHeader struct {
    Data uintptr // 指针
    Len  int     // 长度元数据
}
```

string很明确的是一个胖指针结构体。在给string变量赋值（拷贝）时，会逐个设置pointer和len字段，这个过程不是原子的。在有并发修改时，pointer和len就不一致了，这时就会发生问题：

1. 赋值时 len!=0, pointer=nil: `panic: runtime error: invalid memory address or nil pointer dereference`
2. 赋值时 len和pointer都不为0，但是两者不匹配：会读到错误的数据，截断或读到错误数据

回顾一下golang的string类型的特征：

1. string是值类型。虽然string和slice一样也是胖指针，但string的实现确保修改一个变量的内容时，这个修改对其他变量不可见（重新分配底层数据，而不是通过下标原地修改）
2. string是不可变的。

作为一个java老手，“**不可变对象是线程安全的**”是一个基本概念。但是golang的string却在多线程数据争用中出现了问题，为什么java和golang有这样的差异？后面会讲到。

### 一种修复方案：使用 atomic.Value

使用 `atomic.Value` 包裹string。不过atomic是乐观锁，这样的改动在 `sleep 10 纳秒` 的情况下，会导致CAS陷入自旋，CPU占用率100%且不阻塞住，这时候就要显式使用mutex了。

```go
package main

import (
	"fmt"
	"sync/atomic"
	"time"
)

func main() {
	var atomicFullPath atomic.Value
	atomicFullPath.Store("init")
	go func() {
		for i := 1; i < 10000; i++ {
			request(atomicFullPath)
		}
	}()

	for {
		atomicFullPath.Store("")
		time.Sleep(10 * time.Nanosecond)
		atomicFullPath.Store("/test/test/test")
		time.Sleep(10 * time.Nanosecond)
	}

}

func request(c atomic.Value) {
	println(fmt.Sprintf("fullPath: %s", c.Load().(string)))
}
```

## java的String为什么没这个问题

### 首先：java赋值/传参是pass by copy of object reference

以下面的代码为例，Java的赋值和传参（非基础类型）操作可以分为两步：

```java
String str = new String()
```

| | 步骤 | 是否原子 | 备注 |
| --- | --- | --- | --- |
| 1 | 通过new()方法初始化对象（省略更前面的类加载、内存申请、static变量初始化、父类对象初始化） | 不原子 | 逐个初始化各个字段。在《java并发编程》中说到，不能在new()方法中泄漏this引用，因为此时的this还没有被完全初始化好 |
| 2 | pass by copy of object reference | 引用的拷贝都是原子的 |  |

另外提两个点：

1. java的object其实都是object reference
2. java都是值传递的，针对object reference，值传递指的是pass by copy of object reference。这个拷贝是原子的。

而golang的string胖指针是个struct，赋值时会逐个设置pointer和len字段，这个过程不是原子的。这是java String和golang string的第一个区别，但不是全部，请继续看。

### 其次：Java对象的final字段初始化后对所有线程可见

`final` 在Java中本来是变量、属性创建后不可修改的意思。[JSR-133修订](https://jcp.org/en/jsr/detail?id=133)新增了针对 `final` 字段的两个“禁止重排序”规则，以保证 `final` 字段在构造方法执行完毕后对所有线程可见（详见[Java内存模型中final字段语意](https://docs.oracle.com/javase/specs/jls/se21/html/jls-17.html#jls-17.5)）。这也是Java不可变对象是线程安全的根本原因。

[JSR-133修订](https://jcp.org/en/jsr/detail?id=133)还给 `volatile` 关键词增加了“顺序一致性”的保证，一个典型的场景是使用双重检验锁 + `static volatile` 来保证顺序一致性（防止读到未完全初始化的对象）和可见性（读到最新的值）。总之[JSR-133修订](https://jcp.org/en/jsr/detail?id=133)是对Java内存模型一次重要的修订。


## 一切的罪魁祸首：数据争用(data race)

Rust的一个文档[Data Races and Race Conditions](https://doc.rust-lang.org/nomicon/races.html)介绍了data race（数据争用）和 race condition（竞态条件）。引用Rust文档中对data race的定义：

Safe Rust guarantees an absence of data races, which are defined as:

1. two or more threads concurrently accessing a location of memory
2. one or more of them is a write
3. one or more of them is unsynchronized

这意味着如果要在golang中完全避免数据争用，需要对某个data的全部并发访问都上锁。这无疑是困难的，现实是代码里data race到处可见（ `go build` 加上 `-race`，运行时会一直panic）。在[The Go Memory Model(golang内存模型)](https://go.dev/ref/mem)中，全篇都在说如何使用channel、lock、atomic、once等同步手段实现data-race-free的golang程序，有兴趣可以看下

但是rust这门优秀的语言天生避免了这个问题（不使用unsafe rust的前提下），其实现机制如下：

1. 值的可变引用只能有一个（所有权机制），只有可变引用可以修改值
2. 需要跨线程传递/同步的值需要满足 `send + sync` 约束，实现方式是包裹 `Arc<Mutex<YourData>>`。编译器强制你包裹Mutex，否则编译都通不过。——Rust代码只要可以编译，运行时就不大会出离谱的问题。

除了data race，还有race condition竞态条件，这需要通过临界区保护，详见[Data Races and Race Conditions](https://doc.rust-lang.org/nomicon/races.html)，本文不展开。
