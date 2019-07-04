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

# 上传ssh公钥开启免密登陆

```shell
mkdir /root/.ssh
#上传我的公钥（你们别用我的公钥。如果不小心用了，麻烦告诉我IP😝）
echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQzKHfZLlFEdaRUjfSK4twhL0y7+v23Ko4EI1nl6E1/zYqloSZCH3WqQFLGA7gnFlqSAfEHgCdD/4Ubei5a49iG0KSPajS6uPkrB/eiirTaGbe8oRKv2ib4R7ndbwdlkcTBLYFxv8ScfFQv6zBVX3ywZtRCboTxDPSmmrNGb2nhPuFFwnbOX8McQO5N4IkeMVedUlC4w5//xxSU67i1i/7kZlpJxMTXywg8nLlTuysQrJHOSQvYHG9a6TbL/tOrh/zwVFbBS+kx7X1DIRoeC0jHlVJSSwSfw6ESrH9JW71cAvn6x6XjjpGdQZJZxpnR1NTiG4Q5Mog7lCNMJjPtwJ not@home > /root/.ssh/authorized_keys
#关闭密码登陆
sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
#关闭GSSAPI认证登陆
sed -i "s/GSSAPIAuthentication yes/GSSAPIAuthentication no/g" /etc/ssh/sshd_config
#关闭UseDNS(解决ssh缓慢)
sed -i "s/#UseDNS no/UseDNS no/g" /etc/ssh/sshd_config
sed -i "s/UseDNS yes/UseDNS no/g" /etc/ssh/sshd_config
sed -i "s/#UseDNS yes/UseDNS no/g" /etc/ssh/sshd_config
service sshd restart
```

# 一键安装shadowsocks-libev

