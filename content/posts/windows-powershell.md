---
title: "Windows Powershell常用脚本"
subtitle:
tags:
  - windows
date: 2025-12-04T15:37:22+08:00
lastmod: 2025-12-04T15:37:22+08:00
draft: false
categories:
  - undefined
weight: 10
description:
highlightjslanguages:
  - powershell
---

对 linux 的 shell 脚本比较熟悉后，发现 windows 的 powershell 也挺好用的。这里记录一些常用的脚本片段，方便以后查阅。

<!--more-->

## 查看磁盘占用

类似 `du -h --max-depth 1`（Linux） 或 `du -d1 -h`（MacOS） 的功能，可以使用 PowerShell 脚本来查看当前目录下的文件夹大小：

> 可以 `code $PROFILE` 打开 PowerShell 配置文件，将下面的函数添加进去，这样就可以在 PowerShell 中使用 `ds` 命令来查看当前目录下的文件夹大小。

```powershell
function Get-FolderSize {
    Write-Host '正在计算当前目录的空间占用，请稍候。。。' -ForegroundColor Yellow
    # 统计当前目录下的文件(不在子文件夹中)
    $currentFiles = Get-ChildItem -File -Force -ErrorAction SilentlyContinue
    if ($currentFiles) {
        $currentSize = ($currentFiles | Measure-Object -Property Length -Sum).Sum
    } else {
        $currentSize = 0
    }

    # 统计所有子文件夹
    $folders = Get-ChildItem -Force | Where-Object { $_.PSIsContainer } | ForEach-Object {
        $files = Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue
        if ($files) {
            $size = ($files | Measure-Object -Property Length -Sum).Sum
        } else {
            $size = 0
        }
        [PSCustomObject]@{
            Name = $_.Name
            SizeGB = [math]::Round($size / 1GB, 2)
            SizeMB = [math]::Round($size / 1MB, 2)
        }
    }

    # 添加当前目录文件统计
    if ($currentSize -gt 0) {
        $currentDirEntry = [PSCustomObject]@{
            Name = "."
            SizeGB = [math]::Round($currentSize / 1GB, 2)
            SizeMB = [math]::Round($currentSize / 1MB, 2)
        }
        $allEntries = @($currentDirEntry) + $folders
    } else {
        $allEntries = $folders
    }

    # 按大小排序并显示
    $allEntries | Sort-Object SizeGB -Descending | Format-Table -AutoSize
}

# 创建 alias
Set-Alias -Name ds -Value Get-FolderSize
```

```
C:\Program Files (x86)\Steam\steamapps\common:

Name                             SizeGB    SizeMB
----                             ------    ------
MonsterHunterWilds               154.94 158661.41
Baldurs Gate 3                   144.74 148214.57
BlackMythWukong                  140.48 143856.29
Monster Hunter World              98.39  100747.9
ForzaHorizon4                     94.58  96844.94
Cyberpunk 2077                    91.23  93415.27
ELDEN RING                         66.2  67786.84
Palworld                           29.5  30207.92
Hades                             11.08  11348.39
Hades II                          10.17  10410.33
wallpaper_engine                   1.32   1348.01
Steamworks Shared                  0.56    569.12
MonsterHunterWildsBetatest         0.44    451.38
Black Myth Wukong Benchmark Tool   0.04     41.16
Steam Controller Configs              0         0
```

## 放开某端口的防火墙

```powershell
$port=2222
New-NetFirewallRule -DisplayName "Allow Port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
```

## 系统信息相关

### 查看 CPU 和内存使用情况

```powershell
# CPU 使用率
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3

# 内存使用情况
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, @{N='MemoryMB';E={[math]::Round($_.WorkingSet64/1MB,2)}}

# 系统内存概览
Get-CimInstance Win32_OperatingSystem | Select-Object @{N='TotalMemoryGB';E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}, @{N='FreeMemoryGB';E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
```

### 查看磁盘使用情况

```powershell
# 查看所有磁盘分区使用情况
Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}}, @{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}}, @{N='TotalGB';E={[math]::Round(($_.Used+$_.Free)/1GB,2)}}
```

## 进程管理

### 查找并终止进程

```powershell
# 按名称查找进程
Get-Process -Name *chrome* | Select-Object Id, ProcessName, CPU, @{N='MemoryMB';E={[math]::Round($_.WorkingSet64/1MB,2)}}

# 终止进程
Stop-Process -Name "进程名" -Force

# 按端口查找并终止进程
$port = 8080
Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | ForEach-Object {
    $process = Get-Process -Id $_.OwningProcess
    Write-Host "端口 $port 被进程占用: $($process.ProcessName) (PID: $($process.Id))"
    # Stop-Process -Id $_.OwningProcess -Force  # 取消注释以终止进程
}
```

### 查看端口占用

```powershell
# 查看所有监听端口
Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, @{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}} | Sort-Object LocalPort

# 查看特定端口
Get-NetTCPConnection -LocalPort 80 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, @{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}}
```

## 网络相关

### 测试网络连通性

```powershell
# 类似 ping，但更强大
Test-NetConnection -ComputerName google.com -Port 443

# 批量测试多个主机
@("google.com", "github.com", "baidu.com") | ForEach-Object {
    $result = Test-NetConnection -ComputerName $_ -Port 443 -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Host = $_
        TcpTestSucceeded = $result.TcpTestSucceeded
        PingSucceeded = $result.PingSucceeded
        RTT = $result.PingReplyDetails.RoundtripTime
    }
} | Format-Table -AutoSize
```

### 查看网络配置

