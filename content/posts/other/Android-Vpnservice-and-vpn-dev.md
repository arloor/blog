---
title: "安卓Vpn开发思路"
author: "刘港欢"
date: 2019-01-30
categories: [ "网络编程"]
tags: ["program"]
weight: 10
---

经过2个月的开发，我的http代理可以说没有遗憾了，当然还有可以改进的地方，比如多用户认证啥的，但是没有必要啦。

为了在安卓上也能愉快地使用自己开发的代理，研究了一下安卓Vpnservice，在此记录一下当前的进度，并确定以后的开发思路。
<!--more-->

# 前言——几种不同的代理方式

在网上找了一篇我觉得讲的比较对和易懂的[博客](https://blog.csdn.net/binhoubin/article/details/63251662):引用开始

翻墙有几种方式：

1：vpn和各种自定义的vpn；它们是把iOS的ip数据包的内容通过一个tcp转发到vpn服务器，然后在服务器上创建一个tun虚拟网卡，再把接收到的ip数据包内容通过系统的函数发给网卡，然后网卡再把这个原始的ip数据包内容加上自己的ip地址等信息发送出去，对方接收到数据之后，解析出来，在ip之上的内容是没有改变的，所以tcp的连接之类的整个过程是不会影响的，只是在返回数据时，它识别到的源ip地址变成了服务器上虚拟网卡的地址；

2：http代理，现在主流的系统都支持设置http代理；它们的原理是客户端系统在发送http请求时，并不是把数据包发给真正的目的地址，而是与代理服务器创建一个tcp连接，把http包发送给代理服务器，这样代理服务器就可以接收到一个http请求，然后再从请求中得到真正的目的地址，把这个请求转发给目的ip，所以从服务器上来看，就是一个最基本的http服务器而已，只是它的目的从处理请求变成了转发请求；整个请求过程中，在http层上的内容不会改变，但是在tcp这一层会改变；对于客户端操作系统来说，在发送http之前，我们要先与目的地建立连接，但是操作系统并不知道我们是不是用来发送http的，所以它就不能让我们去连接代理服务器，由此可知，http代理的客户端处理不会是操作系统来提供，而是应该上层应用程序来提供；比如提供一个发送http的函数，那么在这个函数中，我们就可以知道它肯定是用来发http的，就可以去连接代理服务器而不是直接的目标服务器；这就解释了为什么有些http请求不走代理（比如libcurl创建的http请求，大部分的linux终端命令），因为这要库去支持，不过现在主流的浏览器都支持；

3：socks5代理，socks5代理中，客户端与代理服务器tcp连接上后，客户端会向代理服务器发送协商数据和真正的目标地址，代理服务器就与直接的目标地址连接，然后再把后续的请求转发到目标地址上；相对于http代理来说，socks5代理不区分上层协议，所以可以在系统库中去实现；

翻墙原理上是这几个基本的方法，vpn的ip数据转发，http代理的http数据转发，sock5代理的tcp,udp数据转发。

但是由于这几种方式都有它的明确的特征和易于识别，比如vpn,sock5代理特征明显，http代理数据明文可见，导致了用来翻墙不稳定(当然自定义vpn可以解决这个问题)；

ShadowSocks的优点为sock5代理类似，由于不是在ip层面上，所以数据包相对来说要小（不用传ip数据包头与tcp数据包头，所有理论上它要快一些）

所以现在大家都在用ShadowSocks，在pc端它的实现比较简单，因为它只要在本地实现一个sockt5代理服务器就好了，这样在sock5代理服务器内部，就能得到tcp数据的内容，把内容通过自己的协议转发到远程服务器，让远程服务器转发tcp的内容；相当于本地和服务器上两边实现了类似的socket5代理；

但是对于iOS，android而言，sock5代理在非越狱和root的情况下不被支持，不过能得到ip数据包，所以要想办法把ip数据包转成tcp/udp的包，这样才能分析出tcp/udp中的内容进行转发；

这里引入一个开源的tcp/ip协议栈，它简单占用内存小，所以能运行在移动设备上，我们要的是让它接收系统的ip数据包，分析出tcp/udp数据内容。但是对于标准的tcp/ip协议栈，由于系统的ip数据包发送的目的地与这个协议栈运行的地址，所以正常情况下它是不会被解析出来的，不过由于这个协议栈相对来说简单，所以我们可以进行改造，让它不管是去哪里的ip数据包，都像本来就是发送给他的一样；这样它能accept 发给其它地址的tcp的连接，可以直接读取tcp连接之后的发送的内容；这也就是为什么叫tun2socks了（改造的过程其实很简单，只是把在tcp段组成tcp时的ip和port限制去掉就行了），并且由于它能让我们得到tcp发送的数据包，这样就不用另一个socks代理了。


引用结束。

我写的[HttpProxy](https://github.com/arloor/proxy)就是一个http代理（tcp代理），而安卓、iphone要求的是一个VPN（因为手机只给ip数据报）。socks则是不管应用层是tcp还是udp。所以从通用性上讲，VPN>socks>tcp代理。我的HttpProxy在这个时代可以说超级菜鸡了。

引用部分最后提到的开源tcp/ip协议栈是iwIP（我在别的博客看到的，可能我引用的部分是抄的别人的。。），引用还提到的tun2socks，则将在[解决方案二](#解决方案二)中详细解释。


# VpnService和安卓VPN例子

VpnService是开发安卓VPN的基础，下面是[官方文档的阐释](https://developer.android.com/reference/android/net/VpnService)

 VpnService is a base class for applications to extend and build their own VPN solutions. In general, it creates a virtual network interface, configures addresses and routing rules, and returns a file descriptor to the application. Each read from the descriptor retrieves an outgoing packet which was routed to the interface. Each write to the descriptor injects an incoming packet just like it was received from the interface. The interface is running on Internet Protocol (IP), so packets are always started with IP headers. The application then completes a VPN connection by processing and exchanging packets with the remote server over a tunnel.

 上面的阐释的重点是：虚拟一个网卡、返回文件描述符、 读写的内容是ip数据报

 安卓example的[ToyVpn](https://android.googlesource.com/platform/development/+/master/samples/ToyVpn)；初步搭一个vpn应用的框架可以看[这里](https://www.tuicool.com/articles/uuiMje)，这个仅仅是搭建了框架，功能（ip数据包的收发）则没有实现


# 所以问题来了

Vpnservice是安卓提供给开发者用于开发自己的VPN的服务。开发者继承这个Vpnservice，从而实现VPN。手机本身是有一块网卡，安卓虚拟出一个网卡，然后通过NAT，将真实网卡上的出站流量转发到虚拟网卡上，然后Vpnservice获取这个虚拟网卡上的“流量”，并转发给Vpn的服务端。其实还是挺好理解的。问题在于，上面说的流量，并不是传输层的tcp/udp流量，而是ip数据报。

tcp代理所操作的是tcp包，现在要处理ip数据报。而且java语言只提供了传输层（tcp/udp）的socket传输api。这意味着，开发Vpn必定有一部分需要使用其他语言（C/C++）。

看安卓example的[ToyVpn](https://android.googlesource.com/platform/development/+/master/samples/ToyVpn)中server的代码，发现他的代码就是直接open /dev下的网卡文件，然后读写来收取ip数据（一切皆文件真的骚。。）

# 解决方案一

一句话：将ip数据报通过Udp发送给代理服务器，代理服务器解包后得到原始的ip数据报，通过C/C++写进网卡文件。

通过Udp传输的原因是，Udp（用户数据报）是ip数据报的简单包裹，不像tcp数据包那样，增加了很复杂的东西，也不进行失败重传等操作。要清楚，我们这里传输的是较底层的ip数据报，在ip数据报的上层，可能是UDP，也可能是TCP，不管传输层是什么协议，消息的正确性，失败重传等等，都有人做过，我们只要传就好了，所以用UDP是最好的。

通过C/C++写进网卡，这个可能要用JNI，没用过，学学吧。

其实就是ip over udp。下面是一段对这个概念的阐释：[原文](https://www.cnblogs.com/zhangzl2013/p/foo_over_udp.html)

数据报文封包和UDP隧道相对来说还是比较容易理解的概念。试想一个进入隧道的TCP数据包：

![](/img/090749575304490.jpg)


这个数据报有正常的IP和TCP头，后面是用户要发送的数据。封包的过程如下：

![](/img/090751088583813.jpg)


这样，这个数据包就是一个UDP数据包，里面装的是TCP数据包。系统可以将他想普通的UDP数据包一样发送；在接收端，额外的UDP头部被去掉后，原始的包含tcp消息的ip数据报经修改后（修改源ip地址）继续进入网络堆栈进行处理。

这其实也就是正经的VPN的概念了。这也是ToyVpn所采用的实现方式。


# 解决方案二

在安卓机上解析ip数据报，最终拿到tcp/udp的数据部分，最后传输。这意味着需要处理tcp协议栈中的握手等等，怎么看怎么不靠谱，主要是难度大。

直到看到了tun2socks和iwIP，才意识到这个有难度的轮子其实已经有人造了。安卓使用最广泛的翻墙工具就是shadowsocks了，赫然看到[shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)的readme中的“OPEN SOURCE LICENSES”含有tun2socks。行吧，shadowsocks都用这个技术，够权威了。

下面就说，什么是tun2socks，直接引用别人的[博客](https://blog.csdn.net/dog250/article/details/70343230)了。这个博主csdn排名15，牛逼

## 总览
tun2socks实现一种机制，它可以让你无需改动任何应用程序而完全透明地将数据用socks协议封装，转发给一个socks代理，然后由该代理程序负责与真实服务器之间转发应用数据。使用代理有两种方式，一种是你自己显式配置代理，这样一来，数据离开你的主机时它的目标地址就是代理服务器，另一种是做透明代理，即在中途把原始数据重定向到一个应用程序，由该代理程序代理转发。tun2socks在第二种的基础上，完成了socks协议的封装，并且实现该机制时使用了强大的tun网卡而不必再去配置复杂的iptables规则。

## 什么是socks代理
本文以TCP为例，就不再提UDP了。所以说，简单点，把socks代理称为带有认证功能的TCP代理是合适的。

TCP代理非常容易理解，然而纯粹的TCP代理并不实用，必然要加入一些控制功能，比如谁可以被代理，谁不能被代理，如何认证，最多可以代理多少路的请求等等。有了这些控制手段，TCP代理才真正变得实用起来。

## 附：socks代理如何运作

socks的运作原理非常简单，就是在TCP数据外包一层socks协议头，到达socks代理服务器后，脱去socks头，然后通过socks服务器与真实服务器之间建立的连接将TCP裸数据传给真实服务器。如下图所示：

![](/img/20170422014544920.png)

请注意，socks代理并不理解任何应用层协议，它只是负责转发应用层数据而已，这一点使socks成为了一个通用的代理协议，这一点和HTTP代理服务器是完全不同的。

## 什么是tun网卡

这个就不再多说。之所以有这个小节是为了文章的完整性。也是为了给初学者一个完整的提纲来更深入的学习。

## 什么是透明代理

我理解的透明代理就是“偷偷的给你做代理”，这一点与你在浏览器里显式设置socks代理服务器完全不同。透明代理就比如说下面这样子：

![](/img/20170422014626480.png)

要实现这一点有很多方式，比如你可以用Linux的TProxy+Policy routing机制，关于这种方式请参见[《socket的IP_TRANSPARENT选项实现代理》](https://blog.csdn.net/dog250/article/details/7518054)，然而，很多时候，这种方式行不通。

## 现实中的需求

如果给一个Linux的root账户，那么几乎可以随意显摆，而很多时候这并不可能。比如Android系统就不能随意root，这就意味着你无法在Android系统上随意地配置iptables规则，路由等。那么想在Android系统上免root实现一个透明代理，就需要别的办法。而tun2socks提供了一种这样的办法。

## tun2socks能做什么
如果理解了上述所有的概念，那么tun2socks就不剩下什么了。先给出一个总览图：

![](/img/20170422014704077.png)

通过上图，我们看到tun2socks可以被拆解出三个部分，即tun网卡部分，协议处理部分以及socks转换部分，这三部分在tun2socks的处理流程是串行的。我来一个一个说。

### 1.tun网卡部分

该部分解决了一个基本的问题，即“如何获取原始的数据包”。拿到了数据包，什么都好办了。

### 2.协议处理部分

如果你想做透明代理，那么你必须“想办法把数据流导入到本地”，完成这件事有好多种办法，以Linux为例，比如做一个DNAT即可完成，再比如如上所述，用tun网卡直接把原始数据包捕获到一个应用程序。显然tun2socks采用了后者。

两者有何不同呢？

很大的不同。如果使用DNAT的话，目标地址和端口将会是本地的一个代理程序，比如socks代理，那么操作系统的协议栈会自动将数据包交到该代理程序，除了这个DNAT之外不需要再做任何操作。而使用tun捕获数据包的话，由于只是捕获到了IP数据报文，这意味着你要自己处理IP层以上的逻辑，比如TCP按序交付，TCP状态处理，TCP拥塞控制，你要确保代理程序收到的数据包看起来是“经过协议栈处理过的数据包”，“就像是直接从socket的recv接口读到的一样”。

tun2socks使用现成的lwip来完成了协议处理。lwip是一个轻量级的用户态协议栈，非常适合完成这种协议适配工作。


### 3.socks协议转换部分

经过第2部分，即协议处理之后，现在tun2socks拿到的已经是源主机试图发送到原始目标主机的裸数据了，接下来它可以做的事情可就多了，当然可以用socks协议封装裸数据，将其发送给一个socks代理程序。


### tun2socks与OpenVPN

只要是使用了tun网卡获取原始数据，那么任何框架都会面临一个必须回答的问题，即拿到原始的IP数据报文或者以太帧之后，下一步如何处理这些数据。OpenVPN和tun2socks显然是给出了两种不同的回答，而这不同的回答即是OpenVPN和tun2socks之间唯一的不同。

引用结束，作者说tun2socks和OpenVPN采用了两种完全不同的解答，其实也就是这里的tun2socks和OpenVpn了。

看到这里不禁感叹前人的智慧，存在即合理。看起来，我的http代理用于翻墙只是一种过时的选择了，的确是socks的时代，特别是有了tun2socks。