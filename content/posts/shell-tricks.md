---
title: "我常用Shell编程的小把戏"
date: 2022-05-08T17:19:30+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

个人搞了很多零散的shell脚本，开个博客统一整理下
<!--more-->

## 统计客户端连接数

```shell
cat > /usr/local/bin/nt <<\EOF
netstat -nt|grep -E "ESTABLISHED|CLOSE_WAIT"|tail -n +3|awk -F "[ :]+"  -v OFS="" '$5<10000 && $5!="22" && $7>1024 {printf("%15s   => %15s:%-5s %s\n",$6,$4,$5,$9)}'|sort|uniq -c|sort -rn
EOF
chmod +x /usr/local/bin/nt
nt
```

**说明**

过滤了localPort为22（到ssh的连接）、remotePort在1024以下（如80，443等公开服务）的连接，剩下的连接可以认为是remote主动发起连接的，可以认为是本机的client。

**效果**

```shell
     10  124.78.xxx.xxx   =>       10.0.4.10:443
```

**用到的知识**

1. awk设置FS、OFS
2. awk条件判断
3. tail从第几行开始显示文件
4. sort和uniq搭配使用，统计行出现次数

## 统计网卡流量

```shell
cat > /usr/local/bin/netsum << \EOF
echo ""
echo Time: $(date)
cat /proc/uptime| awk -F. '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("uptime：\033[32m%d天%d时%d分%d秒\033[0m\n",run_days,run_hour,run_minute,run_second)}'
echo "--------------------------------------------------------------------------" 
cat /proc/net/dev|tail -n +3|awk 'BEGIN{sumIn=0;sumOut=0;printf("流量累计使用情况：\n%6s %9s %9s\n","eth","out","in")} {eth=$1;sumIn+=$2;sumOut+=$10;xin=$2 / 1073741824;xout=$10 / 1073741824;printf("%6s \033[32m%7.2fGB\033[0m \033[32m%7.2fGB\033[0m\n",eth,xout,xin)} END{printf("%6s \033[32m%7.2fGB\033[0m \033[32m%7.2fGB\033[0m\n","sum:",sumOut / 1073741824,sumIn / 1073741824)}'
echo "--------------------------------------------------------------------------"
EOF
chmod +x /usr/local/bin/netsum
if ! grep "/usr/local/bin/netsum" /etc/crontab > /dev/null; 
then 
  echo "* * * * * root /usr/local/bin/netsum > /etc/motd" >> /etc/crontab; 
else 
  echo 已设置定时任务; 
fi
```


**使用效果**

```shell
Time: Sun May 8 17:30:34 CST 2022
uptime：1天21时44分26秒
--------------------------------------------------------------------------
流量累计使用情况：
   eth       out        in
   lo:    0.03GB    0.03GB
 eth0:   13.86GB   14.08GB
 eth1:    0.00GB    0.00GB
  sum:   13.88GB   14.11GB
--------------------------------------------------------------------------
```

**用到的知识**

1. awk 加减乘除表达式运算
2. awk BEGIN、END，在处理开始和结束执行任务
3. printf 格式化输出 `printf "%5s 分隔符 %5s\n" one two`
4. 利用grep返回结果在if语句里判断文件中是否存在某语句

```shell
if ! grep "/usr/local/bin/netsum" /etc/crontab > /dev/null; 
then
....
else
....
fi
```


## sed替换文本内容

```shell
sed -i "s/UseDNS.*/UseDNS no/g" /etc/ssh/sshd_config
```

将匹配`UseDNS.*`的行都换成`UseDNS no`，并写入原文件。支持正则表达式，见[sed_regular_expressions](https://www.yiibai.com/sed/sed_regular_expressions.html)

## sed删除行

```shell
sed -i '/^alias nt=.*/d' .bashrc
```