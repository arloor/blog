---
title: "Centos8安装MongoDB 4.2"
date: 2020-02-11T15:15:28+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

参考文档:[linuxconfig.org](https://linuxconfig.org/how-to-install-mongodb-on-redhat-8)

<!--more-->

## 安装过程

**1** 下载安装包到`/opt`，并解压缩，创建文件夹的软链接

```shell
cd /opt 
wget -O mongodb-linux-x86_64-rhel80-4.2.3.tgz https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel80-4.2.3.tgz
tar -zxvf mongodb-linux-x86_64-rhel80-4.2.3.tgz  
ln -s mongodb-linux-x86_64-rhel80-4.2.3 mongodb
```

**2** 创建相关的用户和文件夹

```shell
useradd mongod
mkdir -p /var/lib/mongo
chown -R mongod:mongod /opt/mongodb*
chown -R mongod: /var/lib/mongo
```

**3** 创建配置文件、systemd服务、配置环境变量

创建配置文件

```shell
vim /etc/mongod.conf
#内容如下
storage:
  dbPath: "/var/lib/mongo"
  journal:
    enabled: true

net:
  port: 27017
  bindIp: "127.0.0.1"
```

创建systemd服务

```shell
vim /etc/systemd/system/mongod.service
#内容如下
[Unit]
Description=MongoDB
After=syslog.target network.target

[Service]
Type=simple

User=mongod
Group=mongod

ExecStart=/opt/mongodb/bin/mongod --config /etc/mongod.conf

[Install]
WantedBy=multi-user.target
```

配置环境变量

```shell
vim /etc/profile.d/mongodb.sh
#内容如下
## mongodb
PATH=$PATH:/opt/mongodb/bin
```

**4** 启动MongoDB服务

```shell
systemctl daemon-reload
systemctl start mongod
systemctl status mongod
```

**5** 进入mongo交互终端

```shell
# 使环境变量生效
. /etc/profile.d/mongodb.sh
mongo
```

显示内容如下：

```h
MongoDB shell version v4.2.3
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("04c11ecc-5ae4-4f8f-a81b-bb2c2595126d") }
MongoDB server version: 4.2.3
Server has startup warnings: 
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] 
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] ** WARNING: Access control is not enabled for the database.
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] **          Read and write access to data and configuration is unrestricted.
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] 
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] 
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] **        We suggest setting it to 'never'
2020-02-11T16:02:25.696+0800 I  CONTROL  [initandlisten] 
---
Enable MongoDB's free cloud-based monitoring service, which will then receive and display
metrics about your deployment (disk utilization, CPU, operation statistics, etc).

The monitoring data will be available on a MongoDB website with a unique URL accessible to you
and anyone you share the URL with. MongoDB may use this information to make product
improvements and to suggest MongoDB products and deployment options to you.

To enable free monitoring, run the following command: db.enableFreeMonitoring()
To permanently disable this reminder, run the following command: db.disableFreeMonitoring()
---

> db
test
> use test
switched to db test
> 
```


## 增加用户

使用`mongo`进入交互终端

```shell
use admin

db.createUser(
  {
    user: "superuser",
    pwd: "changeMeToAStrongPassword",
    roles: [ "root" ]
  }
)

show users

# {
#    "_id" : "admin.superuser",
#    "userId" : UUID("7c2aee5c-6af5-4e25-ae0f-4422c6a8a03c"),
#    "user" : "superuser",
#    "db" : "admin",
#    "roles" : [
#            {
#              "role" : "root",
#              "db" : "admin"
#            }
#    ],
#    "mechanisms" : [
#            "SCRAM-SHA-1",
#            "SCRAM-SHA-256"
#    ]
#  }

db.shutdownServer() #关闭
exit
```

## 开启用户认证

修改配置文件

```
vim /etc/mongod.conf

## 增加如下：
security:
  authorization: "enabled"
```

启动mongod

```
service mongod start
```

进入mongo交互终端

```
mongo -u superuser  -p changeMeToAStrongPassword
```


## fedora31安装shadowsocks-libev

```shell
yum install epel-release -y
yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel -y
export http_proxy=http://localhost:8081
export https_proxy=http://localhost:8081
wget https://github.com/shadowsocks/shadowsocks-libev/releases/download/v3.3.4/shadowsocks-libev-3.3.4.tar.gz
tar -zxvf shadowsocks-libev-3.3.4.tar.gz
./configure --disable-documentation
make && make install
```


