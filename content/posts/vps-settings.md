---
title: "VPS基础配置"
date: 2023-07-10T14:42:50+08:00
draft: false
categories: [ "undefined"]
tags: ["tools"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```shell
echo "set bell-style none" >> /etc/inputrc
timedatectl set-timezone Asia/Shanghai

mkdir -p /root/.ssh
#关闭密码
grep "PasswordAuthentication yes " /etc/ssh/sshd_config
sed  -i  -e 's/\(#\)\?PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
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
systemctl restart sshd

## 开启bbr
uname -r  ##输出内核版本大于4.9
echo net.core.default_qdisc=fq >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf
sysctl -p
lsmod |grep bbr


## 禁用firewalld
systemctl disable firewalld --now
## 关闭selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config  
sestatus

## zsh
yum install -y zsh
sh -c "$(curl -fsSL --insecure https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
usermod -s /bin/zsh $USER
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sed -i  -e "s/^plugin.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g" ~/.zshrc
## 在命令提示符前增加hostname
echo 'export PS1="%m "${PS1}' >> ~/.zshrc
## 恢复bash的PS1
cat >> ~/.bashrc <<\EOF
export PS1="[\u@\h \W]\$ "
EOF

yum install -y tuned # 性能优化

cat > /usr/local/bin/netsum   <<\EOF                                                      
echo ""
echo Time: $(date '+%F %T')
cat /proc/uptime| awk -F. '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("uptime：\033[32m%d天%d时%d分%d秒\033[0m\n",run_days,run_hour,run_minute,run_second)}'
echo "--------------------------------------------------------------------------" 
cat /proc/net/dev|tail -n +3|awk 'BEGIN{sumIn=0;sumOut=0;printf("流量累计使用情况：\n%6s %9s %9s\n","eth","out","in")} {eth=$1;sumIn+=$2;sumOut+=$10;xin=$2 / 1073741824;xout=$10 / 1073741824;printf("%6s \033[32m%7.2fGB\033[0m \033[32m%7.2fGB\033[0m\n",eth,xout,xin)} END{printf("%6s \033[32m%7.2fGB\033[0m \033[32m%7.2fGB\033[0m\n","sum:",sumOut / 1073741824,sumIn / 1073741824)}'
echo "--------------------------------------------------------------------------"
EOF
chmod +x /usr/local/bin/netsum

cat > /usr/local/bin/nt    <<\EOF
netstat -ntp|grep -E "ESTABLISHED|CLOSE_WAIT"|tail -n +3|awk -F "[ :]+"  -v OFS="" '$5<10000 && $5!="22" && $7>1024 {printf("%15s   => %15s:%-5s %s\n",$6,$4,$5,$9)}'|sort|uniq -c|sort -rn
EOF
chmod +x /usr/local/bin/nt

netsum
nt
```