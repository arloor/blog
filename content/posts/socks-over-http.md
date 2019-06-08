---
title: "Sogo—使用http协议进行混淆/伪装的socks5代理"
date: 2019-04-10T14:24:10+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
- sock5
- sock5代理
- http混淆
---

之前写了一个http代理，用起来也是十分地舒服，但是有几个点还是有些遗憾的：

- http代理只能代理http协议，相比socks5代理不够通用。。
- netty是个好框架，但是java占用内存是真的多。。

所以，我又写了一个socks5代理，起名叫[sogo](https://github.com/arloor/sogo)。

sogo本身包含sogo(client)和sogo-server。如果把sogo和sogo-server看成一个整体，一个黑盒，这个整体就是一个socks5代理。sogo(client)与本地电脑交互；sogo-server与目标网站交互；sogo(client)和sogo-server之间的交互就是http协议包裹payload进行通信。
<!--more-->

## 特性

sogo项目最好的两个特性如下：

1. 使用http包裹payload(有意义的数据)。
2. 将sogo-server所在的ip:端口伪装成一个http网站。

效用、坚固、美观——对软件产品的三个要求。上面两个特性，既可以说是坚固，也可以说是美观，至于效用就不用说了，在这里谈坚固和美观的前提就是效用被完整地实现。用通俗地话来说，这个代理的坚固和美观就是：伪装、防止被识别。

## 处理socks5握手——对socks5协议的实现

sogo(client)与本地电脑交互，因此需要实现socks5协议，与本地用户（比如chrome）握手协商。

一个典型的sock5握手的顺序：

1. client：0x05 0x01 0x00
2. proxy: 0x05 0x00 
3. client: 0x05 0x01 0x00 0x01 ip1 ip2 ip3 ip4 0x00 0x50
4. proxy: 0x05 0x00 0x00 0x01 0x00 0x00 0x00 0x00 0x10 0x10
5. proxy盲转发client与server之间的流量

这一部分代码见如下两个函数：

```java
//file: sogo/main.go

//读 5 1 0 写回 5 0
func handshake(clientCon net.Conn) error {
	var buf = make([]byte, 300)
	numRead, err := clientCon.Read(buf)
	if err != nil {
		return err
	} else if numRead == 3 && buf[0] == 0X05 && buf[1] == 0X01 && buf[2] == 0X00 {
		return mio.WriteAll(clientCon, []byte{0x05, 0x00})
	} else {
		log.Printf("%d", buf[:numRead])
		return mio.WriteAll(clientCon, []byte{0x05, 0x00})
	}
}

func getTargetAddr(clientCon net.Conn) (string, error) {
	var buf = make([]byte, 1024)
	numRead, err := clientCon.Read(buf)
	if err != nil {
		return "", err
	} else if numRead > 3 && buf[0] == 0X05 && buf[1] == 0X01 && buf[2] == 0X00 {
		if buf[3] == 3 {
			log.Printf("目的地址类型:%d 域名长度:%d 目标域名:%s 目标端口:%s", buf[3], buf[4], buf[5:5+buf[4]], strconv.Itoa(int(binary.BigEndian.Uint16(buf[5+buf[4]:7+buf[4]]))))
			writeErr := mio.WriteAll(clientCon, []byte{0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10})
			return string(buf[5:5+buf[4]]) + ":" + strconv.Itoa(int(binary.BigEndian.Uint16(buf[5+buf[4]:7+buf[4]]))), writeErr
		} else if buf[3] == 1 {
			log.Printf("目的地址类型:%d  目标域名:%s 目标端口:%s", buf[3], net.IPv4(buf[4], buf[5], buf[6], buf[7]).String(), strconv.Itoa(int(binary.BigEndian.Uint16(buf[8:10]))))
			writeErr := mio.WriteAll(clientCon, []byte{0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10})
			return net.IPv4(buf[4], buf[5], buf[6], buf[7]).String() + ":" + strconv.Itoa(int(binary.BigEndian.Uint16(buf[8:10]))), writeErr
		} else {
			return "", errors.New("不能处理ipv6")
		}

	} else {
		return "", errors.New("不能处理非CONNECT请求")
	}
}
```

完成handshake, getTargetAddr 之后，chrome就会发送真实的http请求了，sogo(client) 要做的就是将这部分http请求进行加密，然后加上http请求的头，发送到sogo-server。

## 使用http包裹payload

第一部分：如何将真实的http请求，再进行加密，最后加上假的http请求头，变成伪装好的http请求，发送给sogo-server。


```java
//file: sogo/mio/prefix.go
var fakeHost = "qtgwuehaoisdhuaishdaisuhdasiuhlassjd.com"  //虚假host

func AppendHttpRequestPrefix(buf []byte, addr string) []byte {
	Simple(&buf, len(buf))//对真实的http请求的简单加密
	// 演示base64编码
	addrBase64 := base64.NewEncoding("abcdefghijpqrzABCKLMNOkDEFGHIJl345678mnoPQRSTUVstuvwxyWXYZ0129+/").EncodeToString([]byte(addr))
	buf = append([]byte("POST /target?at="+addrBase64+" HTTP/1.1\r\nHost: "+fakeHost+"\r\nAccept: */*\r\nContent-Type: text/plain\r\naccept-encoding: gzip, deflate\r\ncontent-length: "+strconv.Itoa(len(buf))+"\r\n\r\n"), buf...)
	return buf
}
```

包裹完毕之后返回的[]byte就可以发送给sogo-server了。

第二部分：将sogo-server从目标网站获得的真实响应进行简单加密，包裹http响应头，发送给sogo(client)。




```java
//file: sogo-server/mio/prefix.go
func AppendHttpResponsePrefix(buf []byte) []byte {
	Simple(&buf, len(buf))
	buf = append([]byte("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: "+strconv.Itoa(len(buf))+"\r\n\r\n"), buf...)
	return buf
}
```

包裹完毕之后返回的[]byte就可以发送给sogo(client)了。

## 解包伪装好的请求、响应

先看以下伪装好的请求的样子：

```shell
POST /target?at={targetAddrBase64} HTTP/1.1
Host: {fakehost}
Accept: */*
Content-Type: text/plain
accept-encoding: gzip, deflate
content-length: {content-length}

{payload-after-crypto}
```

sogo-server拿到这个伪装好的请求，要做的事有：

1. 获取{targetAddrBase64}，拿到真实的目标网站地址
2. 获取请求头的Host字段，如果不是定义好的fakehost，则说明是直接访问sogo-server，这时sogo-server就是个到混淆网站的反向代理（这就是之前提到的第二个特性。下面将会详细解释如何实现
3. 获取{content-length}，根据这个content-length确定payload部分的长度。
4. 读取指定长度的payload，解密，并创建到targetAddr的连接，转发至targetAddr

这些步骤很明确吧。其实有一些细节，挺麻烦的。

tcp是面向流的协议，也就是会有很多个连续的上面的片段，要合理划分出这些片段。有些人称这个为解决“tcp粘包”，谷歌tcp粘包就能搜到如何实现这个需求。但是注意，不要称这个为“tcp粘包”，别人会说tcp是面向流的协议，哪来什么包，你知识体系有问题，你看过tcp协议没有。这些话都是知乎上某一问题的答案说的。所以，别说“tcp粘包”，但是可以用这个关键词去搜索如何解决这个问题。

如果，现在你看了如何解决这个问题，其实就是一句话，在tcp上层定义自己的应用层协议：也就是tcp报文的格式。http这个应用层协议就是一种tcp报文的一种定义。

我们的伪装好的报文就是http协议，所以要做的就是实现自己的http请求解析器，获取我们关心的信息。

sogo的http请求解析器，在：

```java
//file sogo-server/server.go
func read(clientConn net.Conn, redundancy []byte) (payload, redundancyRetain []byte, target string, readErr error)
```

这一部分有点繁杂。。不多解释，自己看代码吧。

## 伪装sogo-server:80为其他http网站

这一部分就是第二特性：将sogo-server所在的ip:端口伪装成一个http网站。

上一节，我们提到 {fakehost}。我们故意将{fakehost}定义为一个复杂、很长的域名。我们伪装的请求，都会带有如下请求头

```shell
Host: {fakehost}
```

如果，http请求的Host不是这个{fakehost}则说明这不是一个经sogo(client)的请求，而是直接请求了sogo-server。也就是，有人来嗅探啦！

对这种，我们就会将该请求，原封不动地转到伪装站。（其实还是有点修改的，但这是细节，看代码吧）所以，直接访问sogo-server-ip:80 就是访问伪装站：80。

## linux上服务端部署

```shell
yum install -y wget
wget https://github.com/arloor/sogo/releases/download/v1.0/sogo-server
wget https://github.com/arloor/sogo/releases/download/v1.0/sogo-server.json

chmod +x sogo-server
mv -f sogo-server /usr/local/bin/
mv -f sogo-server.json /usr/local/bin/

#创建service
cat > /lib/systemd/system/sogo-server.service <<EOF
[Unit]
Description=sogo-server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/
ExecStart=/usr/local/bin/sogo-server
LimitNOFILE=100000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

service  sogo-server start
systemctl daemon-reload
systemctl enable sogo-server

```

## linux上客户端安装（java版）

```shell
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.rpm
#wget http://repo-1252282974.cossh.myqcloud.com/jdk-8u131-linux-x64.rpm #使用腾讯云对象存储
rpm -ivh jdk-8u131-linux-x64.rpm
rm -f jdk-8u131-linux-x64.rpm

mkdir socks5
cd socks5
wget http://repo-1252282974.cossh.myqcloud.com/sogo.jar
wget http://repo-1252282974.cossh.myqcloud.com/sogo.jso

#创建service
cat > /lib/systemd/system/sogo.service <<EOF
[Unit]
Description=一个socks5代理

[Service]
Restart=always
WorkingDirectory=/root/socks5
ExecStart=/usr/bin/java -jar /root/socks5/sogo.jar -c /root/socks5/sogo.json
LimitNOFILE=100000
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sogo
systemctl start sogo
#vim /etc/hosts #配置proxy1 proxy2
```

## linux上客户端安装（过时）

```shell
# 国内机器下面两个wget会很慢，考虑本地下载再上传到服务器吧
wget https://github.com/arloor/sogo/releases/download/v1.0/sogo.json
wget https://github.com/arloor/sogo/releases/download/v1.0/sogo

chmod +x sogo
mv -f sogo /usr/local/bin/
mv -f sogo.json /usr/local/bin/
kill -9 $(ps -aux|grep -v "grep"|grep sogo|awk '$1!=""{print $2}')
ulimit -n 65536 #设置进程最多打开文件数量，防止 too many openfiles错误（太多连接
# 运行前，先修改/usr/local/bin/sogo.json
(sogo &) #以 /usr/local/bin/sogo.json 为配置文件  该配置下，服务端地址被设置为proxy
#(sogo -c path &)  #以path指向的文件为配置文件
```

## windows客户端安装

到[Release](https://github.com/arloor/sogo/releases/tag/v1.0)下载`sogo.exe`和`sogo.json`。

sogo.json内容如下：

```json
{
  "ClientPort": 8888,
  "Use": 0,
  "Servers": [
    {
      "ProxyAddr": "proxy",
      "ProxyPort": 80,
      "UserName": "a",
      "Password": "b"
    }
  ],
  "Dev":false
}
```
先修改`ProxyAddr`为服务端安装的地址即可。其他配置项是高级功能，例如多服务器管理，多用户管理（用户认证）等等。

>shadowsocks是没有多用户管理的，ss每个端口对应一个用户。sogo则使用用户名+密码认证，使多个用户使用同一个服务器端口。

修改好之后，双击`sogo.exe`，这时会发现该目录下多了一个 sogo_8888.log 的文件，这就说明，在本地的8888端口启动好了这个sock5代理。（没有界面哦。


## 写Sogo有感

sogo代码不多，对go语言、网络编程感兴趣的人可以看看。这篇博客梳理了一下sogo的实现原理，总之，sogo是一个优雅的代理。

<!-- 机缘巧合之下，sogo刚好满足了一家公司业务的需要，于是刚刚写好就投入了使用。


<img src="/img/earn-money-start.jpg" alt="电报聊天记录：很凑巧的发现了别人的需求" width="500px" style="max-width: 100%;">

就是这样，sogo意外地成为我的第一个“有别人愿意用”的作品，并且收到了实际的回报。从后来的了解来看，sogo解决了他们业务的重大痛点。他们的软件是第三方telegram，用于聊天挖矿（我不懂），并且内部封装socks5代理的配置来连接电报服务器，从而免去用户自己寻找电报代理。之前都是使用网上找的公开socks5代理隔几天就挂完。翻看他们的群组通知，好多条都是说，“连接服务器有问题，正在解决，抱歉”，直到有了sogo！可以说sogo现在是他们这个软件很重要的一个基础设施。（不吹能死吗？

所以呀，钱要少了。不过本来就没想赚钱，有总比没有好对吧。另一方面，这也是对我的技术能力的认可。嗯，这才是最重要的吧，挺爽的。以前写的东西没人用，后来写的东西自己用，现在写的东西别人买来用，境界就不一样啦。用三个词概括一下这段经历吧：机缘巧合😱、钱要少了😭、得到认可😄。


<img src="/img/talk-about-payment.jpg" alt="电报聊天记录：很凑巧的发现了别人的需求" width="500px" style="max-width: 100%;">

放一张服务器的运行状况监控证明一下有人用😂。如下图的监控所示，服务器的带宽和tcp连接数量都保持在稳定的水平。tcp连接数较多，但是带宽不大，这也符合文字内容传输的使用场景。

![](/img/monitor-aliyun.png)

24小时的带宽占用如下，夜深人静的时候最低，可以说很真实了

![](/img/bandwagon-daikuan.jpg) -->

废话说得够啦，最后来听听歌吧。 Something just like this 😍

<div class="iframe-container">
    <iframe src="https://www.youtube.com/embed/-SgyhUdJ_TY" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## 维护日志

### 1.因[]byte未复用，导致频繁GC，从而cpu占用夸张

在带宽达到50M时，cpu占用达到夸张的50%。想想实现，就知道时内存没有复用导致频繁GC，所以就想弄个内存池出来，本来想自己实现，后来发现GO语言有sync.pool满足这个临时对象池的需求。

### 2.因为频繁写入日志文件，导致cpu iowait过高

从监控来看，cpu占用达到夸张的90%，使用top命令看到cpu的iowait有70%多。

iowait是cpu等待io的时间占比，sogo应用是网络IO，一般不会有磁盘IO，唯一有可能的只有写入日志文件。在关闭日志记录之后，cpu iowait降低至0，问题解决。

一些排查iowait占用高的方法：

#### 查找哪个硬盘正在被写入

```shell
[root@coolnull ~]# iostat -x 2 5
 avg-cpu: %user %nice %system %iowait %steal %idle
  3.66 0.00 47.64 48.69 0.00 0.00

 Device: rrqm/s wrqm/s r/s w/s rkB/s wkB/s avgrq-sz avgqu-sz await r_await w_await svctm %util
 sda 44.50 39.27 117.28 29.32 11220.94 13126.70 332.17 65.77 462.79 9.80 2274.71 7.60 111.41
 dm-0 0.00 0.00 83.25 9.95 10515.18 4295.29 317.84 57.01 648.54 16.73 5935.79 11.48 107.02
 dm-1 0.00 0.00 57.07 40.84 228.27 163.35 8.00 93.84 979.61 13.94 2329.08 10.93 107.02
```

上述示例的iostat命令将每2秒打印出报告，共打印5次；-x参数告诉iostata打印出更详尽的报告

iostat打印出的第1个报告，数值是基于最后一次系统启动的时间统计的；基于这个原因，在大部份情况下，iostat打印出的第1个报告应该被忽略。每个子报告都是基于上1次的报告。在这个例子中，我们的命令将打印5次报告，第2份报告就是从第1份报告开始后的硬盘数据，第3份报告基于第2份，依此类推。

上述示例，sda盘的%utilized达到了111.41%。这表示引起I/O慢的进程在写入sda盘。因为我这个测试实例中只有1个硬盘，但对于有多硬盘的服务器来说，这可以缩小在使用I/O的进程范围。

除了iostat的%utilized能提供丰富的信息外，像rrqm/s、wrqm/s这些每秒读、写的请求数，r/s、w/s每秒读写数也很有用。在我们的例子中，我们的程序看起来读写很繁重的信息也能帮助我们确定这个讨人厌的进程。

#### 查找引起高I/O的进程

```shell
[root@coolnull ~]# iotop
 Total DISK READ: 8.00 M/s | Total DISK WRITE: 20.36 M/s
  TID PRIO USER DISK READ DISK WRITE SWAPIN IO> COMMAND
 15758 be/4 root 7.99 M/s 8.01 M/s 0.00 % 61.97 % bonnie++ -n 0 -u 0 -r 239 -s 478 -f -b -d /tmp
```

查看哪个进程使用硬盘最多的最简单的方法就是使用iotop命令。通过查看数据，我们很容易就能确定是bonnie++这个进程引起我们机器高I/O

虽然iotop好用，但默认主流的linux发行版中是没有安装的；并且我个人也不推荐依赖默认系统没有安装的命令。系统管理员总是会碰到这样的情况，他们没办法在短时间内简单地安装这些非默认包。

如果iotop没办法用，以下的步聚还是可以帮助你缩小这些讨人厌进程的范围

#### 进程状态列表

ps命令能打印出内存，cpu的情况但没办法打印出硬盘I/O的情况。虽然ps没办法打印出I/O的情况，但它可以显示出进程是否在等待I/O。

The ps state field provides the processes current state; below is a list of states from the man page.
ps状态列提供了进程当前的状态，以下从man ps上获取的进程stat列表

```shell
PROCESS STATE CODES
 D uninterruptible sleep (usually IO)
 R running or runnable (on run queue)
 S interruptible sleep (waiting for an event to complete)
 T stopped, either by a job control signal or because it is being traced.
 W paging (not valid since the 2.6.xx kernel)
 X dead (should never be seen)
 Z defunct ("zombie") process, terminated but not reaped by its parent.
```

等待I/O的进程通过处于uninterruptible sleep或D状态；通过给出这些信息我们就可以简单的查找出处在wait状态的进程

示例：

```shell
[root@coolnull ~]# for x in `seq 1 1 10`; do ps -eo state,pid,cmd | grep "^D"; echo "----"; sleep 5; done
 D 248 [jbd2/dm-0-8]
 D 16528 bonnie++ -n 0 -u 0 -r 239 -s 478 -f -b -d /tmp
 ----
 D 22 [kswapd0]
 D 16528 bonnie++ -n 0 -u 0 -r 239 -s 478 -f -b -d /tmp
 ----
 D 22 [kswapd0]
 D 16528 bonnie++ -n 0 -u 0 -r 239 -s 478 -f -b -d /tmp
 ----
 D 22 [kswapd0]
 D 16528 bonnie++ -n 0 -u 0 -r 239 -s 478 -f -b -d /tmp
 ----
 D 16528 bonnie++ -n 0 -u 0 -r 239 -s 478 -f -b -d /tmp
 ----
```

上述命令会每5秒循环打印出位于D状态的进程，共打印10次

从上面的输出可以看出bonnie++，pid 16528比其它进程更加占用I/O。从这点，bonnie++看起来更有可能引起I/O Wait。但仅凭进程处于uninterruptible sleep state誊，还不能完全确定就是这引起的I/O wait。

为了帮助肯定我们的怀疑，我们可以使用/proc文件系统。在这个进程目录里，每个进程都有一个io文件，里面的数值跟iotop命令获取的I/O数值一样。

```shell
[root@coolnull ~]# cat /proc/16528/io
 rchar: 48752567
 wchar: 549961789
 syscr: 5967
 syscw: 67138
 read_bytes: 49020928
 write_bytes: 549961728
 cancelled_write_bytes: 0
```

read_bytes和write_bytes就这个进程读写硬盘的字节数。在这里，bonnie++已经读取了46MB，写入524MB的数据。对很多进程，这可能不是很多，但在我们这个实例这足够引起高i/o wait。

#### 查找哪个文件在被繁重地写入

lsof命令会为你展示指定进程打开的所有文件或依赖提供选项的所有进程。从这个列表，人们可以根据文件的大小和/proc io文件里出现的次数做出有用的猜测，哪个文件正在被频繁地写入。

为了减少输出的内容，我们可以使用-p 选项来只打印指定进程id打开的文件

```shell
[root@coolnull ~]# lsof -p 16528
 COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
 bonnie++ 16528 root cwd DIR 252,0 4096 130597 /tmp
 <truncated>
 bonnie++ 16528 root 8u REG 252,0 501219328 131869 /tmp/Bonnie.16528
 bonnie++ 16528 root 9u REG 252,0 501219328 131869 /tmp/Bonnie.16528
 bonnie++ 16528 root 10u REG 252,0 501219328 131869 /tmp/Bonnie.16528
 bonnie++ 16528 root 11u REG 252,0 501219328 131869 /tmp/Bonnie.16528
 bonnie++ 16528 root 12u REG 252,0 501219328 131869 <strong>/tmp/Bonnie.16528
```

### 3.报错：too many open files

错误日志如下：

```shell
Socket accept error: accept tcp [::]:80: accept4: too many open files;
```

too many open files(打开的文件过多)是Linux系统中常见的错误，从字面意思上看就是说程序打开的文件数过多，不过这里的files不单是文件的意思，也包括打开的通讯链接(比如socket)，正在监听的端口等等，所以有时候也可以叫做句柄(handle)，这个错误通常也可以叫做句柄数超出系统限制。

引起的原因就是进程在某个时刻打开了超过shell会话限制的文件数量以及通讯链接数，通过命令`ulimit -a`可以查看当前shell会话设置的最大句柄数是多少

```shell
# ulimit -a
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 14732
max locked memory       (kbytes, -l) 64
max memory size         (kbytes, -m) unlimited
open files                      (-n) 1024  #太小了，可以直接改到65536
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 10240
cpu time               (seconds, -t) unlimited
max user processes              (-u) 1024
virtual memory          (kbytes, -v) unlimited
file locks                      (-x) unlimited
```

open files那一行就代表当前shell会话目前允许单个进程打开的最大句柄数，这里是1024，这个值对于这个使用场景太小了。 

使用命令lsof -p 进程id可以查看单个进程所有打开的文件详情，使用命令lsof -p 进程id | wc -l可以统计进程打开了多少文件：（PS：使用lsof -i:80|wc -l可以查看80端口有多少个连接）

```shell
lsof -p $(ps -aux|grep -v "grep"|grep sogo|awk '$1!=""{print $2}')|wc -l
#1610
lsof -i:80|wc -l
#337
```


问题定位到这个limit过低，解决自然就是增加这个limit。最最简单的方法是执行以下脚本，增加当前shell和它的子进程的limit，然后重启进程。

```
ulimit -n 65536
```

> 作为临时限制，ulimit 可以作用于通过使用其命令登录的 shell 会话，在会话终止时便结束限制，并不影响于其他 shell 会话。而对于长期的固定限制，ulimit 命令语句又可以被添加到由登录 shell 读取的文件中，作用于特定的 shell 用户。前面多次提到shell会话，ulimit的影响范围是，输入ulimit命令之后的命令，也就是对当前shell和当前shell的子进程生效，对其它shell不产生影响。

重启进程后，可以执行以下命令，查看新的limit是否对新进程生效

```shell
cat /proc/$pid/limits|grep open
# Max open files            65536                65536                files
```

另一种，通过修改配置文件来修改limit，在重启后不会失效：

```shell
vim /etc/security/limits.conf  
#在最后加入  
* soft nofile 65536  
* hard nofile 65536  
#或者只加入：
* - nofile 65536
# 星号表示所有用户，也可以写用户名，对单独用户生效
# 有hard和soft两个限制，- 表示同时设置
```

conf文件修改完成后，启动新的shell会话（重新ssh上去），这些limit对新的shell会话就生效了，不需要重启机器哦（需要重新登陆shell）