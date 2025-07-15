#!/bin/bash

# 生产级 Docker 构建脚本 - 支持多种回退策略

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
MAX_RETRIES=3
BUILD_TIMEOUT=1800  # 30分钟
HEALTH_CHECK_TIMEOUT=300  # 5分钟

echo -e "${BLUE}🏗️ 生产级 Docker 构建脚本${NC}"
echo "================================"

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}" | tee -a build.log
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}" | tee -a build.log
            ;;
        "INFO")
            echo -e "${GREEN}[$timestamp] [INFO] $message${NC}" | tee -a build.log
            ;;
        *)
            echo "[$timestamp] [$level] $message" | tee -a build.log
            ;;
    esac
}

# 检查系统要求
check_system_requirements() {
    log "INFO" "检查系统要求..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker 未安装"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "ERROR" "Docker Compose 未安装"
        exit 1
    fi
    
    # 检查磁盘空间
    local available_space=$(df . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5000000 ]; then  # 5GB
        log "WARN" "磁盘空间不足，建议至少有 5GB 可用空间"
    fi
    
    # 检查内存
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_memory" -lt 2048 ]; then  # 2GB
        log "WARN" "可用内存不足，建议至少有 2GB 可用内存"
    fi
    
    log "INFO" "系统要求检查完成"
}

# 检测架构和环境
detect_environment() {
    log "INFO" "检测环境..."
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DOCKER_PLATFORM="linux/amd64"
            ;;
        aarch64|arm64)
            DOCKER_PLATFORM="linux/arm64"
            ;;
        *)
            log "WARN" "未知架构: $ARCH，使用默认设置"
            DOCKER_PLATFORM="linux/amd64"
            ;;
    esac
    
    # 检测操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    else
        OS_NAME="Unknown"
        OS_VERSION="Unknown"
    fi
    
    # 检测网络环境
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
        NETWORK_ENV="international"
    elif curl -s --connect-timeout 5 https://www.baidu.com > /dev/null; then
        NETWORK_ENV="china"
    else
        NETWORK_ENV="limited"
    fi
    
    log "INFO" "环境检测完成: $OS_NAME $OS_VERSION, $ARCH, 网络: $NETWORK_ENV"
}

# 选择最佳构建策略
select_build_strategy() {
    log "INFO" "选择构建策略..."
    
    case "$NETWORK_ENV" in
        "china")
            DOCKERFILE="worker.china.Dockerfile"
            COMPOSE_FILE="docker-compose.china.yaml"
            log "INFO" "使用中国网络优化策略"
            ;;
        "international")
            if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
                DOCKERFILE="worker.playwright-official.Dockerfile"
                COMPOSE_FILE="docker-compose.enhanced.yaml"
                log "INFO" "使用 ARM64 + Playwright 策略"
            else
                DOCKERFILE="worker.Dockerfile"
                COMPOSE_FILE="docker-compose.enhanced.yaml"
                log "INFO" "使用标准构建策略"
            fi
            ;;
        *)
            DOCKERFILE="worker.prebuilt.Dockerfile"
            COMPOSE_FILE="docker-compose.enhanced.yaml"
            log "INFO" "使用预编译二进制策略"
            ;;
    esac
}

# 准备构建环境
prepare_build_environment() {
    log "INFO" "准备构建环境..."
    
    # 清理旧的构建缓存
    docker builder prune -f || true
    
    # 创建构建网络
    docker network create firecrawl-build-network 2>/dev/null || true
    
    # 设置构建参数
    BUILD_ARGS=""
    if [ -n "$HTTP_PROXY" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg HTTP_PROXY=$HTTP_PROXY"
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg HTTPS_PROXY=$HTTPS_PROXY"
    fi
    
    log "INFO" "构建环境准备完成"
}

# 构建镜像（带重试）
build_image_with_retry() {
    local dockerfile="$1"
    local tag="$2"
    local context="$3"
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        log "INFO" "构建镜像 $tag (尝试 $((retry_count + 1))/$MAX_RETRIES)"
        
        if timeout $BUILD_TIMEOUT docker build \
            $BUILD_ARGS \
            --platform $DOCKER_PLATFORM \
            -f "$dockerfile" \
            -t "$tag" \
            "$context"; then
            log "INFO" "镜像 $tag 构建成功"
            return 0
        else
            retry_count=$((retry_count + 1))
            log "WARN" "镜像 $tag 构建失败，重试中..."
            
            # 清理失败的构建缓存
            docker builder prune -f || true
            
            # 等待一段时间再重试
            sleep $((retry_count * 10))
        fi
    done
    
    log "ERROR" "镜像 $tag 构建失败，已达到最大重试次数"
    return 1
}

# 构建所有镜像
build_images() {
    log "INFO" "开始构建镜像..."
    
    # 构建 worker 镜像
    if ! build_image_with_retry "$DOCKERFILE" "0001coder/coolcrawl-worker:robust" "."; then
        log "ERROR" "Worker 镜像构建失败"
        
        # 尝试备用策略
        log "INFO" "尝试备用构建策略..."
        if [ "$DOCKERFILE" != "worker.prebuilt.Dockerfile" ]; then
            DOCKERFILE="worker.prebuilt.Dockerfile"
            if ! build_image_with_retry "$DOCKERFILE" "0001coder/coolcrawl-worker:robust" "."; then
                log "ERROR" "所有构建策略都失败了"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    # 构建 server 镜像
    local server_dockerfile="${DOCKERFILE/worker/server}"
    if [ ! -f "$server_dockerfile" ]; then
        # 如果没有对应的 server dockerfile，复制 worker dockerfile 并修改
        cp "$DOCKERFILE" "$server_dockerfile"
        sed -i 's/worker:production/start:production/g' "$server_dockerfile"
        sed -i 's/8080/3002/g' "$server_dockerfile"
    fi
    
    if ! build_image_with_retry "$server_dockerfile" "0001coder/coolcrawl-server:robust" "."; then
        log "ERROR" "Server 镜像构建失败"
        exit 1
    fi
    
    log "INFO" "所有镜像构建完成"
}

# 健康检查
health_check() {
    log "INFO" "执行健康检查..."
    
    # 启动服务
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # 等待服务启动
    local check_count=0
    local max_checks=$((HEALTH_CHECK_TIMEOUT / 10))
    
    while [ $check_count -lt $max_checks ]; do
        if curl -s http://localhost:3002/test > /dev/null; then
            log "INFO" "健康检查通过"
            return 0
        fi
        
        check_count=$((check_count + 1))
        log "INFO" "等待服务启动... ($check_count/$max_checks)"
        sleep 10
    done
    
    log "ERROR" "健康检查失败"
    
    # 显示日志以便调试
    log "INFO" "显示服务日志："
    docker-compose -f "$COMPOSE_FILE" logs --tail=50
    
    return 1
}

# 性能测试
performance_test() {
    log "INFO" "执行性能测试..."
    
    # 简单的性能测试
    local start_time=$(date +%s)
    
    # 测试 API 响应时间
    local response_time=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:3002/test)
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    log "INFO" "API 响应时间: ${response_time}s"
    log "INFO" "总测试时间: ${total_time}s"
    
    # 检查响应时间是否合理
    if (( $(echo "$response_time > 5.0" | bc -l) )); then
        log "WARN" "API 响应时间较慢"
    else
        log "INFO" "API 响应时间正常"
    fi
}

