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
