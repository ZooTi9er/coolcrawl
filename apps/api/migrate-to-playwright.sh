#!/bin/bash

# Firecrawl Puppeteer 到 Playwright 迁移脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎭 Firecrawl Puppeteer 到 Playwright 迁移脚本${NC}"
echo "================================================"

# 检查当前环境
check_environment() {
    echo -e "${YELLOW}检查当前环境...${NC}"
    
    # 检查是否在正确的目录
    if [ ! -f "package.json" ]; then
        echo -e "${RED}错误：请在 apps/api 目录下运行此脚本${NC}"
        exit 1
    fi
    
    # 检查是否有 Puppeteer 依赖
    if ! grep -q "puppeteer" package.json; then
        echo -e "${YELLOW}⚠ 未检测到 Puppeteer 依赖${NC}"
    else
        echo -e "${GREEN}✓ 检测到 Puppeteer 依赖${NC}"
    fi
    
    echo -e "${GREEN}✓ 环境检查完成${NC}"
}

# 备份当前配置
backup_current_config() {
    echo -e "${YELLOW}备份当前配置...${NC}"
    
    local backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份重要文件
    cp package.json "$backup_dir/"
    cp pnpm-lock.yaml "$backup_dir/" 2>/dev/null || true
    cp worker.Dockerfile "$backup_dir/" 2>/dev/null || true
    cp server.Dockerfile "$backup_dir/" 2>/dev/null || true
    
    # 备份 WebScraper 目录
    if [ -d "src/scraper/WebScraper" ]; then
        cp -r src/scraper/WebScraper "$backup_dir/"
    fi
    
    echo -e "${GREEN}✓ 配置已备份到 $backup_dir${NC}"
}

# 安装 Playwright 依赖
install_playwright() {
    echo -e "${YELLOW}安装 Playwright 依赖...${NC}"
    
    # 添加 Playwright 依赖
    pnpm add playwright
    pnpm add -D @playwright/test
    
    # 安装 Playwright 浏览器
    npx playwright install chromium --with-deps
    
    echo -e "${GREEN}✓ Playwright 安装完成${NC}"
}

# 更新 package.json 脚本
update_package_scripts() {
    echo -e "${YELLOW}更新 package.json 脚本...${NC}"
    
    # 创建临时的 package.json 更新脚本
    cat > update_package.js << 'EOF'
const fs = require('fs');
const path = require('path');

const packagePath = path.join(__dirname, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));

// 添加 Playwright 相关脚本
packageJson.scripts = packageJson.scripts || {};
packageJson.scripts['test:playwright'] = 'playwright test';
packageJson.scripts['test:playwright:ui'] = 'playwright test --ui';
packageJson.scripts['test:playwright:debug'] = 'playwright test --debug';

// 更新现有脚本以支持 Playwright
if (packageJson.scripts['test']) {
    packageJson.scripts['test:puppeteer'] = packageJson.scripts['test'];
    packageJson.scripts['test'] = 'playwright test';
}

fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2));
console.log('✓ package.json 脚本已更新');
EOF
    
    node update_package.js
    rm update_package.js
    
    echo -e "${GREEN}✓ package.json 更新完成${NC}"
}

# 创建 Playwright 配置文件
create_playwright_config() {
    echo -e "${YELLOW}创建 Playwright 配置文件...${NC}"
    
    cat > playwright.config.ts << 'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './src/__tests__/playwright',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3002',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: 'pnpm run start',
    url: 'http://localhost:3002',
    reuseExistingServer: !process.env.CI,
  },
});
EOF
    
    echo -e "${GREEN}✓ Playwright 配置文件已创建${NC}"
}

# 创建示例测试文件
create_sample_tests() {
    echo -e "${YELLOW}创建示例测试文件...${NC}"
    
    mkdir -p src/__tests__/playwright
    
    cat > src/__tests__/playwright/scraper.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';
import { playwrightAdapter } from '../../scraper/PlaywrightAdapter';

test.describe('Playwright Scraper Tests', () => {
  test.afterAll(async () => {
    await playwrightAdapter.close();
  });

  test('should scrape a simple webpage', async () => {
    const result = await playwrightAdapter.scrapePage('https://example.com');
    
    expect(result).toBeDefined();
    expect(result.metadata.title).toBeTruthy();
    expect(result.content).toBeTruthy();
    expect(result.markdown).toBeTruthy();
    expect(result.metadata.sourceURL).toBe('https://example.com');
  });

  test('should handle page with main content', async () => {
    const result = await playwrightAdapter.scrapePage('https://example.com', {
      onlyMainContent: true
    });
    
    expect(result).toBeDefined();
    expect(result.content.length).toBeGreaterThan(0);
  });

  test('should handle page load timeout', async () => {
    const result = await playwrightAdapter.scrapePage('https://httpbin.org/delay/2', {
      waitFor: 1000
    });
    
    expect(result).toBeDefined();
  });
});
EOF
    
    echo -e "${GREEN}✓ 示例测试文件已创建${NC}"
}

