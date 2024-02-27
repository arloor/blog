---
title: "go使用sync.pool实现复用[]byte——降低IO密集应用的GC频率"
date: 2019-04-14T14:22:51+08:00
draft: false
categories: [ "undefined"]
tags: ["go"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

前一篇文章介绍了`sogo`这个socks5代理的实现，在原始的sogo实现中，有一个重大的问题是：没有复用内存，导致频繁GC，导致cpu占用很高。对于socket通信这种io密集的应用，复用`[]byte`还是很重要的，不然每次去make新的`[]byte`，这些`[]byte`迟早要被GC，这就导致了cpu占用高的问题。解决这个问题也很简单，就是引入内存池。

在go语言的世界里，内存池有两种，一种是官方的sync.pool——临时对象池；另一种是利用channel实现的自定义内存池。下面将首先介绍这两种内存池的特点。

## 1.标准库sync.pool

用法很简单，如下所示：

```java
package main
 
import(
    "fmt"
    "sync"
)
 
func main() {
    p := &sync.Pool{
        New: func() interface{} {
            return 0
        },
    }
 
    a := p.Get().(int)
    p.Put(1)
    b := p.Get().(int)
    fmt.Println(a, b)
}
```

```
p.Get().(int) #这种写法是将Interface{}强转成int
```

使用Get/Put方法取出和放回Interface对象。如果Get时池中没有对象，则调用New，新建对象并返回。

1. 这个标准库的实现，内部也是使用锁来保证线程（协程）安全，但是使用了更细粒度的锁，类似java的concurrentHashMap，这样就能减少竞争。
2. sync.pool中空闲的对象会在下一次GC时被清空。

以上两点，就是sync.pool最重要的两个特征：细粒度锁、pool中空闲对象在GC时仍然会被清空。

从我现在的理解来看，细粒度锁是很好的，但是GC时仍然会被回收这个我觉得有点不爽。。应该提供一个可以自定义的回收策略吧，比如定时5分钟这样，下一次GC还是太频繁了。从下面的代码来看，用户也没有办法自己去覆写poolCleanup函数：runtime_registerPoolCleanup由runtime实现，并且是私有防范。

```java
func init() {
	runtime_registerPoolCleanup(poolCleanup)
}

func indexLocal(l unsafe.Pointer, i int) *poolLocal {
	lp := unsafe.Pointer(uintptr(l) + uintptr(i)*unsafe.Sizeof(poolLocal{}))
	return (*poolLocal)(lp)
}

// Implemented in runtime.
func runtime_registerPoolCleanup(cleanup func())
```


在src/sync/pool.go的代码的开头，一大段注释中写道：

>// On the other hand, a free list maintained as part of a short-lived object is not a suitable use for a Pool, since the overhead does not amortize well in that scenario. It is more efficient to have such objects implement their own free list.

意思应该是，持有sync.pool的对象不能是短命的对象（一个[博客](https://segmentfault.com/a/1190000016987629)有不一样的理解：sync.pool中的对象不能是短命对象，我不认可这个）。我们的内存池是一个全局的资源池，“全局”这个东西的生命周期就是一个进程的开始到消亡，应该是最长的了，使用sync.pool作为我们的内存池，应该是可以的，但我始终不怎么满意GC时，仍然会被回收这个。

## 2.使用channel机制实现的pool

我看到好几个使用channel实现的pool，大体如下:

```java
package bpool

// BytePool implements a leaky pool of []byte in the form of a bounded
// channel.
type BytePool struct {
	c chan []byte
	w int
}

// NewBytePool creates a new BytePool bounded to the given maxSize, with new
// byte arrays sized based on width.
func NewBytePool(maxSize int, width int) (bp *BytePool) {
	return &BytePool{
		c: make(chan []byte, maxSize),
		w: width,
	}
}

// Get gets a []byte from the BytePool, or creates a new one if none are
// available in the pool.
func (bp *BytePool) Get() (b []byte) {
	select {
	case b = <-bp.c:
	// reuse existing buffer
	default:
		// create new buffer
		b = make([]byte, bp.w)
	}
	return
}

// Put returns the given Buffer to the BytePool.
func (bp *BytePool) Put(b []byte) {
	if cap(b) < bp.w {
		// someone tried to put back a too small buffer, discard it
		return
	}

	select {
	case bp.c <- b[:bp.w]:
		// buffer went back into pool
	default:
		// buffer didn't go back into pool, just discard
	}
}

// Width returns the width of the byte arrays in this pool.
func (bp *BytePool) Width() (n int) {
	return bp.w
}
```

这段代码定义的pool的特点有：
1. pool的大小固定，put多余的buf将会被丢弃（leaky）
2. 只接受固定宽度的buf

这段代码用的还是挺多的，shadowsocks-go的[leakbuf.go](https://github.com/shadowsocks/shadowsocks-go/blob/master/shadowsocks/leakybuf.go)其实也是这样，也有这两个特点。唯一的不同是，shadowsocks-go的Put会检查`[]byte`的长度是否正确，不正确则panic（这应该是他的实现决定的）。shadowsocks-go的起名也挺好玩“leakybuf”，或许叫leakypool更恰当，会漏水的池子——多余的、宽度不对的buf都会被丢弃。

使用sync.pool会在GC时回收pool空闲的buf（pool中buf数量可能为0），使用这个leakypool则会回收过多（丢弃）的buf（pool中数量基本不会为0）。前面是回收到剩余0空闲，后面是回收到空闲数量<=channel的容量。

- sync.pool可能会面临pool中无空闲可用的情况，需要重新make；leakypool则不会有这个问题。
- sync.pool不要求`[]byte`固定容量，更加自由。leakpool则只能复用固定长度的`[]byte`（当然，改下源码就不再有这个问题）
- sync.pool有更细粒度的锁

以上就是这两个方案的区别。

为了更好地使用内存池，下面补一点go基础的东西。。

## slice内部

slice建立在array的基础上，首先讲go的array

```
var a [4]int
a[0] = 1
i := a[0]
// i == 1
```

和java一样，array包括类型和长度。包裹相同类型的对象，但长度不同的数组是不同的类型，比如`[3]int`和`[4]int`是不一样的类型，没错，go的数组的`[]`放在前面。`var a [4]int `会将数组的所有元素初始化为0。

与c语言不同，array变量代表整个数组，而非是指向数组第一个元素的指针。所以，赋值或者作为参数传递数组，都会copy整个数组（形参、实参的区别）。为了避免copy，可以传递数组的指针。

在这里提一下：`b := [2]byte{ 0x01, 0x02}`这时初始化了一个长度为2的字节数组，而非byte的slice。没错,`[]byte`是slice,`[n]byte`是数组！ `b := []byte{ 0x01, 0x02}`就是初始化了一个byte的slice。

下面开始讲slice。

slice的底层有一个array，所以可以从array转成slice；把一个slice赋值给另一个slice，两个slice共享同一个底层的array，修改array的值，对两个slice都有效。如下所示：

```
func main()  {
	array:=[5]int{0,1,2,3,4}
	a:=array[:]
	b:=array[1:]//同：b=a[1:] 
	array[4]=-1
	fmt.Println(a)
	fmt.Println(b)
	//[0 1 2 3 -1]
	//[1 2 3 -1]
}
```

好了，看slice的东西，其实只是为了弄清一句话：

>append 的结果是一个包含原 slice 所有元素加上新添加的元素的 slice。

>如果 s 的底层数组太小，而不能容纳所有值时，会分配一个更大的数组。 返回的 slice 会指向这个新分配的数组。

我的问题是这样的，socket编程处理数据秒不了要append两个slice，旧slice和新slice是不是都要放回池中。

好好看看slice之后，我有了这样的认识：slice其实只是指针，我们的pool其实要保留的就是slice所指向的数组。"如果 s 的底层数组太小，而不能容纳所有值时，会分配一个更大的数组。"如果旧slice的底层数组不够大，那么append操作会让这个旧的底层数组失去引用，面临回收。所以需要为了避免旧的底层数组被回收，让旧的slice的cap大一点吗？

我们细细想一下：

b=append(a,c...)。这样我们有三个slice，执行完毕会有两个或者三个底层数组参与（取决于a的底层数组够不够大）。为了尽可能地复用（将所有出现过的数组都放进pool），那么旧不要丢弃a的底层数组，最终只有两个底层数组参与。从试图将所有的数组放入pool的角度看，a的cap要大一点。

但是将所有数组都放进pool真的好吗？

对于leakypool，我觉得不好，因为leakypool限定了pool中可以有的数量，多了的最后都被GC。

对于sync.pool，我觉得好。我之前也说了，sync.pool中空闲的buf会被自动回收，那多放进来一些数组，也是得回收啊，为什么说好？举一个例子：某一时刻有2000个socket连接，共使用4000个底层数组，pool中缓存0个（4000个底层数组都被socket连接相关的处理持有）。下一时刻，只有1950个socket连接，供使用3900个底层数组，pool中缓存100个底层数组。这时新来10个socket连接，从pool中去除20个底层数组。然后，GC发生，pool中的80个底层数组被回收。这整个过程反应的是，pool随着需求增减缓冲的情形。唯一的不可控点是何时GC。只要gc不频繁，就是好的。

查了一下相关资料，gc发生的三种情况：

1. 自动GC：分配大于32k的内存时如果探测到堆上存活对象>memstats.gc_trigger（激发阈值）。这个32K是怎么来的？
2. 主动GC：调用runtime.GC()
3. 定时GC：如果两分钟没有进行GC，则进行一次


{{<youtube wji4g0JOMBE>}}