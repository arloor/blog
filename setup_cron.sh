#!/bin/bash

# 自动配置cron任务的脚本
# 用于定期检查和更新k3s外部IP

SCRIPT_PATH="/root/blog/update_k3s_external_ip.sh"
CRON_JOB="*/5 * * * * $SCRIPT_PATH >/dev/null 2>&1"

echo "正在配置cron任务..."
echo "脚本路径: $SCRIPT_PATH"
echo "执行频率: 每5分钟检查一次"

# 检查脚本是否存在
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "错误: 脚本文件不存在: $SCRIPT_PATH"
    exit 1
fi

# 检查脚本是否有执行权限
if [[ ! -x "$SCRIPT_PATH" ]]; then
    echo "错误: 脚本文件没有执行权限: $SCRIPT_PATH"
    exit 1
fi

# 检查当前cron任务中是否已存在相同的任务
if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
    echo "警告: cron任务中已存在该脚本，正在移除旧任务..."
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
fi

# 添加新的cron任务
echo "正在添加cron任务..."
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

if [[ $? -eq 0 ]]; then
    echo "成功添加cron任务:"
    echo "$CRON_JOB"
    echo ""
    echo "当前的cron任务列表:"
    crontab -l
    echo ""
    echo "如需手动执行脚本，请运行: sudo $SCRIPT_PATH"
    echo "如需移除cron任务，请运行: crontab -e"
else
    echo "错误: 添加cron任务失败"
    exit 1
fi
