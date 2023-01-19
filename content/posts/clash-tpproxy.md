---
title: "Clash透明代理"
date: 2023-01-19T13:55:54+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

clash透明代理可以使用ShellClash，这里记录下其中的核心技术，掌握核心技术才好。

<!--more-->

## 前言

一开始我使用Clash tun模式，遇到的最大问题是dns污染。后面看到了Shell Clash看到了使用redir和nftables相关的东西。

## 利用iptables-redirct来做透明代理

### clash配置

1. 关闭tun
2. 使用dns的fallback配置来避免dns污染相关问题

```yaml
mixed-port: 7890
redir-port: 7892
authentication: [""]
allow-lan: true
mode: Rule
log-level: info
ipv6: false
external-controller: :9999
external-ui: ui
secret: 
tun: {enable: false}
experimental: {ignore-resolve-fail: true, interface-name: en0}
dns: {enable: true, ipv6: false, listen: 0.0.0.0:1053, use-hosts: true, enhanced-mode: redir-host, default-nameserver: [114.114.114.114, 223.5.5.5, 127.0.0.1:53], nameserver: [114.114.114.114, 223.5.5.5], fallback: [1.0.0.1, 8.8.4.4], fallback-filter: {geoip: true}}

store-selected: true
hosts:
   'localhost': 127.0.0.1
```

### 使用iptables-redirct规则

