#!/bin/bash
# Firecrawl ARM64 自动化测试套件
# 基于实际验证结果的完整测试流程

set -e

echo "🧪 Firecrawl ARM64 自动化测试套件"
echo "================================="

# 测试结果统计
TESTS_PASSED=0
TESTS_FAILED=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}运行测试: $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ $test_name - 通过${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name - 失败${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# 主测试流程
main() {
    echo "开始 Firecrawl ARM64 测试套件"
    
    # 1. 容器状态测试
    run_test "容器运行状态" "docker-compose ps | grep -q 'Up'"
    
    # 2. 健康检查测试
    run_test "API 健康检查" "curl -s http://localhost:3002/test | grep -q 'Hello, world!'"
    
    # 3. Chromium 验证
    run_test "Chromium 版本检查" "docker exec api-worker-1 chromium --version --no-sandbox | grep -q 'Chromium'"
    
    # 4. 环境变量测试
    run_test "Puppeteer 环境变量" "docker exec api-worker-1 env | grep -q 'PUPPETEER_SKIP_DOWNLOAD=true'"
    
    # 5. 功能测试
    run_test "网页抓取功能" "curl -s -X POST http://localhost:3002/v0/scrape -H 'Content-Type: application/json' -d '{\"url\": \"https://example.com\"}' | grep -q '\"success\":true'"
    
    # 6. 性能测试
    run_test "API 响应时间" "timeout 5s curl -s http://localhost:3002/test > /dev/null"
    
    # 测试结果汇总
    echo ""
    echo "📊 测试结果汇总"
    echo "==============="
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    echo "总计: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "🎉 所有测试通过！"
        exit 0
    else
        echo "❌ 有测试失败，请检查日志"
        exit 1
    fi
}

# 运行主函数
main "$@"
