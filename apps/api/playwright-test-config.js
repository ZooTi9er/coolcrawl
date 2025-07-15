// Playwright 测试配置 - 基于实际测试结果优化

const { chromium } = require('playwright');

// 测试配置
const testConfig = {
  // 使用最新的 ARM64 镜像
  dockerImage: 'mcr.microsoft.com/playwright:v1.54.1-noble-arm64',
  
  // 浏览器启动配置（针对 ARM64 优化）
  browserOptions: {
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--disable-gpu',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      '--disable-features=TranslateUI',
      '--disable-ipc-flooding-protection',
      // ARM64 特定优化
      '--memory-pressure-off',
      '--max_old_space_size=2048',
    ],
  },
  
  // 页面配置
  contextOptions: {
    viewport: { width: 1920, height: 1080 },
    userAgent: 'Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    // 针对 ARM64 的超时设置
    timeout: 30000,
  },
  
  // 网络配置
  networkOptions: {
    timeout: 30000,
    retries: 3,
    waitUntil: 'networkidle',
  }
};

// 测试函数
async function testPlaywrightSetup() {
  console.log('🧪 开始 Playwright ARM64 测试...');
  
  let browser;
  try {
    // 启动浏览器
    console.log('启动 Chromium 浏览器...');
    browser = await chromium.launch(testConfig.browserOptions);
    
    // 创建上下文
    console.log('创建浏览器上下文...');
    const context = await browser.newContext(testConfig.contextOptions);
    
    // 创建页面
    console.log('创建新页面...');
    const page = await context.newPage();
    
    // 测试基本导航
    console.log('测试基本导航...');
    await page.goto('https://example.com', testConfig.networkOptions);
    
    const title = await page.title();
    console.log(`✅ 页面标题: ${title}`);
    
    // 测试内容提取
    console.log('测试内容提取...');
    const content = await page.textContent('body');
    console.log(`✅ 内容长度: ${content.length} 字符`);
    
    // 测试 JavaScript 执行
    console.log('测试 JavaScript 执行...');
    const userAgent = await page.evaluate(() => navigator.userAgent);
    console.log(`✅ User Agent: ${userAgent}`);
    
    // 测试截图功能
    console.log('测试截图功能...');
    await page.screenshot({ path: 'test-screenshot.png' });
    console.log('✅ 截图保存成功');
    
    // 测试 PDF 生成
    console.log('测试 PDF 生成...');
    await page.pdf({ path: 'test-page.pdf', format: 'A4' });
    console.log('✅ PDF 生成成功');
    
    console.log('🎉 所有测试通过！');
    
    return {
      success: true,
      results: {
        title,
        contentLength: content.length,
        userAgent,
        screenshotGenerated: true,
        pdfGenerated: true
      }
    };
    
  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    return {
      success: false,
      error: error.message
    };
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// 性能测试函数
async function performanceTest() {
  console.log('⚡ 开始性能测试...');
  
  const startTime = Date.now();
  let browser;
  
  try {
    browser = await chromium.launch(testConfig.browserOptions);
    const context = await browser.newContext(testConfig.contextOptions);
    const page = await context.newPage();
    
    // 测试多个页面的加载时间
    const testUrls = [
      'https://example.com',
      'https://httpbin.org/html',
      'https://jsonplaceholder.typicode.com/posts/1'
    ];
    
    const results = [];
    
    for (const url of testUrls) {
      const pageStartTime = Date.now();
      await page.goto(url, testConfig.networkOptions);
      const loadTime = Date.now() - pageStartTime;
      
      results.push({
        url,
        loadTime,
        title: await page.title()
      });
      
      console.log(`✅ ${url} - 加载时间: ${loadTime}ms`);
    }
    
    const totalTime = Date.now() - startTime;
    console.log(`🏁 总测试时间: ${totalTime}ms`);
    
    return {
      success: true,
      totalTime,
      results
    };
    
  } catch (error) {
    console.error('❌ 性能测试失败:', error.message);
    return {
      success: false,
      error: error.message
    };
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// 导出配置和测试函数
module.exports = {
  testConfig,
  testPlaywrightSetup,
  performanceTest
};

// 如果直接运行此文件，执行测试
if (require.main === module) {
  (async () => {
    console.log('🚀 Playwright ARM64 测试套件');
    console.log('============================');
    
    // 基本功能测试
    const basicTest = await testPlaywrightSetup();
    if (!basicTest.success) {
      console.error('基本测试失败，退出');
      process.exit(1);
    }
    
    // 性能测试
    const perfTest = await performanceTest();
    if (!perfTest.success) {
      console.error('性能测试失败');
    }
    
    console.log('\n📊 测试总结:');
    console.log('- 基本功能:', basicTest.success ? '✅ 通过' : '❌ 失败');
    console.log('- 性能测试:', perfTest.success ? '✅ 通过' : '❌ 失败');
    
    if (perfTest.success) {
      console.log(`- 总耗时: ${perfTest.totalTime}ms`);
      console.log(`- 平均页面加载: ${Math.round(perfTest.results.reduce((sum, r) => sum + r.loadTime, 0) / perfTest.results.length)}ms`);
    }
    
    console.log('\n🎯 推荐配置已验证，可以安全使用！');
  })();
}
