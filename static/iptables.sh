#! /bin/bash

echo ""
echo 时间：$(date)

remotehost=hknathosts.ddnspod.xyz #中转目标host，自行修改
port=58100  #中转端口，自行修改

remote=$(host -t a  $remotehost|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
lastremote=$(cat /root/remoteip)

if [ "$lastremote" = "$remote" ]; then
    echo 地址解析未变化，退出
    exit 1
fi

echo last-remote-ip: $lastremote
echo new-remote-ip: $remote
echo $remote > /root/remoteip


## 获取本机地址
local=$(ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1 | grep -Ev '(^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.1[6-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.2[0-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.3[0-1]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$)')
if [ "x${extip}" = "x" ]; then
	local=$(ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1 )
fi
echo  local-ip: $local
echo  重新设置iptables转发

iptables -F -t nat

## 中转到nathosts
iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination $remote:$port
iptables -t nat -A PREROUTING -p udp --dport $port -j DNAT --to-destination $remote:$port
iptables -t nat -A POSTROUTING -p tcp -d $remote --dport $port -j SNAT --to-source $local
iptables -t nat -A POSTROUTING -p udp -d $remote --dport $port -j SNAT --to-source $local

# ============================================================================================
# 以下为固定
## 中转到natcloud
iptables -t nat -A PREROUTING -p tcp --dport 28100 -j DNAT --to-destination 219.76.152.121:28100
iptables -t nat -A PREROUTING -p udp --dport 28100 -j DNAT --to-destination 219.76.152.121:28100
iptables -t nat -A POSTROUTING -p tcp -d 219.76.152.121 --dport 28100 -j SNAT --to-source $local
iptables -t nat -A POSTROUTING -p udp -d 219.76.152.121 --dport 28100 -j SNAT --to-source $local