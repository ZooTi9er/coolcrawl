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
