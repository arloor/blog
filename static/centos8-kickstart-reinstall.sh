[[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1;

black="\033[0m"
baseUrl="http://mirrors.huaweicloud.com/centos/8.1.1911"

## 检查依赖
function CheckDependence(){
FullDependence='0';
for BIN_DEP in `echo "$1" |sed 's/,/\n/g'`
  do
    if [[ -n "$BIN_DEP" ]]; then
      Founded='0';
      for BIN_PATH in `echo "$PATH" |sed 's/:/\n/g'`
        do
          ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
          if [ $? == '0' ]; then
            Founded='1';
            break;
          fi
        done
      if [ "$Founded" == '1' ]; then
        echo -en "$BIN_DEP\t\t[\033[32mok\033[0m]\n";
      else
        FullDependence='1';
        echo -en "$BIN_DEP\t\t[\033[31mfail\033[0m]\n";
      fi
    fi
  done
if [ "$FullDependence" == '1' ]; then
  exit 1;
fi
}

clear && echo -e "\n\033[36m# Check Dependence\033[0m\n"
CheckDependence wget,awk,xz,openssl,grep,dirname,file,cut,cat,cpio,gzip
echo "Dependence Check done"


## 寻找grub.cfg
[[ -f '/boot/grub/grub.cfg' ]] && GRUBOLD='0' && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg';
[[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub2/grub.cfg' ]] && GRUBOLD='0' && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg';
[[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub/grub.conf' ]] && GRUBOLD='1' && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf';
[ -z "$GRUBDIR" -o -z "$GRUBFILE" ] && echo -ne "Error! \nNot Found grub path.\n" && exit 1;
## 为了简单起见，不支持grub1
[ "x$GRUBOLD" = "x1" ] && echo "Error! \ngrub1 not supported, please use centos7 as Base OS. since centos7 use grub2" && exit1


echo -e "\n\033[36m# Install\033[0m\n"
## 下载kernel和initrd
echo "initrd.img downloading...."
wget --no-check-certificate -qO '/boot/initrd.img' "${baseUrl}/BaseOS/x86_64/os/isolinux/initrd.img"
echo "vmlinuz downloading...."
wget --no-check-certificate -qO '/boot/vmlinuz' "${baseUrl}/BaseOS/x86_64/os/isolinux/vmlinuz"
echo "done"

## 查看网络信息 ip、网关、掩码
  DEFAULTNET="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
  [[ -n "$DEFAULTNET" ]] && IPSUB="$(ip addr |grep ''${DEFAULTNET}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";
  ###ip地址
  IPv4="$(echo -n "$IPSUB" |cut -d'/' -f1)";
  ### /16 /24等子网掩码
  NETSUB="$(echo -n "$IPSUB" |grep -o '/[0-9]\{1,2\}')";
  ### 网关
  GATE="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
  ### MASK 255.255.0.0
  [[ -n "$NETSUB" ]] && MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${NETSUB}'' |cut -d'/' -f1)";

[[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
echo "Not found \`ip command\`, Exit！please use centos7 as Base os." && exit 1
}

##检查/etc/sysconfig/network-scripts
[[ ! -d '/etc/sysconfig/network-scripts' ]] && echo "/etc/sysconfig/network-scripts not exit. please use centos7 as base os.exit." && exit 1
## 检查本机是不是dhcp的 最终设置AutoNet 1-dhcp 0-static
[[ -d '/etc/sysconfig/network-scripts' ]] && {
  ICFGN="$(find /etc/sysconfig/network-scripts -name 'ifcfg-*' |grep -v 'lo'|wc -l)" || ICFGN='0';
  [[ "$ICFGN" -ne '0' ]] && {
    for NetCFG in `ls -1 /etc/sysconfig/network-scripts/ifcfg-* |grep -v 'lo$' |grep -v ':[0-9]\{1,\}'`
      do 
      ## 打印 BOOTPROTO=dhcp 如果有的话，并且设置AutoNet=1 意为启动时使用dhcp
        [[ -n "$(cat $NetCFG | sed -n '/BOOTPROTO.*[dD][hH][cC][pP]/p')" ]] && AutoNet='1' || {
          ## AutoNet=0 同时从network-scripts中加载NETMASK，GATEWAY
          AutoNet='0' && . $NetCFG;
          [[ -n $NETMASK ]] && MASK="$NETMASK";
          [[ -n $GATEWAY ]] && GATE="$GATEWAY";
        }
        [[ "$AutoNet" -eq '0' ]] && break;
      done
  }
}

echo -e "\n\033[36m# Network Infomation\033[0m"
[[ "$AutoNet" -eq '1' ]]&&{
  echo DHCP:  enable
}||{
  echo DHCP:  disable
}
echo IPV4： $IPv4
echo GATEWAY：  $GATE  
echo MASK：  $MASK $NETSUB
echo

# 展示最新的boot entry
rm -f /boot/loader/entries/temp.conf
 cd /boot/loader/entries/
 ls /boot/loader/entries/|tail -1|xargs cat > /var/temp.conf
 [[ -n "$(grep 'linux.*/\|kernel.*/' /var/temp.conf |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

 LinuxKernel="$(grep 'linux.*/\|kernel.*/' /var/temp.conf |awk '{print $1}' |head -n 1)";
[[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
LinuxIMG="$(grep 'initrd.*/' /var/temp.conf |awk '{print $1}' |tail -n 1)";
## 如果没有initrd 则增加initrd
[ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" /var/temp.conf && LinuxIMG='initrd';

## 分未Inboot和NoBoot修改加载kernel和initrd的
[[ "$Type" == 'InBoot' ]] && {
  sed -i "/$LinuxKernel.*\//c$LinuxKernel\\t\/boot\/vmlinuz" /var/temp.conf;
  sed -i "/$LinuxIMG.*\//c$LinuxIMG\\t\/boot\/initrd.img" /var/temp.conf;
}

[[ "$Type" == 'NoBoot' ]] && {
  sed -i "/$LinuxKernel.*\//c$LinuxKernel\\t\/vmlinuz" /var/temp.conf
  sed -i "/$LinuxIMG.*\//c$LinuxIMG\\t\/initrd.img" /var/temp.conf;
}

sed -i "/options.*/coptions inst.ks=file:\/\/ks.cfg" /var/temp.conf;
sed -i "/title.*/ctitle reinstall-centos8" /var/temp.conf
sed -i "/id.*/cid reinstall-centos8" /var/temp.conf
sed -i "/version.*/cversion zthe-last" /var/temp.conf

rm -f /boot/loader/entries/temp.conf
cp /var/temp.conf /boot/loader/entries/

## 删除saved_entry ——即下次默认启动的
[[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;

echo -e "\n\033[36m# Setup Kickstart\033[0m"

[[ -d /boot/tmp ]] && rm -rf /boot/tmp;
mkdir -p /boot/tmp;
cd /boot/tmp;
## 判断initrd压缩类型，centos8为：: xz compressed data 这里COMPTYPE为xz
COMPTYPE="$(file /boot/initrd.img |grep -o ':.*compressed data' |cut -d' ' -f2 |sed -r 's/(.*)/\L\1/' |head -n1)"
[[ -z "$COMPTYPE" ]] && echo "Detect compressed type fail." && exit 1;
CompDected='0'
for ListCOMP in `echo -en 'lzma\nxz\ngzip'`
  do
    if [[ "$COMPTYPE" == "$ListCOMP" ]]; then
      CompDected='1'
      if [[ "$COMPTYPE" == 'gzip' ]]; then
        NewIMG="initrd.img.gz"
      else
        NewIMG="initrd.img.$COMPTYPE"
      fi
      mv -f "/boot/initrd.img" "/boot/$NewIMG"
      break;
    fi
  done
[[ "$CompDected" != '1' ]] && echo "Detect compressed type not support." && exit 1;
[[ "$COMPTYPE" == 'lzma' ]] && UNCOMP='xz --format=lzma --decompress';
[[ "$COMPTYPE" == 'xz' ]] && UNCOMP='xz --decompress';
[[ "$COMPTYPE" == 'gzip' ]] && UNCOMP='gzip -d';
##解压缩initrd，会产生# bin  dev  etc  init  initrd.img  lib  lib64  proc  root  run  sbin  shutdown  sys  sysroot  tmp  usr  var
$UNCOMP < ../$NewIMG | cpio --extract  --make-directories --no-absolute-filenames >>/dev/null 2>&1
# $UNCOMP < ../$NewIMG | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1

## 编写ks.cfg
cat >/boot/tmp/ks.cfg<<EOF
#version=RHEL8
autopart --type=plain --nohome --noboot
# Partition clearing information
clearpart --all --initlabel
# Reboot after installation
reboot
# Use graphical install
graphical
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='cn'
# System language
lang zh_CN.UTF-8

# Network information
#ONDHCP network  --bootproto=dhcp --device=ens3 --nameserver=223.6.6.6 --ipv6=auto --activate
#NODHCP network --bootproto=static --ip=$IPv4 --netmask=$MASK --gateway=$GATE --device=ens3 --nameserver=223.6.6.6 --ipv6=auto --activate
network  --hostname=centos8.localdomain
repo --name="AppStream" --baseurl=${baseUrl}/BaseOS/x86_64/os/../../../AppStream/x86_64/os/
# Use network installation
url --url="${baseUrl}/BaseOS/x86_64/os/"
liveimg --url=${baseUrl}/BaseOS/x86_64/os/images/install.img --noverifyssl
# Root password
rootpw --plaintext arloor.com
# SELinux configuration
selinux --disabled
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --enabled="chronyd"
sshkey --username=root "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQzKHfZLlFEdaRUjfSK4twhL0y7+v23Ko4EI1nl6E1/zYqloSZCH3WqQFLGA7gnFlqSAfEHgCdD/4Ubei5a49iG0KSPajS6uPkrB/eiirTaGbe8oRKv2ib4R7ndbwdlkcTBLYFxv8ScfFQv6zBVX3ywZtRCboTxDPSmmrNGb2nhPuFFwnbOX8McQO5N4IkeMVedUlC4w5//xxSU67i1i/7kZlpJxMTXywg8nLlTuysQrJHOSQvYHG9a6TbL/tOrh/zwVFbBS+kx7X1DIRoeC0jHlVJSSwSfw6ESrH9JW71cAvn6x6XjjpGdQZJZxpnR1NTiG4Q5Mog7lCNMJjPtwJ not@home"
# System timezone
timezone Asia/Shanghai --isUtc

%packages
@^minimal-environment
kexec-tools
kexec-tools

%end

%addon com_redhat_kdump --disable

%end

%post --interpreter=/usr/bin/bash --log=/root/ks-post.log
#  https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-script-file-format-reference_installing-rhel-as-an-experienced-user#post-script-in-kickstart-file_scripts-in-kickstart-file
yum install -y wget tar vim git 
%end


%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
EOF

#设置ks是DHCP还是手动设置ip
[[ "$AutoNet" == '1' ]] && {
  sed -i 's/#ONDHCP\ //g' /boot/tmp/ks.cfg
} || {
  sed -i 's/#NODHCP\ //g' /boot/tmp/ks.cfg
}

rm -rf ../$NewIMG;
## 将解压后的initrd和创建的ks一起重新打包
find . | cpio -H newc --create | gzip -9 > ../initrd.img;
# find . | cpio -H newc --create --verbose | gzip -9 > ../initrd.img;
rm -rf /boot/tmp;
echo -e  "done\n"

echo   -e "\033[36mEnter any key to start Centos8 install Or Ctrl+C to cancel${black}" &&read aaa

[ "$1" = "-a" ]&&{
  sed -i "/version.*/cversion 9.99.9-147.8.1.el8_1.x86_64" /boot/loader/entries/temp.conf
  echo -e "The VPS wiil reboot and installation will auto start and complete.\nAfter minutes, you can login the new centos8 OS with passwd '\033[36marloor.com${black}'"
}||{
  echo -e "The VPS wiil reboot.\nThen you have 100 seconds to enter the vps's VNC\n and boot the '\033[36mreinstall-centos8${black}' menuentry to start the kickstart installation.\nYou can view the installation via VNC then.\nAfter minutes, you can login the new centos8 OS with passwd '\033[36marloor.com${black}'"
}

sleep 3 && reboot >/dev/null 2>&1
