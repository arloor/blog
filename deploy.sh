#! /bin/bash
# wget -O /usr/local/bin/tarloor http://www.arloor.com/tarloor.sh
## 
# 当前使用hugo 0.53(支持scss)
dir=/home/x1/blog
dir=$PWD
host=$([ "$1" = "" ]&& echo "sg.gcall.me"|| echo "$1")
port=22

git pull
git add .
git commit -m "commit @arloor $(date)"
git push
if [ "$?" = 0  ]
then 
    # 调用服务器上的更新博客脚本方式
    # 该脚本会检查httpd、hugo、和git仓库，实现完全自动化
    # ssh root@$host  -p$port -t "
    # bash tarloor 0 # 0不使用代理，1使用代理
    # "

    ssh root@sg.gcall.me  -p22 -t "
    rm -rf /var/blog
    wget -O /usr/local/bin/tarloor https://raw.githubusercontent.com/arloor/arloor.github.io/master/docs/tarloor_deb.sh
    bash tarloor 0 # 0不使用代理，1使用代理
    "

    ssh root@hk.gcall.me  -p22 -t "
    rm -rf /var/blog
    wget -O /usr/local/bin/tarloor https://raw.githubusercontent.com/arloor/arloor.github.io/master/docs/tarloor.sh
    bash tarloor 0 # 0不使用代理，1使用代理
    "

    ssh root@bwg.arloor.com  -p22 -t "
    rm -rf /var/blog
    wget -O /usr/local/bin/tarloor https://raw.githubusercontent.com/arloor/arloor.github.io/master/docs/tarloor.sh
    bash tarloor 0 # 0不使用代理，1使用代理
    "
echo -e "\033[32m 请访问： https://"$host"\033[0m"
else
    echo -e "\033[32m 推送失败 \033[0m"
fi



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
