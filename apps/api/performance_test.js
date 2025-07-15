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
                'Content-Length': Buffer.byteLength(postData)
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

        req.setTimeout(15000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

async function performanceTest() {
    console.log('⚡ 性能压力测试');
    console.log('='.repeat(40));
    
    const testUrl = "https://example.com";
    const concurrentRequests = 5;
    const totalRequests = 10;
    
    console.log(`测试配置:`);
    console.log(`  目标URL: ${testUrl}`);
    console.log(`  并发请求数: ${concurrentRequests}`);
    console.log(`  总请求数: ${totalRequests}`);
    console.log(`  测试端点: /v0/scrape`);
    
    const results = [];
    const startTime = Date.now();
    
    // 分批执行请求
    for (let batch = 0; batch < Math.ceil(totalRequests / concurrentRequests); batch++) {
        const batchStart = Date.now();
        const batchPromises = [];
        
        const requestsInBatch = Math.min(concurrentRequests, totalRequests - batch * concurrentRequests);
        
        console.log(`\n🚀 执行第 ${batch + 1} 批请求 (${requestsInBatch} 个请求)...`);
        
        for (let i = 0; i < requestsInBatch; i++) {
            const requestPromise = makeRequest('/v0/scrape', { url: testUrl })
                .then(result => {
                    console.log(`  请求 ${batch * concurrentRequests + i + 1}: ${result.success ? '✅' : '❌'} ${result.responseTime}ms`);
                    return result;
                })
                .catch(error => {
                    console.log(`  请求 ${batch * concurrentRequests + i + 1}: ❌ ${error.message}`);
                    return { success: false, error: error.message, responseTime: 0 };
                });
            
            batchPromises.push(requestPromise);
        }
        
        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);
        
        const batchTime = Date.now() - batchStart;
        console.log(`  批次完成时间: ${batchTime}ms`);
        
        // 批次间延迟
        if (batch < Math.ceil(totalRequests / concurrentRequests) - 1) {
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    const totalTime = Date.now() - startTime;
    
    // 分析结果
    const successfulRequests = results.filter(r => r.success).length;
    const failedRequests = results.length - successfulRequests;
    const responseTimes = results.filter(r => r.responseTime > 0).map(r => r.responseTime);
    
    const avgResponseTime = responseTimes.length > 0 
        ? Math.round(responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length)
        : 0;
    
    const minResponseTime = responseTimes.length > 0 ? Math.min(...responseTimes) : 0;
    const maxResponseTime = responseTimes.length > 0 ? Math.max(...responseTimes) : 0;
    
    // 计算吞吐量
    const throughput = successfulRequests / (totalTime / 1000); // 请求/秒
    
    console.log('\n📊 性能测试结果:');
    console.log('='.repeat(40));
    console.log(`总请求数: ${results.length}`);
    console.log(`成功请求: ${successfulRequests}`);
    console.log(`失败请求: ${failedRequests}`);
    console.log(`成功率: ${((successfulRequests / results.length) * 100).toFixed(1)}%`);
    console.log(`总测试时间: ${totalTime}ms`);
    console.log(`平均响应时间: ${avgResponseTime}ms`);
    console.log(`最快响应时间: ${minResponseTime}ms`);
    console.log(`最慢响应时间: ${maxResponseTime}ms`);
    console.log(`吞吐量: ${throughput.toFixed(2)} 请求/秒`);
    
    // 响应时间分布
    if (responseTimes.length > 0) {
        const sorted = responseTimes.sort((a, b) => a - b);
        const p50 = sorted[Math.floor(sorted.length * 0.5)];
        const p90 = sorted[Math.floor(sorted.length * 0.9)];
        const p95 = sorted[Math.floor(sorted.length * 0.95)];
        
        console.log('\n📈 响应时间分布:');
        console.log(`P50 (中位数): ${p50}ms`);
        console.log(`P90: ${p90}ms`);
        console.log(`P95: ${p95}ms`);
    }
    
    // 性能评估
    console.log('\n🎯 性能评估:');
    if (avgResponseTime < 3000) {
        console.log('✅ 响应时间: 优秀 (< 3秒)');
    } else if (avgResponseTime < 5000) {
        console.log('⚠️  响应时间: 良好 (3-5秒)');
    } else {
        console.log('❌ 响应时间: 需要优化 (> 5秒)');
    }
    
    if (successfulRequests / results.length >= 0.95) {
        console.log('✅ 成功率: 优秀 (≥ 95%)');
    } else if (successfulRequests / results.length >= 0.90) {
        console.log('⚠️  成功率: 良好 (90-95%)');
    } else {
        console.log('❌ 成功率: 需要优化 (< 90%)');
    }
    
    if (throughput >= 1.0) {
        console.log('✅ 吞吐量: 优秀 (≥ 1 请求/秒)');
    } else if (throughput >= 0.5) {
        console.log('⚠️  吞吐量: 良好 (0.5-1 请求/秒)');
    } else {
        console.log('❌ 吞吐量: 需要优化 (< 0.5 请求/秒)');
    }
    
    return {
        totalRequests: results.length,
        successfulRequests,
        failedRequests,
        successRate: (successfulRequests / results.length) * 100,
        avgResponseTime,
        minResponseTime,
        maxResponseTime,
        throughput,
        totalTime
    };
}

performanceTest().catch(console.error);