```powershell
# 获取 IP 地址信息
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object InterfaceAlias, IPAddress, PrefixLength

# 获取 DNS 服务器
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias, ServerAddresses

# 获取默认网关
Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object InterfaceAlias, NextHop
```

### 刷新 DNS 缓存

```powershell
Clear-DnsClientCache
Write-Host "DNS 缓存已清除" -ForegroundColor Green
```

## 文件操作

### 批量重命名文件

```powershell
# 批量添加前缀
Get-ChildItem -Filter "*.jpg" | Rename-Item -NewName { "prefix_" + $_.Name }

# 批量替换文件名中的字符
Get-ChildItem -Filter "*old*" | Rename-Item -NewName { $_.Name -replace "old", "new" }

# 按序号重命名
$i = 1; Get-ChildItem -Filter "*.png" | ForEach-Object { Rename-Item $_.FullName -NewName ("image_{0:D3}.png" -f $i++)}
```

### 查找大文件

```powershell
# 查找当前目录下大于 100MB 的文件
Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 100MB } | Sort-Object Length -Descending | Select-Object @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}}, FullName | Format-Table -AutoSize
```

### 计算文件哈希

```powershell
# 计算 MD5
Get-FileHash -Path "文件路径" -Algorithm MD5

# 计算 SHA256
Get-FileHash -Path "文件路径" -Algorithm SHA256

# 批量计算当前目录所有文件的哈希
Get-ChildItem -File | Get-FileHash -Algorithm MD5 | Select-Object Hash, @{N='FileName';E={Split-Path $_.Path -Leaf}}
```

### 压缩和解压

```powershell
# 压缩文件夹
Compress-Archive -Path "源文件夹" -DestinationPath "目标.zip"

# 解压缩
Expand-Archive -Path "源.zip" -DestinationPath "目标文件夹"

# 追加文件到现有压缩包
Compress-Archive -Path "新文件" -Update -DestinationPath "现有.zip"
```

## 服务管理

### 查看和管理服务

```powershell
# 查看所有正在运行的服务
Get-Service | Where-Object { $_.Status -eq "Running" } | Sort-Object DisplayName

# 按名称搜索服务
Get-Service -Name "*ssh*" | Select-Object Name, DisplayName, Status, StartType

# 启动/停止/重启服务
Start-Service -Name "服务名"
Stop-Service -Name "服务名"
Restart-Service -Name "服务名"

# 设置服务启动类型
Set-Service -Name "服务名" -StartupType Automatic  # Manual / Disabled
```

## 环境变量

### 查看和设置环境变量

```powershell
# 查看所有环境变量
Get-ChildItem Env: | Sort-Object Name

# 查看特定环境变量
$env:PATH -split ";"

# 临时设置环境变量（仅当前会话）
$env:MY_VAR = "my_value"

# 永久设置用户环境变量
[Environment]::SetEnvironmentVariable("MY_VAR", "my_value", "User")

# 永久设置系统环境变量（需要管理员权限）
[Environment]::SetEnvironmentVariable("MY_VAR", "my_value", "Machine")

# 添加路径到 PATH（永久，用户级别）
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
[Environment]::SetEnvironmentVariable("PATH", "$currentPath;C:\新路径", "User")
```

## 计划任务

### 创建计划任务

```powershell
# 创建一个每天运行的计划任务
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\Scripts\backup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "03:00"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "每日备份" -Action $action -Trigger $trigger -Principal $principal

# 查看计划任务
Get-ScheduledTask | Where-Object { $_.TaskName -like "*备份*" }

# 删除计划任务
Unregister-ScheduledTask -TaskName "每日备份" -Confirm:$false
```

## 剪贴板操作

```powershell
# 复制到剪贴板
"要复制的内容" | Set-Clipboard

# 从剪贴板获取内容
Get-Clipboard

# 将命令输出复制到剪贴板
Get-Process | Out-String | Set-Clipboard
```

## 下载文件

```powershell
# 使用 Invoke-WebRequest 下载
Invoke-WebRequest -Uri "https://example.com/file.zip" -OutFile "file.zip"

# 带进度条的下载
$ProgressPreference = 'Continue'
Invoke-WebRequest -Uri "https://example.com/file.zip" -OutFile "file.zip"

# 使用 curl（PowerShell 7+）或 Start-BitsTransfer（后台下载）
Start-BitsTransfer -Source "https://example.com/file.zip" -Destination "file.zip"
```

## 实用小函数

### 快速打开常用目录

```powershell
# 添加到 $PROFILE
function hosts { notepad C:\Windows\System32\drivers\etc\hosts }
function downloads { Set-Location $env:USERPROFILE\Downloads }
function desktop { Set-Location $env:USERPROFILE\Desktop }
function projects { Set-Location D:\Projects }  # 自定义你的项目目录
```

### 快速创建文件（类似 Linux touch）

```powershell
function touch {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path
    }
}
```

### 历史命令搜索

```powershell
# 搜索历史命令
Get-History | Where-Object { $_.CommandLine -like "*关键词*" }

# 查看所有历史命令（包括之前的会话）
Get-Content (Get-PSReadlineOption).HistorySavePath | Select-String "关键词"
```

### 生成随机密码

```powershell
function New-RandomPassword {
    param([int]$Length = 16)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# 使用
New-RandomPassword -Length 20
```

### 快速 Base64 编解码

```powershell
# 编码
function ConvertTo-Base64 { param([string]$Text) [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text)) }

# 解码
function ConvertFrom-Base64 { param([string]$Base64) [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64)) }
```
