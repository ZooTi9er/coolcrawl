const http = require('http');
const fs = require('fs');

// 测试配置
const API_BASE = 'http://localhost:3002';
const TEST_RESULTS = [];

// 工具函数：发送 HTTP 请求
function makeRequest(endpoint, data, timeout = 30000) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify(data);
        
        const options = {
            hostname: 'localhost',
            port: 3002,
            path: endpoint,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            }
        };

        const req = http.request(options, (res) => {
            let responseData = '';
            
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            
            res.on('end', () => {
                try {
                    const result = JSON.parse(responseData);
                    resolve({ 
                        statusCode: res.statusCode, 
                        data: result,
                        responseTime: Date.now() - startTime
                    });
                } catch (e) {
                    resolve({ 
                        statusCode: res.statusCode, 
                        data: responseData,
                        responseTime: Date.now() - startTime
                    });
                }
            });
        });

        const startTime = Date.now();
        
        req.on('error', (err) => {
            reject(err);
        });

        req.setTimeout(timeout, () => {
            req.destroy();
            reject(new Error(`请求超时 (${timeout}ms)`));
        });

        req.write(postData);
        req.end();
    });
}

// 测试用例定义
const TEST_CASES = {
    scrape: [
        {
            name: "静态网站抓取",
            url: "https://example.com",
            expected: "success"
        },
        {
            name: "新闻网站抓取",
            url: "https://news.ycombinator.com",
            expected: "success"
        },
        {
            name: "技术博客抓取",
            url: "https://blog.openai.com",
            expected: "success"
        },
        {
            name: "无效URL测试",
            url: "https://nonexistent-domain-12345.com",
            expected: "failure"
        },
        {
            name: "PDF文档抓取",
            url: "https://arxiv.org/pdf/2301.00001.pdf",
            expected: "success"
        }
    ],
    crawl: [
        {
            name: "小型网站爬取",
            url: "https://example.com",
            limit: 5,
            expected: "success"
        },
        {
            name: "技术文档爬取",
            url: "https://docs.python.org",
            limit: 3,
            expected: "success"
        }
    ],
    search: [
        {
            name: "技术搜索",
            query: "JavaScript frameworks 2024",
            limit: 3,
            expected: "success"
        },
        {
            name: "中文搜索",
            query: "人工智能发展趋势",
            limit: 3,
            expected: "success"
        }
    ]
};

// 执行单个测试
async function runTest(testType, testCase) {
    const testStart = Date.now();
    console.log(`\n🧪 执行测试: ${testCase.name}`);
    
    try {
        let response;
        let endpoint;
        let requestData;
        
        switch (testType) {
            case 'scrape':
                endpoint = '/v0/scrape';
                requestData = { url: testCase.url };
                break;
            case 'crawl':
                endpoint = '/v0/crawl';
                requestData = { 
                    url: testCase.url,
                    limit: testCase.limit || 5
                };
                break;
            case 'search':
                endpoint = '/v0/search';
                requestData = { 
                    query: testCase.query,
                    limit: testCase.limit || 5,
                    fetchPageContent: false
                };
                break;
        }
        
        response = await makeRequest(endpoint, requestData, 45000);
        
        const testResult = {
            testType,
            testName: testCase.name,
            url: testCase.url || testCase.query,
            statusCode: response.statusCode,
            responseTime: response.responseTime,
            success: response.statusCode === 200 && response.data.success,
            dataSize: JSON.stringify(response.data).length,
            error: response.data.error || null,
            timestamp: new Date().toISOString()
        };
        
        // 分析响应数据
        if (testResult.success && response.data.data) {
            const data = response.data.data;
            testResult.contentLength = data.content ? data.content.length : 0;
            testResult.hasMetadata = !!data.metadata;
            testResult.title = data.metadata ? data.metadata.title : null;
            
            if (testType === 'crawl' && Array.isArray(data)) {
                testResult.pagesCount = data.length;
            }
            
            if (testType === 'search' && Array.isArray(data)) {
                testResult.resultsCount = data.length;
            }
        }
        
        TEST_RESULTS.push(testResult);
        
        // 输出测试结果
        if (testResult.success) {
            console.log(`✅ 测试通过 - 响应时间: ${testResult.responseTime}ms`);
            if (testResult.contentLength) {
                console.log(`   内容长度: ${testResult.contentLength} 字符`);
            }
            if (testResult.title) {
                console.log(`   页面标题: ${testResult.title}`);
            }
            if (testResult.pagesCount) {
                console.log(`   爬取页面数: ${testResult.pagesCount}`);
            }
            if (testResult.resultsCount) {
                console.log(`   搜索结果数: ${testResult.resultsCount}`);
            }
        } else {
            console.log(`❌ 测试失败 - 状态码: ${testResult.statusCode}`);
            if (testResult.error) {
                console.log(`   错误信息: ${testResult.error}`);
            }
        }
        
    } catch (error) {
        console.log(`❌ 测试异常: ${error.message}`);
        TEST_RESULTS.push({
            testType,
            testName: testCase.name,
            url: testCase.url || testCase.query,
            success: false,
            error: error.message,
            responseTime: Date.now() - testStart,
            timestamp: new Date().toISOString()
        });
    }
}

