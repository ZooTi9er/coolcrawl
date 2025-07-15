const https = require('https');
const http = require('http');

function makeRequest(url, data) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify(data);
        
        const options = {
            hostname: 'localhost',
            port: 3002,
            path: '/v0/scrape',
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

        req.setTimeout(45000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

async function testGoogleSearch() {
    const searchUrl = 'https://www.google.com/search?q=2025年+AI+agent';
    
    console.log(`正在测试抓取: ${searchUrl}`);
    console.log('-'.repeat(50));
    
    try {
        const response = await makeRequest('http://localhost:3002/v0/scrape', {
            url: searchUrl
        });
        
        console.log(`HTTP 状态码: ${response.statusCode}`);
        
        if (response.statusCode === 200 && response.data.success) {
            const { content, metadata } = response.data.data;
            
            console.log('✅ 抓取成功!');
            console.log(`页面标题: ${metadata.title || '无标题'}`);
            console.log(`内容长度: ${content.length} 字符`);
            console.log('内容预览:');
            console.log('-'.repeat(30));
            console.log(content.substring(0, 800) + (content.length > 800 ? '...' : ''));
            
            return true;
        } else {
            console.log('❌ 抓取失败:', response.data);
            return false;
        }
        
    } catch (error) {
        console.log('❌ 请求异常:', error.message);
        return false;
    }
}

testGoogleSearch().then(success => {
    process.exit(success ? 0 : 1);
});
