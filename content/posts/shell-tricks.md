---
title: "Shell Tricks"
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
netstat -ntp|grep -E "ESTABLISHED|CLOSE_WAIT"|tail -n +3|awk -F "[ :]+"  -v OFS="" '$5<10000 && $5!="22" && $7>1024 {printf("%15s   => %15s:%-5s %s\n",$6,$4,$5,$9)}'|sort|uniq -c|sort -rn
EOF
chmod +x /usr/local/bin/nt
nt
```

**说明**

过滤了localPort为22（到ssh的连接）、remotePort在1024以下（如80，443等公开服务）的连接，剩下的连接可以认为是remote主动发起连接的，可以认为是本机的client。

**效果**

```shell
     22    209.9.xxx.xx   =>       10.0.4.10:443   144085/rust_xx
      2  222.70.xxx.xxx   =>       10.0.4.10:443   144085/rust_xx
      2   101.90.xx.xxx   =>       10.0.4.10:443   144085/rust_xx
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
echo Time: $(date '+%F %T')
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

## 统计git仓库中用户代码行

```shell
cat > /usr/local/bin/ncode <<\EOF
[ "$1" = "" ]&&user=arloor||user=$1
echo ${user}\'s work summary:
git log --author="${user}" --pretty=tformat: --numstat | awk '{ add += $1; subs += $2; loc += $1 - $2 } END { printf "added lines: %s, removed lines: %s, total lines: %s", add, subs, loc }'
EOF
chmod +x /usr/local/bin/ncode
ncode arloor
```

## Clickhouse简化命令

场景：使用 clickhouse client 连接数据库时，经常要带一些参数，例如ip、用户名等。每次都输入这些信息的话，会比较麻烦。一种解法是写alias，但是在一些场景下免不了`source ~/.zsh_rc`。另一种更通用的方式是写个shell脚本：

```shell
/usr/bin/clickhouse client -h 10.0.218.10 --database xxxx --send_logs_level=trace --log-level=trace --server_logs_file='/tmp/query.log' "$@"
```

核心是最后的 `"$@"` ，其他则是将ck查询的日志传送到本地。

在shell脚本中，`"$@"`和`$@`有不同的行为：

- `"$@"` 保留了每个参数的引号，并且将每个参数视为单独的字符串。所以，如果你传递了多个参数，它们会被视为多个独立的参数。
- `$@` 不保留每个参数的引号，参数之间的空格会被解释为参数分隔符。

在你的例子中，当你执行 `/usr/local/bin/ck --query "select 1"`时，`"$@"` 会把 `--query` 和 `"select 1"` 作为两个独立的参数，而 `$@` 会把它们看作一个参数 `--query select 1`（空格没有被保留）。

在Clickhouse的情况下，它需要`--query`后面跟着的查询字符串作为单独的参数。如果你使用`$@`，查询字符串 `"select 1"` 会和 `--query` 合并为一个参数，而Clickhouse期望它们是分开的，这就是为什么会报错。

所以在这种情况下，使用 `"$@"` 是正确的，因为它会把 `--query` 和 `"select 1"` 作为两个独立的参数传递给 Clickhouse 客户端。