# 生成构建报告
generate_build_report() {
    log "INFO" "生成构建报告..."
    
    local report_file="build-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "build_info": {
    "timestamp": "$(date -Iseconds)",
    "architecture": "$ARCH",
    "platform": "$DOCKER_PLATFORM",
    "os": "$OS_NAME $OS_VERSION",
    "network_environment": "$NETWORK_ENV",
    "dockerfile_used": "$DOCKERFILE",
    "compose_file_used": "$COMPOSE_FILE"
  },
  "build_result": {
    "status": "success",
    "worker_image": "0001coder/coolcrawl-worker:robust",
    "server_image": "0001coder/coolcrawl-server:robust"
  },
  "system_info": {
    "docker_version": "$(docker --version)",
    "docker_compose_version": "$(docker-compose --version)",
    "available_memory": "$(free -m | awk 'NR==2{print $7}') MB",
    "available_disk": "$(df . | awk 'NR==2 {print $4}') KB"
  },
  "images": $(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep coolcrawl | head -10 | jq -R -s 'split("\n")[:-1] | map(split("\t")) | map({"name": .[0], "size": .[1], "created": .[2]})')
}
EOF
    
    log "INFO" "构建报告已生成: $report_file"
}

# 清理函数
cleanup() {
    log "INFO" "执行清理..."
    
    # 清理构建网络
    docker network rm firecrawl-build-network 2>/dev/null || true
    
    # 清理未使用的镜像
    docker image prune -f || true
    
    log "INFO" "清理完成"
}

# 显示使用指南
show_usage_guide() {
    echo ""
    echo -e "${BLUE}📖 生产级构建完成！${NC}"
    echo "================================"
    echo ""
    echo -e "${YELLOW}构建信息：${NC}"
    echo "  - 架构: $ARCH"
    echo "  - 平台: $DOCKER_PLATFORM"
    echo "  - 网络环境: $NETWORK_ENV"
    echo "  - 使用的 Dockerfile: $DOCKERFILE"
    echo ""
    echo -e "${YELLOW}服务管理：${NC}"
    echo "  启动: docker-compose -f $COMPOSE_FILE up -d"
    echo "  停止: docker-compose -f $COMPOSE_FILE down"
    echo "  日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo ""
    echo -e "${YELLOW}监控和调试：${NC}"
    echo "  健康检查: curl http://localhost:3002/test"
    echo "  查看镜像: docker images | grep coolcrawl"
    echo "  查看容器: docker ps"
    echo ""
    echo -e "${GREEN}🎉 构建成功完成！${NC}"
}

# 主函数
main() {
    local skip_health_check=false
    local skip_performance_test=false
    local cleanup_on_exit=true
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-health-check)
                skip_health_check=true
                shift
                ;;
            --skip-performance-test)
                skip_performance_test=true
                shift
                ;;
            --no-cleanup)
                cleanup_on_exit=false
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --skip-health-check      跳过健康检查"
                echo "  --skip-performance-test  跳过性能测试"
                echo "  --no-cleanup             不执行清理"
                echo "  --help                    显示此帮助信息"
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    # 设置清理陷阱
    if [ "$cleanup_on_exit" = true ]; then
        trap cleanup EXIT
    fi
    
    # 执行构建流程
    check_system_requirements
    detect_environment
    select_build_strategy
    prepare_build_environment
    build_images
    
    if [ "$skip_health_check" = false ]; then
        health_check
    fi
    
    if [ "$skip_performance_test" = false ]; then
        performance_test
    fi
    
    generate_build_report
    show_usage_guide
}

# 运行主函数
main "$@"
