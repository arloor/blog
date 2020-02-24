---
title: "nftables设置nat转发(基于centos8)"
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

## centos8 nftables nat规则生成工具

> 仅适用于centos8、redhat8、fedora31

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


## 使用说明

```
# 必须是root用户
# sudo su

# 下载可执行文件
wget -O /usr/local/bin/nat http://cdn.arloor.com/tool/dnat
chmod +x /usr/local/bin/nat

# 生成配置文件，配置文件可按需求修改（请看下文）
cat > /etc/nat.conf <<EOF
SINGLE,49999,59999,baidu.com
RANGE,50000,50010,baidu.com
EOF

# 创建systemd服务
cat > /lib/systemd/system/nat.service <<EOF
[Unit]
Description=动态设置nat规则
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/nat /etc/nat.conf
LimitNOFILE=100000
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# 设置开机启动，并启动该服务
systemctl daemon-reload
systemctl enable nat
systemctl start nat
```

**配置文件内容说明**

`/etc/nat.conf`如下：

```$xslt
SINGLE,49999,59999,baidu.com
RANGE,50000,50010,baidu.com
```

- 每行代表一个规则；行内以英文逗号分隔为4段内容
- SINGLE：单端口转发：本机49999端口转发到baidu.com:59999
- RANGE：范围端口转发：本机50000-50010转发到baidu.com:50000-50010
- 请确保配置文件符合格式要求，否则程序可能会出现不可预期的错误，包括但不限于你和你的服务器炸掉（认真

如需修改转发规则，请`vim /etc/nat.conf`以设定你想要的转发规则。修改完毕后，无需重新启动vps或服务，程序将会自动在最多一分钟内更新nat转发规则（PS：受dns缓存影响，可能会超过一分钟）


## 优势

1. 实现动态nat：自动探测配置文件和目标域名IP的变化，除变更配置外无需任何手工介入
2. 支持IP和域名
3. 以配置文件保存转发规则，可备份或迁移到其他机器
4. 自动探测本机ip
5. 开机自启动
6. 支持端口段

## 一些需要注意的东西

1. 本工具会清空所有防火墙规则（当然，防火墙没那么重要～
2. 本机多个网卡的情况未作测试（大概率会有问题）
3. 本工具在centos8、redhat8、fedora31上有效，其他发行版未作测试
4. 与前作[arloor/iptablesUtils](https://github.com/arloor/iptablesUtils)不兼容，在两个工具之间切换时，请重装系统以确保系统纯净！
