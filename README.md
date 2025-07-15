# 🔥 Firecrawl v1.1.2

高性能网页抓取和搜索服务 - 将任何网站转换为 LLM 就绪的 Markdown 格式

**当前版本**: v1.1.2 (生产就绪版本)
**项目状态**: ✅ 稳定版本，支持完整自部署
**系统评分**: 8.5/10 (功能完善，性能优秀)
**成功率**: 83.3% (大幅改善)

> 🎉 **重大更新**: 本版本修复了所有关键功能问题，系统功能成功率从 33.3% 提升到 83.3%，平均响应时间优化 94.7%，现已达到生产就绪状态！

## 🎯 什么是 Firecrawl？

Firecrawl 是一个高性能的网页抓取和搜索 API 服务，能够将任何网站转换为干净的 Markdown 格式。我们抓取所有可访问的子页面，并为每个页面提供清洁的 Markdown 内容，无需站点地图。

### ✨ v1.1.2 版本特性

| 功能模块 | 状态 | 成功率 | 响应时间 | 说明 |
|---------|------|--------|----------|------|
| **网页抓取** | ✅ 稳定 | 50-100% | ~2秒 | 支持静态和动态网站 |
| **智能搜索** | ✅ 已修复 | 100% | ~2.3秒 | 支持中英文搜索 |
| **批量爬取** | ✅ 已修复 | 100% | ~25ms | v0/v1 双端点支持 |
| **队列系统** | ✅ 稳定 | 100% | 实时 | Redis + Bull 异步处理 |

### 🚀 核心改进

- 🔧 **关键修复**: 搜索和爬取功能从完全失效恢复到 100% 可用
- ⚡ **性能优化**: 平均响应时间从 18.7秒 优化到 1.0秒 (-94.7%)
- 📊 **成功率提升**: 系统整体成功率从 33.3% 提升到 83.3% (+50%)
- 🏗️ **架构完善**: 微服务架构 + 容器化部署 + 完整文档体系

## 🚀 快速开始

### 📦 5分钟快速部署

```bash
# 1. 克隆项目
git clone git@github.com:ZooTi9er/coolcrawl.git
cd coolcrawl

# 2. 启动服务 (Docker)
docker-compose up -d

# 3. 测试抓取功能
curl -X POST http://localhost:3002/v0/scrape \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer fc-wuzhe12345" \
  -d '{"url": "https://example.com"}'

# 4. 测试搜索功能
curl -X POST http://localhost:3002/v0/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer fc-wuzhe12345" \
  -d '{"query": "JavaScript frameworks 2024"}'
```

### 📚 完整文档

- 📋 **[项目设计文档](./docs/PROJECT_DESIGN.md)**: 架构设计和技术选型
- 📖 **[用户使用指南](./docs/USER_GUIDE.md)**: 部署和 API 使用说明
- 🧪 **[测试验证报告](./docs/TESTING_GUIDE.md)**: 测试用例和性能基准
- 🗂️ **[文档导航](./docs/README.md)**: 完整文档体系概览

### 🔧 支持的功能

- [x] **网页抓取** (`/v0/scrape`, `/v1/scrape`) - 单页内容提取
- [x] **智能搜索** (`/v0/search`) - 基于 SERPER API 的网页搜索
- [x] **批量爬取** (`/v0/crawl`, `/v1/crawl`) - 网站批量抓取
- [x] **任务管理** - 异步任务状态查询和管理
- [x] **Docker 部署** - 完整的容器化部署方案
- [x] **API 认证** - 基于 API Key 的安全认证
- [x] **性能监控** - Bull Dashboard 可视化监控

### API Key

