#!/usr/bin/env python3
import requests
import json
import sys

def test_google_search():
    url = 'http://localhost:3002/v0/scrape'
    
    # 测试 Google 搜索
    search_url = 'https://www.google.com/search?q=2025年+AI+agent'
    data = {'url': search_url}
    
    print(f"正在测试抓取: {search_url}")
    print("-" * 50)
    
    try:
        response = requests.post(url, json=data, timeout=45)
        print(f'HTTP 状态码: {response.status_code}')
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                content = result['data']['content']
                metadata = result['data']['metadata']
                
                print(f'✅ 抓取成功!')
                print(f'页面标题: {metadata.get("title", "无标题")}')
                print(f'内容长度: {len(content)} 字符')
                print(f'内容预览:')
                print("-" * 30)
                print(content[:800] + "..." if len(content) > 800 else content)
                
                return True
            else:
                print(f'❌ 抓取失败: {result}')
                return False
        else:
            print(f'❌ HTTP错误 {response.status_code}: {response.text[:200]}')
            return False
            
    except requests.exceptions.Timeout:
        print('❌ 请求超时')
        return False
    except Exception as e:
        print(f'❌ 请求异常: {e}')
        return False

if __name__ == "__main__":
    success = test_google_search()
    sys.exit(0 if success else 1)
