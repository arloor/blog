#! /bin/bash

## path: /usr/local/bin/tarloor
## wget -O /usr/local/bin/tarloor http://arloor.com/tarloor.sh
hugoVersion="0.97.2"
hugoURL=https://github.com/gohugoio/hugo/releases/download/v${hugoVersion}/hugo_extended_${hugoVersion}_Linux-64bit.tar.gz
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
  echo "安装缺失的依赖....."
  yum install -y git tar  wget > /dev/null
fi
}

print_info(){
    clear
    echo "#############################################################"
    echo "# Update ARLOOR.com contents                                #"
    echo "# Website:  http://www.arloor.com/                          #"
    echo "# Author: ARLOOR <admin@arloor.com>                         #"
    echo "# Github: https://github.com/arloor                         #"
    echo "#############################################################"
    echo
}

print_info

echo -e "\n\033[36m# Check Dependence\033[0m\n"
CheckDependence git,tar,wget 
echo "Dependence Check done"

# 如果不需要使用代理，则使用 bash tarloor 0
[ "$1" = "1" ]&&{
  proxystart=1
  # 设置http代理，使用方法：
  export http_proxy=http://127.0.0.1:3128
  export https_proxy=http://127.0.0.1:3128
  git config --global http.proxy 'http://127.0.0.1:3128'
  git config --global https.proxy 'http://127.0.0.1:3128'
}


# 检查/var/blog是否存在，存在则update
[ ! -d /var/blog ] && echo "arloor blog not exits. git clone...." && {
        git clone https://github.com/arloor/blog.git /var/blog
} || { 
        echo "arloor's blog exits. git pull...."; 
        cd /var/blog
        git pull;
}


# 检查hugo是否安装

hashugo=$(hugo version|grep ${hugoVersion}) && [ "" != " $hashugo" ] && hugo version || {
        echo install hugo extended...;
        mkdir /tmp/hugo
        wget $hugoURL -O /tmp/hugo/hugo.tar.gz;
        tar -zxf /tmp/hugo/hugo.tar.gz -C /tmp/hugo/;
        mv -f /tmp/hugo/hugo /usr/local/bin/;
        chmod +x /usr/local/bin/hugo;
        rm -rf /tmp/hugo
}

# 现在可以关闭代理了
[ "$proxystart" = "1" ]&&{
        export http_proxy=
        export https_proxy=
        #git config --global --unset http.proxy
        #git config --global --unset https.proxy
}

# 检查httpd是否安装
nginx=$(rpm -qa nginx) && [ ! -z $nginx ] && echo nginx installed ||{
        echo "install nginx...";
        yum install nginx -y;
        service nginx start;
        systemctl enable nginx;
}

cd /var/blog
hugo -d /usr/share/nginx/html/
service nginx reload
