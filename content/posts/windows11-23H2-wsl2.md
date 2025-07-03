---
title: "Windows11 WSL2使用"
date: 2024-09-22T13:45:23+08:00
draft: false
categories: 
- undefined
tags: 
- windows
weight: 10
subtitle:
description:
highlightjslanguages:
- powershell
---

wsl全称是windows的linux子系统，可以理解为在你的windows电脑上提供一个linux的工作环境。

## windows虚拟化的基础知识

| windows功能 | 作用 | 其他 |
| --- | --- | --- |
| Hyper-V | 微软自己的虚拟化工具 | 包含了“管理工具”和“平台”，其中“平台”包含“服务”和“虚拟机监控程序” |
| Windows Subsystem for Linux | WSL1，不是我们讨论的WSL2所需要的 | |
| Virtual Machine Platform | 虚拟机平台（WSL2的底层依赖） | 看到说Hyper-V也依赖这个，但启用Hyper-V并不需要启用虚拟机平台，因此我觉得Hyper-V依赖的是“Hyper-V虚拟机监控程序”吧 |
| Windows Sandbox | 一个隔离的桌面环境 | 我反正没用过，不了解 |
| Windows 虚拟机监控程序平台 | 用于支持vmware等第三方虚拟机软件 | |

{{<img windows-feature-disable-virt.png 400 >}}

