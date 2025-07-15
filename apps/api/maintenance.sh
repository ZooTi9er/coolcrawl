#!/bin/bash

# Firecrawl 维护脚本
# 用于定期清理缓存和检查系统状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Firecrawl 系统维护脚本${NC}"
echo "================================"

# 检查磁盘空间
check_disk_space() {
    echo -e "${YELLOW}检查磁盘空间...${NC}"
    
    local available=$(df . | awk 'NR==2 {print $4}')
    local total=$(df . | awk 'NR==2 {print $2}')
    local usage_percent=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    echo "磁盘使用率: ${usage_percent}%"
    
    if [ "$usage_percent" -gt 80 ]; then
        echo -e "${RED}⚠ 磁盘空间不足，建议清理${NC}"
        return 1
    else
        echo -e "${GREEN}✓ 磁盘空间充足${NC}"
        return 0
    fi
}

# 清理 Docker 缓存
clean_docker_cache() {
    echo -e "${YELLOW}清理 Docker 缓存...${NC}"
    
    # 清理未使用的镜像
    docker image prune -f
    
    # 清理未使用的容器
    docker container prune -f
    
    # 清理未使用的网络
    docker network prune -f
    
    # 清理未使用的卷
    docker volume prune -f
    
    # 清理构建缓存
    docker builder prune -f
    
    echo -e "${GREEN}✓ Docker 缓存清理完成${NC}"
}

# 清理 pnpm 缓存
clean_pnpm_cache() {
    echo -e "${YELLOW}清理 pnpm 缓存...${NC}"
    
    if command -v pnpm &> /dev/null; then
        # 清理存储缓存
        pnpm store prune
        
        # 清理全局缓存
        pnpm cache clean --force
        
        echo -e "${GREEN}✓ pnpm 缓存清理完成${NC}"
    else
        echo -e "${YELLOW}⚠ pnpm 未安装，跳过清理${NC}"
    fi
}

# 检查服务状态
check_services() {
    echo -e "${YELLOW}检查服务状态...${NC}"
    
    # 检查 Docker 服务
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✓ Docker 服务运行正常${NC}"
    else
        echo -e "${RED}✗ Docker 服务未运行${NC}"
        return 1
    fi
    
    # 检查 Redis 连接
    if docker-compose ps | grep -q "redis.*Up"; then
        echo -e "${GREEN}✓ Redis 服务运行正常${NC}"
    else
        echo -e "${YELLOW}⚠ Redis 服务未运行或未启动${NC}"
    fi
    
    # 检查应用服务
    if curl -s http://localhost:3002/test > /dev/null; then
        echo -e "${GREEN}✓ API 服务响应正常${NC}"
    else
        echo -e "${YELLOW}⚠ API 服务未响应${NC}"
    fi
}

# 检查网络连接
check_network() {
    echo -e "${YELLOW}检查网络连接...${NC}"
    
    # 检查基本网络连接
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 网络连接正常${NC}"
    else
        echo -e "${RED}✗ 网络连接异常${NC}"
        return 1
    fi
    
    # 检查 npm 镜像源
    if curl -s --connect-timeout 5 https://registry.npmmirror.com/ > /dev/null; then
        echo -e "${GREEN}✓ npm 镜像源连接正常${NC}"
    else
        echo -e "${YELLOW}⚠ npm 镜像源连接异常${NC}"
    fi
    
    # 检查 Docker Hub 连接
    if curl -s --connect-timeout 5 https://hub.docker.com/ > /dev/null; then
        echo -e "${GREEN}✓ Docker Hub 连接正常${NC}"
    else
        echo -e "${YELLOW}⚠ Docker Hub 连接异常${NC}"
    fi
}

# 更新依赖
update_dependencies() {
    echo -e "${YELLOW}检查依赖更新...${NC}"
    
    if [ -f "package.json" ]; then
        # 检查过时的包
        if command -v pnpm &> /dev/null; then
            echo "检查过时的包..."
            pnpm outdated || true
        fi
        
        echo -e "${GREEN}✓ 依赖检查完成${NC}"
    else
        echo -e "${YELLOW}⚠ 未找到 package.json 文件${NC}"
    fi
}

