---
title: "把ubuntu变成我的ubuntu"
date: 2019-01-01T13:14:59+08:00
author: "刘港欢"
categories: [ "ubuntu"]
tags: ["linux"]
weight: 10
---

拿到一个电脑的第一件事，当然是把他变成自己的电脑。装上ubuntu之后的第一件事就是变成自己的ubuntu啦。


# 先放截图

![我的ubuntu](/img/my-ubuntu.png)

# 首先安装需要的工具

```
sudo apt install dconf-editor
sudo apt install gnome-tweak-tool
sudo apt install chrome-gnome-shell
```

# 解决双系统时间不一致问题

```
timedatectl set-local-rtc 1 --adjust-system-clock
```

# 安装windows下的字体，主要是微软雅黑

安装windows字体其实就是把双系统下windows中`C:\Windows\Fonts`下的所有字体，复制到`/usr/share/fonts/windows`中。注意坑：ubuntu下打不开windows存放字体的那个文件夹，所以需要提前在windows中讲fonts压缩好。

字体放大1.25(高分屏笔记本必需啊)，使用之前安装的`tweak`（中文叫优化），修改字体为`微软雅黑`，缩放比例为1.25。
![tweak设置字体](/img/tweak-set-font-ubuntu.png)

为什么要安装windows字体呢？主要因为ubuntu自带的字体放大之后模糊。使用微软雅黑之后就没有这个问题。另外，很多网页都设置`font-family`为雅黑，安装个雅黑总是好的。

# 安装fcitx和搜狗输入法

Ubuntu 18.04 没有提供 Fcitx 输入框架，先安装框架：

