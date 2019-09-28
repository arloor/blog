#! /bin/bash
# 当前使用hugo 0.53(支持scss)
dir=/home/x1/blog
dir=$PWD
host=arloor.com
port=22

git pull
git add .
git commit -m "自动提交 @arloor $(date)"
git push

# 调用服务器上的更新博客脚本方式
# 该脚本会检查httpd、hugo、和git仓库，实现完全自动化
ssh root@$host  -p$port '
[ ! -f /usr/local/ARLOOR.sh ]&& cat > /usr/local/ARLOOR.sh<<\EOF
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
EOF



bash /usr/local/ARLOOR.sh
'

#本地构建，然后上传的方式
#====================================================================================================
# # rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
# # yum repolist
# # yum install -y nginx
# cd $dir
# echo "生成静态资源..."
# hugo

# echo "上传新的静态资源...."
# cd public/
# tar  -zcf  public.tar.gz --exclude=public.tar.gz *
# if [ "$?" != "0" ]; then
#     echo -e "\n 压缩失败，退出"
#     rm -rf ../public #删除生成的静态资源
#     exit 1
# fi

# scp -r -P $port ./public.tar.gz  root@$host:~
# if [ "$?" != "0" ]; then
#     echo -e "\n 上传静态资源失败，退出"
#     rm -rf ../public #删除生成的静态资源
#     exit 1
# fi

# ssh root@$host  -p$port "
# echo "删除服务器的旧版本静态资源...."
# rm -rf /var/www/html/*
# tar -zxf public.tar.gz -C /var/www/html/
# rm -f public.tar.gz
# echo "reload httpd...."
# systemctl  reload httpd
# "
# echo  "部署完毕，请访问 http://"$host
# cd $dir
# rm -rf public #删除生成的静态资源