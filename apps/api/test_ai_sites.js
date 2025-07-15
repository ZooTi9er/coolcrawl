const http = require('http');

// AI 相关网站列表
const aiSites = [
    {
        name: "OpenAI Blog",
        url: "https://openai.com/blog/",
        description: "OpenAI 官方博客，AI 技术前沿资讯"
    },
    {
        name: "Towards Data Science",
        url: "https://towardsdatascience.com/",
        description: "数据科学和 AI 技术文章平台"
    },
    {
        name: "AI News",
        url: "https://artificialintelligence-news.com/",
        description: "人工智能新闻网站"
    },
    {
        name: "MIT Technology Review AI",
        url: "https://www.technologyreview.com/topic/artificial-intelligence/",
        description: "MIT 技术评论 AI 版块"
    },
    {
        name: "Hacker News",
        url: "https://news.ycombinator.com/",
        description: "技术新闻聚合，包含大量 AI 讨论"
    }
];

function scrapeWebsite(url) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify({ url: url });
        
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

        req.setTimeout(30000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

function extractAIAgentInfo(content, title) {
    // 查找与 AI agent 相关的内容
    const keywords = ['ai agent', 'artificial intelligence agent', 'autonomous agent', 'intelligent agent', '2025', 'future', 'trend'];
    const lines = content.split('\n');
    const relevantLines = [];
    
    for (const line of lines) {
        const lowerLine = line.toLowerCase();
        if (keywords.some(keyword => lowerLine.includes(keyword))) {
            relevantLines.push(line.trim());
        }
    }
    
    return relevantLines.slice(0, 3); // 返回前3条相关信息
}

async function testAISites() {
    console.log('🤖 正在抓取 AI 相关网站，查找 2025年 AI Agent 信息...');
    console.log('='.repeat(70));
    
    const results = [];
    
    for (let i = 0; i < Math.min(aiSites.length, 3); i++) {
        const site = aiSites[i];
        console.log(`\n📡 正在抓取: ${site.name}`);
        console.log(`🔗 URL: ${site.url}`);
        
        try {
            const response = await scrapeWebsite(site.url);
            
            if (response.statusCode === 200 && response.data.success) {
                const { content, metadata } = response.data.data;
                const aiInfo = extractAIAgentInfo(content, metadata.title);
                
                console.log(`✅ 抓取成功!`);
                console.log(`📄 页面标题: ${metadata.title || '无标题'}`);
                console.log(`📊 内容长度: ${content.length} 字符`);
                
                if (aiInfo.length > 0) {
                    console.log(`🎯 找到 ${aiInfo.length} 条 AI Agent 相关信息:`);
                    aiInfo.forEach((info, index) => {
                        console.log(`   ${index + 1}. ${info}`);
                    });
                    
                    results.push({
                        site: site.name,
                        url: site.url,
                        title: metadata.title,
                        aiInfo: aiInfo
                    });
                } else {
                    console.log(`ℹ️  未找到明显的 AI Agent 相关信息`);
                }
                
            } else {
                console.log(`❌ 抓取失败: ${response.data.error || '未知错误'}`);
            }
            
        } catch (error) {
            console.log(`❌ 请求异常: ${error.message}`);
        }
        
        console.log('-'.repeat(50));
        
        // 添加延迟避免请求过快
        if (i < aiSites.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    // 汇总结果
    console.log('\n📋 汇总结果:');
    console.log('='.repeat(70));
    
    if (results.length > 0) {
        results.forEach((result, index) => {
            console.log(`\n${index + 1}. 【${result.site}】`);
            console.log(`   标题: ${result.title}`);
            console.log(`   链接: ${result.url}`);
            console.log(`   AI Agent 相关信息:`);
            result.aiInfo.forEach((info, infoIndex) => {
                console.log(`     • ${info}`);
            });
        });
        
        return true;
    } else {
        console.log('❌ 未能获取到有效的 AI Agent 信息');
        return false;
    }
}

testAISites().then(success => {
    process.exit(success ? 0 : 1);
});