# 更新 Dockerfile
update_dockerfiles() {
    echo -e "${YELLOW}更新 Dockerfile...${NC}"
    
    # 创建新的 Dockerfile 版本
    if [ -f "worker.Dockerfile" ]; then
        cp worker.Dockerfile worker.Dockerfile.puppeteer.bak
        cp worker.playwright-official.Dockerfile worker.Dockerfile
        echo -e "${GREEN}✓ worker.Dockerfile 已更新为 Playwright 版本${NC}"
    fi
    
    if [ -f "server.Dockerfile" ]; then
        cp server.Dockerfile server.Dockerfile.puppeteer.bak
        # 为 server.Dockerfile 创建类似的更新
        echo -e "${GREEN}✓ server.Dockerfile 备份已创建${NC}"
    fi
}

# 创建迁移验证脚本
create_verification_script() {
    echo -e "${YELLOW}创建迁移验证脚本...${NC}"
    
    cat > verify-migration.js << 'EOF'
const { playwrightAdapter } = require('./dist/src/scraper/PlaywrightAdapter');

async function verifyMigration() {
  console.log('🔍 验证 Playwright 迁移...');
  
  try {
    // 测试基本功能
    const result = await playwrightAdapter.scrapePage('https://example.com');
    
    console.log('✓ 基本抓取功能正常');
    console.log(`  - 标题: ${result.metadata.title}`);
    console.log(`  - 内容长度: ${result.content.length} 字符`);
    console.log(`  - Markdown 长度: ${result.markdown.length} 字符`);
    
    await playwrightAdapter.close();
    console.log('✓ 浏览器正常关闭');
    
    console.log('\n🎉 Playwright 迁移验证成功！');
    
  } catch (error) {
    console.error('❌ 迁移验证失败:', error.message);
    process.exit(1);
  }
}

verifyMigration();
EOF
    
    echo -e "${GREEN}✓ 迁移验证脚本已创建${NC}"
}

# 显示迁移后的使用指南
show_usage_guide() {
    echo ""
    echo -e "${BLUE}📖 迁移完成！使用指南：${NC}"
    echo "================================"
    echo ""
    echo -e "${YELLOW}1. 构建项目：${NC}"
    echo "   pnpm run build"
    echo ""
    echo -e "${YELLOW}2. 验证迁移：${NC}"
    echo "   node verify-migration.js"
    echo ""
    echo -e "${YELLOW}3. 运行 Playwright 测试：${NC}"
    echo "   pnpm run test:playwright"
    echo ""
    echo -e "${YELLOW}4. 使用新的 Docker 构建：${NC}"
    echo "   docker build -f worker.Dockerfile -t firecrawl-worker:playwright ."
    echo ""
    echo -e "${YELLOW}5. 在代码中使用 Playwright：${NC}"
    echo "   import { playwrightAdapter } from './scraper/PlaywrightAdapter';"
    echo "   const result = await playwrightAdapter.scrapePage(url);"
    echo ""
    echo -e "${GREEN}🎭 Playwright 迁移完成！${NC}"
}

# 主函数
main() {
    local skip_backup=false
    local skip_install=false
    local verify_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --skip-install)
                skip_install=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --skip-backup    跳过配置备份"
                echo "  --skip-install   跳过 Playwright 安装"
                echo "  --verify-only    仅运行验证"
                echo "  --help           显示此帮助信息"
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    # 执行迁移步骤
    check_environment
    
    if [ "$verify_only" = true ]; then
        create_verification_script
        echo -e "${YELLOW}运行验证脚本...${NC}"
        pnpm run build && node verify-migration.js
        return
    fi
    
    if [ "$skip_backup" = false ]; then
        backup_current_config
    fi
    
    if [ "$skip_install" = false ]; then
        install_playwright
    fi
    
    update_package_scripts
    create_playwright_config
    create_sample_tests
    update_dockerfiles
    create_verification_script
    
    show_usage_guide
}

# 运行主函数
main "$@"