> 1. 虚拟机平台会一定程度上影响游戏性能，为了游戏性能，可以关闭虚拟机平台、Hyper-V。Windows虚拟机监控程序平台、适用于Linux的Windows子系统我理解是不影响游戏性能的。参考[用于在 Windows 11 中优化游戏性能的选项](https://prod.support.services.microsoft.com/zh-cn/windows/%E7%94%A8%E4%BA%8E%E5%9C%A8-windows-11-%E4%B8%AD%E4%BC%98%E5%8C%96%E6%B8%B8%E6%88%8F%E6%80%A7%E8%83%BD%E7%9A%84%E9%80%89%E9%A1%B9-a255f612-2949-4373-a566-ff6f3f474613)。
> 2. Hyper-V和vmware等软件是冲突的，详见[虚拟化应用程序无法与 Hyper-V、Device Guard 和 Credential Guard 协同工作](https://learn.microsoft.com/zh-cn/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v)

**关闭虚拟机平台和Hyper-V虚拟机监控程序：**

```powershell
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
DISM /Online /Disable-Feature /FeatureName:Microsoft-Hyper-V-All /NoRestart
# 其实只要关闭 Microsoft-Hyper-V-Hypervisor 就行了
sc.exe config wslservice start= disabled
```

**开启虚拟机平台和Hyper-V虚拟机监控程序：**

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V-All /NoRestart
```

**查看所有windows功能**

```powershell
dism.exe /online /Get-Features
```

## %userprofile%/.wslconfig

```toml
[wsl2]
# networkingMode=bridged
# vmSwitch=Home # 此处的名称和指定的虚拟网络交换机一致
# dhcp=false # 禁用DHCP，在WSL2系统中通过设置Linux的静态IP实现获取IP
networkingMode = mirrored # 端口自动转发，Windows和WSL共享端口，都使用127.0.0.1
dnsTunneling = true # WSL的DNS请求通过Windows转发
firewall = true # WSL同步Windows防火墙规则
autoProxy = true # Windows设置代理时自动同步给WSL，用于使用代理访问外网

[experimental]
sparseVhd = true # 自动清理磁盘空间
autoMemoryReclaim = gradual # 可以在gradual 、dropcache 、disabled之间选择。 如果设置成gradual，需要设置kernelCommandLine以开启cgroupV2，否则docker会有问题
hostAddressLoopback = true # WSL2中访问Windows的localhost

[wsl2]
swap = 0 # 禁用swap，使用内存交换文件，不使用磁盘交换文件
# 开启cgroup v2，用于docker和autoMemoryReclaim = gradual共存
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1 
```

上面的配置启用了自动内存回收，不过仍然可以手动释放page cache（在wsl中执行）：

```bash
echo "sync; echo 3 > /proc/sys/vm/drop_caches; touch /root/drop_caches_last_run" |tee /tmp/drop_caches
install /tmp/drop_caches /usr/local/bin/loss
loss
```

## 安装WSL2

这里使用了Debian12，因为我不喜欢Ubuntu的Snap，而且Debian12的wsl发行版支持ebpf。

```bat
@REM 启用VMP 虚拟机平台
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
echo you may need reboot to take effect
@REM 启用wslservice
sc.exe config wslservice start= demand
wsl --set-default-version 2
wsl -v
wsl --list --online
wsl --install -d Debian
@REM 设置默认root用户
debian config --default-user root
```

## 第一次启动

设置用户名和密码：

![](/img/Snipaste_2024-09-21_16-56-02.png)

启用systemd：

```bash
if ! grep -q "systemd=true" /etc/wsl.conf; then
    cat <<EOF | sudo tee /etc/wsl.conf
[boot]
systemd = true

[user]
default = root

EOF
fi
```

执行 `wsl --shutdown` 重启wsl，然后就可以使用systemd了。

## 其他设置

### apt设置代理

默认安装的Debian的默认源是官方源，国内比较慢，直接配置apt代理。

```bash
if ! grep -q Acquire::http::Proxy /etc/apt/apt.conf.d/proxy.conf;then
    cat <<EOF | sudo tee /etc/apt/apt.conf.d/proxy.conf
Acquire::http::Proxy "https://user:passwd@server:port/";
Acquire::https::Proxy "https://user:passwd@server:port/";
# 否则报错没有ca-certificates
Acquire::https::Verify-Peer "false";
EOF
fi
```

### apt不更新某软件

apt-mark 可以对软件包进行设置（手动/自动）安装标记，也可以用来处理软件包的 dpkg(1) 选中状态，以及列出或过滤拥有某个标记的软件包。 

```bash
apt-mark auto – 标记指定软件包为自动安装
apt-mark manual – 标记指定软件包为手动安装
apt-mark minimize-manual – Mark all dependencies of meta packages as automatically installed.
apt-mark hold – 标记指定软件包为保留(held back)，阻止软件自动更新
apt-mark unhold – 取消指定软件包的保留(held back)标记，解除阻止自动更新
apt-mark showauto – 列出所有自动安装的软件包
apt-mark showmanual – 列出所有手动安装的软件包
apt-mark showhold – 列出设为保留的软件包

比如保留某个软件不更新可以使用hold标记,如docker
sudo apt-mark hold docker*

sudo apt-mark showhold

如果要解除保留可以使用unhold
sudo apt-mark unhold docker*
```

### git设置

由于wsl支持windows和linux的命令互操作，你实际上会有两个git，一个wsl的git，一个windows的git.exe。

**WSL git配置**

```bash
git config --global core.editor vim
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
git config --global "includeIf.hasconfig:remote.*.url:*://*github.com*/**.path" .gitconfig_github
git config --global "includeIf.hasconfig:remote.*.url:git@github.com:*/**.path" .gitconfig_github
cat > ~/.gitconfig_github <<EOF
[user]
        name = arloor
        email = admin@arloor.com
EOF
git config --global credential.helper store
# wsl的git忽略文件权限的变更
git config --global core.filemode false
# wsl的git 提交时自动将crlf转换为lf，checkout时不转成crlf
git config --global core.autocrlf input
```

**windows git配置**

wsl的git 提交时自动将crlf转换为lf，checkout时不转成crlf

```bash
git config --global core.autocrlf input
```

autocrlf的配置详见[git文档](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration#_formatting_and_whitespace)

简单解释就是：

- windows使用crlf换行，linux和macos使用lf换行（早期macos使用cr换行）
- autocrlf=true，提交到index时自动将crlf换成lf，checkout时自动将lf换成crlf。适合windows使用，widnwos默认配置
- autocrlf=input，提交到index时自动将crlf换成lf，checkout时不自动转换。适合macos和linux用。
- autocrlf=false，不自动转换换行符。

git文档推荐，linux和macos使用input，windows使用true。这样保证index、linux、macos中永远是lf，windows中是crlf。

**但是**我的设置成了windows上也是input。

直接原因是我有很多shell脚本，原本git.exe的bash是可以执行crlf的shell文件的。安装wsl后，bash被替换为了Debian的bash，不能处理crlf的shell文件。——我需要shell脚本是lf的。根本原因，换行符的问题是一个历史遗留问题，是操作系统之间的壁垒。现代的ide或者文本编辑器都是跨平台使用的，他们能处理换行符的问题，那么用vscode，idea就行了，不要用windows的老版文本编辑器了。我已经比较习惯在linux处理文本了，vim、grep、awk、sed等等很爽，wsl的最大好处就是在windows上能用上原生的bash，那就文本全部linux化好了。

### 安装ca证书

```bash
sudo cp your-certificate.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

## docker和podman

- 如果你遇到 docker 无法从 Windows 访问的问题。首先确保docker版本在27.3.0以上，这个版本修复了这个问题，见[[27.x backport] Do not DNAT packets from WSL2's loopback0](https://github.com/moby/moby/pull/48514/files#diff-aa946998315144e84ceffe7bd84918fd8d34183af1cae444ce90e2b620ec8371)。如果不能升级docker的话，可以在 /etc/docker/daemon.json 里添加一句 "iptables": false，然后重启docker daemon
    
```json
{
"iptables": false
}
```

- podman容器需要设置 `--network host`，否则其他容器访问会报错 no route to host。

## 参考文档

- [WSL2设置镜像网络模式](https://www.ryanshang.com/2024/01/06/WSL2%E8%AE%BE%E7%BD%AE%E9%95%9C%E5%83%8F%E7%BD%91%E7%BB%9C%E6%A8%A1%E5%BC%8F/)
- [WSL 中的高级设置配置](https://learn.microsoft.com/zh-cn/windows/wsl/wsl-config)

## 内存释放太慢，最不满意的一点

即使有了`autoMemoryReclaim`，任务管理器里看到的 `VmmemWSL` 还是远大于 wsl 里top看到的res + buffer/cache。即使`wsl -t Debian` 也不会释放内存，只有`wsl --shutdown`才可以释放内存。观察到断开所有wsl的terminal和所有由用户启动的后台进程（不包含systemd启动的）都结束后，wsl会在一段时间后自动shutdown，此时VmmemWSL也会降为0。但如果有后台进程常驻的话，就不会自动关闭了，这就建议放个bat文件在桌面，不用wsl的时候就shutdown掉吧。

```bash
@echo off
wsl --shutdown
```

相关issue: [WSL 2 consumes massive amounts of RAM and doesn't return it](https://github.com/microsoft/WSL/issues/4166)

关于内存回收的问题，找到两个文章：

| 文章 | 时间 | 说明 |
| --- | --- | --- |
| [Memory Reclaim in the Windows Subsystem for Linux 2](https://devblogs.microsoft.com/commandline/memory-reclaim-in-the-windows-subsystem-for-linux-2/) | October 30th, 2019 | 基于某kernel patch的pageReporting，将虚拟机闲置的连续的内存返还给宿主机。WSL会在cpu Idle的时候进行内存的compaction，然后进行返还。也可以手动执行`echo 1 > /proc/sys/vm/compact_memory`触发 |
| [Automatic memory reclaim](https://devblogs.microsoft.com/commandline/windows-subsystem-for-linux-september-2023-update/#automatic-memory-reclaim) | September 18th, 2023 | “逐渐释放”：基于CgroupV2的memory.reclaim特性逐渐释放page cache，与docker使用的CgroupV1冲突。“idle时立即释放”：不依赖CgroupV2的特性，可与docker共存 |

## 让wsl一直在后台运行

[https://www.cnblogs.com/wswind/p/17201979.html](https://www.cnblogs.com/wswind/p/17201979.html)

**简单方案：** 写个VBS脚本，启动wsl的terminal在后台一直等待输入：

```bash
set ws=wscript.CreateObject("wscript.shell")
ws.run "wsl -d Debian", 0
```

**进阶方案：** 只启动一个后台进程，即使多次运行该VBS脚本：

keepalive命令：

```bash
cat > /usr/local/bin/keepalive <<'EOF'
command="watch -n 30 'uptime |head -n 3 | tee /tmp/uptime'"
ps -ef|grep "${command}"|grep -v grep
if [ $? -ne 0 ]
then
    sh -c "${command}"
else
    echo "The command is already running"
fi
EOF
chmod +x /usr/local/bin/keepalive
```

写个VBS脚本：

```bash
set ws=wscript.CreateObject("wscript.shell")
ws.run "wsl -d Debian /usr/local/bin/keepalive", 0
```

将这个VBS脚本的快捷方式放到启动文件夹，这样就可以在开机时自动运行了。启动文件夹在：

```bash
%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
```

或者使用windows的任务计划程序设置为用户登录时自动运行，参考[实现 WSL 2 开机免登录自动启动](https://www.sjdhome.com/blog/post/wsl2-auto-start/ )：

![alt text](/img/task-scheduler-keep-wsl-1.png)
![alt text](/img/task-scheduler-keep-wsl-2.png)
![alt text](/img/task-scheduler-keep-wsl-3.png)


## 卸载发行版

```bat
wsl --terminate Debian # 停止
wsl --unregister Debian # 卸载
```

## WSL2 debian12 安装docker并配置daemon.json

- [debian/#install-from-a-package](https://docs.docker.com/engine/install/debian/#install-from-a-package)
- [rhel/#install-using-the-repository](https://docs.docker.com/engine/install/rhel/#install-using-the-repository)
- [#daemon-configuration-file](https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file)

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "iptables": false,
    "proxies": {
        "http-proxy": "http://127.0.0.1:7890",
        "https-proxy": "http://127.0.0.1:7890",
        "no-proxy": "*.test.example.com,.example.org,127.0.0.0/8,localhost,127.0.0.1,docker-registry.somecorporation.com"
    }
}
EOF

sudo systemctl restart docker
```

该脚本修改了 `daemon.json` 文件，具体作用如下：

- `--iptables=false` prevents the Docker daemon from adding iptables rules. If multiple daemons manage iptables rules, they may overwrite rules set by another daemon. **Be aware that disabling this option requires you to manually add iptables rules to expose container ports.** If you prevent Docker from adding iptables rules, Docker also doesn't add IP masquerading rules, even if you set `--ip-masq` to `true`. Without IP masquerading rules, Docker containers can't connect to external hosts or the internet when using network other than default bridge.

- 设置了使用windows clash的代理。

设置代理的另一种方式：[proxy/#daemon-configuration](https://docs.docker.com/engine/daemon/proxy/#daemon-configuration)

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo touch /etc/systemd/system/docker.service.d/http-proxy.conf
if ! grep HTTP_PROXY /etc/systemd/system/docker.service.d/http-proxy.conf;
then
cat >> /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890" "HTTPS_PROXY=http://127.0.0.1:7890" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF
fi
# Flush changes:
sudo systemctl daemon-reload
#Restart Docker:
sudo systemctl restart docker
#Verify that the configuration has been loaded:
sudo systemctl show --property=Environment docker
```

## WSL2 debian12 安装openssh-server

```bash
apt remove -y openssh-server
apt install -y openssh-server
mkdir -p /root/.ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQzKHfZLlFEdaRUjfSK4twhL0y7+v23Ko4EI1nl6E1/zYqloSZCH3WqQFLGA7gnFlqSAfEHgCdD/4Ubei5a49iG0KSPajS6uPkrB/eiirTaGbe8oRKv2ib4R7ndbwdlkcTBLYFxv8ScfFQv6zBVX3ywZtRCboTxDPSmmrNGb2nhPuFFwnbOX8McQO5N4IkeMVedUlC4w5//xxSU67i1i/7kZlpJxMTXywg8nLlTuysQrJHOSQvYHG9a6TbL/tOrh/zwVFbBS+kx7X1DIRoeC0jHlVJSSwSfw6ESrH9JW71cAvn6x6XjjpGdQZJZxpnR1NTiG4Q5Mog7lCNMJjPtwJ not@home >/root/.ssh/authorized_keys
sed -i 's/\(#\)\?PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/\(#\)\?PubkeyAuthentication no/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/\(#\)\?Port .*/Port 222/g' /etc/ssh/sshd_config # 改成222端口
sed -i 's/\(#\)\?UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
systemctl restart sshd
systemctl enable ssh.service
```

放通windows防火墙：

![alt text](/img/winodws11-firewall-setup-port.png)

![alt text](/img/winodws11-firewall-setup-222-port.png)

然后一路下一步即可。

或者直接在管理员权限的powershell执行：

```ps1
New-NetFirewallRule -DisplayName '"Allow SSH on Port xxxxx"' -Direction Inbound -Protocol TCP -LocalPort xxxxx -Action Allow
```

之后就可以使用vscode remote-ssh到WSL2上来开发了。具体的ssh config如下：

```bash
Host wsl
  HostName 192.168.xx.xx
  Port 222
  User root
```

不过因为wsl2有idle自动关闭的特性，所以从外部remote-ssh进来时，需要从外部保活WSL2。思路是ssh到windows上（参考[widnows11启用openssh-server](/posts/mac-wakeonlan-windows-11-msi-motherboard/#windows11-%E5%90%AF%E7%94%A8openssh)），然后执行一个前台命令一直运行，具体命令是：

```bash
ssh windows_user@windows -t wsl
```


> 以下经过测试无用：

或者设置powershell的profile

```ps1
$ShortName = @{
    's' = 'Select-Object'
    'g' = 'Get-Content'
    'keep' = {
        Start-Process "C:\Windows\System32\cscript.exe" -ArgumentList "C:\Users\arloor\Desktop\keep_wsl.vbs"
    }
    'keep2' = {
        Start-Process -FilePath "wsl.exe" -ArgumentList "-d Debian /usr/local/bin/keepalive" 
    }
#  ...
}

# 为每个键设置别名或执行相应的命令
$ShortName.Keys | ForEach-Object {
    if ($_ -eq 'keep' -or $_ -eq 'keep2') {
        # 对 'keep' 使用函数
        Set-Item -Path "function:$($_)" -Value $ShortName.$_ 
    } else {
        # 对其他命令设置别名
        Set-Alias $_ $ShortName.$_
    }
}
```

之后ssh上去后执行`keep`即可。尝试了`ssh xxx -t keep`是没这个效果的，得先ssh进去，再执行keep，后面就能退出这个ssh的窗口了。

## 常见报错解决

### 0x80070422 wslservice服务未启动

```bash
无法启动服务，原因可能是已被禁用或与其相关联的设备没有启动。
Error code: Wsl/0x80070422
```

解决方案：

```bat
sc.exe config wslservice start= demand
```

### 0x8004032d 虚拟机平台功能未启用

```bat
WslRegisterDistribution failed with error: 0x8004032d
Error: 0x8004032d (null)
```
解决方案：在启用和关闭windows功能中打开“虚拟机平台”或使用下面的cmd命令并重启

```bat
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

### 端口被占用问题解决

```bat
# 查看当前动态端口范围
netsh int ipv4 show dynamicport tcp
# 查看被使用的端口
netsh int ipv4 show excludedportrange protocol=tcp

# 修改动态端口范围
netsh int ipv4 set dynamic tcp start=50000 num=15536
netsh int ipv6 set dynamic tcp start=50000 num=15536
# 重启网络
net stop winnat
net start winnat
```
