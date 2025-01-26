---
title: "Windows11启用openssh"
subtitle:
tags: 
- windows
date: 2025-01-26T11:14:36+08:00
lastmod: 2025-01-26T11:14:36+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

## windows11 启用openssh

参考文档：

1. [适用于 Windows 的 OpenSSH 入门](https://learn.microsoft.com/zh-cn/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell&pivots=windows-server-2025#enable-openssh-for-windows-server-2025)
2. [Install Win32 OpenSSH](https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH)

首先启用可选功能 openssh server

![alt text](/img/winodws11-enable-opensshd.png)

然后启动sshd服务，并设置为自动启动，并检查防火墙设置：

```ps1
# Start the sshd service
Start-Service sshd
# 设置为开机自启动
Set-Service -Name sshd -StartupType 'Automatic'
# 检查防火前设置
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}
# 设置默认shell为powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
```

配置sshd_config，位置在 %programdata%\ssh\sshd_config，参考文档：[OpenSSH Server configuration for Windows Server and Windows](https://learn.microsoft.com/zh-cn/windows-server/administration/OpenSSH/openssh-server-configuration)，主要修改下面两个配置：就是强制使用公钥登录

```bash
PubkeyAuthentication yes
PasswordAuthentication no
```

然后重启sshd服务，让配置生效。

在windows上保存公钥: 如果是系统管理员账户（一般第一个账户都是系统管理员账户），则在 `%programdata%/ssh/administrators_authorized_keys` 中保存公钥，如果是普通用户，则在 `%userprofile%/.ssh/authorized_keys` 中保存公钥。

## 设置powershell默认http代理

```ps1
# 确保允许执行脚本
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# 按需创建powershell的profile文件
if (-not (Test-Path -Path $PROFILE)) {
    New-Item -Path $PROFILE -Type File -Force
    Write-Output "Profile 文件已创建: $PROFILE"
} else {
    Write-Output "Profile 文件已存在: $PROFILE"
}

@"
# 设置系统代理
`$proxy = "http://127.0.0.1:7890"  # 你的代理地址和端口
`$env:HTTP_PROXY = `$proxy
`$env:HTTPS_PROXY = `$proxy

# 可选：输出代理状态
Write-Output "HTTP_PROXY is set to `$env:HTTP_PROXY"
"@ | Out-File -FilePath $PROFILE -Encoding UTF8 -Force

# 或者用：Add-Content -Path $PROFILE -Encoding UTF8
# 这个是追加
```

最后C:\Users\arloor\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1内容是：

```ps1
# 设置系统代理
$proxy = "http://127.0.0.1:7890"  # 你的代理地址和端口
$env:HTTP_PROXY = $proxy
$env:HTTPS_PROXY = $proxy

# 可选：输出代理状态
Write-Output "HTTP_PROXY is set to $env:HTTP_PROXY"
```

### 说明：

1. **Here-String (`@"... "@`)**  
   - 使用 `@"` 和 `"@` 包裹多行字符串，内容会原样输出。  
   - 在 PowerShell 中，变量名前的 `\``（反引号）用于转义特殊字符。
   
2. **`Out-File`**  
   - 将内容写入指定文件路径。  
   - 参数：
     - `-FilePath`：指定目标文件路径。
     - `-Encoding UTF8`：使用 UTF-8 编码写入文件。
     - `-Force`：覆盖已有内容。

3. **`Test-Path` 和 `New-Item`**  
   - 确保文件存在。如果文件不存在，就先创建空文件。

## 远程关闭windows

ssh上去后执行 `shutdown /s /f /t 0`

