#!/bin/bash

# ARM64 Docker 构建问题一键修复脚本
# 基于网络搜索结果和社区最佳实践

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 ARM64 Docker 构建问题一键修复${NC}"
echo "=================================="

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}" | tee -a quick-fix.log
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}" | tee -a quick-fix.log
            ;;
        "INFO")
            echo -e "${GREEN}[$timestamp] [INFO] $message${NC}" | tee -a quick-fix.log
            ;;
        *)
            echo "[$timestamp] [$level] $message" | tee -a quick-fix.log
            ;;
    esac
}

# 检查环境
check_environment() {
    log "INFO" "检查环境..."
    
    # 检查目录
    if [ ! -f "package.json" ]; then
        log "ERROR" "请在 apps/api 目录下运行此脚本"
        exit 1
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker 未安装"
        exit 1
    fi
    
    # 检查架构
    local arch=$(uname -m)
    if [[ "$arch" != "arm64" && "$arch" != "aarch64" ]]; then
        log "WARN" "当前架构 $arch 可能不需要此修复脚本"
    fi
    
    log "INFO" "环境检查完成 - 架构: $arch"
}

# 备份配置
backup_config() {
    log "INFO" "备份当前配置..."
    
    local backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份重要文件
    cp *.Dockerfile "$backup_dir/" 2>/dev/null || true
    cp package.json "$backup_dir/"
    cp pnpm-lock.yaml "$backup_dir/" 2>/dev/null || true
    cp docker-compose.yaml "$backup_dir/" 2>/dev/null || true
    
    log "INFO" "配置已备份到 $backup_dir"
}

# 清理缓存
clean_cache() {
    log "INFO" "清理缓存..."
    
    # 清理 Docker 缓存
    docker builder prune -f || true
    docker system prune -f || true
    
    # 清理 pnpm 缓存
    if command -v pnpm &> /dev/null; then
        pnpm store prune || true
        pnpm cache clean --force || true
    fi
    
    log "INFO" "缓存清理完成"
}

# 检测网络环境
detect_network() {
    log "INFO" "检测网络环境..."
    
    # 测试中国网络
    if curl -s --connect-timeout 5 https://mirrors.tuna.tsinghua.edu.cn > /dev/null; then
        NETWORK_ENV="china"
        log "INFO" "检测到中国网络环境"
    # 测试国际网络
    elif curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
        NETWORK_ENV="international"
        log "INFO" "检测到国际网络环境"
    # 测试基本连接
    elif ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        NETWORK_ENV="limited"
        log "INFO" "网络连接受限"
    else
        NETWORK_ENV="offline"
        log "WARN" "网络连接异常"
    fi
}

# 选择修复策略
select_strategy() {
    log "INFO" "选择修复策略..."
    
    case $NETWORK_ENV in
        "china")
            STRATEGY="china-network"
            log "INFO" "使用中国网络优化策略"
            ;;
        "international")
            STRATEGY="playwright"
            log "INFO" "使用 Playwright 策略"
            ;;
        "limited")
            STRATEGY="prebuilt"
            log "INFO" "使用预编译二进制策略"
            ;;
        *)
            STRATEGY="robust"
            log "INFO" "使用健壮构建策略"
            ;;
    esac
}

# 执行中国网络优化策略
fix_china_network() {
    log "INFO" "执行中国网络优化..."
    
    # 运行网络优化脚本
    if [ -f "./setup-china-network.sh" ]; then
        ./setup-china-network.sh
        ./build-china.sh
    else
        log "WARN" "网络优化脚本不存在，使用内置方案"
        
        # 创建优化的 sources.list
        cat > sources.list.china << 'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
        
        # 创建优化的 Dockerfile
        create_optimized_dockerfile
        
        # 构建镜像
        docker build -f worker.optimized.Dockerfile -t firecrawl-worker:fixed .
    fi
}

# 执行 Playwright 策略
fix_playwright() {
    log "INFO" "执行 Playwright 策略..."
    
    if [ -f "./migrate-to-playwright.sh" ]; then
        ./migrate-to-playwright.sh
        docker build -f worker.playwright-official.Dockerfile -t firecrawl-worker:fixed .
    else
        log "WARN" "Playwright 迁移脚本不存在，使用官方镜像"
        
        # 创建基于 Playwright 的 Dockerfile
        cat > worker.playwright.Dockerfile << 'EOF'
FROM mcr.microsoft.com/playwright:v1.40.0-noble

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# 安装 pnpm
RUN npm install -g pnpm@8.15.6

WORKDIR /app
COPY package.json pnpm-lock.yaml ./

# 安装依赖
RUN pnpm install --prod --frozen-lockfile

COPY . .
RUN pnpm run build

EXPOSE 8080
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
CMD [ "pnpm", "run", "worker:production" ]
EOF
        
        docker build -f worker.playwright.Dockerfile -t firecrawl-worker:fixed .
    fi
}

