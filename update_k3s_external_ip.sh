#!/bin/bash

# 脚本用于检测外部IP变化并自动更新k3s配置
# 作者: Generated Script
# 日期: $(date)

# 配置文件路径
K3S_SERVICE_FILE="/etc/systemd/system/k3s.service"
LOG_FILE="/var/log/k3s_ip_update.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 获取当前外部IP
get_external_ip() {
    local ip
    ip=$(curl -s --connect-timeout 10 --max-time 30 https://www.arloor.com/ip)
    if [[ $? -eq 0 ]] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    else
        log "ERROR: 无法获取外部IP或返回的不是有效的IPv4地址: $ip"
        return 1
    fi
}

# 从k3s.service文件中提取当前配置的外部IP
get_current_k3s_ip() {
    if [[ -f "$K3S_SERVICE_FILE" ]]; then
        grep -o "node-external-ip=[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "$K3S_SERVICE_FILE" | cut -d'=' -f2
    else
        echo ""
    fi
}

# 更新k3s.service文件中的外部IP
update_k3s_service() {
    local new_ip="$1"
    local current_k3s_ip
    
    current_k3s_ip=$(get_current_k3s_ip)
    
    log "INFO: 正在更新k3s.service文件，将IP从 $current_k3s_ip 更改为 $new_ip"
    
    # 备份原文件
    cp "$K3S_SERVICE_FILE" "${K3S_SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 替换IP地址
    sed -i "s/--node-external-ip=$current_k3s_ip/--node-external-ip=$new_ip/g" "$K3S_SERVICE_FILE"
    
    if [[ $? -eq 0 ]]; then
        log "INFO: k3s.service文件更新成功"
        return 0
    else
        log "ERROR: 更新k3s.service文件失败"
        return 1
    fi
}

# 重启k3s服务
restart_k3s_service() {
    log "INFO: 正在重新加载systemd配置..."
    systemctl daemon-reload
    
    if [[ $? -ne 0 ]]; then
        log "ERROR: systemctl daemon-reload 失败"
        return 1
    fi
    
    log "INFO: 正在重启k3s服务..."
    systemctl restart k3s.service
    
    if [[ $? -eq 0 ]]; then
        log "INFO: k3s服务重启成功"
        
        # 等待服务启动
        sleep 5
        
        # 检查服务状态
        if systemctl is-active --quiet k3s.service; then
            log "INFO: k3s服务运行正常"
            return 0
        else
            log "ERROR: k3s服务重启后未能正常运行"
            return 1
        fi
    else
        log "ERROR: k3s服务重启失败"
        return 1
    fi
}

# 主函数
main() {
    log "INFO: 开始检查外部IP变化..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: 此脚本需要root权限运行"
        exit 1
    fi
    
    # 检查k3s.service文件是否存在
    if [[ ! -f "$K3S_SERVICE_FILE" ]]; then
        log "ERROR: k3s.service文件不存在: $K3S_SERVICE_FILE"
        exit 1
    fi
    
    # 获取当前外部IP
    local current_ip
    current_ip=$(get_external_ip)
    if [[ $? -ne 0 ]]; then
        log "ERROR: 无法获取当前外部IP，脚本退出"
        exit 1
    fi
    
    log "INFO: 当前外部IP: $current_ip"
    
    # 获取k3s.service文件中当前配置的IP
    local current_k3s_ip
    current_k3s_ip=$(get_current_k3s_ip)
    
    # 如果k3s.service文件中没有node-external-ip参数，则不做任何操作
    if [[ -z "$current_k3s_ip" ]]; then
        log "INFO: k3s.service文件中未找到--node-external-ip参数，跳过更新"
        log "INFO: 脚本执行完成"
        exit 0
    fi
    
    log "INFO: k3s.service中当前配置的IP: $current_k3s_ip"
    
    # 如果IP发生变化
    if [[ "$current_k3s_ip" != "$current_ip" ]]; then
        log "INFO: IP发生变化 (k3s配置: $current_k3s_ip -> 当前外部IP: $current_ip)"
        
        # 更新k3s.service文件
        if update_k3s_service "$current_ip"; then
            # 重启k3s服务
            if restart_k3s_service; then
                log "INFO: IP更新完成，新IP: $current_ip"
            else
                log "ERROR: k3s服务重启失败"
                exit 1
            fi
        else
            log "ERROR: 更新k3s.service文件失败"
            exit 1
        fi
    else
        log "INFO: IP未发生变化，无需更新 (当前IP: $current_ip)"
    fi
    
    log "INFO: 脚本执行完成"
}

# 执行主函数
main "$@"
