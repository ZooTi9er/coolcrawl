#!/bin/bash

# Firecrawl 监控脚本
# 用于监控服务状态和性能指标

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
MONITOR_INTERVAL=30  # 监控间隔（秒）
LOG_FILE="monitor.log"
ALERT_THRESHOLD_CPU=80  # CPU 使用率告警阈值
ALERT_THRESHOLD_MEMORY=80  # 内存使用率告警阈值
ALERT_THRESHOLD_DISK=85  # 磁盘使用率告警阈值

echo -e "${BLUE}📊 Firecrawl 服务监控${NC}"
echo "================================"

# 记录日志
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}[$timestamp] [INFO] $message${NC}"
            ;;
        *)
            echo "[$timestamp] [$level] $message"
            ;;
    esac
}

# 检查服务状态
check_service_status() {
    local service_name="$1"
    local container_name="$2"
    
    if docker ps | grep -q "$container_name"; then
        log_message "INFO" "$service_name 服务运行正常"
        return 0
    else
        log_message "ERROR" "$service_name 服务未运行"
        return 1
    fi
}

# 检查 API 健康状态
check_api_health() {
    local api_url="http://localhost:3002/test"
    local response_time
    
    # 测试 API 响应
    if response_time=$(curl -s -w "%{time_total}" -o /dev/null "$api_url" 2>/dev/null); then
        local response_ms=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)
        
        if [ "$response_ms" -lt 1000 ]; then
            log_message "INFO" "API 响应正常 (${response_ms}ms)"
        elif [ "$response_ms" -lt 3000 ]; then
            log_message "WARN" "API 响应较慢 (${response_ms}ms)"
        else
            log_message "ERROR" "API 响应超时 (${response_ms}ms)"
        fi
        return 0
    else
        log_message "ERROR" "API 无响应"
        return 1
    fi
}

# 检查资源使用情况
check_resource_usage() {
    # 检查 CPU 使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    cpu_usage=${cpu_usage%.*}  # 去掉小数部分
    
    if [ "$cpu_usage" -gt "$ALERT_THRESHOLD_CPU" ]; then
        log_message "WARN" "CPU 使用率过高: ${cpu_usage}%"
    else
        log_message "INFO" "CPU 使用率正常: ${cpu_usage}%"
    fi
    
    # 检查内存使用率
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_mem * 100 / total_mem))
    
    if [ "$memory_usage" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        log_message "WARN" "内存使用率过高: ${memory_usage}%"
    else
        log_message "INFO" "内存使用率正常: ${memory_usage}%"
    fi
    
    # 检查磁盘使用率
    local disk_usage=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ]; then
        log_message "WARN" "磁盘使用率过高: ${disk_usage}%"
    else
        log_message "INFO" "磁盘使用率正常: ${disk_usage}%"
    fi
}

# 检查 Docker 容器资源使用
check_container_resources() {
    echo -e "${YELLOW}检查容器资源使用情况...${NC}"
    
    # 获取容器统计信息
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | while read line; do
        if [[ "$line" != *"CONTAINER"* ]]; then
            local container=$(echo "$line" | awk '{print $1}')
            local cpu_perc=$(echo "$line" | awk '{print $2}' | sed 's/%//')
            local mem_perc=$(echo "$line" | awk '{print $4}' | sed 's/%//')
            
            # 检查 CPU 使用率
            if (( $(echo "$cpu_perc > 80" | bc -l) )); then
                log_message "WARN" "容器 $container CPU 使用率过高: ${cpu_perc}%"
            fi
            
            # 检查内存使用率
            if (( $(echo "$mem_perc > 80" | bc -l) )); then
                log_message "WARN" "容器 $container 内存使用率过高: ${mem_perc}%"
            fi
        fi
    done
}

# 检查网络连接
check_network_connectivity() {
    # 检查外网连接
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log_message "INFO" "外网连接正常"
    else
        log_message "ERROR" "外网连接异常"
    fi
    
    # 检查 npm 镜像源
    if curl -s --connect-timeout 5 https://registry.npmmirror.com/ > /dev/null; then
        log_message "INFO" "npm 镜像源连接正常"
    else
        log_message "WARN" "npm 镜像源连接异常"
    fi
}

