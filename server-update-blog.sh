#! /bin/bash

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


# 设置代理
[ -f /usr/lib/systemd/system/proxy.service ] && {
        service proxy start
        proxystart=1
        sleep 3 #等待代理启动
        # 设置http代理，使用方法：
        export http_proxy=http://127.0.0.1:8081
        export https_proxy=http://127.0.0.1:8081
        git config --global http.proxy 'http://127.0.0.1:8081'
        git config --global https.proxy 'http://127.0.0.1:8081'
}

# 检查/root/blog是否存在，存在则update
[ ! -d /root/blog ] && echo "arloor blog not exits. git clone...." && {
        git clone https://github.com/arloor/blog.git /root/blog
} || { 
        echo "arloor's blog exits. git pull...."; 
        cd /root/blog
        git pull;
}


# 检查hugo是否安装

hashugo=$(hugo version|grep Hugo) && [ "" != " $hashugo" ] && hugo version || {
        echo install hugo0.54 extended...;
        mkdir /tmp/hugo
        wget https://github.com/gohugoio/hugo/releases/download/v0.54.0/hugo_extended_0.54.0_Linux-64bit.tar.gz -qO /tmp/hugo/hugo054.tar.gz;
        tar -zxf /tmp/hugo/hugo054.tar.gz -C /tmp//hugo/;
        mv -f /tmp/hugo/hugo /usr/local/bin/;
        chmod +x /usr/local/bin/hugo;
        rm -rf /tmp/hugo
}

# 现在可以关闭代理了
[ "$proxystart" = "1" ]&&{
        service proxy stop;
        export http_proxy=
        export https_proxy=
}

# 检查httpd是否安装
hashttpd=$(rpm -qa httpd) && [ ! -z $hashttpd ] && echo httpd installed ||{
        echo "install httpd...";
        yum install httpd -y;
        service httpd start;
        systemctl enable httpd;
}

cd /root/blog
hugo -d /var/www/html/
service httpd reload