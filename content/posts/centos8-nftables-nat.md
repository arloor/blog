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