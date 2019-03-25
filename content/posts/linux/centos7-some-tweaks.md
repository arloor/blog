---
title: "玩转VPS与centos 7"
author: "刘港欢"
date: 2019-03-04
categories: [ "linux"]
tags: ["linux"]
weight: 10
---



多年以后，我又开始整vps了，学了三年，也知道怎么整linux了。个人使用的是搬瓦工 DC6 CN2 GIA 机房的vps。[购买链接](https://bwh88.net/aff.php?aff=11132&pid=87)
<!--more-->

> 搬瓦工 DC6 CN2 GIA 机房，编号为 USCA_6，使用中国电信优先级最高的 CN2 GIA 线路，中国电信、中国联通、中国移动三网去程回程全部走 CN2 GIA，线路质量非常好，可以说是等级最高的国际出口。经过测试，去程和回程都使用中国电信提供的cn2 GIA线路，个人使用十分满意

# 一键安装shadowsocks-libev

在研究了安卓VPN的实现之后，发现我的[HttpProxy](http://github.com/arloor/HttpProxy)跟安卓VPN根本不是一回事，基本不可能有安卓客户端了。而shadowsocks安卓所采用的tun2socks+shadowsocks-libev这种模式很现代。所以给自己的centos也装上shadowsocks了。

shadowsocks有很多版本，我选择shadowsocks-libev，全功能且内存占用真的少，C语言省内存啊。

参见[秋水逸冰](https://teddysun.com/357.html)

```
wget --no-check-certificate -O shadowsocks-libev.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev.sh
chmod +x shadowsocks-libev.sh
./shadowsocks-libev.sh 2>&1 | tee shadowsocks-libev.log
```

安装完成后，可以使用`service shadowsocks status`查看状态，ss的配置文件在`/etc/shadowsocks-libev/config.json`

卸载如下：
```
./shadowsocks-libev.sh uninstall
```

# docker 安装ss-libev

先安装docker

```
# 安装相关依赖
yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
# 设置docker源
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# 安装docker 
yum -y install docker-ce
# 开机自启动docker服务
systemctl enable docker
```

拉取镜像并运行

```
passwd=xxxx #改成你的密码
port=8388   #改成你的端口
# 加密协议默认为支持AEAD的aes-256-gcm

service docker start
docker pull shadowsocks/shadowsocks-libev 
docker run -e PASSWORD=$passwd -p $port:8388 -p $port:8388/udp -d --restart always shadowsocks/shadowsocks-libev
echo "配置信息：端口：$port 密码：$passwd 加密协议：aes-256-gcm"
```

这样就以aes-256-gcm运行了ss-libev。详细参数见：[docker镜像README](https://github.com/shadowsocks/shadowsocks-libev/blob/master/docker/alpine/README.md)

# 一个简单的管理docker ss用户的方式

增加新用户：

```
bash start.sh 8000  xxx  2019-01-01 # 端口号  用户名 过期时间  (密码为xxx2019-01-01)
```

定期删除过期用户：

```
awk '{print}' user.txt|xargs -n 3 bash kill.sh
```

唯二不足是

1. 不能直接删除user.txt中的失效用户记录
2. 不能处理用户增加有效期（xufei）

总之就是user.txt的管理不够智能。

start.sh

```shell
#! /bin/bash
# 端口 用户名 到期日期
# bash start.sh 8000  xxx  2019-01-01

 result=$(cat user.txt | grep "$2")
 if [[ "$result" != "" ]]
 then
     echo "已包含该用户记录，请删除原有记录"
 else
     
	docker run -e PASSWORD=$2$3 -p $1:8388 -p $1:8388/udp -d --name $2  --restart always shadowsocks/shadowsocks-libev

	if [ "$?" = "0" ]; then
    		echo "成功为用户$2在$1端口启动服务"
    		echo "$1 $2 $3" &>> user.txt
	else
		 echo "在$1端口启动服务失败，请检查端口占用、container名称和docker服务状态"
    		docker rm $2
	fi

fi
```

kill.sh

```shell
#! /bin/bash
# awk '{print}' user.txt|xargs -n 3 bash kill.sh
# 端口 用户名 到期日期
now=$(date '+%Y-%m-%d')

if [[ "$3" < "$now" ]] ;then
 docker kill $2
 docker rm $2
 echo "rm shadowsocks docker container for user $2"
fi
```

# 配置防火墙

据说centos7默认使firewalld作为防火墙，但是我装了两个centos7都是使用的iptables。现在也比较喜欢iptables，当初配iptables死活都不通。。

安装iptables-services，这样就可以用service iptables xx来控制iptables了

```shell
service firewalld stop
systemctl disable firewalld
yum install iptables-services
```

配置filter表，用于设置INPUT、FORWARD、OUTPUT链，总之就是，开放ssh服务、httpd服务等等需要开放的端口，关闭其他一切
```shell
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  #开启tcp 22端口的读
iptables -A INPUT -p tcp --dport 80 -j ACCEPT  #开启tcp 80端口的读
iptables -A INPUT -p tcp --dport 8099 -j ACCEPT #开启tcp 8099端口的读
iptables -A INPUT -p udp --dport 8099 -j ACCEPT #开启udp 8099端口的读
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT # 允许所以已建立连接（这个有点关键）
iptables -A INPUT -i lo -j ACCEPT  # 允许所有本地
iptables -A INPUT -p icmp -j ACCEPT #允许ping
iptables --policy INPUT DROP #除了以上允许的,设置默认阻止所有读，这个最后再做哦
#或者最后增加这个
# iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited #最后做啊
```

最后service iptables restart，就生效了。可以执行`service iptables save`

顺便提一下，docker映射到宿主机的端口不需要在iptables中开放，因为docker服务自己对iptables做了修改，将相关的请求转发到了docker虚拟出来的网卡中。也因为docker的自动修改，如果重启iptables，将丢失这部分修改，导致docker容器运行异常，此时只能重启docker服务了。所以如果运行了docker，就不要贸然地stop iptables服务啦。



# 修改root用户密码

直接输入passwd命令即可。

# sshd服务配置

## 修改搬瓦工的默认ssh端口

```shell
#vi /etc/ssh/sshd_config
将Port 22前的注释删掉，或者增加

#重启服务
service sshd restart 
```
这个文件开头说，如果安装了selinux，需要执行semanage port -a -t 22 -p tcp。事实证明这台centos7没有selinux。 记得修改防火墙设置哦。

## 配置秘钥登录

将本地的~/.ssh/id_rsa.pub 添加到服务器的~/.ssh/authorized_keys文件中

## 禁用密码登陆

编辑远程服务器上的sshd_config文件：
```shell
vim /etc/ssh/sshd_config
```

找到如下选项并修改(通常情况下，前两项默认为no，地三项如果与此处不符，以此处为准)：
```shell
#PasswordAuthentication yes 改为
PasswordAuthentication no
```

编辑保存完成后，重启ssh服务使得新配置生效，然后就无法使用口令来登录ssh了
```shell
systemctl restart sshd.service
```

# 安装apache

```shell
yum install httpd
systemctl enable httpd
```

# 安装jdk8

```shell
wget --no-check-certificate --no-cookie --header "Cookie: oraclelicense=accept- - securebackup-cookie;" https://download.oracle.com/otn-pub/java/jdk/8u201-b09/42970487e3af4f5aa5bca3f542482c60/jdk-8u201-linux-x64.rpm

yum install jdk-8u201-linux-x64.rpm
```
# 设置时区

```shell
# 查看事件设置信息
timedatectl status
#Local time: 四 2014-12-25 10:52:10 CST
#Universal time: 四 2014-12-25 02:52:10 UTC
#RTC time: 四 2014-12-25 02:52:10
#Timezone: Asia/Shanghai (CST, +0800)
#NTP enabled: yes
#NTP synchronized: yes
#RTC in local TZ: no
#DST active: n/a
```

```shell
timedatectl list-timezones # 列出所有时区
timedatectl set-local-rtc 1 # 将硬件时钟调整为与本地时钟一致, 0 为设置为 UTC 时间
timedatectl set-timezone Asia/Shanghai # 设置系统时区为上海
```

# 番外篇：测试vps回程路由

```shell
cd /usr/local
mkdir trace
cd trace

yum install -y unzip weget
wget https://cdn.ipip.net/17mon/besttrace4linux.zip
unzip besttrace4linux.zip
chmod +x besttrace
rm -f besttrace4linux.zip
cd

ln -fs /usr/local/trace/besttrace /usr/local/bin/trace
trace arloor.com
```

阿里云香港回程路由示例：

```shell
traceroute to baidu.com (220.181.57.216), 30 hops max, 60 byte packets
 1  *
    *
    *
 2  11.52.240.53  0.26 ms  *  美国 defense.gov
    11.52.240.53  0.23 ms  *  美国 defense.gov
    11.52.240.53  0.96 ms  *  美国 defense.gov
 3  *
    *
    *
 4  11.16.2.182  1.19 ms  *  美国 defense.gov
    11.16.2.182  1.09 ms  *  美国 defense.gov
    11.16.2.182  0.99 ms  *  美国 defense.gov
 5  119.38.214.46  1.70 ms  AS37963  中国 香港 阿里云
    119.38.214.46  1.56 ms  AS37963  中国 香港 阿里云
    119.38.214.46  1.45 ms  AS37963  中国 香港 阿里云
 6  203.100.48.253  1.07 ms  AS4809  中国 香港 电信
    203.100.48.253  1.30 ms  AS4809  中国 香港 电信
    203.100.48.253  1.03 ms  AS4809  中国 香港 电信
 7  59.43.186.125  1.53 ms  *  中国 香港 电信
    59.43.186.125  1.47 ms  *  中国 香港 电信
    59.43.186.125  1.51 ms  *  中国 香港 电信
 8  59.43.248.1  40.13 ms  *  中国 北京 电信
    59.43.248.1  40.10 ms  *  中国 北京 电信
    59.43.248.1  40.13 ms  *  中国 北京 电信
 9  59.43.188.77  40.13 ms  *  中国 北京 电信
    59.43.188.77  39.93 ms  *  中国 北京 电信
    59.43.188.77  39.96 ms  *  中国 北京 电信
10  59.43.132.13  40.44 ms  *  中国 北京 电信
    59.43.132.13  40.40 ms  *  中国 北京 电信
    59.43.132.13  40.44 ms  *  中国 北京 电信
11  59.43.80.2  40.79 ms  *  中国 北京 电信
    59.43.80.2  40.56 ms  *  中国 北京 电信
    59.43.80.2  40.59 ms  *  中国 北京 电信
12  *
    220.181.0.194  41.06 ms  AS23724  中国 北京 电信
    *
13  *
    *
    *
14  220.181.17.150  41.23 ms  AS23724  中国 北京 电信
    220.181.17.150  41.20 ms  AS23724  中国 北京 电信
    220.181.17.150  41.24 ms  AS23724  中国 北京 电信
15  *
    *
    *
16  220.181.57.216  40.77 ms  AS23724  中国 北京 电信
    220.181.57.216  40.81 ms  AS23724  中国 北京 电信
    220.181.57.216  40.75 ms  AS23724  中国 北京 电信
```


# 番外篇：在国内阿里云上设置shadowsocks国内中转

上面的安装是国外服务器上做的。这一步的设置国内中转是在国内阿里云的centos7机器上做

使用的是阿里云提供的学生机，5M带宽的轻量应用服务器，114元/年，24岁以下自动获得学生身份。不要小看了5M，看1080p视频不成问题（一个人用的前提下）。[云翼计划2018](https://promotion.aliyun.com/ntms/act/campus2018.html)

为什么要弄国内中转？弄了国内中转之后，是这样的：

```shell
电脑/手机--------阿里云BGP机房--------国外vps
```

因为阿里云BGP机房对所有运营商都提供了很好的网络支持，所以无论家里用的什么宽带，都能保证较好的体验。

我自己使用的vps是搬瓦工DC6 gia的机器，对中国大陆提供双程cn2 gia线路。因此阿里云到国外vps的质量也得到了保证。

自己使用的是移动宽带，不加中转，在电信的cn2 转中国移动路由节点容易出问题，坑死人的移动宽带啊。加上阿里云BGP中转则由阿里云的机器充当路由节点，进行流量的转移，这就是稳定好用的原因。

另外，还有一个概念Qos（服务质量等级），运营商会优先保证等级高的流量。阿里云机房的流量比我们普通家庭带宽的质量等级高，这也是中转方案的一个优点。

总结，中转的好处就是稳。坏处就是中转节点带宽只有5M了😂😂😂。考虑到过不久就要回学校用校园网了，估计校园网的环境下还是要依靠阿里云中转的节点。总之，这样又提供了一个新的选择，节点多一个看着贼爽呢。

![](/img/ssnodes.png)

开始操作：

打开ipv4的转发功能（其他系统可能不一样）

```
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

设置NAT规则

```
iptables -t nat -A PREROUTING -p tcp --dport [国内服务器端口] -j DNAT --to-destination [国外服务器IP]:[国外服务器端口]
iptables -t nat -A PREROUTING -p udp --dport [国内服务器端口] -j DNAT --to-destination [国外服务器IP]:[国外服务器端口]
iptables -t nat -A POSTROUTING -p tcp -d [国外服务器IP] --dport [国外服务器端口] -j SNAT --to-source [国内服务器IP]
iptables -t nat -A POSTROUTING -p udp -d [国外服务器IP] --dport [国外服务器端口] -j SNAT --to-source [国内服务器IP]
```

注意`[国内服务器IP]`那里可能不填公网ip，可能需要填内网ip。就是要确保，这个ip是用来上网的网卡绑定的ip。经过实测，阿里云需要填写服务器的内网ip。

以上是修改了iptables nat表以实现转发。为了成功转发，还需要确保filter表中，forward链和input链没有DROP/REJECT相关的流量，不详细解释。

有问题的可以直接在评论区留言

题外话（自己备忘）：某端口流量转发到本机其他端口：(从localhost访问，这个转发无效)

```
iptables -t nat -A PREROUTING -p tcp --dport 8081 -j REDIRECT --to-ports 8080
```

# 番外篇：vps网速测试

网速测试请主要关注上传速度！

```
wget https://raw.github.com/sivel/speedtest-cli/master/speedtest.py ##下载脚本

python speedtest.py --server 5316  |grep -E "Mbit/s|ms"  ##到南京电信的测试节点
python speedtest.py --server 13704 |grep -E "Mbit/s|ms"  ##到南京联通
python speedtest.py --server 21590 |grep -E "Mbit/s|ms"  ##到南京移动

python speedtest.py ## speedtest自己选择测试节点
python speedtest.py --list|grep "China Telecom" ## 列举中国电信测试节点
python speedtest.py --list|grep "China Unicom"  ## 列举中国联通测试节点
python speedtest.py --list|grep "China Mobile"  ## 列举中国移动测试节点


python speedtest.py --server 5316  --share |grep Share ##到南京电信的测试节点
python speedtest.py --server 13704 --share |grep Share ##到南京联通
python speedtest.py --server 21590 --share |grep Share ##到南京移动
```

## 香港阿里云轻量服务器(149.129.xx.xx)

|时间|运营商|延迟|下载速度|上传速度|
|----|----|---|---|---|
|11:30|南京电信|86ms|92Mbps|😍29Mbps|
|11:30|南京联通|34ms|106Mbps|😍35Mbps|
|11:30|南京移动|42ms|109Mbps|🤢2.67Mbps|
|-|-|-|-|-|
|15:30|南京电信|80-157ms|82Mbps|🤢3-20Mbps狂跳|
|15:30|南京联通|35ms|105Mbps|😍35Mbps|
|15:30|南京移动|42ms|91Mbps|🤢1.80Mbps|
|-|-|-|-|-|
|22:30|南京电信|195ms|72Mbps|🤢2.78Mbps|
|22:30|南京联通|36ms|102Mbps|😍35Mbps|
|22:30|南京移动|70ms|91Mbps|🤢3.09Mbps|

总结：

|运营商|总结|
|---|---|
|电信|🤢速度、延迟非常不稳定|
|联通|😍全天都很好，联通用户就不要犹豫了|
|移动|🤢根本不能用|

这样看来，只有联通值得买香港轻量服务器。

## 搬瓦工dc9 gia(67.230.170.xx)

这个ip段是最开始默认分配的ip段，用了一段时间后出现了速度上不去的问题，如下面的测试所示：

|时间|运营商|延迟|下载速度|上传速度|
|----|----|---|---|---|
|19:30|南京电信|143ms|2.02Mbps|🤢4.09Mbps|
|19:30|南京联通|141ms|2.60Mbps|🤢4.14Mbps|
|19:30|南京移动|145ms|1.78Mbps|🤢3.49Mbps|

总结：

|运营商|总结|
|---|---|
|电信|🤢稳定得慢|
|联通|🤢稳定得慢|
|移动|🤢稳定得慢|

很稳也很慢。稳：三网双程都是cn2 gia，延迟都是145ms左右，而且不会跳；慢：服务器上传下载都慢。

后面开始折腾，从dc9迁到dc8,再从dc8迁回dc9，ip变成了另一个段。接下来会展示迁移之后的测速结果，显然比这个ip的速度好很多，猜测是换了个机架、邻居。

## 搬瓦工dc8 cn2(95.169.17.xx)

|时间|运营商|延迟|下载速度|上传速度|
|----|----|---|---|---|
|02:00|南京电信|171ms|6.45Mbps|16.66Mbps|
|02:00|南京联通|222ms|34Mbps|😍73Mbps|
|02:00|南京移动|177ms|78Mbps|😍83Mbps|

dc8机房最大的优势就是便宜吧，速度有时候高，但会出现不稳的情况。追求延迟低和速度稳定的还是推荐dc6或者dc9这种三网双程cn2 gia线路的机房

## 迁移后搬瓦工dc9 gia(178.157.xx.xx)

|时间|运营商|延迟|下载速度|上传速度|
|----|----|---|---|---|
|11:30|南京电信|135ms|52Mbps|😍73Mbps|
|11:30|南京联通|141ms|27Mbps|😍124Mbps|
|11:30|南京移动|147ms|32Mbps|😍138Mbps|
|-|-|-|-|-|
|14:30|南京电信|135ms|47Mbps|😍108Mbps|
|14:30|南京联通|142ms|64Mbps|😍121Mbps|
|14:30|南京移动|158ms|22Mbps|😍147Mbps|
|-|-|-|-|-|
|15:30|南京电信|137ms|18Mbps|😍76Mbps|
|15:30|南京联通|137ms|54Mbps|😍120Mbps|
|15:30|南京移动|148ms|60Mbps|😍138Mbps|
|-|-|-|-|-|
|19:00|南京电信|135ms|26Mbps|😍94Mbps|
|19:00|南京联通|137ms|37Mbps|😍121Mbps|
|19:00|南京移动|155ms|42Mbps|😍65Mbps|
|-|-|-|-|-|
|22:00|南京电信|135ms|27Mbps|😍99Mbps|
|22:00|南京联通|143ms|28Mbps|😍120Mbps|
|22:00|南京移动|147ms|4Mbps|49Mbps|


迁两次机房后，ip变为这个段，速度有了很大提升。猜测是原来机器的邻居太暴力或者原来所在的机架网络设备有问题？总之之前的体验很坑。从这个测试结果看，dc9还是很值得入的。

如果开到dc9的机器，出现网速慢的情况，可以尝试跟我一样迁两次机房看看。