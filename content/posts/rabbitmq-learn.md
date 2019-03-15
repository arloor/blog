---
title: "RabbitMQ的使用"
date: 2019-03-14T21:19:06+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
---

# rabbitmq java api使用demo

详情见github项目[rabbitmqdemo](https://github.com/arloor/rabbitmqdemo)

# 在centos7上安装RabbitMQ 3.7.13

RabbitMQ是使用Erlang编写的消息中间件，因此首先需要安装Erlang，而且RabbitMQ与Erlang版本有着对应关系。

首先到[RabbitMQ 3.7.13的realse页面](https://github.com/rabbitmq/rabbitmq-server/releases/tag/v3.7.13)。其中提到3.7.13版本的RabbitMQ需要20.3.x及以后的Erlang版本，并且说了一句，可能21.x的有某种问题，为了避免这个问题，直接使用20.3.x版本的Erlang。

## 安装Erlang 20.3.8.20

接下来就安装这个版本的Erlang。[安装guide](http://www.rabbitmq.com/install-rpm.html)提到安装Erlang有很多种方法，其中说到，RabbitMQ维护了一个去除多余依赖/模块的Erlang版本，我们就用这个RabbitMQ官方维护的Eralng吧。在[packagecloud](https://packagecloud.io/rabbitmq/erlang)中下载[erlang-20.3.8.20-1.el7.x86_64.rpm](https://packagecloud.io/rabbitmq/erlang/packages/el/7/erlang-20.3.8.20-1.el7.x86_64.rpm)：使用网页右侧提供的wget下载rpm包到vps，然后使用

```
rpm -i erlang-20.3.8.20-1.el7.x86_64.rpm
```

安装该rpm包

![](/img/Erlang4RabbitMQ-install.png)

另外，该rpm包也可以在[github realease](https://github.com/rabbitmq/erlang-rpm/releases/tag/v20.3.8.20)找到。

## 安装RabbitMQ 3.7.13

前往[packagecloud](https://packagecloud.io/rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.13-1.el7.noarch.rpm)，使用页面右方提供的wget方法下载，然后使用

```
rpm -i rabbitmq-server-3.7.13-1.el7.noarch.rpm
```

进行安装。PS:[RabbitMQ 3.7.13的realse页面](https://github.com/rabbitmq/rabbitmq-server/releases/tag/v3.7.13)同样可以下载rpm包。

之后就可以使用如下命令启动rabbitmq的服务

```
service rabbitmq-server start
```
# rabbitmqctl命令行工具

其他命令和命令详解参见[rabbitmqctl命令行工具](http://www.rabbitmq.com/rabbitmqctl.8.html)   

我用到的命令如下   

## list_users

显示存在的用户。效果如下：  
```
PS C:\Windows\system32> rabbitmqctl list_users
Listing users ...
arloor  [administrator]
guest   [administrator]
```

图中的arloor是自行添加的。guest是rabbitmq自动生成的，密码为“guest”。  
可以看到 后面的`user_tag`都显示为`[administrator]`.
关于`user_tag`。最初只要知道`[administrator]`具有最高权限（对虚拟主机的访问权限与此不同），其他user_tag有monitoring、policymaker、management、空  

## add_user username password

`rabbitmqctl add_user username password`  
增加用户。   
新增加的用户user_tag为空，表示只是简单的生产者消费者。

## set_user_tags username administrator

`rabbitmqctl set_user_tags username administrator`  
赋予某个用户超级管理员权限。

## 关于vhosts的一些命令

注意：这里的都可以通过rabbitmq的网页管理控制台达到相同目的，但还是记录一下   

### rabbitmqctl list_vhosts

`rabbitmqctl list_vhosts`显示所有虚拟主机的名字

### set_permissions [-p vhost] user conf write read

`rabbitmqctl set_permissions -p /myvhost tonyg “^tonyg-.*” “.*” “.*”`  给用户对/myvhost虚拟主机的一些权限。


# RabbitMQ 网页管理控制台

使用`rabbitmq-plugins enable rabbitmq_management`开启。  
然后重启rabbitmq服务，之后就可以打开[http://localhost:15672/](http://localhost:15672/)进行网页的管理。  

# AMPQ 协议

这里才讲协议，因为感觉我是一个先动手再动脑的人，理论必须先有实践才能懂的人。。实际过程中，我也是先看了java的代码遇到了exchange、binding、queue才去看这些是什么意思。   

## vhost 虚拟主机

在RabbitMQ中用户只能在虚拟主机(vhost)的粒度进行权限管理，参见上面的rabbitctl 命令。rabbitmq默认有一个“/”的虚拟主机。   

## queue 队列

queue队列是消息的容器，由consumer通过程序（这里是java）建立。queue一旦建立，consumer就会等待消息到来，到来就取走进行处理。  
如果consumer试图重复创建同一个名字的queue，rabbitmq会忽略。同时一旦queue被创建，那么queue的属性就不可修改了。因为这些特点，queue的名字和属性适合写进程序的配置文件。

## exchange 交换机 bindings 路由表

在讲exhange之前讲这样一段废话：queue由consumer创建了，但是并没有消息发送给queue。消息要发送给某一个queue，需要自己携带一个route key（路由键），通过exchange（交换机）查看自己的bindings（路由表）决定将消息发送给哪个queue。

疑问？exchange也有consumer建立？疑问确定，consumer需要注册自己的queue以及发送到该queue的exchange，以及binding。

换句话说，一个实例只需要注册自己消费的那部分。发送的那部分，所需要知道的exchange及路由键不需要注册。

一个binding就是一个基于route key将exchange和queue连接起来的路由规则。   
exchange根据bindings将消息发送给queue。   
这里的一个交换机对应一个进程。注意！这意味着，交换机的声明要谨慎一点，就是不能随意的声明多个交换机！这会丢人的。。  

整理一下，创建了一个queue，又创建了一个exchange，这时候需要建立binding，确定消息的路由关系。示例代码：
```
channel.exchangeDeclare(exchangeName, "direct", true);
String queueName = channel.queueDeclare().getQueue();
channel.queueBind(queueName, exchangeName, routingKey);
```

## exchange的类型：

`channel.exchangeDeclare(exchangeName, "direct", true);`的第二个参数

- Fanout Exchange – 不处理路由键。你只需要简单的将队列绑定到交换机上。一个发送到交换机的消息都会被转发到与该交换机绑定的所有队列上。很像子网广播，每台子网内的主机都获得了一份复制的消息。Fanout交换机转发消息是最快的。

- Direct Exchange – 处理路由键。需要将一个队列绑定到交换机上，要求该消息与一个特定的路由键完全匹配。这是一个完整的匹配。如果一个队列绑定到该交换机上要求路由键 “dog”，则只有被标记为“dog”的消息才被转发，不会转发dog.puppy，也不会转发dog.guard，只会转发dog。

- Topic Exchange – 将路由键和某模式进行匹配。此时队列需要绑定要一个模式上。符号“#”匹配一个或多个词，符号“*”匹配不多不少一个词。因此“audit.#”能够匹配到“audit.irs.corporate”，但是“audit.*” 只会匹配到“audit.irs”。我在RedHat的朋友做了一张不错的图，来表明topic交换机是如何工作的：

# 持久化 durable

队列和交换机有一个创建时候指定的标志durable，直译叫做坚固的。durable的唯一含义就是具有这个标志的队列和交换机会在重启之后重新建立，它不表示说在队列当中的消息会在重启后恢复。   
因为binding是依赖exchange和queue的，因此有以下几个特性：
- exchange和queue的durable标志一样才能绑定
- exchange和queue的都是durable的那么binding也是持久化的，反之不是

## 消息持久化？

要考虑的第一个问题：真的需要消息持久化吗？未处理的消息需要在重启之后继续处理吗？考虑这个问题的原因是：消息的丢失和消息写入磁盘持久化的权衡。  

下面谈怎么做到消息持久化：Delivery Mode。  
在将消息投递到exchange之前，将Delivery Mode设置为2即可。  