# 检查日志错误
check_logs_for_errors() {
    echo -e "${YELLOW}检查服务日志中的错误...${NC}"
    
    # 检查最近的 Docker Compose 日志
    local error_count=$(docker-compose logs --since="5m" 2>/dev/null | grep -i "error\|exception\|failed" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        log_message "WARN" "发现 $error_count 个错误日志条目"
        
        # 显示最近的错误
        echo -e "${RED}最近的错误日志:${NC}"
        docker-compose logs --since="5m" 2>/dev/null | grep -i "error\|exception\|failed" | tail -5
    else
        log_message "INFO" "未发现错误日志"
    fi
}

# 生成监控报告
generate_monitoring_report() {
    local report_file="monitoring-report-$(date +%Y%m%d-%H%M%S).json"
    
    # 收集系统信息
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_mem * 100 / total_mem))
    local disk_usage=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # 生成 JSON 报告
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "system": {
    "cpu_usage": "${cpu_usage%.*}",
    "memory_usage": "$memory_usage",
    "disk_usage": "$disk_usage"
  },
  "services": {
    "api_status": "$(curl -s http://localhost:3002/test > /dev/null && echo 'healthy' || echo 'unhealthy')",
    "redis_status": "$(docker ps | grep redis > /dev/null && echo 'running' || echo 'stopped')"
  },
  "network": {
    "external_connectivity": "$(ping -c 1 8.8.8.8 > /dev/null 2>&1 && echo 'ok' || echo 'failed')",
    "npm_registry": "$(curl -s --connect-timeout 5 https://registry.npmmirror.com/ > /dev/null && echo 'ok' || echo 'failed')"
  }
}
EOF
    
    log_message "INFO" "监控报告已生成: $report_file"
}

# 自动修复常见问题
auto_fix_issues() {
    echo -e "${YELLOW}尝试自动修复常见问题...${NC}"
    
    # 检查并重启停止的容器
    local stopped_containers=$(docker ps -a | grep "Exited" | awk '{print $1}')
    if [ -n "$stopped_containers" ]; then
        log_message "INFO" "发现停止的容器，尝试重启..."
        echo "$stopped_containers" | xargs docker restart
    fi
    
    # 检查磁盘空间，如果不足则清理
    local disk_usage=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 85 ]; then
        log_message "INFO" "磁盘空间不足，执行清理..."
        docker system prune -f
    fi
}

# 显示实时监控
show_realtime_monitoring() {
    echo -e "${BLUE}实时监控模式 (按 Ctrl+C 退出)${NC}"
    echo "================================"
    
    while true; do
        clear
        echo -e "${BLUE}📊 Firecrawl 实时监控 - $(date)${NC}"
        echo "================================"
        
        # 显示服务状态
        echo -e "${YELLOW}服务状态:${NC}"
        check_service_status "API Server" "coolcrawl-server" && echo "✓ API Server" || echo "✗ API Server"
        check_service_status "Worker" "coolcrawl-worker" && echo "✓ Worker" || echo "✗ Worker"
        check_service_status "Redis" "redis" && echo "✓ Redis" || echo "✗ Redis"
        echo ""
        
        # 显示资源使用
        echo -e "${YELLOW}资源使用:${NC}"
        check_resource_usage
        echo ""
        
        # 显示 API 健康状态
        echo -e "${YELLOW}API 健康状态:${NC}"
        check_api_health
        echo ""
        
        # 等待下次检查
        sleep "$MONITOR_INTERVAL"
    done
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --realtime      实时监控模式"
    echo "  --check         执行一次完整检查"
    echo "  --report        生成监控报告"
    echo "  --auto-fix      自动修复常见问题"
    echo "  --interval N    设置监控间隔（秒，默认30）"
    echo "  --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --realtime           # 启动实时监控"
    echo "  $0 --check              # 执行一次检查"
    echo "  $0 --interval 60        # 设置60秒间隔"
}

# 主函数
main() {
    local realtime_mode=false
    local check_once=false
    local generate_report_flag=false
    local auto_fix=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --realtime)
                realtime_mode=true
                shift
                ;;
            --check)
                check_once=true
                shift
                ;;
            --report)
                generate_report_flag=true
                shift
                ;;
            --auto-fix)
                auto_fix=true
                shift
                ;;
            --interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    # 执行相应操作
    if [ "$realtime_mode" = true ]; then
        show_realtime_monitoring
    elif [ "$check_once" = true ]; then
        log_message "INFO" "开始执行监控检查"
        check_resource_usage
        check_network_connectivity
        check_api_health
        check_logs_for_errors
        log_message "INFO" "监控检查完成"
    elif [ "$generate_report_flag" = true ]; then
        generate_monitoring_report
    elif [ "$auto_fix" = true ]; then
        auto_fix_issues
    else
        show_help
    fi
}

# 运行主函数
main "$@"
