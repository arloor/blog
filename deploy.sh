#! /bin/bash
# yum install httpd
cd /home/x1/blog
echo "生成静态资源..."
hugo
ssh root@arloor.com "
echo "stop httpd ...."
systemctl  stop httpd
echo "删除服务器的旧版本静态资源...."
rm -rf /var/www/html/*
"
echo "上传新的静态资源...."
scp -r ./public/* root@arloor.com:/var/www/html
echo "重启httpd...."
ssh root@arloor.com "systemctl  start httpd"