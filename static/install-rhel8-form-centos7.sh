print_info(){
    clear
    echo "#############################################################"
    echo "# Install Centos8 on a centos7 VPS.                         #"
    echo "# Usage: bash install.sh                                    #"
    echo "# Website:  http://www.arloor.com/                              #"
    echo "# Author: ARLOOR <admin@arloor.com>                         #"
    echo "# Github: https://github.com/arloor                         #"
    echo "#############################################################"
    echo
}

print_info
baseUrl="http://someme.me/rhel8-install/"

[[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1;

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

echo -e "\n\033[36m# Check Dependence\033[0m\n"
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
wget --no-check-certificate -qO '/boot/initrd.img' "${baseUrl}/isolinux/initrd.img"
echo "vmlinuz downloading...."
wget --no-check-certificate -qO '/boot/vmlinuz' "${baseUrl}/isolinux/vmlinuz"
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


### 备份grub文件
[[ ! -f $GRUBDIR/$GRUBFILE ]] && echo "Error! Not Found $GRUBFILE. " && exit 1;

[[ ! -f $GRUBDIR/$GRUBFILE.old ]] && [[ -f $GRUBDIR/$GRUBFILE.bak ]] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old;
mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak;
[[ -f $GRUBDIR/$GRUBFILE.old ]] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE;

## 截取原grub中的第一个menuentry到/tmp/grub.new
[[ "$GRUBOLD" == '0' ]] && {
  READGRUB='/tmp/grub.read'
  cat $GRUBDIR/$GRUBFILE |sed -n '1h;1!H;$g;s/\n/+++/g;$p' |grep -oPm 1 'menuentry\ .*\{.*\}\+\+\+' |sed 's/\+\+\+/\n/g' >$READGRUB
  LoadNum="$(cat $READGRUB |grep -c 'menuentry ')"
  if [[ "$LoadNum" -eq '1' ]]; then
    cat $READGRUB |sed '/^$/d' >/tmp/grub.new;
  elif [[ "$LoadNum" -gt '1' ]]; then
    CFG0="$(awk '/menuentry /{print NR}' $READGRUB|head -n 1)";
    CFG2="$(awk '/menuentry /{print NR}' $READGRUB|head -n 2 |tail -n 1)";
    CFG1="";
    for tmpCFG in `awk '/}/{print NR}' $READGRUB`
      do
        [ "$tmpCFG" -gt "$CFG0" -a "$tmpCFG" -lt "$CFG2" ] && CFG1="$tmpCFG";
      done
    [[ -z "$CFG1" ]] && {
      echo "Error! read $GRUBFILE. ";
      exit 1;
    }

    sed -n "$CFG0,$CFG1"p $READGRUB >/tmp/grub.new;
    [[ -f /tmp/grub.new ]] && [[ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ]] || {
      echo -ne "\033[31mError! \033[0mNot configure $GRUBFILE. \n";
      exit 1;
    }
  fi
  [ ! -f /tmp/grub.new ] && echo "Error! $GRUBFILE. " && exit 1;
  ## 修改标头
  sed -i "/menuentry.*/c\menuentry\ \'Install Centos8 \[$DIST\ $VER\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" /tmp/grub.new
  sed -i "/echo.*Loading/d" /tmp/grub.new;
  ## 找到在哪插入新的menuentry
  INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
}


## 从已有menuentry判断/boot是否为单独分区
[[ -n "$(grep 'linux.*/\|kernel.*/' /tmp/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

LinuxKernel="$(grep 'linux.*/\|kernel.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)";
[[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
LinuxIMG="$(grep 'initrd.*/' /tmp/grub.new |awk '{print $1}' |tail -n 1)";
## 如果没有initrd 则增加initrd
[ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" /tmp/grub.new && LinuxIMG='initrd';



## 分未Inboot和NoBoot修改加载kernel和initrd的
[[ "$Type" == 'InBoot' ]] && {
  [[ "$AutoNet" -eq '1' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz  ip=dhcp inst.repo=http:\/\/someme.me\/rhel8-install\/BaseOS\/ inst.lang=zh_CN inst.keymap=cn selinux=0 inst.stage2=http:\/\/someme.me\/rhel8-install\/ " /tmp/grub.new;
  [[ "$AutoNet" -eq '0' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz  ip=$IPv4::$GATE:$MASK:my_hostname:eth0:none inst.repo=http:\/\/someme.me\/rhel8-install\/BaseOS\/ inst.lang=zh_CN inst.keymap=cn selinux=0 inst.stage2=http:\/\/someme.me\/rhel8-install\/ " /tmp/grub.new;
  sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrd.img" /tmp/grub.new;
}

[[ "$Type" == 'NoBoot' ]] && {
  [[ "$AutoNet" -eq '1' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz  ip=dhcp inst.repo=http:\/\/someme.me\/rhel8-install\/BaseOS\/ inst.lang=zh_CN inst.keymap=us selinux=0 inst.stage2=http:\/\/someme.me\/rhel8-install\/ " /tmp/grub.new;
  [[ "$AutoNet" -eq '0' ]] && sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz  ip=$IPv4::$GATE:$MASK:my_hostname:eth0:none inst.repo=http:\/\/someme.me\/rhel8-install\/BaseOS\/ inst.lang=zh_CN inst.keymap=cn selinux=0 inst.stage2=http:\/\/someme.me\/rhel8-install\/ " /tmp/grub.new;
  sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrd.img" /tmp/grub.new;
}

## 增加空行
sed -i '$a\\n' /tmp/grub.new;

## 根据是否-a，决定将新的条目查到第一个还是尾部
[ "$1" = "-a" ]&&{
  ## 将新的menuentry插入到grub，作为第一个menuentry
  sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
  sed -i ''${INSERTGRUB}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE;
}||{
  ##  插入到grub尾部，并作为最后一个menuentry；同时设置超时时间为100s，以给与充分时间连接VNC
  sed -i ''${INSERTGRUB}'i\set timeout=100\n' $GRUBDIR/$GRUBFILE;
  sed -i '$i\\n' $GRUBDIR/$GRUBFILE
  sed -i '$r /tmp/grub.new' $GRUBDIR/$GRUBFILE
}

## 删除saved_entry ——即下次默认启动的
[[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;

echo -e "\n\033[36m# Due to reboot\033[0m"
echo -e "\n\033[33m\033[04mYour VPS will reboot to install Centos8.\nPlease enter the VNC in 100 seconds!\nThen you can setup the system and start the installation!\n\033[0m\n"

echo  "Enter any key to reboot Or Ctrl+C to cancel:"&& read a
sleep 1 && reboot >/dev/null 2>&1