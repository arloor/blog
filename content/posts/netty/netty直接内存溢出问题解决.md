---
title: "Netty直接内存溢出问题解决"
date: 2018-12-10T20:24:51+08:00
author: "刘港欢"
categories: [ "netty"]
tags: ["Program"]
weight: 10
---

## 问题
自己用netty实现的代理，在测速、下载（跑满网速）的情况下总是会报OutOfDirectMemory异常。

## 原因及解决
在github netty项目下有这样一个[issue](https://github.com/netty/netty/issues/7699)。描述了这样一个问题。

总结一下里面说的。出现这个异常有两种情况，pooled buf没有release；写太快，超过了极限。
<!--more-->

重要摘录：

If i'm right, Netty in NIO-mode tries to offer a "unlimited" layer above a actually limited layer (socket, network). Netty uses DirectMemory to buffer performance differences between both layers. Means "writing to fast" that the buffer capacity in DirectMemory is overcharged by to much Write&Flush on a Netty context?
How can I balance this? Is there an API, where i can request the current loading and use this information to slow down my writes on Netty?

yes... you may try writing faster then the remote peer accepts.... You can check Channel.isWritable() to see if it is writable atm. ChannelInboundHandler.channelWritabilityChanged(...) will be triggered whenever the writability state of the Channel changes


## 设想的解决方案
既然是写太快了，就控制写的速度，主要就是监控isWritable了。

实现：因为是代理，所以场景是channel A读，转发给channel B(写)。这里的问题就是，A读的太快，B来不及写，全挤在（直接）内存中。所以需要反馈机制。代码如下：
```
 @Override
    public void channelWritabilityChanged(ChannelHandlerContext ctx) throws Exception {
        boolean canWrite = ctx.channel().isWritable();
        logger.warn(ctx.channel()+" 可写性："+canWrite);
        //流量控制，不允许继续读
        remoteChannel.config().setAutoRead(canWrite);
        super.channelWritabilityChanged(ctx);
    }
   ```
通过setAutoRead实际上就表示，selector不在关注该channel的op_read。也就不会再读了。


以下来自[http://www.cnblogs.com/yuyijq/p/4431798.html](http://www.cnblogs.com/yuyijq/p/4431798.html)
isWritable其实在上一篇文章已经介绍了一点，不过这里我想结合网络层再啰嗦一下。上面我们讲的autoread一般是接收端的事情，而发送端也有速率控制的问题。Netty为了提高网络的吞吐量，在业务层与socket之间又增加了一个ChannelOutboundBuffer。在我们调用channel.write的时候，所有写出的数据其实并没有写到socket，而是先写到ChannelOutboundBuffer。当调用channel.flush的时候才真正的向socket写出。因为这中间有一个buffer，就存在速率匹配了，而且这个buffer还是无界的。也就是你如果没有控制channel.write的速度，会有大量的数据在这个buffer里堆积，而且如果碰到socket又『写不出』数据的时候，很有可能的结果就是资源耗尽。而且这里让这个事情更严重的是ChannelOutboundBuffer很多时候我们放到里面的是DirectByteBuffer，什么意思呢，意思是这些内存是放在GC Heap之外。如果我们仅仅是监控GC的话还监控不出来这个隐患。

那么说到这里，socket什么时候会写不出数据呢？在上一节我们了解到接收端有一个read buffer，其实发送端也有一个send buffer。我们调用socket的write的时候其实是向这个send buffer写数据，如果写进去了就表示成功了(所以这里千万不能将socket.write调用成功理解成数据已经到达接收端了)，如果send buffer满了，对于同步socket来讲，write就会阻塞直到超时或者send buffer又有空间(这么一看，其实我们可以将同步的socket.write理解为半同步嘛)。对于异步来讲这里是立即返回的。 

那么进入send buffer的数据什么时候会减少呢？是发送到网络的数据就会从send buffer里去掉么？也不是这个样子的。还记得TCP有重传机制么，如果发送到网络的数据都从send buffer删除了，那么这个数据没有得到确认TCP怎么重传呢？所以send buffer的数据是等到接收端回复ACK确认后才删除。那么，如果接收端非常慢，比如CPU占用已经到100%了，而load也非常高的时候，很有可能来不及处理网络事件，这个时候send buffer就有可能会堆满。这就导致socket写不出数据了。而发送端的应用层在发送数据的时候往往判断socket是不是有效的(是否已经断开)，而忽略了是否可写，这个时候有可能就还一个劲的写数据，最后导致ChannelOutboundBuffer膨胀，造成系统不稳定。

所以，Netty已经为我们考虑了这点。channel有一个isWritable属性，可以来控制ChannelOutboundBuffer，不让其无限制膨胀。至于isWritable的实现机制可以参考前一篇。

## 效果

在使用`setAutoRead`调整流量之后，不会出现之前下载一百多M东西，内存就占1G的问题，可以确定这个问题被解决。