# 执行预编译二进制策略
fix_prebuilt() {
    log "INFO" "执行预编译二进制策略..."
    
    if [ -f "./worker.prebuilt.Dockerfile" ]; then
        docker build -f worker.prebuilt.Dockerfile -t firecrawl-worker:fixed .
    else
        log "WARN" "预编译 Dockerfile 不存在，创建简化版本"
        
        # 创建简化的 Dockerfile
        cat > worker.simple.Dockerfile << 'EOF'
FROM node:20-slim

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# 配置镜像源
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main" > /etc/apt/sources.list

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    curl wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable

WORKDIR /app
COPY package.json pnpm-lock.yaml ./

# 配置 npm 镜像源
RUN npm config set registry https://registry.npmmirror.com/
RUN pnpm install --prod --frozen-lockfile

COPY . .
RUN pnpm run build

EXPOSE 8080
CMD [ "pnpm", "run", "worker:production" ]
EOF
        
        docker build -f worker.simple.Dockerfile -t firecrawl-worker:fixed .
    fi
}

# 执行健壮构建策略
fix_robust() {
    log "INFO" "执行健壮构建策略..."
    
    if [ -f "./build-robust.sh" ]; then
        ./build-robust.sh --skip-health-check
    else
        log "WARN" "健壮构建脚本不存在，使用基础修复"
        fix_china_network
    fi
}

# 创建优化的 Dockerfile
create_optimized_dockerfile() {
    cat > worker.optimized.Dockerfile << 'EOF'
FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# 配置中国镜像源
COPY sources.list.china /etc/apt/sources.list

# 配置 apt 重试设置
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries

# 配置 npm 镜像源
RUN npm config set registry https://registry.npmmirror.com/

RUN corepack enable

WORKDIR /app
COPY package.json pnpm-lock.yaml ./

FROM base AS deps
RUN pnpm install --prod --frozen-lockfile

FROM base AS build
COPY . .
RUN pnpm install --frozen-lockfile && pnpm run build

FROM base
# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    chromium chromium-sandbox \
    fonts-liberation fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app .

EXPOSE 8080
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium"
CMD [ "pnpm", "run", "worker:production" ]
EOF
}

# 验证修复结果
verify_fix() {
    log "INFO" "验证修复结果..."
    
    # 检查镜像是否构建成功
    if docker images | grep -q "firecrawl-worker.*fixed"; then
        log "INFO" "镜像构建成功"
        
        # 测试镜像基本功能
        if docker run --rm firecrawl-worker:fixed node --version > /dev/null 2>&1; then
            log "INFO" "镜像功能正常"
            return 0
        else
            log "WARN" "镜像功能测试失败"
            return 1
        fi
    else
        log "ERROR" "镜像构建失败"
        return 1
    fi
}

# 启动服务测试
test_service() {
    log "INFO" "启动服务测试..."
    
    # 更新 docker-compose.yaml 使用新镜像
    if [ -f "docker-compose.yaml" ]; then
        sed -i.bak 's/image: .*/image: firecrawl-worker:fixed/' docker-compose.yaml
    fi
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    sleep 15
    
    # 测试 API
    if curl -s http://localhost:3002/test > /dev/null; then
        log "INFO" "服务启动成功"
        return 0
    else
        log "WARN" "服务可能需要更多时间启动"
        return 1
    fi
}

# 生成修复报告
generate_report() {
    log "INFO" "生成修复报告..."
    
    local report_file="fix-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ARM64 Docker 构建修复报告"
        echo "========================="
        echo "修复时间: $(date)"
        echo "网络环境: $NETWORK_ENV"
        echo "修复策略: $STRATEGY"
        echo ""
        echo "系统信息:"
        echo "- 架构: $(uname -m)"
        echo "- 操作系统: $(uname -s)"
        echo "- Docker 版本: $(docker --version)"
        echo ""
        echo "构建结果:"
        docker images | grep firecrawl
        echo ""
        echo "服务状态:"
        docker-compose ps 2>/dev/null || echo "服务未启动"
    } > "$report_file"
    
    log "INFO" "修复报告已生成: $report_file"
}

# 主函数
main() {
    local auto_mode=false
    local skip_test=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                auto_mode=true
                shift
                ;;
            --skip-test)
                skip_test=true
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --auto       自动模式，不询问用户"
                echo "  --skip-test  跳过服务测试"
                echo "  --help       显示此帮助信息"
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    # 执行修复流程
    check_environment
    backup_config
    clean_cache
    detect_network
    select_strategy
    
    # 根据策略执行修复
    case $STRATEGY in
        "china-network")
            fix_china_network
            ;;
        "playwright")
            fix_playwright
            ;;
        "prebuilt")
            fix_prebuilt
            ;;
        "robust")
            fix_robust
            ;;
    esac
    
    # 验证修复结果
    if verify_fix; then
        log "INFO" "修复成功！"
        
        # 测试服务（如果不跳过）
        if [ "$skip_test" = false ]; then
            test_service
        fi
        
        generate_report
        
        echo ""
        echo -e "${GREEN}🎉 修复完成！${NC}"
        echo "镜像标签: firecrawl-worker:fixed"
        echo "查看日志: cat quick-fix.log"
        echo "查看报告: cat fix-report-*.txt"
        echo ""
        echo "下一步："
        echo "1. 验证服务: curl http://localhost:3002/test"
        echo "2. 查看状态: docker-compose ps"
        echo "3. 查看日志: docker-compose logs"
        
    else
        log "ERROR" "修复失败，请查看日志文件 quick-fix.log"
        echo ""
        echo -e "${RED}❌ 修复失败${NC}"
        echo "请查看详细文档："
        echo "- docs/ARM64_DOCKER_SOLUTION.md"
        echo "- docs/TROUBLESHOOTING_GUIDE.md"
        exit 1
    fi
}

# 运行主函数
main "$@"
