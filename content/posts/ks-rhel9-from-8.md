---
title: "Ks Rhel9 From 8"
date: 2023-07-12T09:58:57+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## ks.cfg

```shell
#version=RHEL8
# Generated using Blivet version 3.6.0
ignoredisk --only-use="sda|hda|xda|vda|xvda|nvme0n1"
# Partition clearing information
clearpart --none --initlabel
# Disk partitioning information
reqpart 
part pv.559 --fstype="lvmpv" --ondisk=vda --size=3076
volgroup rhel --pesize=4096 pv.559
logvol / --fstype="ext4" --size=3072 --name=root --vgname=rhel
# Reboot after installation
reboot
# Use graphical install
graphical
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='cn'
# System language
lang zh_CN.UTF-8

# Network information
# Use network installation
url --url="http://199.180.115.74/rhel8-install"

# Root password
rootpw --plaintext arloor.com
# SELinux configuration
selinux --disabled
firewall --disabled
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --enabled="chronyd"
sshkey --username=root "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQzKHfZLlFEdaRUjfSK4twhL0y7+v23Ko4EI1nl6E1/zYqloSZCH3WqQFLGA7gnFlqSAfEHgCdD/4Ubei5a49iG0KSPajS6uPkrB/eiirTaGbe8oRKv2ib4R7ndbwdlkcTBLYFxv8ScfFQv6zBVX3ywZtRCboTxDPSmmrNGb2nhPuFFwnbOX8McQO5N4IkeMVedUlC4w5//xxSU67i1i/7kZlpJxMTXywg8nLlTuysQrJHOSQvYHG9a6TbL/tOrh/zwVFbBS+kx7X1DIRoeC0jHlVJSSwSfw6ESrH9JW71cAvn6x6XjjpGdQZJZxpnR1NTiG4Q5Mog7lCNMJjPtwJ not@home"
# System timezone
timezone Asia/Shanghai --isUtc

%packages
@^minimal-environment
tuned
vim
git
tar
wget
curl

%end

%addon com_redhat_kdump --disable

%end
```