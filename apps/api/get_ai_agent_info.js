const http = require('http');

// 专门查找 AI Agent 相关的网站和页面
const targetUrls = [
    "https://www.anthropic.com/",
    "https://blog.langchain.dev/",
    "https://huggingface.co/blog",
    "https://www.deepmind.com/blog",
    "https://research.google/blog/"
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

        req.setTimeout(25000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.write(postData);
        req.end();
    });
}

function extractAIAgentInfo(content) {
    // 更精确的关键词匹配
    const agentKeywords = [
        'ai agent', 'artificial intelligence agent', 'autonomous agent', 
        'intelligent agent', 'multi-agent', 'agent framework',
        'conversational agent', 'virtual agent', 'digital agent'
    ];
    
    const futureKeywords = ['2025', '2024', 'future', 'next year', 'upcoming', 'trend', 'prediction'];
    
    const sentences = content.split(/[.!?]+/).map(s => s.trim()).filter(s => s.length > 20);
    const relevantInfo = [];
    
    for (const sentence of sentences) {
        const lowerSentence = sentence.toLowerCase();
        
        // 检查是否包含 agent 相关关键词
        const hasAgentKeyword = agentKeywords.some(keyword => lowerSentence.includes(keyword));
        
        if (hasAgentKeyword) {
            // 优先选择包含未来时间词的句子
            const hasFutureKeyword = futureKeywords.some(keyword => lowerSentence.includes(keyword));
            
            if (hasFutureKeyword || relevantInfo.length < 3) {
                relevantInfo.push({
                    text: sentence,
                    priority: hasFutureKeyword ? 1 : 2
                });
            }
        }
    }
    
    // 按优先级排序并返回前5条
    return relevantInfo
        .sort((a, b) => a.priority - b.priority)
        .slice(0, 5)
        .map(item => item.text);
}

async function getAIAgentInfo() {
    console.log('🤖 正在搜集 2025年 AI Agent 相关信息...');
    console.log('='.repeat(70));
    
    const allResults = [];
    
    for (let i = 0; i < Math.min(targetUrls.length, 3); i++) {
        const url = targetUrls[i];
        const siteName = url.replace('https://', '').replace('www.', '').split('/')[0];
        
        console.log(`\n📡 正在抓取: ${siteName}`);
        console.log(`🔗 URL: ${url}`);
        
        try {
            const response = await scrapeWebsite(url);
            
            if (response.statusCode === 200 && response.data.success) {
                const { content, metadata } = response.data.data;
                const aiInfo = extractAIAgentInfo(content);
                
                console.log(`✅ 抓取成功!`);
                console.log(`📄 页面标题: ${metadata.title || '无标题'}`);
                console.log(`📊 内容长度: ${content.length} 字符`);
                
                if (aiInfo.length > 0) {
                    console.log(`🎯 找到 ${aiInfo.length} 条 AI Agent 相关信息:`);
                    aiInfo.forEach((info, index) => {
                        console.log(`   ${index + 1}. ${info.substring(0, 150)}${info.length > 150 ? '...' : ''}`);
                    });
                    
                    allResults.push(...aiInfo.map(info => ({
                        source: siteName,
                        url: url,
                        title: metadata.title,
                        content: info
                    })));
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
        
        // 添加延迟
        if (i < targetUrls.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 3000));
        }
    }
    
    // 输出最终的5条信息
    console.log('\n🎯 2025年 AI Agent 相关信息汇总 (前5条):');
    console.log('='.repeat(70));
    
    if (allResults.length > 0) {
        const topResults = allResults.slice(0, 5);
        
        topResults.forEach((result, index) => {
            console.log(`\n${index + 1}. 【来源: ${result.source}】`);
            console.log(`   ${result.content}`);
            console.log(`   🔗 链接: ${result.url}`);
        });
        
        return true;
    } else {
        console.log('❌ 未能获取到有效的 AI Agent 信息');
        
        // 提供一些通用的 AI Agent 信息作为备选
        console.log('\n📚 提供一些通用的 2025年 AI Agent 趋势信息:');
        const generalInfo = [
            "AI Agent 将在2025年变得更加自主和智能，能够处理复杂的多步骤任务",
            "多模态 AI Agent 将整合文本、图像、语音等多种输入输出方式",
            "企业级 AI Agent 将广泛应用于客户服务、数据分析和业务流程自动化",
            "个人助理型 AI Agent 将具备更强的上下文理解和个性化能力",
            "AI Agent 之间的协作和通信将成为重要发展方向"
        ];
        
        generalInfo.forEach((info, index) => {
            console.log(`${index + 1}. ${info}`);
        });
        
        return false;
    }
}

getAIAgentInfo().then(success => {
    process.exit(success ? 0 : 1);
});
