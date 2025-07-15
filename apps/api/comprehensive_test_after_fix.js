const http = require('http');

function makeRequest(endpoint, data, method = 'POST') {
    return new Promise((resolve, reject) => {
        const postData = method === 'POST' ? JSON.stringify(data) : null;
        const startTime = Date.now();
        
        const options = {
            hostname: 'localhost',
            port: 3002,
            path: endpoint,
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer fc-wuzhe12345'
            }
        };

        if (postData) {
            options.headers['Content-Length'] = Buffer.byteLength(postData);
        }

        const req = http.request(options, (res) => {
            let responseData = '';
            
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            
            res.on('end', () => {
                const responseTime = Date.now() - startTime;
                try {
                    const result = JSON.parse(responseData);
                    resolve({ 
                        statusCode: res.statusCode, 
                        data: result,
                        responseTime,
                        success: res.statusCode === 200 && (result.success !== false)
                    });
                } catch (e) {
                    resolve({ 
                        statusCode: res.statusCode, 
                        data: responseData,
                        responseTime,
                        success: false
                    });
                }
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        req.setTimeout(45000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        if (postData) {
            req.write(postData);
        }
        req.end();
    });
}

async function comprehensiveTestAfterFix() {
    console.log('🔧 Firecrawl 修复后综合功能测试');
    console.log('='.repeat(60));
    
    const testSuites = [
        {
            name: "网页抓取功能 (/v0/scrape)",
            tests: [
                { url: "https://example.com", endpoint: "/v0/scrape" },
                { url: "https://blog.openai.com", endpoint: "/v0/scrape" }
            ]
        },
        {
            name: "搜索功能 (/v0/search)",
            tests: [
                { query: "JavaScript frameworks 2024", endpoint: "/v0/search" },
                { query: "人工智能发展", endpoint: "/v0/search" }
            ]
        },
        {
            name: "爬取功能 (/v0/crawl & /v1/crawl)",
            tests: [
                { url: "https://example.com", endpoint: "/v0/crawl" },
                { url: "https://example.com", endpoint: "/v1/crawl" }
            ]
        }
    ];
    
    let totalTests = 0;
    let passedTests = 0;
    let results = [];
    
    for (const suite of testSuites) {
        console.log(`\n🧪 ${suite.name}`);
        console.log('='.repeat(40));
        
        let suiteResults = [];
        
        for (const test of suite.tests) {
            totalTests++;
            console.log(`\n📋 测试: ${test.endpoint}`);
            
            if (test.url) {
                console.log(`URL: ${test.url}`);
            }
            if (test.query) {
                console.log(`查询: ${test.query}`);
            }
            
            try {
                let requestData = {};
                if (test.url) requestData.url = test.url;
                if (test.query) requestData.query = test.query;
                
                const result = await makeRequest(test.endpoint, requestData);
                
                console.log(`状态码: ${result.statusCode}`);
                console.log(`响应时间: ${result.responseTime}ms`);
                
                const testResult = {
                    endpoint: test.endpoint,
                    url: test.url,
                    query: test.query,
                    statusCode: result.statusCode,
                    responseTime: result.responseTime,
                    success: result.success
                };
                
                if (result.success) {
                    console.log('✅ 测试通过');
                    
                    // 分析返回数据
                    if (test.endpoint.includes('scrape')) {
                        const contentLength = result.data.data?.content?.length || 0;
                        console.log(`内容长度: ${contentLength} 字符`);
                        testResult.contentLength = contentLength;
                    } else if (test.endpoint.includes('search')) {
                        const resultCount = result.data.data?.length || 0;
                        console.log(`搜索结果数: ${resultCount}`);
                        testResult.resultCount = resultCount;
                    } else if (test.endpoint.includes('crawl')) {
                        if (result.data.jobId) {
                            console.log(`任务ID: ${result.data.jobId}`);
                            testResult.jobId = result.data.jobId;
                        } else if (result.data.data?.id) {
                            console.log(`任务ID: ${result.data.data.id}`);
                            testResult.jobId = result.data.data.id;
                        }
                    }
                    
                    passedTests++;
                } else {
                    console.log('❌ 测试失败');
                    if (result.data.error) {
                        console.log(`错误: ${result.data.error}`);
                        testResult.error = result.data.error;
                    }
                }
                
                suiteResults.push(testResult);
                
            } catch (error) {
                console.log('❌ 请求异常');
                console.log(`错误: ${error.message}`);
                
                suiteResults.push({
                    endpoint: test.endpoint,
                    url: test.url,
                    query: test.query,
                    error: error.message,
                    success: false
                });
            }
        }
        
        results.push({
            suiteName: suite.name,
            results: suiteResults
        });
    }
    
    console.log('\n📊 修复后综合测试总结');
    console.log('='.repeat(60));
    console.log(`总测试数: ${totalTests}`);
    console.log(`通过测试: ${passedTests}`);
    console.log(`失败测试: ${totalTests - passedTests}`);
    console.log(`总体成功率: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    // 按功能分析
    console.log('\n📈 分功能成功率:');
    for (const suite of results) {
        const suitePassed = suite.results.filter(r => r.success).length;
        const suiteTotal = suite.results.length;
        const suiteRate = ((suitePassed / suiteTotal) * 100).toFixed(1);
        console.log(`${suite.suiteName}: ${suiteRate}% (${suitePassed}/${suiteTotal})`);
    }
    
    // 性能分析
    const allResults = results.flatMap(s => s.results).filter(r => r.success && r.responseTime);
    if (allResults.length > 0) {
        const avgResponseTime = allResults.reduce((sum, r) => sum + r.responseTime, 0) / allResults.length;
        console.log(`\n⚡ 平均响应时间: ${Math.round(avgResponseTime)}ms`);
    }
    
    // 与原始测试报告对比
    console.log('\n📊 与原始测试报告对比:');
    console.log(`原始总体成功率: 33.3%`);
    console.log(`修复后成功率: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    console.log(`改善幅度: +${(((passedTests / totalTests) * 100) - 33.3).toFixed(1)}%`);
    
    console.log('\n原始分功能成功率:');
    console.log('- 网页抓取: 60.0%');
    console.log('- 网页爬取: 0.0%');
    console.log('- 搜索功能: 0.0%');
    
    if (passedTests / totalTests >= 0.8) {
        console.log('\n🎉 修复效果显著！系统功能大幅改善');
    } else if (passedTests / totalTests >= 0.6) {
        console.log('\n✅ 修复效果良好，主要问题已解决');
    } else {
        console.log('\n⚠️  修复有一定效果，但仍需进一步优化');
    }
    
    return {
        totalTests,
        passedTests,
        successRate: (passedTests / totalTests) * 100,
        results
    };
}

comprehensiveTestAfterFix().catch(console.error);
