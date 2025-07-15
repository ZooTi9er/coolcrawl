const http = require('http');

function makeRequest(endpoint, data, timeout = 10000) {
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
                    resolve({ statusCode: res.statusCode, data: result });
                } catch (e) {
                    resolve({ statusCode: res.statusCode, data: responseData });
                }
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        req.setTimeout(timeout, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

const EDGE_CASES = [
    {
        name: "空URL测试",
        endpoint: "/v0/scrape",
        data: { url: "" },
        expectedStatus: 400
    },
    {
        name: "无效JSON格式",
        endpoint: "/v0/scrape",
        data: "invalid json",
        expectedStatus: 400
    },
    {
        name: "缺少必需参数",
        endpoint: "/v0/scrape",
        data: {},
        expectedStatus: 400
    },
    {
        name: "超长URL测试",
        endpoint: "/v0/scrape",
        data: { url: "https://example.com/" + "a".repeat(2000) },
        expectedStatus: [400, 500]
    },
    {
        name: "特殊字符URL",
        endpoint: "/v0/scrape",
        data: { url: "https://example.com/测试?param=值&other=特殊字符" },
        expectedStatus: [200, 400, 500]
    },
    {
        name: "不存在的端点",
        endpoint: "/v0/nonexistent",
        data: { url: "https://example.com" },
        expectedStatus: 404
    },
    {
        name: "HTTP方法错误",
        endpoint: "/v0/scrape",
        method: "GET",
        data: null,
        expectedStatus: [404, 405]
    }
];

async function testEdgeCase(testCase) {
    console.log(`\n🧪 测试: ${testCase.name}`);
    
    try {
        let response;
        
        if (testCase.method === "GET") {
            // GET 请求测试
            response = await new Promise((resolve, reject) => {
                const options = {
                    hostname: 'localhost',
                    port: 3002,
                    path: testCase.endpoint,
                    method: 'GET'
                };

                const req = http.request(options, (res) => {
                    let data = '';
                    res.on('data', chunk => data += chunk);
                    res.on('end', () => {
                        resolve({ statusCode: res.statusCode, data });
                    });
                });

                req.on('error', reject);
                req.setTimeout(5000, () => {
                    req.destroy();
                    reject(new Error('请求超时'));
                });
                req.end();
            });
        } else {
            response = await makeRequest(testCase.endpoint, testCase.data, 5000);
        }
        
        const expectedStatuses = Array.isArray(testCase.expectedStatus) 
            ? testCase.expectedStatus 
            : [testCase.expectedStatus];
        
        const isExpectedStatus = expectedStatuses.includes(response.statusCode);
        
        if (isExpectedStatus) {
            console.log(`✅ 通过 - 状态码: ${response.statusCode} (符合预期)`);
        } else {
            console.log(`❌ 失败 - 状态码: ${response.statusCode} (预期: ${expectedStatuses.join(' 或 ')})`);
        }
        
        // 检查错误响应格式
        if (response.statusCode >= 400 && typeof response.data === 'object' && response.data.error) {
            console.log(`   错误信息: ${response.data.error}`);
        }
        
        return {
            testName: testCase.name,
            statusCode: response.statusCode,
            expectedStatus: testCase.expectedStatus,
            success: isExpectedStatus,
            error: response.data.error || null
        };
        
    } catch (error) {
        console.log(`❌ 异常: ${error.message}`);
        return {
            testName: testCase.name,
            success: false,
            error: error.message
        };
    }
}

async function runEdgeCaseTests() {
    console.log('🔍 边界情况和错误处理测试');
    console.log('='.repeat(50));
    
    const results = [];
    
    for (const testCase of EDGE_CASES) {
        const result = await testEdgeCase(testCase);
        results.push(result);
        await new Promise(resolve => setTimeout(resolve, 1000)); // 延迟
    }
    
    // 统计结果
    const totalTests = results.length;
    const passedTests = results.filter(r => r.success).length;
    const failedTests = totalTests - passedTests;
    
    console.log('\n📊 边界测试结果统计:');
    console.log(`   总测试数: ${totalTests}`);
    console.log(`   通过测试: ${passedTests}`);
    console.log(`   失败测试: ${failedTests}`);
    console.log(`   通过率: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    // 显示失败的测试
    const failedResults = results.filter(r => !r.success);
    if (failedResults.length > 0) {
        console.log('\n❌ 失败的测试:');
        failedResults.forEach(result => {
            console.log(`   - ${result.testName}: ${result.error || '状态码不符合预期'}`);
        });
    }
    
    return results;
}

runEdgeCaseTests().catch(console.error);