在研究了安卓VPN的实现之后，发现我的[HttpProxy](http://github.com/arloor/HttpProxy)跟安卓VPN根本不是一回事，基本不可能有安卓客户端了。而shadowsocks安卓所采用的tun2socks+shadowsocks-libev这种模式很现代。所以给自己的centos也装上shadowsocks了。

shadowsocks有很多版本，我选择shadowsocks-libev，全功能且内存占用真的少，C语言省内存啊。


```
wget --no-check-certificate -O shadowsocks-libev.sh https://raw.githubusercontent.com/arloor/shadowsocks_install/master/shadowsocks-libev.sh
chmod +x shadowsocks-libev.sh
./shadowsocks-libev.sh 2>&1 | tee shadowsocks-libev.log
```

安装完成后，可以使用`service shadowsocks status`查看状态，ss的配置文件在`/etc/shadowsocks-libev/config.json`

卸载如下：
```
./shadowsocks-libev.sh uninstall
```

## 使用systemd管理shadowsocks服务

上面的脚本安装后ss由init.d管理，下面的脚本则将其转交给systemd管理(centos7 已测试通过)

```shell
 wget --no-check-certificate -O systemd.sh https://raw.githubusercontent.com/arloor/shadowsocks_install/master/systemd.sh
chmod +x systemd.sh
./systemd.sh
```

以后即可使用service ss xxx管理shadowsocks了。


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
service docker start
# 拉取镜像并运行
passwd=xxxx ; port=8388   #改成你的密码和端口
# 加密协议默认为支持AEAD的aes-256-gcm

docker run -e PASSWORD=$passwd -p $port:8388 -p $port:8388/udp -d --name ss --restart always shadowsocks/shadowsocks-libev
ip=`wget -qO- http://whatismyip.akamai.com`
echo "配置信息: 服务器地址：$ip  端口：$port 密码：$passwd 加密协议：aes-256-gcm"
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

# centos 7升级内核，开启bbr

1.查看当前linux内核

```shell
uname -r
# 3.10.0-514.el7.x86_64
cat /etc/redhat-release 
# CentOS Linux release 7.3.1611 (Core)
```

2.启用ELRepo库

```shell
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
```

3.列出相关内核包

```shell
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
```

![](/img/kernels.png)

4.安装新内核

```shell
yum --enablerepo=elrepo-kernel install kernel-ml  #以后升级也是执行这句
```

5.检查现在可以用于启动得内核列表

```shell
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
# CentOS Linux (5.0.5-1.el7.elrepo.x86_64) 7 (Core)
# CentOS Linux (3.10.0-957.10.1.el7.x86_64) 7 (Core)
# CentOS Linux (3.10.0-957.5.1.el7.x86_64) 7 (Core)
# CentOS Linux (3.10.0-957.el7.x86_64) 7 (Core)
# CentOS Linux (0-rescue-20190215172108590907433256076310) 7 (Core)
```

由上面可以看出新内核(5.0.5)目前位置在0，原来的内核(3.10.0)目前位置在1，所以如果想生效最新的内核，还需要我们修改内核的启动顺序为0

6.设置默认启动内核为刚安装得内核

```shell
vim /etc/default/grub

GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=0
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto rhgb quiet"
GRUB_DISABLE_RECOVERY="true"

# 设置 GRUB_DEFAULT=0, 意思是 GRUB 初始化页面的第一个内核将作为默认内核
```

7.重新生成grub-config，并使用新内核重启

```shell
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot
```

现在就可以使用uname命令查看内核了

8.开启bbr很简单：

```shell
uname -r  ##输出内核版本大于4.9
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p
lsmod |grep bbr
```

# 配置防火墙

据说centos7默认使firewalld作为防火墙，但是我装了两个centos7都是使用的iptables。现在也比较喜欢iptables，当初配iptables死活都不通。。

安装iptables-services，这样就可以用service iptables xx来控制iptables了

```shell
service firewalld stop
systemctl disable firewalld
yum -y install iptables-services
systemctl enable iptables
service iptables save #先保存当前（空）的iptables规则
systemctl start iptables
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
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.rpm
#wget http://repo-1252282974.cossh.myqcloud.com/jdk-8u131-linux-x64.rpm #使用腾讯云对象存储
rpm -ivh jdk-8u131-linux-x64.rpm
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

# 设置ddns

nat vps的特点是ip地址会改变，有个需求就是设置ddns，当nat的公网ip改变时，就更新域名解析。

从一个网址fork了一个脚本，修改了一下。

原理说明，定时调用DNSPOD（腾讯云）的api，更新DNSPOD（腾讯云）中的域名解析记录。

因此，要满足如下3个前提条件：

- 有一个域名在DNSPOD（腾讯云）腾讯云中解析
- 登陆DNSPOD后台，增加一个token
- 新建一个A记录，例如xxx.arloor.com 指向 127.0.0.1，之后这个A记录就会定时地被脚本修改（如果不做这个，会失败）

其中提到的token和A记录会需要写进dns.conf中，下面是如何在nat vps上部署这个脚本：

```shell
systemctl status crond
systemctl enable crond
systemctl restart crond

sudo su
cd /usr/local
git clone https://github.com/arloor/ddnspod.git
cd ddnspod
cp dns.conf.example dns.conf
vi dns.conf  #编辑dns.conf
# ---- arToken="8xx74,69a5fxxxxxxxxxxxxx75b0ecd1e"  #修改为自己的
# ---- arDdnsCheck "arloor.com" "xxx"               #修改为自己的
# --------------------------------------------------------------
echo "* * * * * root /usr/local/ddnspod/ddnspod.sh &>> /root/ddns.log" >> /etc/crontab
cd 
```



现在，每分钟会执行一次

```shell
/usr/local/ddnspod/ddnspod.sh &>> /root/ddns.log
```

从而检查公网ip，自动修改A记录指向该nat机器的公网ip。可以通过`tailf /var/log/cron`命令查看crontab定时任务的运行情况。




# 三种开机自启动方式

## 1.利用chkconfig xx on

```shell
# 1. 将脚本移动到/etc/rc.d/init.d目录下
# mv  /opt/script/StartTomcat.sh /etc/rc.d/init.d
# 2. 增加脚本的可执行权限
chmod +x  /etc/rc.d/init.d/StartTomcat.sh
# 3. 添加脚本到开机自动启动项目中
cd /etc/rc.d/init.d
chkconfig --add StartTomcat.sh
chkconfig StartTomcat.sh on
```

## 2.编辑/etc/rc.d/rc.loacl

```
echo "command" >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
```

## 3.试用systemd编写服务(推荐)

见[Systemd服务文件编写-centos7下](/posts/systemd/)


# 番外篇：测试vps回程路由

```shell
yum install -y unzip wget

cd /usr/local
mkdir trace
cd trace
wget https://cdn.ipip.net/17mon/besttrace4linux.zip
unzip besttrace4linux.zip
chmod +x besttrace
rm -f besttrace4linux.zip
cd

ln -fs /usr/local/trace/besttrace /usr/local/bin/trace
trace arloor.com
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


<img src="/img/ssnodes.png" alt="" width="800px" style="max-width: 100%;">

开始操作：

## 方案一：使用iptables，适用于落地鸡ip不会改变的情况

写了一个支持域名的iptables转发脚本，执行以下命令即可使用

```shell
rm -f iptables.sh;
wget  https://raw.githubusercontent.com/arloor/iptablesUtils/master/iptables.sh;
bash iptables.sh;
```

输入local port，remote port，target domain/ip。其中target domain/ip既可以是ip，也可以是域名。

```shell
本脚本用途：
设置本机tcp和udp端口转发
原始iptables仅支持ip地址，该脚本增加域名支持（要求域名指向的主机ip不变）
若要支持ddns，请使用 https://raw.githubusercontent.com/arloor/iptablesUtils/master/setCroniptablesDDNS.sh;

local port:8388
remote port:1234
target domain/ip:xxx.com
target-ip: xx.xx.xx.xx
local-ip: xx.xx.xx.xx
done!
```

题外话（自己备忘）：某端口流量转发到本机其他端口：(从localhost访问，这个转发无效)

```shell
iptables -t nat -A PREROUTING -p tcp --dport 8081 -j REDIRECT --to-ports 8080
```

### 删除本机某端口上的转发

```shell
rm -f rmPreNatRule.sh
wget https://raw.githubusercontent.com/arloor/iptablesUtils/master/rmPreNatRule.sh;
bash rmPreNatRule.sh $localport
```

### 当然iptables也能处理ip会变的情况，这里提供我写的脚本

执行以下命令

```shell
rm -f setCroniptablesDDNS.sh
wget https://raw.githubusercontent.com/arloor/iptablesUtils/master/setCroniptablesDDNS.sh;
bash setCroniptablesDDNS.sh


#local port:80
#remote port:58000
#targetDDNS:xxxx.example.com
#done!
#现在每分钟都会检查ddns的ip是否改变，并自动更新
```

输入local port, remote port, targetDDNS即可。之后会每分钟每分钟都会检查ddns的ip是否改变，并自动更新。执行日志见 /root/iptables.log

## 方案二：使用socat，适用于落地鸡是使用了ddns更新域名解析的nat vps


执行以下命令，填写转发地址和端口即可。该命令会设置开机自启动，同一设置不需要多次执行，也请不需要在同一端口配置多个转发。

```shell
wget http://arloor.com/socat.sh
bash socat.sh
```

停止：

```
kill -9 $(ps -ef|grep socat|grep -v grep|awk '{print $2}')
```

另外，该脚本会停止iptables服务，导致防火墙规则失效，对一般用户来说不是啥大问题。

# 番外篇：自己搭建speedtest网站

先安装docker

```shell
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
systemctl start docker
docker run -d --restart always --name  speedtest -p 0.0.0.0:80:80 arloor/speedtest:latest
```

或者，自己构建镜像：

拉取speedtest镜像并运行

```shell
cd 
git clone -b docker https://github.com/adolfintel/speedtest.git
cd speedtest
docker build -t arloor/speedtest:latest .
docker run -d --restart always --name  speedtest -p 0.0.0.0:80:80 arloor/speedtest:latest
cd 
```

现在就可以访问 http://ip:80 测速了。参见[speedtest项目](https://github.com/adolfintel/speedtest/tree/docker)

# 番外篇：vps上传速度测试

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

