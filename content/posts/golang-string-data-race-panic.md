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

简单说下问题：多个 goroutine 并发读写 string，读取 string（`fmt.Println`和`json.Marshal`）的 goroutine 会 panic。根因是 string 是一个胖指针，除了 pointer 字段之外还有一个 len 字段的元数据。在给 string 变量赋值（拷贝）时，会逐个设置 pointer 和 len 字段，这个过程不是原子的。在有并发修改时，pointer 和 len 就不一致了，这时就回发生问题：当 len 不为 0，pointer 为 nil(0x0)时，就会`panic: runtime error: invalid memory address or nil pointer dereference`。

本文首先探究下为什么 golang string 有这个问题，然后对比下 java 的 string 为什么没这个问题，最后介绍数据争用(data race)问题以及 Golang 和 Rust 如何避免该问题。

<!--more-->

## golang string data race 的 panic 复现及分析

### 最简复现：

```go
package main

// go run main/string_data_race_panic.go

import (
	"fmt"
	"reflect"
	"time"
	"unsafe"
)

// 并发读写string，会panic
func main() {
	str := "init"
	go func() { // goroutine 不断读取fullpath
		for i := 1; i < 10000; i++ {
			read(str)
		}
	}()

	for { // main goroutine会不断修改fullPath.
		str = ""
		time.Sleep(10 * time.Nanosecond)
		str = "/test/test/test"
		time.Sleep(10 * time.Nanosecond)
	}

}

func read(c string) { // 这里传参，有一次拷贝，会做feild（string的poiner和len）的赋值
	s := (*reflect.StringHeader)(unsafe.Pointer(&c))
	fmt.Printf("ptr: 0x%x, len: %d ", s.Data, s.Len)
	fmt.Printf("fullPath: %s\n", c)
	// 或者下面的json Marshal，也会panic
	// _, _ = json.Marshal(c)
}
```

### panic 内容：

```bash
ptr: 0x0, len: 15 panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x475234]

goroutine 7 [running]:
fmt.(*buffer).writeString(...)
        /usr/local/go/src/fmt/print.go:108
fmt.(*fmt).padString(0xc00009ecf0?, {0x0, 0xf})
        /usr/local/go/src/fmt/format.go:113 +0xa5
fmt.(*fmt).fmtS(0xc00009ed48?, {0x0?, 0xc000184040?})
        /usr/local/go/src/fmt/format.go:362 +0x39
fmt.(*pp).fmtString(0x1?, {0x0?, 0xc00009ed80?}, 0x48f8c5?)
        /usr/local/go/src/fmt/print.go:497 +0xc5
fmt.(*pp).printArg(0xc000184000, {0x4a3d40, 0xc0000148b0}, 0x73)
        /usr/local/go/src/fmt/print.go:741 +0x1d5
fmt.(*pp).doPrintf(0xc000184000, {0x4be76d, 0xd}, {0xc00009ef70, 0x1, 0x1})
        /usr/local/go/src/fmt/print.go:1074 +0x37e
fmt.Fprintf({0x4e57f8, 0xc000072020}, {0x4be76d, 0xd}, {0xc00009ef70, 0x1, 0x1})
        /usr/local/go/src/fmt/print.go:224 +0x71
fmt.Printf(...)
        /usr/local/go/src/fmt/print.go:233
main.request({0x0, 0xf})
        /root/main.go:34 +0xe7
main.main.func1()
        /root/main.go:17 +0x2f
created by main.main in goroutine 1
        /root/main.go:15 +0x76
exit status 2
```

关注 panic 信息中的这一行：

```bash
fmt.(*fmt).padString(0x1400011a1c0?, {0x0, 0xf}) // 0x0是指针地址nil，0xf是长度（15，即/test/test/test的长度）
```

0x0 是指针地址 nil，0xf 是长度（15，即/test/test/test 的长度）。发现 len 是 15，尝试解引用 nil 指针来读底层数据，就会 panic

### 根因分析：

为了分析这个 panic 的根因，先看 string 的定义：

```go
// go/src/reflect/value.go

// StringHeader is the runtime representation of a string.
// ...
type StringHeader struct {
    Data uintptr // 指针
    Len  int     // 长度元数据
}
```

string 很明确的是一个胖指针结构体。在给 string 变量赋值（拷贝）时，会逐个设置 pointer 和 len 字段，这个过程不是原子的。在有并发修改时，pointer 和 len 就不一致了，这时就会发生问题：

1. 赋值时 len!=0, pointer=nil: `panic: runtime error: invalid memory address or nil pointer dereference`
2. 赋值时 len 和 pointer 都不为 0，但是两者不匹配：会读到错误的数据，截断或读到错误数据

