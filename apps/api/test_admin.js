const http = require('http');

function testAdminInterface() {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'localhost',
            port: 3002,
            path: '/admin/undefined/queues',
            method: 'GET'
        };

        const req = http.request(options, (res) => {
            let data = '';
            
            res.on('data', chunk => {
                data += chunk;
            });
            
            res.on('end', () => {
                const result = {
                    statusCode: res.statusCode,
                    contentType: res.headers['content-type'],
                    responseSize: data.length,
                    containsBullDashboard: data.includes('Bull Dashboard'),
                    containsQueues: data.includes('web-scraper'),
                    success: res.statusCode === 200 && data.includes('Bull Dashboard')
                };
                resolve(result);
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        req.setTimeout(5000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.end();
    });
}

async function runAdminTest() {
    console.log('🔧 测试管理界面 (Bull Dashboard)');
    console.log('-'.repeat(40));
    
    try {
        const result = await testAdminInterface();
        
        console.log('测试结果:');
        console.log(`  HTTP状态码: ${result.statusCode}`);
        console.log(`  Content-Type: ${result.contentType}`);
        console.log(`  响应大小: ${result.responseSize} bytes`);
        console.log(`  包含Bull Dashboard: ${result.containsBullDashboard ? '是' : '否'}`);
        console.log(`  包含队列信息: ${result.containsQueues ? '是' : '否'}`);
        console.log(`  测试结果: ${result.success ? '✅ 通过' : '❌ 失败'}`);
        
    } catch (error) {
        console.log(`❌ 测试失败: ${error.message}`);
    }
}

runAdminTest();
