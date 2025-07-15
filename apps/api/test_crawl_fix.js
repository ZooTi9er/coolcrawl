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
                        success: res.statusCode === 200
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

        req.setTimeout(30000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        if (postData) {
            req.write(postData);
        }
        req.end();
    });
}

async function testCrawlFix() {
    console.log('🕷️ 测试爬取功能修复');
    console.log('='.repeat(50));
    
    const testCases = [
        {
            name: "v0 爬取测试",
            endpoint: "/v0/crawl",
            url: "https://example.com",
            expected: "返回 jobId"
        },
        {
            name: "v1 爬取测试",
            endpoint: "/v1/crawl", 
            url: "https://example.com",
            expected: "返回正确的数据格式"
        }
    ];
    
    let passedTests = 0;
    let totalTests = testCases.length;
    
    for (const testCase of testCases) {
        console.log(`\n📋 测试: ${testCase.name}`);
        console.log(`端点: ${testCase.endpoint}`);
        console.log(`URL: ${testCase.url}`);
        console.log(`期望: ${testCase.expected}`);
        
        try {
            const result = await makeRequest(testCase.endpoint, {
                url: testCase.url,
                crawlerOptions: {
                    limit: 5
                }
            });
            
            console.log(`状态码: ${result.statusCode}`);
            console.log(`响应时间: ${result.responseTime}ms`);
            
            if (result.success) {
                console.log('✅ 爬取请求成功');
                
                if (testCase.endpoint === "/v0/crawl") {
                    // v0 应该返回 jobId
                    if (result.data.jobId) {
                        console.log(`✅ 返回 jobId: ${result.data.jobId}`);
                        
                        // 测试状态查询
                        console.log('🔍 测试状态查询...');
                        const statusResult = await makeRequest(`/v0/crawl/status/${result.data.jobId}`, null, 'GET');
                        console.log(`状态查询结果: ${statusResult.statusCode}`);
                        if (statusResult.success) {
                            console.log(`任务状态: ${statusResult.data.status || 'unknown'}`);
                        }
                        
                        passedTests++;
                    } else {
                        console.log('❌ 未返回 jobId');
                    }
                } else if (testCase.endpoint === "/v1/crawl") {
                    // v1 应该返回结构化数据
                    if (result.data.success && result.data.data) {
                        console.log('✅ 返回正确的数据格式');
                        console.log(`数据类型: ${typeof result.data.data}`);
                        
                        if (result.data.data.id) {
                            console.log(`✅ 包含任务 ID: ${result.data.data.id}`);
                            
                            // 测试 v1 状态查询
                            console.log('🔍 测试 v1 状态查询...');
                            const statusResult = await makeRequest(`/v1/crawl/${result.data.data.id}`, null, 'GET');
                            console.log(`v1 状态查询结果: ${statusResult.statusCode}`);
                            if (statusResult.success) {
                                console.log(`任务状态: ${statusResult.data.status || 'unknown'}`);
                            }
                        }
                        
                        passedTests++;
                    } else {
                        console.log('❌ 数据格式不正确');
                        console.log('返回数据:', JSON.stringify(result.data, null, 2));
                    }
                }
                
            } else {
                console.log('❌ 爬取请求失败');
                if (result.data.error) {
                    console.log(`错误信息: ${result.data.error}`);
                }
                console.log('响应数据:', JSON.stringify(result.data, null, 2));
            }
            
        } catch (error) {
            console.log('❌ 请求异常');
            console.log(`错误: ${error.message}`);
        }
        
        console.log('-'.repeat(40));
    }
    
    console.log(`\n📊 爬取功能测试总结:`);
    console.log(`通过测试: ${passedTests}/${totalTests}`);
    console.log(`成功率: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    if (passedTests === totalTests) {
        console.log('🎉 爬取功能修复成功！');
    } else {
        console.log('⚠️  爬取功能仍需进一步修复');
    }
    
    return {
        passed: passedTests,
        total: totalTests,
        successRate: (passedTests / totalTests) * 100
    };
}

testCrawlFix().catch(console.error);