回顾一下 golang 的 string 类型的特征：

1. string 是值类型。虽然 string 和 slice 一样也是胖指针，但 string 的实现确保修改一个变量的内容时，这个修改对其他变量不可见（重新分配底层数据，而不是通过下标原地修改）
2. string 是不可变的。

作为一个 java 老手，“**不可变对象是线程安全的**”是一个基本概念。但是 golang 的 string 却在多线程数据争用中出现了问题，为什么 java 和 golang 有这样的差异？后面会讲到。

### 一种修复方案：使用 atomic.Value

使用 `atomic.Value` 包裹 string。不过 atomic 是基于 CAS 的，这样的改动在 `sleep 10 纳秒` 的情况下，会导致 CAS 陷入忙等待，CPU 占用率 100%且阻塞住，这时候就要显式使用 mutex 了。

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

## java 的 String 为什么没这个问题

### 首先：java 赋值/传参是 pass by copy of object reference

以下面的代码为例，Java 的赋值和传参（非基础类型）操作可以分为两步：

```java
String str = new String()
```

|     | 步骤                                                                                        | 是否原子             | 备注                                                                                                                  |
| --- | ------------------------------------------------------------------------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 1   | 通过 new()方法初始化对象（省略更前面的类加载、内存申请、static 变量初始化、父类对象初始化） | 不原子               | 逐个初始化各个字段。在《java 并发编程》中说到，不能在 new()方法中泄漏 this 引用，因为此时的 this 还没有被完全初始化好 |
| 2   | pass by copy of object reference                                                            | 引用的拷贝都是原子的 |                                                                                                                       |

另外提两个点：

1. java 的 object 其实都是 object reference
2. java 都是值传递的，针对 object reference，值传递指的是 pass by copy of object reference。这个拷贝是原子的。

而 golang 的 string 胖指针是个 struct，赋值时会逐个设置 pointer 和 len 字段，这个过程不是原子的。这是 java String 和 golang string 的第一个区别，但不是全部，请继续看。

### 其次：Java 对象的 final 字段初始化后对所有线程可见

`final` 在 Java 中本来是变量、属性创建后不可修改的意思。[JSR-133 修订](https://jcp.org/en/jsr/detail?id=133)新增了针对 `final` 字段的两个“禁止重排序”规则，以保证 `final` 字段在构造方法执行完毕后对所有线程可见（详见[Java 内存模型中 final 字段语意](https://docs.oracle.com/javase/specs/jls/se21/html/jls-17.html#jls-17.5)）。这也是 Java 不可变对象是线程安全的根本原因。

[JSR-133 修订](https://jcp.org/en/jsr/detail?id=133)还给 `volatile` 关键词增加了“顺序一致性”的保证，一个典型的场景是使用双重检验锁 + `static volatile` 来保证顺序一致性（防止读到未完全初始化的对象）和可见性（读到最新的值）。总之[JSR-133 修订](https://jcp.org/en/jsr/detail?id=133)是对 Java 内存模型一次重要的修订。

## 一切的罪魁祸首：数据争用(data race)

Rust 的一个文档[Data Races and Race Conditions](https://doc.rust-lang.org/nomicon/races.html)介绍了 data race（数据争用）和 race condition（竞态条件）。引用 Rust 文档中对 data race 的定义：

Safe Rust guarantees an absence of data races, which are defined as:

1. two or more threads concurrently accessing a location of memory
2. one or more of them is a write
3. one or more of them is unsynchronized

这意味着如果要在 golang 中完全避免数据争用，需要对某个 data 的全部并发访问都上锁。这无疑是困难的，现实是代码里 data race 到处可见（ `go build` 加上 `-race`，运行时会一直 panic）。在[The Go Memory Model(golang 内存模型)](https://go.dev/ref/mem)中，全篇都在说如何使用 channel、lock、atomic、once 等同步手段实现 data-race-free 的 golang 程序，有兴趣可以看下

但是 rust 这门优秀的语言天生避免了这个问题（不使用 unsafe rust 的前提下），其实现机制如下：

1. 值的可变引用只能有一个（所有权机制），只有可变引用可以修改值
2. 需要跨线程传递/同步的值需要满足 `send + sync` 约束，实现方式是包裹 `Arc<Mutex<YourData>>`。编译器强制你包裹 Mutex，否则编译都通不过。——Rust 代码只要可以编译，运行时就不大会出离谱的问题。

除了 data race，还有 race condition 竞态条件，这需要通过临界区保护，详见[Data Races and Race Conditions](https://doc.rust-lang.org/nomicon/races.html)，本文不展开。
