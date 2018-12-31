---
title: "proxynew-基于netty的翻墙代理"
date: 2018-12-31
author: "刘港欢"
categories: [ "java","网络编程","netty"]
tags: ["Program"]
weight: 10
---

暑假使用java NIO实现了一个java http代理。那个http代理远远不算完善：两个线程，不能翻墙。之后学习了netty，并且使用netty实现了一个可翻墙的http代理，经过一个多月的使用，十分满意。今天来记录一下这里面值得写下来的东西。

先放项目地址[proxynew](https://github.com/arloor/proxynew)<!--more-->

# 如何翻墙

翻墙其实很简单：tcp编程+加解密+（流量伪装）

- tcp编程解决的是，获取浏览器的请求、改造（解析+加密+解密）请求、转发请求、获取相应、转发响应。
- 加解密解决的是，瞒过GFW的眼睛，实现翻墙
- 流量伪装：经过加密的流量虽然可以瞒过GFW，但是可以确定不是正常的流量（例如http、https等）

流量伪装不是翻墙必须的。（不确定对不对start）但是在有些情况下，这很重要。很火的shadowsocks，有一种嗅探方法可以确定流量是不是ss的。原理要牵扯到socks5协议和shadowsocks实现。socks5协议如同http协议一样，是对tcp报文格式的一种约定，约定握手、报文开头等。shadowsocks使用socks5协议，并且自定义了代理的报文。嗅探方法其实就是嗅探这个报文格式，为了应对嗅探，伪装成别的流量就很有价值啦。（不确定对不对end）

我的代理没有做流量伪装，压根不是shadowsocks，也没有用任何协议。关于协议，这么理解吧，协议就是对报文包装格式的定义。网络层下面的几层定义什么帧、数据报、tcp报文，无非做的是对数据的拆解、包装，再加上一些字段比如目标ip等等。应用层的http、socks5则定义了tcp报文的格式，http请求的格式、响应头等等，socks握手等等。而我的代理为了简单，没有定义某种格式，所以谈不上使用了“某种协议”。

所以，shadowsocks的实现是 tcp编程+sock5协议+加解密+（流量伪装），而我的没有使用协议。

# 什么是netty

netty是java实现的高性能网络通信框架。在我眼里，netty做了这么几件事：实现reactor模式，事件驱动的编程范式，使用pipeline架构模式管理socket连接的生命周期。

## reactor模式

在[proxyme-基于javanio的http代理](/posts/proxyme-基于javanio的http代理/)提到过，可以优化的点是引入reactor模式，使用多个线程来处理多个socket连接。netty使用了`EventLoopGroup`（多个线程的组）来管理多个连接。每一个连接生效之后，就会在EventloopGroup中分配一个EventLoop给该连接。这个EventLoop实际上就是一个线程，这个线程将会一直负责socket连接的整个生命，由生到死。这个EventLoop负责在某些事件发生时，调用相应的方法。比如发生读事件，就会调用pipeline中所有ChannelInboundHandler的ChannelRead()方法。

提到reactor模式不得不提一下go。go语言使用goroutine来实现并行。`go someFunction(a,b,c,d)`就开启了一个新的go程。所以在go中实现reactor模式十分容易：accept到一个连接，就`go handlerConnection(theConnection)`，这样就使用一个go程去管理该生命周期。

在go中实现reactor模式很简单，其实在java中实现也不难。无非就是新建一个线程/提交到线程池，代码也就是`new Thread().start()`或者`excutors.submit(task)`这样。

public interface Dispatcher {
这里又要向[java-design-pattern](https://github.com/iluwatar/java-design-patterns/tree/master/reactor)学习了。他对事件处理引入了一个Dispatcer接口（接口就有很多中实现啦，单线程的分派、线程池的分派、自己实现的线程池的分派）。

Dispatcher接口
```java
public interface Dispatcher {
  void onChannelReadEvent(AbstractNioChannel channel, Object readObject, SelectionKey key);
  void stop() throws InterruptedException;
}
```
一个Dispatcher实现
```java
public class ThreadPoolDispatcher implements Dispatcher {
  private final ExecutorService executorService;
  public ThreadPoolDispatcher(int poolSize) {
    this.executorService = Executors.newFixedThreadPool(poolSize);
  }

  @Override
  public void onChannelReadEvent(AbstractNioChannel channel, Object readObject, SelectionKey key) {
    executorService.execute(() -> channel.getHandler().handleChannelRead(channel, readObject, key));
  }
  @Override
  public void stop() throws InterruptedException {
    executorService.shutdown();
    executorService.awaitTermination(4, TimeUnit.SECONDS);
  }
}
```
可以看到，核心也就是一行`executorService.execute(lambda)`。但是就是要抽取出（!增加!）一个Dispatcher，这样我们要写的不是`executorService.execute(lambda)`而是`dispatcher.onChannelReadEvent(.....)`。（搞得和事件驱动有点像，其实reactor确实有点事件驱动的意思）

从这里也可以看到，其实设计模式就是在做抽象出一个东西（增加）的事情。所以使用设计模式其实在做的是：思考玩功能的实现之后，思考代码的组织，而这个组织的过程是在增加。

抽取共同的东西、增加——设计模式


## Event Driven 事件驱动

`go handler(theConnection)`可以很方便地实现netty的reactor模式的一部分功能，但不是全部。不加入事件驱动的go代码大概就是这样了：

```
func handleProxyConnection(proxyConn, localConn net.Conn) {
	for {
		var buf = make([]byte, 2048)
		numRead, err := proxyConn.Read(buf)//一直读，下面是读结果的处理....................
		if nil != err {
			fmt.Println("读远程出错，", err)//出错啦，下面是异常的处理.........................
			proxyConn.Close()
			proxyConn.Close()
			break
		}
		fmt.Println("从远程读到：", numRead, "字节")
		writeAllBytes(localConn, proxyConn, buf, numRead)
	}
}
```
这段代码是真实的我在使用的代码（代理的客户端）。可以看到，不使用`事件驱动`就是这样，事件和事件的处理放在了一起。我们一般的做法是，将代码隔离成方法。就像上面那样，将写定义在`writeAllBytes`函数中。这样做就实现了，事件名称（名称、声明...）和事件的处理（定义）相分离。但是这还不是事件驱动，事件驱动是真正实现事件接收和事件处理分离。

一个典型的[事件驱动](https://github.com/iluwatar/java-design-patterns/tree/master/event-driven-architecture)：

```java
//事件
public interface Event {
  Class<? extends Event> getType();
}
//事件处理
public interface Handler<E extends Event> {
  void onEvent(E event);
}

//事件分派器
public class EventDispatcher {
  private Map<Class<? extends Event>, Handler<? extends Event>> handlers;
  public EventDispatcher() {
    handlers = new HashMap<>();
  }
  public <E extends Event> void registerHandler(Class<E> eventType,
                                                Handler<E> handler) {
    handlers.put(eventType, handler);
  }
  @SuppressWarnings("unchecked")
  public <E extends Event> void dispatch(E event) {
    Handler<E> handler = (Handler<E>) handlers.get(event.getClass());
    if (handler != null) {
      handler.onEvent(event);
    }
  }
}
```
可以看到，事件与事件的真正分离，各自与dispacther耦合，可以认为是事件不依赖事件处理，而依赖事件分派器。！！！所以实现事件驱动不难，只要引入事件分派器！就可以称为事件驱动了，谨记。


## pipeline架构模式

有的事情，一步做不好，我分几步做。所以好几个handler组成一个pipeline，一个handler的工作做完了，我fire下一个handler，不多说啦。

reactor、事件驱动、pipeline，这三个东西是netty最重要的抽象了。至于EventLoopGroup、EventLoop则是实现上的事情。

netty的另一个贡献，直接内存我只会用，确保不用错，但没有深入，不扯。

# OutOfDirectMemory异常

这个问题的已经在[netty直接内存溢出问题解决](/posts/netty直接内存溢出问题解决/)详细进行了解释。但还是要在这提一下，因为这个坑只有遇到才会知道吧，也算是一种独特的经历了。详情见那一篇文章啦。

# 总结

经历了自建ssr被封，linux下没有好的客户端种种事情之后，现在终于有了好用的自己的代理，很是舒服。最关键的是用自己写的，心里明明白白、胸有成竹的感觉。

额外分享一个小诀窍，linux快速设置shell代理
```
#vim $PATH/pass

#! /bin/bash
# 设置http代理，使用方法：
# 在terminal中输入 ". pass" （前提是将此路径加入path）
# 效果：该terminal将使用如下的代理
export http_proxy=http://127.0.0.1:8081
export https_proxy=http://127.0.0.1:8081
```
以后，输入`. pass`，当前终端就可以使用这个代理了。原因：source/. 是在当前shell执行的，不会新建bash

心心念念也算有一年多了，至此终于写出了一个完善的http翻墙代理，也算是完成了一个夙愿！