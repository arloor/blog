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
temp=$(cat /etc/ssh/sshd_config|grep "UseDNS"|grep -v "#");
if [ "$temp" != "" ];then
 sed -i "s/UseDNS.*/UseDNS no/g" /etc/ssh/sshd_config
else
 echo >> /etc/ssh/sshd_config
 echo UseDNS no >> /etc/ssh/sshd_config
fi
# 检查UseDNS确实被关闭
cat /etc/ssh/sshd_config|grep UseDNS
service sshd restart
```

# 监控网卡累计流量

```
cat > /usr/local/bin/netsum.sh << \EOF
echo ""
echo Time: $(date)
cat /proc/uptime| awk -F. '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("uptime：%d天%d时%d分%d秒\n",run_days,run_hour,run_minute,run_second)}'
echo 流量累计使用情况：
cat /proc/net/dev|tail -n +3|awk '{eth=$1;xin=$2 / 1073741824;xout=$10 / 1073741824;printf("%s 入%.2fGB 出%.2fGB\n",eth,xin,xout)}'
EOF
chmod +x /usr/local/bin/netsum.sh
bash /usr/local/bin/netsum.sh
echo '0 4 * * * root /usr/local/bin/netsum.sh >> /root/net.log' >> /etc/crontab 
```

每天四点记录自上次开机以来vps累计使用的流量到`/root/net.log`。内容如下所示：

```
Time: 2019年 09月 09日 星期一 20:56:08 CST
uptime：11天1时53分58秒
流量累计使用情况：
eth0: 入30.20GB 出28.68GB
lo: 入0.00GB 出0.00GB
docker0: 入0.00GB 出0.00GB
```

# 安装python3.7

centos7默认只有python2.7，并且没有安装pip。我要装python3以及pip3。

```shell
yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make libffi-devel
wget https://www.python.org/ftp/python/3.7.0/Python-3.7.0.tgz
tar -zxvf Python-3.7.0.tgz
cd Python-3.7.0
#进入解压后的目录，依次执行下面命令进行手动编译
./configure prefix=/usr/local/python3 
make && make install
ln -s /usr/local/python3/bin/python3.7 /usr/bin/py3
ln -s /usr/local/python3/bin/pip3.7 /usr/bin/pip3
py3 -V
# Python 3.7.0
```

> PS:如果创建的软连接是到/usr/bin/python，则需要执行以下脚本，来修复yum

```shell
vi /usr/bin/yum 
把 #! /usr/bin/python 修改为 #! /usr/bin/python2 
vi /usr/libexec/urlgrabber-ext-down 
把 #! /usr/bin/python 修改为 #! /usr/bin/python2
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

**使用systemd管理shadowsocks服务**

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

# centos 7升级内核，开启bbr


一键完成：

```shell
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
yum --enablerepo=elrepo-kernel install -y kernel-ml  #以后升级也是执行这句
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
sed -i "s/GRUB_DEFAULT.*/GRUB_DEFAULT=0/g" /etc/default/grub
cat /etc/default/grub|grep GRUB_DEFAULT
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot

#重启后
uname -r  ##输出内核版本大于4.9
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p
lsmod |grep bbr
```

分部解析：

**1.查看当前linux内核**

```shell
uname -r
# 3.10.0-514.el7.x86_64
cat /etc/redhat-release 
# CentOS Linux release 7.3.1611 (Core)
```

**2.启用ELRepo库**

```shell
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
```

**3.列出相关内核包**

```shell
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
```

![](/img/kernels.png)

**4.安装新内核**

```shell
yum --enablerepo=elrepo-kernel install kernel-ml  #以后升级也是执行这句
```

**5.检查现在可以用于启动得内核列表**

```shell
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
# CentOS Linux (5.0.5-1.el7.elrepo.x86_64) 7 (Core)
# CentOS Linux (3.10.0-957.10.1.el7.x86_64) 7 (Core)
# CentOS Linux (3.10.0-957.5.1.el7.x86_64) 7 (Core)
# CentOS Linux (3.10.0-957.el7.x86_64) 7 (Core)
# CentOS Linux (0-rescue-20190215172108590907433256076310) 7 (Core)
```

由上面可以看出新内核(5.0.5)目前位置在0，原来的内核(3.10.0)目前位置在1，所以如果想生效最新的内核，还需要我们修改内核的启动顺序为0

**6.设置默认启动内核为刚安装得内核**

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

**7.重新生成grub-config，并使用新内核重启**

```shell
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot
```

现在就可以使用uname命令查看内核了

**8.开启bbr很简单：**

```shell
uname -r  ##输出内核版本大于4.9
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p
lsmod |grep bbr
```

**# 配置防火墙**

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

**1.利用chkconfig xx on**

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

**2.编辑/etc/rc.d/rc.loacl**

```
echo "command" >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
```

**3.使用systemd编写服务(推荐)**

见[Systemd服务文件编写-centos7下](/posts/linux/systemd/)


# 测试vps回程路由

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



# 流量转发

**iptables转发静态域名解析（域名指向的ip不变）的host**

写了一个支持域名的iptables转发脚本，执行以下命令即可使用

```shell
wget -O iptables.sh https://raw.githubusercontent.com/arloor/iptablesUtils/master/iptables.sh;bash iptables.sh;
```

题外话（自己备忘）：某端口流量转发到本机其他端口：(从localhost访问，这个转发无效)

```shell
iptables -t nat -A PREROUTING -p tcp --dport 8081 -j REDIRECT --to-ports 8080
```

**删除本机某端口上的转发**

```shell
wget -O rmPreNatRule.sh https://raw.githubusercontent.com/arloor/iptablesUtils/master/rmPreNatRule.sh;bash rmPreNatRule.sh 8080[要删除的端口号]
```

**iptables转发动态解析的域名（ddns）**

执行以下命令

```shell
wget -O dnat-install.sh https://raw.githubusercontent.com/arloor/iptablesUtils/master/dnat-install.sh
bash dnat-install.sh
```


# 搭建网速测试网站

先安装docker

```shell
yum install -y wget
wget -qO- https://get.docker.com/|bash
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