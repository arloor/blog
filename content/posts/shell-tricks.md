---
title: "Shell编程笔记"
date: 2022-05-08T17:19:30+08:00
draft: false
categories: ["undefined"]
tags: ["tools"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
---

个人搞了很多零散的 shell 脚本，开个博客统一整理下

<!--more-->

## 统计客户端连接数

```bash
cat > /usr/local/bin/nt <<\EOF
netstat -ntp|grep -E "ESTABLISHED|CLOSE_WAIT"|awk -F "[ :]+"  -v OFS="" '$5<10000 && $5!="22" && $7>1024 {printf("%15s   => %15s:%-5s %s\n",$6,$4,$5,$9)}'|sort|uniq -c|sort -rn
EOF
chmod +x /usr/local/bin/nt
nt
```

**说明**

过滤了 localPort 为 22（到 ssh 的连接）、remotePort 在 1024 以下（如 80，443 等公开服务）的连接，剩下的连接可以认为是 remote 主动发起连接的，可以认为是本机的 client。

**效果**

```bash
     22    209.9.xxx.xx   =>       10.0.4.10:443   144085/rust_xx
      2  222.70.xxx.xxx   =>       10.0.4.10:443   144085/rust_xx
      2   101.90.xx.xxx   =>       10.0.4.10:443   144085/rust_xx
```

**用到的知识**

1. awk 设置 FS、OFS
2. awk 条件判断
3. tail 从第几行开始显示文件
4. sort 和 uniq 搭配使用，统计行出现次数

## 统计网卡流量

```bash
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

```bash
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
4. 利用 grep 返回结果在 if 语句里判断文件中是否存在某语句

```bash
if ! grep "/usr/local/bin/netsum" /etc/crontab > /dev/null;
then
....
else
....
fi
```

## sed 替换文本内容

```bash
sed -i "s/UseDNS.*/UseDNS no/g" /etc/ssh/sshd_config
```

将匹配`UseDNS.*`的行都换成`UseDNS no`，并写入原文件。支持正则表达式，见[sed_regular_expressions](https://www.yiibai.com/sed/sed_regular_expressions.html)

## sed 删除行

```bash
sed -i '/^alias nt=.*/d' .bashrc
```

## awk 设置变量

`host=$1` 设置了 host 这个变量，并在后续的 awk command 中用到

```bash
➜  ~ cat /data/bin/pod
kubectl get pod -A -o wide -l app=proxy |awk -v host=$1 '$8==host {print $2}'
➜  ~ pod hk
proxy-pqhhc
```

## Clickhouse 简化命令

场景：使用 clickhouse client 连接数据库时，经常要带一些参数，例如 ip、用户名等。每次都输入这些信息的话，会比较麻烦。一种解法是写 alias，但是在一些场景下免不了`source ~/.zsh_rc`。另一种更通用的方式是写个 shell 脚本：

```bash
/usr/bin/clickhouse client -h 10.0.218.10 --database xxxx --send_logs_level=trace --log-level=trace --server_logs_file='/tmp/query.log' "$@"
```

核心是最后的 `"$@"` ，其他则是将 ck 查询的日志传送到本地。

在 shell 脚本中，`"$@"`和`$@`有不同的行为：

- `"$@"` 保留了每个参数的引号，并且将每个参数视为单独的字符串。所以，如果你传递了多个参数，它们会被视为多个独立的参数。
- `$@` 不保留每个参数的引号，参数之间的空格会被解释为参数分隔符。

在你的例子中，当你执行 `/usr/local/bin/ck --query "select 1"`时，`"$@"` 会把 `--query` 和 `"select 1"` 作为两个独立的参数，而 `$@` 会把它们看作一个参数 `--query select 1`（空格没有被保留）。

在 Clickhouse 的情况下，它需要`--query`后面跟着的查询字符串作为单独的参数。如果你使用`$@`，查询字符串 `"select 1"` 会和 `--query` 合并为一个参数，而 Clickhouse 期望它们是分开的，这就是为什么会报错。

所以在这种情况下，使用 `"$@"` 是正确的，因为它会把 `--query` 和 `"select 1"` 作为两个独立的参数传递给 Clickhouse 客户端。

## Clickhouse 导入不同环境数据

用 Fomart CSV 进行导入

```bash
# 定义sql
query=$(cat <<EOF
with 'c4e22d5e5c90364863af7e06e3c9d9c5' as traceID,
'20230805' as part
SELECT
    *
FROM tracing_span_v3_distributed
where trace_id=traceID
and _partition_id=part
order by seq,span_id
EOF
)
# 将结果集赋值给result
result=$(ck --query "$query Format CSV")
# 生成导入数据的脚本
cat > a.sh <<EPF
ck40 --query "insert into tracing_span_v3 Format CSV" <<\EOF
$result
EOF
EPF
```

接下来通过 scp 或者 ftp 或者直接复制文本的方式将 a.sh 下载到目标环境，执行 a.sh 即可导入。

## curl -sSLf

使用 `curl` 命令时，可以通过添加不同的参数来定制你的请求。`-sSLf` 参数具有以下作用：

1. `-s`（或 `--silent`）：这个选项会使 `curl` 进入“静默”模式，意味着所有的常规和进度错误都会被抑制，不会显示在命令行界面上。

2. `-S`（或 `--show-error`）：与 `-s` 一起使用时，这个选项允许在发生错误时显示错误消息。如果只使用了 `-s` 参数而没有 `-S` 参数，那么即使发生错误，也不会在屏幕上显示任何内容。通过组合这两个选项，你可以隐藏正常的进度和信息输出，但在出现问题时显示错误信息。

3. `-L`（或 `--location`）：这个选项告诉 `curl` 如果遇到重定向，就自动跟随重定向的位置。对于许多网络请求，这是非常有用的，因为它允许 `curl` 透明地处理重定向，无需人工干预。

4. `-f`（或 `--fail`）：通常，当 HTTP 请求返回非成功的状态代码（如 404 或 500）时，`curl` 仍会显示页面的响应体。使用 `-f` 选项会导致 `curl` 在遇到错误代码时立即失败并不显示响应体。这有助于在脚本中更容易地检测和处理失败的情况。

总体来说，组合这些选项的效果是，`curl` 将在正常操作时保持静默，但在出现错误时显示错误消息，同时自动处理重定向并且在遇到服务器错误时失败。这使得 `curl` 更加方便地用于自动化脚本和错误处理，尤其是在你的观察性平台开发工作中可能会非常有用。

## curl 并 gzip 解压缩

```bash
version="2023.07.22"
curl -Lf "https://github.com/Dreamacro/clash/releases/download/premium/clash-$(go env GOOS)-$(go env GOARCH)-${version}.gz" | gzip -d > /tmp/clash
install -m 777 /tmp/clash /usr/local/bin/clash
```

## shell 脚本获取脚本所在目录

- shebang 行是 /bin/bash 时：

```bash
#! /bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo $SCRIPT_DIR
```

- shebang 行是 /bin/sh 时：

```bash
#! /bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo $SCRIPT_DIR
```
