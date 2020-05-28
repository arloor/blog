---
title: "Nodebb"
date: 2020-05-28T20:36:51+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

```
cd
wget https://nodejs.org/dist/v12.17.0/node-v12.17.0-linux-x64.tar.xz -O /root/node-v12.17.0-linux-x64.tar.xz
cd /usr/local
tar -xvf /root/node-v12.17.0-linux-x64.tar.xz
ln -fs /usr/local/node-v12.17.0-linux-x64/bin/node /usr/local/bin/node
ln -fs /usr/local/node-v12.17.0-linux-x64/bin/npm /usr/local/bin/npm
node -v

yum install -y redis
service redis start


cd
rm -rf nodebb/
git clone https://github.com/NodeBB/NodeBB.git nodebb
cd nodebb
git checkout v1.13.2
./nodebb setup

cd 




wget https://nodejs.org/dist/latest-v10.x/node-v10.20.1-linux-x64.tar.xz -O /root/node-v10.20.1-linux-x64.tar.xz
cd /usr/local
tar -xvf /root/node-v10.20.1-linux-x64.tar.xz
ln -fs /usr/local/node-v10.20.1-linux-x64/bin/node /usr/local/bin/node
ln -fs /usr/local/node-v10.20.1-linux-x64/bin/npm /usr/local/bin/npm
node -v


 ./nodebb start
```