// 主测试函数
async function runAllTests() {
    console.log('🚀 开始 Firecrawl 全面功能测试');
    console.log('='.repeat(60));
    
    // 测试网页抓取功能
    console.log('\n📄 测试网页抓取功能 (/v0/scrape)');
    console.log('-'.repeat(40));
    for (const testCase of TEST_CASES.scrape) {
        await runTest('scrape', testCase);
        await new Promise(resolve => setTimeout(resolve, 2000)); // 延迟避免请求过快
    }
    
    // 测试网页爬取功能
    console.log('\n🕷️  测试网页爬取功能 (/v0/crawl)');
    console.log('-'.repeat(40));
    for (const testCase of TEST_CASES.crawl) {
        await runTest('crawl', testCase);
        await new Promise(resolve => setTimeout(resolve, 3000));
    }
    
    // 测试搜索功能
    console.log('\n🔍 测试搜索功能 (/v0/search)');
    console.log('-'.repeat(40));
    for (const testCase of TEST_CASES.search) {
        await runTest('search', testCase);
        await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    // 生成测试报告
    generateReport();
}

// 生成测试报告
function generateReport() {
    console.log('\n📊 测试报告生成中...');
    console.log('='.repeat(60));
    
    const totalTests = TEST_RESULTS.length;
    const successfulTests = TEST_RESULTS.filter(r => r.success).length;
    const failedTests = totalTests - successfulTests;
    const successRate = ((successfulTests / totalTests) * 100).toFixed(1);
    
    // 按测试类型分组统计
    const statsByType = {};
    TEST_RESULTS.forEach(result => {
        if (!statsByType[result.testType]) {
            statsByType[result.testType] = { total: 0, success: 0, avgResponseTime: 0 };
        }
        statsByType[result.testType].total++;
        if (result.success) {
            statsByType[result.testType].success++;
        }
        statsByType[result.testType].avgResponseTime += result.responseTime || 0;
    });
    
    // 计算平均响应时间
    Object.keys(statsByType).forEach(type => {
        statsByType[type].avgResponseTime = Math.round(
            statsByType[type].avgResponseTime / statsByType[type].total
        );
        statsByType[type].successRate = (
            (statsByType[type].success / statsByType[type].total) * 100
        ).toFixed(1);
    });
    
    // 输出报告
    console.log('\n📈 总体测试结果:');
    console.log(`   总测试数: ${totalTests}`);
    console.log(`   成功测试: ${successfulTests}`);
    console.log(`   失败测试: ${failedTests}`);
    console.log(`   成功率: ${successRate}%`);
    
    console.log('\n📊 分类测试结果:');
    Object.entries(statsByType).forEach(([type, stats]) => {
        console.log(`   ${type.toUpperCase()}:`);
        console.log(`     成功率: ${stats.successRate}% (${stats.success}/${stats.total})`);
        console.log(`     平均响应时间: ${stats.avgResponseTime}ms`);
    });
    
    // 保存详细报告到文件
    const reportData = {
        summary: {
            totalTests,
            successfulTests,
            failedTests,
            successRate: parseFloat(successRate),
            timestamp: new Date().toISOString()
        },
        statsByType,
        detailedResults: TEST_RESULTS
    };
    
    fs.writeFileSync('test_report.json', JSON.stringify(reportData, null, 2));
    console.log('\n💾 详细测试报告已保存到: test_report.json');
    
    // 输出失败的测试
    const failedTestResults = TEST_RESULTS.filter(r => !r.success);
    if (failedTestResults.length > 0) {
        console.log('\n❌ 失败的测试:');
        failedTestResults.forEach(result => {
            console.log(`   - ${result.testName}: ${result.error || '未知错误'}`);
        });
    }
    
    console.log('\n🎉 测试完成!');
}

// 启动测试
runAllTests().catch(console.error);
