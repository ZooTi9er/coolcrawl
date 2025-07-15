const http = require('http');

function makeSearchRequest(query, limit = 5) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify({
            query: query,
            limit: limit,
            lang: "zh",
            country: "cn",
            fetchPageContent: false  // 只获取搜索结果，不抓取页面内容
        });
        
        const options = {
            hostname: 'localhost',
            port: 3002,
            path: '/v0/search',
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

        req.setTimeout(30000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

async function testSearch() {
    const query = '2025年 AI agent';
    
    console.log(`🔍 正在搜索: "${query}"`);
    console.log('='.repeat(60));
    
    try {
        const response = await makeSearchRequest(query, 5);
        
        console.log(`HTTP 状态码: ${response.statusCode}`);
        
        if (response.statusCode === 200 && response.data.success) {
            const results = response.data.data;
            
            console.log(`✅ 搜索成功! 找到 ${results.length} 条结果:`);
            console.log('='.repeat(60));
            
            results.forEach((result, index) => {
                console.log(`\n📄 结果 ${index + 1}:`);
                console.log(`标题: ${result.title || '无标题'}`);
                console.log(`链接: ${result.url}`);
                console.log(`描述: ${result.description || '无描述'}`);
                console.log('-'.repeat(50));
            });
            
            return true;
        } else {
            console.log('❌ 搜索失败:', response.data);
            return false;
        }
        
    } catch (error) {
        console.log('❌ 请求异常:', error.message);
        return false;
    }
}

testSearch().then(success => {
    process.exit(success ? 0 : 1);
});
