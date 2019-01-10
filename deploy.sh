#! /bin/bash
# 当前使用hugo 0.53(支持scss)
dir=/home/x1/blog
host=arloor.com

# yum install httpd
# systemctl enable httpd
cd $dir
echo "生成静态资源..."
hugo
ssh root@$host "
# echo "stop httpd ...."
# systemctl  stop httpd
echo "删除服务器的旧版本静态资源...."
rm -rf /var/www/html/*
"
echo "上传新的静态资源...."
cd public/
tar  -zcf  public.tar.gz --exclude=public.tar.gz *
scp -r ./public.tar.gz root@$host:/var/www/html
echo "reload httpd...."
ssh root@$host "
cd /var/www/html
tar -zxf public.tar.gz
systemctl  reload httpd
"
echo  "部署完毕，请访问 http://"$host
cd $dir
rm -rf public #删除生成的静态资源