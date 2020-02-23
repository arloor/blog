---
title: "centos8使用nftables设置nat转发"
date: 2020-02-02T22:33:10+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

nftables具有脚本编程能力，并且使用脚本更新规则具有事务性，要么全部成功，要么全部不成功。这两个特性很有趣，今天用nftables的编程能力来做下nat转发。
<!--more-->

## nftables脚本

废话不多说，直接上nftables脚本。假设这个脚本在`/etc/nftables/diy.nft`

```shell
#!/usr/sbin/nft -f

define localIP = 172.17.37.225
define remoteIP = xx.xx.xx.xx
define remotePort = xx
define localPort = xx
delete table ip nat
add table ip nat
add chain nat PREROUTING { type nat hook prerouting priority -100 ; }
add chain nat POSTROUTING { type nat hook postrouting priority 100 ; }
add rule ip nat PREROUTING tcp dport $localPort counter dnat to $remoteIP:$remotePort
add rule ip nat PREROUTING udp dport $localPort counter dnat to $remoteIP:$remotePort
# masquerade为自动寻找网卡ip
# add rule ip nat POSTROUTING ip daddr $remoteIP tcp dport $remotePort counter masquerade
# add rule ip nat POSTROUTING ip daddr $remoteIP tcp dport $remotePort counter masquerade
add rule ip nat POSTROUTING ip daddr $remoteIP tcp dport $remotePort counter snat to $localIP
add rule ip nat POSTROUTING ip daddr $remoteIP udp dport $remotePort counter snat to $localIP
```

## 执行脚本

假设这个脚本在`/etc/nftables/diy.nft`

```
chown root /etc/nftables/diy.nft
chmod u+x /etc/nftables/diy.nft
/etc/nftables/diy.nft
```

这样就将上述脚本执行了。

## 开机运行以上脚本

**前提条件**：你的nftables脚本在`/etc/nfatables`文件夹下

**1** 编辑`/etc/sysconfig/nftables.conf`

增加这样一行：

```
include "/etc/nftables/diy.nft"
```

**2** 开机运行该脚本

```
systemctl enable nftables
```

**3** 不重启，立即执行该脚本

```
systemctl start nftables
```


## 一些其他情况

**1** 关于端口段的nat，只需要在脚本中采取如下表现形式：

```
nft add rule ip nat PREROUTING tcp dport 20000-30000 counter dnat to 8.8.8.8:20000-30000
```

要注意，源端口段和目标端口段一定要一样，不然nat会出现不符合预期的情况。

**2**  nat转发首先需要开启ip_forward功能

```
    echo "端口转发开启"
    sed -n '/^net.ipv4.ip_forward=1/'p /etc/sysctl.conf | grep -q "net.ipv4.ip_forward=1"
    if [ $? -ne 0 ]; then
        echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
    fi
```

## 参考文档

[redhat8 nftables](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/getting-started-with-nftables_configuring-and-managing-networking)

-----------------------------------------------------------------

下面介绍一个nftables规则生成的工具，github地址是[arloor/nftables-nat-rust](https://github.com/arloor/nftables-nat-rust)

## centos8 nftables nat规则生成工具

> 仅适用于centos8、redhat8

## 准备工作

1. 关闭firewalld
2. 关闭selinux
3. 开启内核端口转发

以下一键完成：

```$xslt
service firewalld stop
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sed -n '/^net.ipv4.ip_forward=1/'p /etc/sysctl.conf | grep -q "net.ipv4.ip_forward=1"
if [ $? -ne 0 ]; then
    echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
fi
```


## 使用方式：

```
wget -O nat http://cdn.arloor.com/tool/nat
chmod +x nat
./nat nat.conf
```

其中`nat.conf`类似如下：

```$xslt
SINGLE,443,443,baidu.com
RANGE,1000,2000,baidu.com
```

- 每行代表一个规则
- SINGLE：单端口转发：本机443端口转发到baidu.com:443
- RANGE：范围端口转发：本机1000-2000转发到baidu.com:1000-2000

## 输出示例

```$xslt
nftables脚本如下：
#!/usr/sbin/nft -f

flush ruleset
add table ip nat
add chain nat PREROUTING { type nat hook prerouting priority -100 ; }
add chain nat POSTROUTING { type nat hook postrouting priority 100 ; }

#SINGLE { local_port: 10000, remote_port: 443, remote_domain: "baidu.com" }
add rule ip nat PREROUTING tcp dport 10000 counter dnat to 39.156.69.79:443
add rule ip nat PREROUTING udp dport 10000 counter dnat to 39.156.69.79:443
add rule ip nat POSTROUTING ip daddr 39.156.69.79 tcp dport 443 counter snat to 172.17.37.225
add rule ip nat POSTROUTING ip daddr 39.156.69.79 udp dport 443 counter snat to 172.17.37.225

#RANGE { port_start: 1000, port_end: 2000, remote_domain: "baidu.com" }
add rule ip nat PREROUTING tcp dport 1000-2000 counter dnat to 220.181.38.148:1000-2000
add rule ip nat PREROUTING udp dport 1000-2000 counter dnat to 220.181.38.148:1000-2000
add rule ip nat POSTROUTING ip daddr 220.181.38.148 tcp dport 1000-2000 counter snat to 172.17.37.225
add rule ip nat POSTROUTING ip daddr 220.181.38.148 udp dport 1000-2000 counter snat to 172.17.37.225


执行/usr/sbin/nft -f temp.nft
执行结果: exit code: 0
```

## 注意

1. 重启会转发规则会失效，此时重新执行`./nat nat.conf`即可
2. 当本机ip或目标主机ip变化时，需要手动执行`./nat nat.conf`
3. 本机多个网卡的情况未作测试
4. 本工具在centos8上有效，其他发行版未作测试