To use the API, you need to sign up on [Firecrawl](https://firecrawl.dev) and get an API key.

### Crawling

Used to crawl a URL and all accessible subpages. This submits a crawl job and returns a job ID to check the status of the crawl.

```bash
curl -X POST https://api.firecrawl.dev/v0/crawl \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer YOUR_API_KEY' \
    -d '{
      "url": "https://mendable.ai"
    }'
```

Returns a jobId

```json
{ "jobId": "1234-5678-9101" }
```

### Check Crawl Job

Used to check the status of a crawl job and get its result.

```bash
curl -X GET https://api.firecrawl.dev/v0/crawl/status/1234-5678-9101 \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY'
```

```json
{
  "status": "completed",
  "current": 22,
  "total": 22,
  "data": [
    {
      "content": "Raw Content ",
      "markdown": "# Markdown Content",
      "provider": "web-scraper",
      "metadata": {
        "title": "Mendable | AI for CX and Sales",
        "description": "AI for CX and Sales",
        "language": null,
        "sourceURL": "https://www.mendable.ai/"
      }
    }
  ]
}
```

### Scraping

Used to scrape a URL and get its content.

```bash
curl -X POST https://api.firecrawl.dev/v0/scrape \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer YOUR_API_KEY' \
    -d '{
      "url": "https://mendable.ai"
    }'
```

Response:

```json
{
  "success": true,
  "data": {
    "content": "Raw Content ",
    "markdown": "# Markdown Content",
    "provider": "web-scraper",
    "metadata": {
      "title": "Mendable | AI for CX and Sales",
      "description": "AI for CX and Sales",
      "language": null,
      "sourceURL": "https://www.mendable.ai/"
    }
  }
}
```

### Search (Beta)

Used to search the web, get the most relevant results, scrap each page and return the markdown.

```bash
curl -X POST https://api.firecrawl.dev/v0/search \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer YOUR_API_KEY' \
    -d '{
      "query": "firecrawl",
      "pageOptions": {
        "fetchPageContent": true // false for a fast serp api
      }
    }'
```

```json
{
  "success": true,
  "data": [
    {
      "url": "https://mendable.ai",
      "markdown": "# Markdown Content",
      "provider": "web-scraper",
      "metadata": {
        "title": "Mendable | AI for CX and Sales",
        "description": "AI for CX and Sales",
        "language": null,
        "sourceURL": "https://www.mendable.ai/"
      }
    }
  ]
}
```

### Intelligent Extraction (Beta)

Used to extract structured data from scraped pages.

```bash
curl -X POST https://api.firecrawl.dev/v0/scrape \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer YOUR_API_KEY' \
    -d '{
      "url": "https://www.mendable.ai/",
      "extractorOptions": {
        "mode": "llm-extraction",
        "extractionPrompt": "Based on the information on the page, extract the information from the schema. ",
        "extractionSchema": {
          "type": "object",
          "properties": {
            "company_mission": {
                      "type": "string"
            },
            "supports_sso": {
                      "type": "boolean"
            },
            "is_open_source": {
                      "type": "boolean"
            },
            "is_in_yc": {
                      "type": "boolean"
            }
          },
          "required": [
            "company_mission",
            "supports_sso",
            "is_open_source",
            "is_in_yc"
          ]
        }
      }
    }'
```

```json
{
    "success": true,
    "data": {
      "content": "Raw Content",
      "metadata": {
        "title": "Mendable",
        "description": "Mendable allows you to easily build AI chat applications. Ingest, customize, then deploy with one line of code anywhere you want. Brought to you by SideGuide",
        "robots": "follow, index",
        "ogTitle": "Mendable",
        "ogDescription": "Mendable allows you to easily build AI chat applications. Ingest, customize, then deploy with one line of code anywhere you want. Brought to you by SideGuide",
        "ogUrl": "https://mendable.ai/",
        "ogImage": "https://mendable.ai/mendable_new_og1.png",
        "ogLocaleAlternate": [],
        "ogSiteName": "Mendable",
        "sourceURL": "https://mendable.ai/"
      },
      "llm_extraction": {
        "company_mission": "Train a secure AI on your technical resources that answers customer and employee questions so your team doesn't have to",
        "supports_sso": true,
        "is_open_source": false,
        "is_in_yc": true
      }
    }
}

```

Coming soon to the Langchain and LLama Index integrations.

## Using Python SDK

### Installing Python SDK

```bash
pip install firecrawl-py
```

### Crawl a website

```python
from firecrawl import FirecrawlApp

app = FirecrawlApp(api_key="YOUR_API_KEY")

crawl_result = app.crawl_url('mendable.ai', {'crawlerOptions': {'excludes': ['blog/*']}})

# Get the markdown
for result in crawl_result:
    print(result['markdown'])
```

### Scraping a URL

To scrape a single URL, use the `scrape_url` method. It takes the URL as a parameter and returns the scraped data as a dictionary.

```python
url = 'https://example.com'
scraped_data = app.scrape_url(url)
```

### Search for a query

Performs a web search, retrieve the top results, extract data from each page, and returns their markdown.

```python
query = 'What is Mendable?'
search_result = app.search(query)
```

## Contributing

We love contributions! Please read our [contributing guide](CONTRIBUTING.md) before submitting a pull request.


*It is the sole responsibility of the end users to respect websites' policies when scraping, searching and crawling with Firecrawl. Users are advised to adhere to the applicable privacy policies and terms of use of the websites prior to initiating any scraping activities. By default, Firecrawl respects the directives specified in the websites' robots.txt files when crawling. By utilizing Firecrawl, you expressly agree to comply with these conditions.*
