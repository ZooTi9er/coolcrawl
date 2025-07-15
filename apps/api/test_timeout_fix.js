const http = require('http');

function makeRequest(endpoint, data) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify(data);
        const startTime = Date.now();
        
        const options = {
            hostname: 'localhost',
            port: 3002,
            path: endpoint,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData),
                'Authorization': 'Bearer fc-wuzhe12345'
            }
        };

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
                        success: res.statusCode === 200 && result.success
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

        req.setTimeout(60000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

async function testTimeoutFix() {
    console.log('⏱️ 测试超时处理优化');
    console.log('='.repeat(50));
    
    const testCases = [
        {
            name: "复杂网站抓取 - Hacker News",
            url: "https://news.ycombinator.com",
            expected: "改善超时处理，提升成功率"
        },
        {
            name: "技术博客抓取 - OpenAI Blog",
            url: "https://blog.openai.com",
            expected: "快速响应，验证优化效果"
        },
        {
            name: "静态网站抓取 - Example.com",
            url: "https://example.com",
            expected: "基准测试，确保现有功能正常"
        }
    ];
    
    let passedTests = 0;
    let totalTests = testCases.length;
    let results = [];
    
    for (const testCase of testCases) {
        console.log(`\n📋 测试: ${testCase.name}`);
        console.log(`URL: ${testCase.url}`);
        console.log(`期望: ${testCase.expected}`);
        
        try {
            const result = await makeRequest('/v0/scrape', {
                url: testCase.url,
                pageOptions: {
                    onlyMainContent: true
                }
            });
            
            console.log(`状态码: ${result.statusCode}`);
            console.log(`响应时间: ${result.responseTime}ms`);
            
            const testResult = {
                name: testCase.name,
                url: testCase.url,
                statusCode: result.statusCode,
                responseTime: result.responseTime,
                success: result.success
            };
            
            if (result.success) {
                console.log('✅ 抓取成功');
                console.log(`内容长度: ${result.data.data ? result.data.data.content?.length || 0 : 0} 字符`);
                
                if (result.data.data && result.data.data.metadata) {
                    console.log(`页面标题: ${result.data.data.metadata.title || 'N/A'}`);
                }
                
                testResult.contentLength = result.data.data ? result.data.data.content?.length || 0 : 0;
                testResult.title = result.data.data?.metadata?.title || 'N/A';
                
                passedTests++;
            } else {
                console.log('❌ 抓取失败');
                if (result.data.error) {
                    console.log(`错误信息: ${result.data.error}`);
                    testResult.error = result.data.error;
                }
            }
            
            results.push(testResult);
            
        } catch (error) {
            console.log('❌ 请求异常');
            console.log(`错误: ${error.message}`);
            
            results.push({
                name: testCase.name,
                url: testCase.url,
                error: error.message,
                success: false
            });
        }
        
        console.log('-'.repeat(40));
    }
    
    console.log(`\n📊 超时处理优化测试总结:`);
    console.log(`通过测试: ${passedTests}/${totalTests}`);
    console.log(`成功率: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    // 性能分析
    const successfulResults = results.filter(r => r.success);
    if (successfulResults.length > 0) {
        const avgResponseTime = successfulResults.reduce((sum, r) => sum + r.responseTime, 0) / successfulResults.length;
        const maxResponseTime = Math.max(...successfulResults.map(r => r.responseTime));
        const minResponseTime = Math.min(...successfulResults.map(r => r.responseTime));
        
        console.log(`\n📈 性能指标:`);
        console.log(`平均响应时间: ${Math.round(avgResponseTime)}ms`);
        console.log(`最快响应时间: ${minResponseTime}ms`);
        console.log(`最慢响应时间: ${maxResponseTime}ms`);
        
        // 与之前测试报告对比
        console.log(`\n📊 与原始测试对比:`);
        console.log(`原始平均响应时间: 18,700ms (包含超时)`);
        console.log(`优化后平均响应时间: ${Math.round(avgResponseTime)}ms`);
        console.log(`性能提升: ${((18700 - avgResponseTime) / 18700 * 100).toFixed(1)}%`);
    }
    
    if (passedTests === totalTests) {
        console.log('🎉 超时处理优化成功！');
    } else if (passedTests > 0) {
        console.log('⚠️  超时处理有所改善，但仍需进一步优化');
    } else {
        console.log('❌ 超时处理优化效果不明显');
    }
    
    return {
        passed: passedTests,
        total: totalTests,
        successRate: (passedTests / totalTests) * 100,
        results: results
    };
}

testTimeoutFix().catch(console.error);
