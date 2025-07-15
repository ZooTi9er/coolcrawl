#!/bin/bash

# Firecrawl Docker 构建脚本
# 用于解决中国网络环境下的构建问题

set -e  # 遇到错误立即退出

echo "🚀 开始构建 Firecrawl Docker 镜像..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查代理设置
check_proxy() {
    echo -e "${YELLOW}检查代理设置...${NC}"
    if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        echo -e "${GREEN}✓ 检测到代理设置${NC}"
        echo "HTTP_PROXY: ${HTTP_PROXY:-未设置}"
        echo "HTTPS_PROXY: ${HTTPS_PROXY:-未设置}"
    else
        echo -e "${YELLOW}⚠ 未检测到代理设置，如果网络访问有问题，请设置代理${NC}"
    fi
}

# 清理缓存
clean_cache() {
    echo -e "${YELLOW}清理缓存...${NC}"
    
    # 清理 Docker 缓存
    echo "清理 Docker BuildKit 缓存..."
    docker builder prune -f || true
    
    # 清理 pnpm 缓存
    echo "清理 pnpm 缓存..."
    if command -v pnpm &> /dev/null; then
        pnpm store prune || true
        pnpm cache clean --force || true
    fi
    
    # 清理 node_modules
    echo "清理 node_modules..."
    rm -rf node_modules || true
    
    echo -e "${GREEN}✓ 缓存清理完成${NC}"
}

# 检查网络连接
check_network() {
    echo -e "${YELLOW}检查网络连接...${NC}"
    
    # 测试 npm 镜像源连接
    if curl -s --connect-timeout 5 https://registry.npmmirror.com/ > /dev/null; then
        echo -e "${GREEN}✓ 淘宝镜像源连接正常${NC}"
    else
        echo -e "${RED}✗ 淘宝镜像源连接失败${NC}"
        echo "尝试使用官方源..."
    fi
}

# 设置 npm 配置
setup_npm_config() {
    echo -e "${YELLOW}配置 npm 设置...${NC}"
    
    # 创建 .npmrc 文件
    cat > .npmrc << 'EOF'
registry=https://registry.npmmirror.com/
puppeteer_download_host=https://npmmirror.com/mirrors
chromedriver_cdnurl=https://npmmirror.com/mirrors/chromedriver
electron_mirror=https://npmmirror.com/mirrors/electron/
sass_binary_site=https://npmmirror.com/mirrors/node-sass/
fetch-retries=3
fetch-retry-factor=2
fetch-retry-mintimeout=10000
fetch-retry-maxtimeout=60000
EOF
    
    echo -e "${GREEN}✓ npm 配置完成${NC}"
}

# 构建镜像
build_images() {
    echo -e "${YELLOW}开始构建 Docker 镜像...${NC}"
    
    # 设置构建参数
    BUILD_ARGS=""
    if [ -n "$HTTP_PROXY" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg HTTP_PROXY=$HTTP_PROXY"
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg HTTPS_PROXY=$HTTPS_PROXY"
    fi
    if [ -n "$NO_PROXY" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg NO_PROXY=$NO_PROXY"
    fi
    
    # 构建 worker 镜像
    echo "构建 worker 镜像..."
    docker build $BUILD_ARGS -f worker.Dockerfile -t 0001coder/coolcrawl-worker:enhanced . || {
        echo -e "${RED}✗ worker 镜像构建失败${NC}"
        exit 1
    }
    
    # 构建 server 镜像
    echo "构建 server 镜像..."
    docker build $BUILD_ARGS -f server.Dockerfile -t 0001coder/coolcrawl-server:enhanced . || {
        echo -e "${RED}✗ server 镜像构建失败${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✓ 镜像构建完成${NC}"
}

# 验证构建结果
verify_build() {
    echo -e "${YELLOW}验证构建结果...${NC}"
    
    # 检查镜像是否存在
    if docker images | grep -q "coolcrawl-worker.*enhanced"; then
        echo -e "${GREEN}✓ worker 镜像构建成功${NC}"
    else
        echo -e "${RED}✗ worker 镜像未找到${NC}"
        exit 1
    fi
    
    if docker images | grep -q "coolcrawl-server.*enhanced"; then
        echo -e "${GREEN}✓ server 镜像构建成功${NC}"
    else
        echo -e "${RED}✗ server 镜像未找到${NC}"
        exit 1
    fi
}

# 主函数
main() {
    echo "================================================"
    echo "🔥 Firecrawl Docker 构建脚本"
    echo "================================================"
    
    # 检查是否在正确的目录
    if [ ! -f "package.json" ]; then
        echo -e "${RED}错误：请在 apps/api 目录下运行此脚本${NC}"
        exit 1
    fi
    
    # 解析命令行参数
    CLEAN_CACHE=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN_CACHE=true
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --clean    构建前清理所有缓存"
                echo "  --help     显示此帮助信息"
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    # 执行构建步骤
    check_proxy
    
    if [ "$CLEAN_CACHE" = true ]; then
        clean_cache
    fi
    
    check_network
    setup_npm_config
    build_images
    verify_build
    
    echo "================================================"
    echo -e "${GREEN}🎉 构建完成！${NC}"
    echo "================================================"
    echo "现在可以运行以下命令启动服务："
    echo "docker-compose -f docker-compose.enhanced.yaml up -d"
    echo ""
    echo "或者使用原始配置："
    echo "docker-compose up -d"
}

# 运行主函数
main "$@"
