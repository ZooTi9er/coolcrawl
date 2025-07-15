#!/bin/bash

# 中国网络环境 Docker 构建优化脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🇨🇳 中国网络环境 Docker 构建优化${NC}"
echo "================================"

# 检测网络环境
detect_network_environment() {
    echo -e "${YELLOW}检测网络环境...${NC}"
    
    # 测试各种镜像源的连通性
    local sources=(
        "mirrors.tuna.tsinghua.edu.cn"
        "mirrors.ustc.edu.cn"
        "mirrors.aliyun.com"
        "mirrors.163.com"
        "registry.npmmirror.com"
    )
    
    local working_sources=()
    
    for source in "${sources[@]}"; do
        if curl -s --connect-timeout 5 "https://$source" > /dev/null 2>&1; then
            working_sources+=("$source")
            echo -e "${GREEN}✓ $source 连接正常${NC}"
        else
            echo -e "${RED}✗ $source 连接失败${NC}"
        fi
    done
    
    if [ ${#working_sources[@]} -eq 0 ]; then
        echo -e "${RED}⚠ 所有镜像源连接失败，可能需要配置代理${NC}"
        return 1
    else
        echo -e "${GREEN}✓ 检测到 ${#working_sources[@]} 个可用镜像源${NC}"
        return 0
    fi
}

# 配置 Debian 镜像源
configure_debian_sources() {
    echo -e "${YELLOW}配置 Debian 镜像源...${NC}"
    
    cat > sources.list.china << 'EOF'
# 清华大学镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware

# 中科大镜像源（备用）
deb https://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware

# 阿里云镜像源（备用）
deb https://mirrors.aliyun.com/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
    
    echo -e "${GREEN}✓ Debian 镜像源配置已创建${NC}"
}

# 配置 npm 镜像源
configure_npm_sources() {
    echo -e "${YELLOW}配置 npm 镜像源...${NC}"
    
    cat > .npmrc.china << 'EOF'
# 淘宝镜像源
registry=https://registry.npmmirror.com/

# 二进制包镜像源
puppeteer_download_host=https://npmmirror.com/mirrors
chromedriver_cdnurl=https://npmmirror.com/mirrors/chromedriver
electron_mirror=https://npmmirror.com/mirrors/electron/
sass_binary_site=https://npmmirror.com/mirrors/node-sass/
phantomjs_cdnurl=https://npmmirror.com/mirrors/phantomjs/
python_mirror=https://npmmirror.com/mirrors/python/

# 网络配置
fetch-retries=3
fetch-retry-factor=2
fetch-retry-mintimeout=10000
fetch-retry-maxtimeout=60000
fetch-timeout=60000

# 代理配置（如果需要）
# proxy=http://127.0.0.1:10808
# https-proxy=http://127.0.0.1:10808
EOF
    
    echo -e "${GREEN}✓ npm 镜像源配置已创建${NC}"
}

# 创建优化的 Dockerfile
create_optimized_dockerfile() {
    echo -e "${YELLOW}创建优化的 Dockerfile...${NC}"
    
    cat > worker.china.Dockerfile << 'EOF'
FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
LABEL fly_launch_runtime="Node.js"

# 配置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 配置中国镜像源
COPY sources.list.china /etc/apt/sources.list

# 配置 apt 优化设置
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::https::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::ftp::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'APT::Install-Suggests "false";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Dpkg::Options "--force-confdef";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Dpkg::Options "--force-confold";' >> /etc/apt/apt.conf.d/80-retries

# 配置 npm 镜像源
COPY .npmrc.china /root/.npmrc
RUN npm config set registry https://registry.npmmirror.com/ && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-factor 2 && \
    npm config set fetch-retry-mintimeout 10000 && \
    npm config set fetch-retry-maxtimeout 60000 && \
    npm config set fetch-timeout 60000

RUN corepack enable

WORKDIR /app
COPY package.json pnpm-lock.yaml .npmrc* ./

FROM base AS prod-deps
RUN pnpm config set store-dir /tmp/pnpm-store && \
    pnpm config set registry https://registry.npmmirror.com/ && \
    pnpm install --prod --frozen-lockfile --no-optional && \
    rm -rf /tmp/pnpm-store

FROM base AS build
COPY . .
RUN pnpm config set store-dir /tmp/pnpm-store && \
    pnpm config set registry https://registry.npmmirror.com/ && \
    pnpm install --frozen-lockfile --no-optional && \
    pnpm run build && \
    rm -rf /tmp/pnpm-store

FROM base

# 更新包列表并安装基础工具
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        curl \
        wget \
        gnupg \
        ca-certificates \
        fonts-liberation \
        fonts-noto-cjk \
        fonts-wqy-zenhei \
        fonts-wqy-microhei && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# 尝试多种方式安装 Chromium
RUN (apt-get update -qq && \
     apt-get install --no-install-recommends -y chromium chromium-sandbox && \
     rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*) || \
    (echo "Chromium 安装失败，尝试使用 Playwright..." && \
     pnpm add playwright && \
     npx playwright install chromium --with-deps)

COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app /app

EXPOSE 8080

# 配置浏览器路径
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium"
ENV PLAYWRIGHT_BROWSERS_PATH="/ms-playwright"

CMD [ "pnpm", "run", "worker:production" ]
EOF
    
    echo -e "${GREEN}✓ 优化的 Dockerfile 已创建${NC}"
}

# 创建 Docker Compose 优化配置
create_optimized_compose() {
    echo -e "${YELLOW}创建优化的 Docker Compose 配置...${NC}"
    
    cat > docker-compose.china.yaml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:latest
    restart: always
    volumes:
      - redis_data:/data
    # 使用中国镜像源
    # image: registry.cn-hangzhou.aliyuncs.com/library/redis:latest
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  worker:
    build:
      context: .
      dockerfile: worker.china.Dockerfile
      args:
        - HTTP_PROXY=${HTTP_PROXY:-}
        - HTTPS_PROXY=${HTTPS_PROXY:-}
        - NO_PROXY=${NO_PROXY:-}
    image: 0001coder/coolcrawl-worker:china
    pull_policy: never
    environment:
      - REDIS_URL=redis://redis:6379
      - USE_DB_AUTHENTICATION=false
      - NODE_ENV=production
      - TZ=Asia/Shanghai
      # 网络配置
      - HTTP_PROXY=${HTTP_PROXY:-}
      - HTTPS_PROXY=${HTTPS_PROXY:-}
      - NO_PROXY=localhost,127.0.0.1,redis,${NO_PROXY:-}
    restart: always
    depends_on:
      redis:
        condition: service_healthy
    # DNS 配置
    dns:
      - 223.5.5.5  # 阿里 DNS
      - 114.114.114.114  # 114 DNS
      - 8.8.8.8  # Google DNS（备用）
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M

  server:
    build:
      context: .
      dockerfile: server.china.Dockerfile
      args:
        - HTTP_PROXY=${HTTP_PROXY:-}
        - HTTPS_PROXY=${HTTPS_PROXY:-}
        - NO_PROXY=${NO_PROXY:-}
    image: 0001coder/coolcrawl-server:china
    pull_policy: never
    environment:
      - REDIS_URL=redis://redis:6379
      - USE_DB_AUTHENTICATION=false
      - HOST=0.0.0.0
      - NODE_ENV=production
      - TZ=Asia/Shanghai
      - HTTP_PROXY=${HTTP_PROXY:-}
      - HTTPS_PROXY=${HTTPS_PROXY:-}
      - NO_PROXY=localhost,127.0.0.1,redis,${NO_PROXY:-}
    ports:
      - "3002:3002"
    restart: always
    depends_on:
      redis:
        condition: service_healthy
    dns:
      - 223.5.5.5
      - 114.114.114.114
      - 8.8.8.8
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3002/test"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M

volumes:
  redis_data:
    driver: local
EOF
    
    echo -e "${GREEN}✓ 优化的 Docker Compose 配置已创建${NC}"
}

# 创建构建脚本
create_build_script() {
    echo -e "${YELLOW}创建中国环境构建脚本...${NC}"
    
    cat > build-china.sh << 'EOF'
#!/bin/bash

# 中国环境 Docker 构建脚本

set -e

echo "🇨🇳 开始中国环境 Docker 构建..."

# 检查代理设置
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    echo "✓ 检测到代理设置"
    echo "HTTP_PROXY: ${HTTP_PROXY:-未设置}"
    echo "HTTPS_PROXY: ${HTTPS_PROXY:-未设置}"
fi

# 清理缓存
echo "清理 Docker 缓存..."
docker builder prune -f || true

# 构建镜像
echo "构建 worker 镜像..."
docker build -f worker.china.Dockerfile -t 0001coder/coolcrawl-worker:china . || {
    echo "❌ worker 镜像构建失败"
    exit 1
}

echo "构建 server 镜像..."
cp worker.china.Dockerfile server.china.Dockerfile
sed -i 's/worker:production/start:production/g' server.china.Dockerfile
sed -i 's/8080/3002/g' server.china.Dockerfile
docker build -f server.china.Dockerfile -t 0001coder/coolcrawl-server:china . || {
    echo "❌ server 镜像构建失败"
    exit 1
}

echo "🎉 构建完成！"
echo ""
echo "启动服务："
echo "docker-compose -f docker-compose.china.yaml up -d"
EOF
    
    chmod +x build-china.sh
    echo -e "${GREEN}✓ 构建脚本已创建${NC}"
}

# 创建网络测试脚本
create_network_test() {
    echo -e "${YELLOW}创建网络测试脚本...${NC}"
    
    cat > test-network.sh << 'EOF'
#!/bin/bash

# 网络连接测试脚本

echo "🌐 测试网络连接..."

# 测试基本网络连接
test_connection() {
    local url="$1"
    local name="$2"
    
    if curl -s --connect-timeout 5 "$url" > /dev/null; then
        echo "✓ $name 连接正常"
        return 0
    else
        echo "✗ $name 连接失败"
        return 1
    fi
}

# 测试各种服务
echo "测试基础网络..."
test_connection "https://www.baidu.com" "百度"
test_connection "https://www.google.com" "Google"

echo ""
echo "测试镜像源..."
test_connection "https://registry.npmmirror.com" "npm 淘宝镜像"
test_connection "https://mirrors.tuna.tsinghua.edu.cn" "清华镜像"
test_connection "https://mirrors.ustc.edu.cn" "中科大镜像"
test_connection "https://mirrors.aliyun.com" "阿里云镜像"

echo ""
echo "测试 Docker 镜像源..."
test_connection "https://docker.1ms.run" "Docker 镜像源 1"
test_connection "https://docker.m.daocloud.io" "Docker 镜像源 2"
test_connection "https://dockerproxy.com" "Docker 镜像源 3"

echo ""
echo "测试完成！"
EOF
    
    chmod +x test-network.sh
    echo -e "${GREEN}✓ 网络测试脚本已创建${NC}"
}

# 显示使用指南
show_usage_guide() {
    echo ""
    echo -e "${BLUE}📖 中国网络环境优化完成！${NC}"
    echo "================================"
    echo ""
    echo -e "${YELLOW}1. 测试网络连接：${NC}"
    echo "   ./test-network.sh"
    echo ""
    echo -e "${YELLOW}2. 构建优化镜像：${NC}"
    echo "   ./build-china.sh"
    echo ""
    echo -e "${YELLOW}3. 启动服务：${NC}"
    echo "   docker-compose -f docker-compose.china.yaml up -d"
    echo ""
    echo -e "${YELLOW}4. 如果需要代理，设置环境变量：${NC}"
    echo "   export HTTP_PROXY=http://127.0.0.1:10808"
    echo "   export HTTPS_PROXY=http://127.0.0.1:10808"
    echo ""
    echo -e "${YELLOW}5. 监控构建过程：${NC}"
    echo "   docker-compose -f docker-compose.china.yaml logs -f"
    echo ""
    echo -e "${GREEN}🇨🇳 中国网络环境优化完成！${NC}"
}

# 主函数
main() {
    local test_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test-only)
                test_only=true
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --test-only    仅运行网络测试"
                echo "  --help         显示此帮助信息"
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    if [ "$test_only" = true ]; then
        detect_network_environment
        create_network_test
        ./test-network.sh
        return
    fi
    
    # 执行优化步骤
    detect_network_environment
    configure_debian_sources
    configure_npm_sources
    create_optimized_dockerfile
    create_optimized_compose
    create_build_script
    create_network_test
    
    show_usage_guide
}

# 运行主函数
main "$@"
