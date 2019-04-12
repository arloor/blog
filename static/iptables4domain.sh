#! /bin/bash

#wget -qO- http://arloor.com/iptables4domain.sh|bash

echo 时间：$(date)

red="\033[31m"
black="\033[0m"

if [ $USER = "root" ];then
	echo " "
else
    echo   -e "${red}请使用root用户执行本脚本!! ${black}"
    exit 1
fi

 #中转目标host，自行修改
remotehost=
#中转端口，自行修改
port=
localport=
if [  "$remotehost"  =  "" ];then
    echo -n "remote domain/ip:" ;read remotehost
fi

if [ "$(echo  $remotehost |grep -E -o '([0-9]{1,3}[\.]){3}[0-9]{1,3}')" != "" ];then
    isip=true
    remote=$remotehost
else
    remote=$(host -t a  $remotehost|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
fi
if [ "$remote" = "" ];then
    echo -e "${red}无法解析remotehost，请填写正确的remotehost！${black}"
    exit 1
fi

if [  "$port"  =  "" ];then
    echo -n "target port:" ;read port
fi
if [  "$localport"  =  "" ];then
    echo -n "local port:" ;read localport
fi


# 开启端口转发
sed -n '/^net.ipv4.ip_forward=1/'p /etc/sysctl.conf | grep -q "net.ipv4.ip_forward=1"
if [ $? -eq 0 ]; then
    echo ""
else
    echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
fi


## 获取本机地址
local=$(ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1 | grep -Ev '(^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.1[6-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.2[0-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.3[0-1]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$)')
if [ "x${extip}" = "x" ]; then
	local=$(ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1 )
fi
echo target-ip: $remote
echo  local-ip: $local


# iptables -F -t nat
# ## 因为iptables 规则被清空了，所以重启docker服务，已重新设置iptables规则
# service docker restart


## 中转到nathosts
iptables -t nat -A PREROUTING -p tcp --dport $localport -j DNAT --to-destination $remote:$port
iptables -t nat -A PREROUTING -p udp --dport $localport -j DNAT --to-destination $remote:$port
iptables -t nat -A POSTROUTING -p tcp -d $remote --dport $port -j SNAT --to-source $local
iptables -t nat -A POSTROUTING -p udp -d $remote --dport $port -j SNAT --to-source $local
echo 端口转发成功
