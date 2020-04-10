#! /bin/bash

## path: /usr/local/bin/tarloor
## wget -O /usr/local/bin/tarloor http://arloor.com/tarloor.sh
hugoURL=https://github.com/gohugoio/hugo/releases/download/v0.54.0/hugo_extended_0.54.0_Linux-64bit.tar.gz

print_info(){
    clear
    echo "#############################################################"
    echo "# Update ARLOOR.com contents                                #"
    echo "# Website:  http://arloor.com/                              #"
    echo "# Author: ARLOOR <admin@arloor.com>                         #"
    echo "# Github: https://github.com/arloor                         #"
    echo "#############################################################"
    echo
}

print_info

yum install -y git tar  wget 


proxystart=1
# 设置http代理，使用方法：
export http_proxy=http://127.0.0.1:8081
export https_proxy=http://127.0.0.1:8081
git config --global http.proxy 'http://127.0.0.1:8081'
git config --global https.proxy 'http://127.0.0.1:8081'

# 检查/var/blog是否存在，存在则update
[ ! -d /var/blog ] && echo "arloor blog not exits. git clone...." && {
        git clone https://github.com/arloor/blog.git /var/blog
} || { 
        echo "arloor's blog exits. git pull...."; 
        cd /var/blog
        git pull;
}


# 检查hugo是否安装

hashugo=$(hugo version|grep Hugo) && [ "" != " $hashugo" ] && hugo version || {
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
