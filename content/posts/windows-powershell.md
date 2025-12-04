---
title: "Windows Powershell常用脚本"
subtitle:
tags:
  - undefined
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