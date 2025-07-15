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

        req.setTimeout(30000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

async function testSearchFix() {
    console.log('🔍 测试搜索功能修复');
    console.log('='.repeat(50));
    
    const testCases = [
        {
            name: "JavaScript框架搜索",
            query: "JavaScript frameworks 2024",
            expected: "返回3-5个搜索结果"
        },
        {
            name: "中文搜索测试",
            query: "人工智能发展趋势",
            expected: "正确处理中文查询"
        }
    ];
    
    let passedTests = 0;
    let totalTests = testCases.length;
    
    for (const testCase of testCases) {
        console.log(`\n📋 测试: ${testCase.name}`);
        console.log(`查询: "${testCase.query}"`);
        console.log(`期望: ${testCase.expected}`);
        
        try {
            const result = await makeRequest('/v0/search', {
                query: testCase.query,
                searchOptions: {
                    limit: 5
                }
            });
            
            console.log(`状态码: ${result.statusCode}`);
            console.log(`响应时间: ${result.responseTime}ms`);
            
            if (result.success) {
                console.log('✅ 搜索请求成功');
                console.log(`返回结果数量: ${result.data.data ? result.data.data.length : 0}`);
                
                if (result.data.data && result.data.data.length > 0) {
                    console.log('📄 搜索结果示例:');
                    const firstResult = result.data.data[0];
                    if (firstResult.metadata) {
                        console.log(`  标题: ${firstResult.metadata.title || 'N/A'}`);
                        console.log(`  URL: ${firstResult.metadata.sourceURL || 'N/A'}`);
                        console.log(`  内容长度: ${firstResult.content ? firstResult.content.length : 0} 字符`);
                    }
                }
                passedTests++;
            } else {
                console.log('❌ 搜索请求失败');
                if (result.data.error) {
                    console.log(`错误信息: ${result.data.error}`);
                }
            }
            
        } catch (error) {
            console.log('❌ 请求异常');
            console.log(`错误: ${error.message}`);
        }
        
        console.log('-'.repeat(40));
    }
    
    console.log(`\n📊 搜索功能测试总结:`);
    console.log(`通过测试: ${passedTests}/${totalTests}`);
    console.log(`成功率: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    if (passedTests === totalTests) {
        console.log('🎉 搜索功能修复成功！');
    } else {
        console.log('⚠️  搜索功能仍需进一步修复');
    }
    
    return {
        passed: passedTests,
        total: totalTests,
        successRate: (passedTests / totalTests) * 100
    };
}

testSearchFix().catch(console.error);
