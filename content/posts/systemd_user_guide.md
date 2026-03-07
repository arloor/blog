---
title: "systemd用户模式和user journal使用指南"
date: 2026-03-07T11:40:56+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

这篇文章把 systemd 用户模式和 user journal 彻底讲清楚。

<!--more-->

## Systemd 用户模式是什么

简单说，systemd 不只是给 root 用的。每个登录用户都可以跑自己的 `systemd --user` 实例，用来管理用户级别的后台服务和定时任务——不需要 sudo。

用户单元文件放在以下目录：

| 目录                           | 用途                   |
| ------------------------------ | ---------------------- |
| `~/.config/systemd/user/`      | 用户自定义的服务       |
| `~/.local/share/systemd/user/` | 用户安装的服务         |
| `/usr/lib/systemd/user/`       | 系统提供的用户服务模板 |

所有操作都带 `--user` 参数，和系统级的 `systemctl` 用法几乎一样：

```bash
systemctl --user start my-app       # 启动
systemctl --user stop my-app        # 停止
systemctl --user restart my-app     # 重启
systemctl --user status my-app      # 查看状态
systemctl --user enable my-app      # 开机自启
systemctl --user daemon-reload      # 重新加载配置
```

有一个前提：必须启用 **linger**，否则用户注销后所有用户服务都会被杀掉：

```bash
sudo loginctl enable-linger $USER
loginctl show-user $USER | grep Linger   # 确认输出 Linger=yes
```

---

## 写一个用户服务

在 `~/.config/systemd/user/` 下创建 `.service` 文件即可。一个最小的服务文件长这样：

```ini
[Unit]
Description=My App
After=network.target

[Service]
Type=simple
ExecStart=/path/to/your/executable
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

几个关键字段说明：

- **Type**：`simple`（默认，进程不 fork）、`forking`（进程会 fork）、`oneshot`（跑一次就退出）、`notify`（进程主动通知 systemd 就绪）。
- **Restart=always**：挂了自动拉起来。
- **StandardOutput=journal**：日志发到 journal，后面用 `journalctl --user` 查看。
- **WantedBy=default.target**：用户登录（或 linger）时自动拉起。

### 实际例子：Node.js 应用

```ini
[Unit]
Description=Node.js Web App
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node /home/%i/apps/web-app/server.js
WorkingDirectory=/home/%i/apps/web-app
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

部署流程：

```bash
systemctl --user daemon-reload
systemctl --user start web-app
systemctl --user enable web-app
curl http://localhost:3000   # 验证
```

### 环境变量

可以直接写在 service 文件里，也可以引用外部文件：

```ini
[Service]
Environment="VAR1=value1"
EnvironmentFile=/home/%i/.env
```

---

## 用户定时器

systemd timer 是 cron 的现代替代品。需要两个文件：一个 `.service` 定义要做的事，一个 `.timer` 定义什么时候做。

`~/.config/systemd/user/backup.service`：

```ini
[Unit]
Description=Backup Script

[Service]
Type=oneshot
ExecStart=/home/%i/scripts/backup.sh
StandardOutput=journal
StandardError=journal
```

`~/.config/systemd/user/backup.timer`：

```ini
[Unit]
Description=Run backup daily
Requires=backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl --user enable --now backup.timer   # 启用并立即激活
systemctl --user list-timers                 # 查看所有定时器
```

常用的 `OnCalendar` 格式：

| 格式                   | 含义              |
| ---------------------- | ----------------- |
| `hourly`               | 每小时            |
| `daily`                | 每天              |
| `weekly`               | 每周              |
| `*-*-* 02:00:00`       | 每天凌晨 2 点     |
| `Mon,Wed,Fri 09:00:00` | 周一三五上午 9 点 |

---

## 重头戏：启用 User Journal

到这里你可能已经发现问题了——`journalctl --user` 根本没输出。这是 systemd 最让人困惑的默认行为之一。

### 为什么默认不可用

systemd journal 有两种存储模式：

| 模式               | 目录               | 说明     |
| ------------------ | ------------------ | -------- |
| volatile（内存）   | `/run/log/journal` | 重启丢失 |
| persistent（磁盘） | `/var/log/journal` | 持久保存 |

默认配置是 `Storage=auto`，逻辑是：

- `/var/log/journal` 目录存在 → persistent
- 不存在 → volatile

关键来了：**user journal 只在 persistent 模式下才会创建**。这是 systemd 文档里明确说明的。所以在大多数发行版的默认配置下，`journalctl --user` 就是不可用的。

### 启用步骤

**第一步：配置 persistent storage**

编辑 `/etc/systemd/journald.conf`：

```ini
[Journal]
Storage=persistent
SystemMaxUse=500M
RuntimeMaxUse=200M
SystemKeepFree=1G
```

`SystemMaxUse` 和 `SystemKeepFree` 是为了防止日志撑满磁盘。生产环境必须配。

**第二步：创建目录并设置权限**

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
```

`systemd-tmpfiles` 会自动创建 `/var/log/journal/<machine-id>/` 并设置正确的权限，比手动 `chown` 更可靠。

**第三步：重启 journald 并 flush**

```bash
sudo systemctl restart systemd-journald
sudo journalctl --flush
```

为什么需要 flush？因为 systemd 的设计是这样的：

```
journald 启动 → 先写 /run（内存）→ flush 后才切换到 /var/log（磁盘）
```

正常启动时 `systemd-journal-flush.service` 会自动做这件事。但我们是在运行中改配置，需要手动触发一次。

**第四步：验证**

```bash
# 检查 journald 状态，应该同时看到 Runtime Journal 和 System Journal
systemctl status systemd-journald

# 查看 user journal
journalctl --user -n 50
```

如果 `systemctl status systemd-journald` 的输出里只有 `Runtime Journal` 而没有 `System Journal`，说明 persistent 还没生效。

### 完整命令汇总

```bash
sudo nano /etc/systemd/journald.conf          # 设置 Storage=persistent
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
sudo journalctl --flush
journalctl --user -n 50                        # 验证
```

---

## 常见问题排查

### `journalctl --user` 报 No journal files were found

persistent storage 未启用。按上面的步骤走一遍。

### 配置了 persistent 但 journald 仍显示 runtime

大概率是没有执行 flush：

```bash
sudo journalctl --flush
```

### `/var/log/journal` 存在但不工作

权限问题或 machine-id 子目录缺失。用 systemd-tmpfiles 修复：

```bash
sudo systemd-tmpfiles --create --prefix /var/log/journal
```

### 服务启动失败

```bash
systemctl --user status my-app -l              # 查看详细状态
journalctl --user -u my-app --no-pager         # 查看完整日志
```

### 服务里访问不到 shell 环境变量

用户级 systemd 服务运行在独立的环境中，不会继承 shell 的 `.bashrc` 或 `.profile`。需要在 service 文件里显式声明：

```ini
[Service]
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="HOME=/home/%i"
```

---

## 小结

Systemd 用户模式是一个被严重低估的功能。它让普通用户也能享受到 systemd 的服务管理、自动重启、日志收集和定时任务能力。唯一的坑是 user journal 默认不可用，但只要启用 persistent storage 并执行一次 flush，一切就通了。

核心要点：

1. `loginctl enable-linger` 让用户服务在注销后继续运行
2. 服务文件放 `~/.config/systemd/user/`，所有命令加 `--user`
3. 日志查看依赖 persistent journal——`Storage=persistent` + `journalctl --flush`
4. 生产环境记得配 `SystemMaxUse` 限制日志大小
