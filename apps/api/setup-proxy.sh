#!/bin/bash

# 代理配置脚本
# 用于配置 Docker 和 npm 的代理设置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认代理配置
DEFAULT_PROXY_HOST="127.0.0.1"
DEFAULT_PROXY_PORT="10808"

echo "🌐 Firecrawl 代理配置脚本"
echo "================================"

# 检测代理设置
detect_proxy() {
    echo -e "${YELLOW}检测代理设置...${NC}"
    
    # 检查环境变量
    if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        echo -e "${GREEN}✓ 检测到现有代理设置${NC}"
        echo "HTTP_PROXY: ${HTTP_PROXY:-未设置}"
        echo "HTTPS_PROXY: ${HTTPS_PROXY:-未设置}"
        return 0
    fi
    
    # 检查常见代理端口
    for port in 10808 7890 8080 1080; do
        if nc -z $DEFAULT_PROXY_HOST $port 2>/dev/null; then
            echo -e "${GREEN}✓ 检测到代理服务运行在端口 $port${NC}"
            DETECTED_PROXY="http://$DEFAULT_PROXY_HOST:$port"
            return 0
        fi
    done
    
    echo -e "${YELLOW}⚠ 未检测到代理服务${NC}"
    return 1
}

# 配置代理
setup_proxy() {
    local proxy_url="$1"
    
    echo -e "${YELLOW}配置代理设置...${NC}"
    
    # 创建代理环境变量文件
    cat > .env.proxy << EOF
# 代理配置
HTTP_PROXY=$proxy_url
HTTPS_PROXY=$proxy_url
NO_PROXY=localhost,127.0.0.1,redis,docker.1ms.run,docker.m.daocloud.io,dockerproxy.com,docker.xuanyuan.me,hub.atomgit.com

# Docker 构建时使用的代理
DOCKER_BUILDKIT_HTTP_PROXY=$proxy_url
DOCKER_BUILDKIT_HTTPS_PROXY=$proxy_url
DOCKER_BUILDKIT_NO_PROXY=localhost,127.0.0.1,redis
EOF
    
    # 配置 npm 代理
    npm config set proxy $proxy_url
    npm config set https-proxy $proxy_url
    
    # 配置 pnpm 代理
    if command -v pnpm &> /dev/null; then
        pnpm config set proxy $proxy_url
        pnpm config set https-proxy $proxy_url
    fi
    
    echo -e "${GREEN}✓ 代理配置完成${NC}"
    echo "代理地址: $proxy_url"
}

# 测试代理连接
test_proxy() {
    local proxy_url="$1"
    
    echo -e "${YELLOW}测试代理连接...${NC}"
    
    # 测试 HTTP 连接
    if curl -s --proxy $proxy_url --connect-timeout 5 https://www.google.com > /dev/null; then
        echo -e "${GREEN}✓ 代理连接正常${NC}"
        return 0
    else
        echo -e "${RED}✗ 代理连接失败${NC}"
        return 1
    fi
}

# 配置 Docker 代理
setup_docker_proxy() {
    local proxy_url="$1"
    
    echo -e "${YELLOW}配置 Docker 代理...${NC}"
    
    # 创建 Docker daemon 配置目录
    sudo mkdir -p /etc/systemd/system/docker.service.d
    
    # 创建代理配置文件
    sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null << EOF
[Service]
Environment="HTTP_PROXY=$proxy_url"
Environment="HTTPS_PROXY=$proxy_url"
Environment="NO_PROXY=localhost,127.0.0.1,docker.1ms.run,docker.m.daocloud.io,dockerproxy.com"
EOF
    
    # 重新加载 systemd 配置
    sudo systemctl daemon-reload
    
    # 重启 Docker 服务
    echo "重启 Docker 服务..."
    sudo systemctl restart docker
    
    echo -e "${GREEN}✓ Docker 代理配置完成${NC}"
}

# 清除代理设置
clear_proxy() {
    echo -e "${YELLOW}清除代理设置...${NC}"
    
    # 清除环境变量文件
    rm -f .env.proxy
    
    # 清除 npm 代理
    npm config delete proxy 2>/dev/null || true
    npm config delete https-proxy 2>/dev/null || true
    
    # 清除 pnpm 代理
    if command -v pnpm &> /dev/null; then
        pnpm config delete proxy 2>/dev/null || true
        pnpm config delete https-proxy 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ 代理设置已清除${NC}"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项] [代理地址]"
    echo ""
    echo "选项:"
    echo "  --auto        自动检测并配置代理"
    echo "  --clear       清除代理设置"
    echo "  --docker      同时配置 Docker daemon 代理（需要 sudo）"
    echo "  --test        测试代理连接"
    echo "  --help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --auto                           # 自动检测代理"
    echo "  $0 http://127.0.0.1:10808          # 手动设置代理"
    echo "  $0 --docker http://127.0.0.1:10808 # 设置代理并配置 Docker"
    echo "  $0 --clear                          # 清除代理设置"
}

# 主函数
main() {
    local auto_detect=false
    local clear_proxy_flag=false
    local setup_docker_flag=false
    local test_only=false
    local proxy_url=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                auto_detect=true
                shift
                ;;
            --clear)
                clear_proxy_flag=true
                shift
                ;;
            --docker)
                setup_docker_flag=true
                shift
                ;;
            --test)
                test_only=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            http://*|https://*)
                proxy_url="$1"
                shift
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 执行相应操作
    if [ "$clear_proxy_flag" = true ]; then
        clear_proxy
        exit 0
    fi
    
    if [ "$auto_detect" = true ]; then
        if detect_proxy; then
            if [ -n "$DETECTED_PROXY" ]; then
                proxy_url="$DETECTED_PROXY"
            elif [ -n "$HTTP_PROXY" ]; then
                proxy_url="$HTTP_PROXY"
            fi
        else
            echo -e "${RED}无法自动检测代理，请手动指定代理地址${NC}"
            exit 1
        fi
    fi
    
    if [ -z "$proxy_url" ]; then
        echo -e "${RED}错误：请指定代理地址或使用 --auto 选项${NC}"
        show_help
        exit 1
    fi
    
    if [ "$test_only" = true ]; then
        test_proxy "$proxy_url"
        exit $?
    fi
    
    # 配置代理
    setup_proxy "$proxy_url"
    
    # 测试代理连接
    if test_proxy "$proxy_url"; then
        echo -e "${GREEN}✓ 代理配置成功并测试通过${NC}"
    else
        echo -e "${YELLOW}⚠ 代理配置完成，但连接测试失败${NC}"
    fi
    
    # 配置 Docker 代理（如果需要）
    if [ "$setup_docker_flag" = true ]; then
        setup_docker_proxy "$proxy_url"
    fi
    
    echo ""
    echo "代理配置完成！现在可以运行构建脚本："
    echo "source .env.proxy && ./build.sh"
}

# 运行主函数
main "$@"