# 生成系统报告
generate_report() {
    echo -e "${YELLOW}生成系统报告...${NC}"
    
    local report_file="maintenance-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Firecrawl 系统维护报告"
        echo "生成时间: $(date)"
        echo "================================"
        echo ""
        
        echo "系统信息:"
        echo "- 操作系统: $(uname -s)"
        echo "- 内核版本: $(uname -r)"
        echo "- 架构: $(uname -m)"
        echo ""
        
        echo "Docker 信息:"
        docker version --format "- Docker 版本: {{.Server.Version}}" 2>/dev/null || echo "- Docker: 未安装或未运行"
        echo ""
        
        echo "磁盘使用情况:"
        df -h . | awk 'NR==2 {printf "- 使用率: %s\n- 可用空间: %s\n", $5, $4}'
        echo ""
        
        echo "内存使用情况:"
        free -h | awk 'NR==2 {printf "- 总内存: %s\n- 已使用: %s\n- 可用: %s\n", $2, $3, $7}'
        echo ""
        
        echo "服务状态:"
        if docker-compose ps > /dev/null 2>&1; then
            docker-compose ps
        else
            echo "- Docker Compose 服务未运行"
        fi
        
    } > "$report_file"
    
    echo -e "${GREEN}✓ 系统报告已生成: $report_file${NC}"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --clean-all     清理所有缓存（Docker + pnpm）"
    echo "  --clean-docker  仅清理 Docker 缓存"
    echo "  --clean-pnpm    仅清理 pnpm 缓存"
    echo "  --check         检查系统状态"
    echo "  --update        检查依赖更新"
    echo "  --report        生成系统报告"
    echo "  --full          执行完整维护（推荐）"
    echo "  --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --full       # 执行完整维护"
    echo "  $0 --check      # 仅检查系统状态"
    echo "  $0 --clean-all  # 清理所有缓存"
}

# 主函数
main() {
    local clean_all=false
    local clean_docker=false
    local clean_pnpm=false
    local check_only=false
    local update_deps=false
    local generate_report_flag=false
    local full_maintenance=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean-all)
                clean_all=true
                shift
                ;;
            --clean-docker)
                clean_docker=true
                shift
                ;;
            --clean-pnpm)
                clean_pnpm=true
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            --update)
                update_deps=true
                shift
                ;;
            --report)
                generate_report_flag=true
                shift
                ;;
            --full)
                full_maintenance=true
                shift
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
    
    # 如果没有指定选项，显示帮助
    if [ $# -eq 0 ] && [ "$clean_all" = false ] && [ "$clean_docker" = false ] && \
       [ "$clean_pnpm" = false ] && [ "$check_only" = false ] && \
       [ "$update_deps" = false ] && [ "$generate_report_flag" = false ] && \
       [ "$full_maintenance" = false ]; then
        show_help
        exit 0
    fi
    
    # 执行维护任务
    echo "开始执行维护任务..."
    echo ""
    
    # 检查磁盘空间
    check_disk_space
    echo ""
    
    # 执行相应操作
    if [ "$full_maintenance" = true ]; then
        check_services
        echo ""
        check_network
        echo ""
        clean_docker_cache
        echo ""
        clean_pnpm_cache
        echo ""
        update_dependencies
        echo ""
        generate_report
    else
        if [ "$check_only" = true ]; then
            check_services
            echo ""
            check_network
        fi
        
        if [ "$clean_all" = true ]; then
            clean_docker_cache
            echo ""
            clean_pnpm_cache
        elif [ "$clean_docker" = true ]; then
            clean_docker_cache
        elif [ "$clean_pnpm" = true ]; then
            clean_pnpm_cache
        fi
        
        if [ "$update_deps" = true ]; then
            update_dependencies
        fi
        
        if [ "$generate_report_flag" = true ]; then
            generate_report
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🎉 维护任务完成！${NC}"
}

# 运行主函数
main "$@"