sudo apt install fcitx
先去 [搜狗输入法官网](https://pinyin.sogou.com/linux/?r=pinyin) 下载输入法安装包，为 deb 格式的安装包，安装它：

sudo gdebi xxxxxx.deb
然后移步到 设置→区域和语言 ，删除一部分输入源，只保留汉语，接着选择 管理已安装的语言 ，修改 键盘输入法系统 为 fcitx 。关闭窗口，打开所有程序，选择软件 Fcitx 配置 ，选择加号添加搜狗输入法。

# 设置开机自启动

ubuntu 18.04使用了systemd作为服务管理。因此要做如下操作：

```
ln -fs /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
```
之后，编辑`/etc/rc.local`编写一个自启动脚本即可。我的rc.local如下：
```
#!/bin/bash

#开启代理
cd /home/x1/bin/proxy
(./proxy &>> proxy.log &)
lsof -i:8081||echo
```

# 干掉顶部横栏，增大桌面的可用面积

我很讨厌这个横栏，所以曾经十分讨厌gnome。今天终于找到办法将横栏删除。

1. 方法一：使用`hide top bar`gnome拓展。推荐！
2. 方法二：修改gnome shell css

如何修改gnome shell css:直接修改：/usr/share/gnome-shell/theme/ubuntu.css，在最底部加入：
```
#panel,#panel *{
height: 0px;
color: rgba(0, 0, 0, 0)
}
```

# 安装网易云音乐

在写这篇文章时，网易云音乐为：1.1.0

首先 下载安装包（Ubuntu 16.04 64 位），然后就是正常的 deb 包安装过程。

安装完毕后，会发现在应用列表中 点击应用图标无法启动软件 ，解决方案：

修改网易云音乐的启动图标

```
sudo gedit /usr/share/applications/netease-cloud-music.desktop
```
修改 Exec 这一行内容

```
Exec=sh -c "unset SESSION_MANAGER && netease-cloud-music %U"
```

# 使用dconf-editor修改小配置

找到之前安装的`dconf-editor`。这是一个类似windows注册表的东西。

我做的修改是：

```
将org.gnome.shell.extensions.dash-to-dock的click-action设为 'cycle-windows'
```
这样以后点击dock上的图标后的反应比较适合我。使用`dconf-editor`还可以修改很多东西，自己摸索吧。

# 安装tar包的软件

曾经我喜欢将tar包解压到/opt文件夹，然后编辑`/etc/profile.d/xx.sh`来设置$PATH。但是有个问题，sudo到root之后，自己设置的path就不管用了。原因是secure path：在sudo命令后，PATH被设置为预定的secure path。也就是`/etc/profile.d`下的sh文件配置PATH对sudo 之后的环境不生效。

所以以后我决定将所有软件安装到`/usr/local`，然后创建可执行文件的软连接到`/usr/local/bin`。

以下是安装`nodejs`的例子：

```
# 先将node-v8.15.0-linux-x64.tar.gz解压到/usr/bin，然后：
sudo ln -fs /usr/local/node-v8.15.0-linux-x64/bin/node /usr/local/bin/node 
sudo ln -fs /usr/local/node-v8.15.0-linux-x64/bin/npm /usr/local/bin/npm
```
注意，以后可能要全局安装其他npm包，也需要创建软连接，比如安装pm2:
```
sudo npm install -g pm2
sudo ln -fs /usr/local/node-v8.15.0-linux-x64/bin/pm2 /usr/local/bin/pm2
```

# 设置shell代理

```
#vim /usr/local/bin/pass

#! /bin/bash
# 设置http代理，使用方法：
# 在terminal中输入 ". pass" （前提是将此路径加入path）
# 效果：该terminal将使用如下的代理
export http_proxy=http://127.0.0.1:8081
export https_proxy=http://127.0.0.1:8081
```

这样就可以方便地用上我写的代理啦。最好的大概就是安装go、node包、apt安装docker时超级方便。

这里要吐槽诡异的apt：使用代理之后，他的https connect请求是这样的：

```
CONNECT download.docker.com:443 HTTP/1.1
Host: 127.0.0.1:8081
User-Agent: Debian APT-HTTP/1.3 (1.6.6)
```
这个host写成我的代理。。所以我半夜改代理适配这个apt请求。。

# 安装静态博客网站生成器hugo

本博客就是用hugo生成的，还是很好用的。为什么不用hexo，因为我不喜欢node，而有点喜欢go

```
snap install hugo --channel=extended #with the “extended” Sass/SCSS 
```

Sass/SCSS支持还是一定要的。在写这篇博客时，我安装的hugo版本是`0.53`

多扯一下hugo生成的静态网页的部署：自己写了个脚本：
```
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
scp -r ./public/* root@$host:/var/www/html
echo "reload httpd...."
ssh root@$host "systemctl  reload httpd"
echo  "部署完毕，请访问 http://"$host
```
其实也就是在centos7服务器上安装了`apache(httpd)`，然后hugo生成public文件下的静态资源，将这些静态资源复制到服务器`/var/www/html`中。为了舒服地（不需要输ssh密码）使用该脚本，请使用ssh秘钥登录centos7服务器。

# 安装grub主题

主题包地址：[Gnome Look - GRUB Themes](https://www.gnome-look.org/browse/cat/109/order/latest) （自行挑选喜欢的）

安装步骤 ：

首先下载主题包，多为压缩包，解压出文件。使用 sudo nautilus 打开文件管理器。

定位到目录：/boot/grub， 新建文件夹 ：themes，把解压出的文件拷贝到文件夹中。

接着（终端下）使用 gedit 修改 grub 文件：

```
sudo vim /etc/default/grub
在该文件末尾添加：

# GRUB_THEME="/boot/grub/themes/主题包文件夹名称/theme.txt"
GRUB_THEME="/boot/grub/themes/Cyber-Security/theme.txt"

最后：更新grub配置
sudo update-grub
```

#  设置登录页面(GDM)的背景

需要修改文件 ubuntu.css，它位于 /usr/share/gnome-shell/theme 。

```
sudo vim /usr/share/gnome-shell/theme/ubuntu.css
```
在文件中找到关键字 lockDialogGroup，如下行：

```
#lockDialogGroup {
   background: #2c001e url(resource:///org/gnome/shell/theme/noise-texture.png);
   background-repeat: repeat; }
```
修改图片路径即可，样例如下：

```
#lockDialogGroup {
  background: #2c001e url(file:///boot/grub/gdm.jpg);
  background-repeat: no-repeat;
  background-size: cover;
  background-position: center; }
```

最后执行`update-grub`

# 开启bbr（tcp拥塞控制）

```
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p 
lsmod | grep bbr  #检查是否有tcp_bbr
```

# 开启ssh服务并设置防火墙

```
sudo apt-get install openssh-server
# sudo service ssh start

#安装gufw图形化防火墙配置工具
sudo apt install gufw
```
打开防火墙配置（gufw），要是不知道如何配置，搜一下吧～

# 安装tlp, tlp-rdw：设置充电阀值

保护电池用啦～关于电池，有一条：最好的电池电量是40%-60%。我设置我的电脑到70%停止充电。

```
sudo apt install tlp, tlp-rdw
sudo tlp start
```
tlp可以设置充电阀值，详见[arch linux wiki](https://wiki.archlinux.org/index.php/TLP_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87))

实际上我没有用tlp，因为发现在windows下配置了之后，就不需要在ubuntu上再做设置了。