![](/img/netfilter.54ecb183.png)
[Project X透明代理文档](https://xtls.github.io/document/level-2/transparent_proxy/transparent_proxy.html#iptables-nftables)

关键摘要：

1. 为非网关设备：控制PREROUTING，将非网关的其他设备redirect到clash的redir端口上
2. 为网关自己：控制OUTPUT链，将网关本身发出的流量也走到clash中，并重新走一次PREROUTING一边进行透明代理
3. **因为使用的是redirect模式，所以需要打开内核的ip_forward特性**。（iptables-tpproxy则需要根据fwmark进行增加ip route

开启内核的ip_forward

```shell
sed -i '/^net.ipv4.ip_forward=0/'d /etc/sysctl.conf
sed -n '/^net.ipv4.ip_forward=1/'p /etc/sysctl.conf | grep -q "net.ipv4.ip_forward=1"
if [ $? -ne 0 ]; then
    echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
fi
```

nftables的redirect（以下只代理tcp，不代理udp）

```shell
cat > /lib/systemd/system/con.service <<EOF
[Unit]
Description=clash
After=network.target

[Service]
Type=simple
User=root
ExecStartPre=nft flush ruleset
ExecStart=/bin/su shellclash -c "/opt/con/clashnet -d /opt/con/"
ExecStartPost=nft -f /etc/nftables/nftables-redirect-clash.nft
Restart=on-failure
RestartSec=3s
LimitNOFILE=999999


[Install]
WantedBy=multi-user.target
EOF
```

```shell
mkdir /etc/nftables
cat > /etc/nftables/nftables-redirect-clash.nft <<EOF
table ip nat {
	chain clash_dns {
		meta l4proto udp redirect to :1053
	}

	chain PREROUTING {
		type nat hook prerouting priority dstnat; policy accept;
		meta l4proto udp udp dport 53 jump clash_dns
		meta l4proto tcp tcp dport { 22,53,587,465,995,993,143,80,443,8080} jump clash
	}

	chain clash {
		ip daddr 0.0.0.0/8 return
		ip daddr 10.0.0.0/8 return
		ip daddr 127.0.0.0/8 return
		ip daddr 100.64.0.0/10 return
		ip daddr 169.254.0.0/16 return
		ip daddr 172.16.0.0/12 return
		ip daddr 192.168.0.0/16 return
		ip daddr 224.0.0.0/4 return
		ip daddr 240.0.0.0/4 return
		meta l4proto tcp ip saddr 192.168.0.0/16 redirect to :7892
		meta l4proto tcp ip saddr 10.0.0.0/8 redirect to :7892
	}
}
table ip6 nat {
	chain clashv6_dns {
		meta l4proto udp redirect to :1053
	}

	chain PREROUTING {
		type nat hook prerouting priority dstnat; policy accept;
		meta l4proto udp udp dport 53 jump clashv6_dns
	}
}
table ip filter {
	chain INPUT {
		type filter hook input priority filter; policy accept;
		meta l4proto tcp ip saddr 10.0.0.0/8 tcp dport 7890 accept
		meta l4proto tcp ip saddr 127.0.0.0/8 tcp dport 7890 accept
		meta l4proto tcp ip saddr 192.168.0.0/16 tcp dport 7890 accept
		meta l4proto tcp ip saddr 172.16.0.0/12 tcp dport 7890 accept
		meta l4proto tcp tcp dport 7890 reject
	}
}
table ip6 filter {
	chain INPUT {
		type filter hook input priority filter; policy accept;
		meta l4proto tcp tcp dport 7890 reject
	}
}
EOF

if [ -z "$(id shellclash 2>/dev/null | grep 'root')" ];then
			if ckcmd userdel useradd groupmod; then
				userdel shellclash 2>/dev/null
				useradd shellclash -u 7890
				groupmod shellclash -g 7890
				sed -Ei s/7890:7890/0:7890/g /etc/passwd
			else
				grep -qw shellclash /etc/passwd || echo "shellclash:x:0:7890:::" >> /etc/passwd
			fi
		fi

cat > /etc/nftables/nftables-redirect-clash-local.nft <<EOF
table ip nat {
	chain PREROUTING {
		type nat hook prerouting priority dstnat; policy accept;
		meta l4proto udp udp dport 53 jump clash_dns
		meta l4proto tcp tcp dport { 22,53,587,465,995,993,143,80,443,8080} jump clash
		meta l4proto tcp jump clash
	}

	chain clash {
		ip daddr 0.0.0.0/8 return
		ip daddr 10.0.0.0/8 return
		ip daddr 127.0.0.0/8 return
		ip daddr 100.64.0.0/10 return
		ip daddr 169.254.0.0/16 return
		ip daddr 172.16.0.0/12 return
		ip daddr 192.168.0.0/16 return
		ip daddr 224.0.0.0/4 return
		ip daddr 240.0.0.0/4 return
		meta l4proto tcp ip saddr 192.168.0.0/16 redirect to :7892
		meta l4proto tcp ip saddr 10.0.0.0/8 redirect to :7892
	}

	chain clash_dns {
		meta l4proto udp redirect to :1053
	}

	chain clash_out {
		skgid 7890 return
		ip daddr 0.0.0.0/8 return
		ip daddr 10.0.0.0/8 return
		ip daddr 100.64.0.0/10 return
		ip daddr 127.0.0.0/8 return
		ip daddr 169.254.0.0/16 return
		ip daddr 192.168.0.0/16 return
		ip daddr 224.0.0.0/4 return
		ip daddr 240.0.0.0/4 return
		meta l4proto tcp redirect to :7892
	}

	chain OUTPUT {
		type nat hook output priority -100; policy accept;
		meta l4proto tcp jump clash_out
		meta l4proto udp udp dport 53 jump clash_dns_out
	}

	chain clash_dns_out {
		skgid 7890 return
		meta l4proto udp redirect to :1053
	}
}
table ip6 nat {
	chain PREROUTING {
		type nat hook prerouting priority dstnat; policy accept;
		meta l4proto udp udp dport 53 jump clashv6_dns
	}

	chain clashv6_dns {
		meta l4proto udp redirect to :1053
	}
}
table ip filter {
	chain INPUT {
		type filter hook input priority filter; policy accept;
		meta l4proto tcp ip saddr 10.0.0.0/8 tcp dport 7890 accept
		meta l4proto tcp ip saddr 127.0.0.0/8 tcp dport 7890 accept
		meta l4proto tcp ip saddr 192.168.0.0/16 tcp dport 7890 accept
		meta l4proto tcp ip saddr 172.16.0.0/12 tcp dport 7890 accept
		meta l4proto tcp tcp dport 7890 reject
	}
}
table ip6 filter {
	chain INPUT {
		type filter hook input priority filter; policy accept;
		meta l4proto tcp tcp dport 7890 reject
	}
}
EOF
nft flush ruleset
service con restart
nft -f /etc/nftables/nftables-redirect-clash-local.nft
```

## iptables-tpproxy

[Istio的流量劫持和Linux下透明代理实现](https://www.ichenfu.com/2019/04/09/istio-inbond-interception-and-linux-transparent-proxy/)

后续再补充，和redirect的主要区别是不需要ip_forward的特性，nftables的语句将主要是--tp-proxy等。因为tpproxy需要给流量标记，还需要单独对有流量标记的流量配置路由表

> 除了利用REDIRECT模式，Istio还提供TPROXY模式，当然也是借助Linux内核提供的功能实现的，对于TPROXY模式，实现的原理要相对复杂不少，需要借助iptables和路由：通过iptables将数据包打上mark，然后使用一个特殊的路由，将数据包指向本地，由于使用了mangle表，所以数据包的原始和目的地址都是不会被修改的。下面是一个例子：

```shell
iptables -t mangle -A PREROUTING -p tcp -j TPROXY --tproxy-mark 0x1/0x1 --on-port 8888
ip rule add fwmark 0x1/0x1 pref 100 table 100
ip route add local default dev lo table 100
```

