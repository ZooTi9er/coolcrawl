# Firecrawl 用户使用说明报告 v1.1

## 📋 **文档概述**

**文档版本**: v1.1  
**创建时间**: 2025年7月15日 22:50 (UTC+8)  
**适用版本**: Firecrawl v1.0+  
**项目仓库**: git@github.com:ZooTi9er/coolcrawl.git  
**支持联系**: 通过 GitHub Issues 提交问题  

---

## 🚀 **快速开始**

### **系统要求**

#### **最低配置要求**
| 组件 | 最低要求 | 推荐配置 | 说明 |
|------|----------|----------|------|
| **操作系统** | Linux/macOS/Windows | Linux (Ubuntu 20.04+) | 支持 Docker 环境 |
| **CPU** | 2核心 | 4核心+ | 影响并发处理能力 |
| **内存** | 4GB | 8GB+ | 影响缓存和队列性能 |
| **存储** | 20GB | 50GB+ SSD | 数据库和日志存储 |
| **网络** | 10Mbps | 100Mbps+ | 影响抓取速度 |

#### **软件依赖**
- **Docker**: 20.10+ 和 Docker Compose 2.0+
- **Node.js**: 18+ (如果本地开发)
- **PostgreSQL**: 14+ (如果独立部署)
- **Redis**: 7+ (如果独立部署)

### **Docker 快速部署**

#### **1. 克隆项目**
```bash
git clone git@github.com:ZooTi9er/coolcrawl.git
cd coolcrawl
```

#### **2. 配置环境变量**
```bash
# 复制环境变量模板
cp apps/api/.env.example apps/api/.env

# 编辑配置文件
nano apps/api/.env
```

**关键配置项**:
```bash
# 基础配置
USE_DB_AUTHENTICATION=false
API_KEY=your-api-key-here
HOST=0.0.0.0
PORT=3002

# 数据库配置
DATABASE_URL=postgresql://postgres:password@db:5432/firecrawl
REDIS_URL=redis://redis:6379

# 搜索服务配置 (重要!)
SERPER_API_KEY=dd957bb61a200a750bbe5f49e6f71b26e7eed5d1

# 可选配置
SCRAPING_BEE_API_KEY=your-scraping-bee-key
```

#### **3. 启动服务**
```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f langfuse-web
```

#### **4. 验证部署**
```bash
# 健康检查
curl http://localhost:3002/health

# 测试抓取功能
curl -X POST http://localhost:3002/v0/scrape \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key-here" \
  -d '{"url": "https://example.com"}'
```

---

## 🔧 **API 使用指南**

### **认证方式**

所有 API 请求都需要在 Header 中包含 API Key：
```bash
Authorization: Bearer your-api-key-here
```

### **1. 网页抓取功能**

#### **基础抓取 (v0)**
```bash
curl -X POST http://localhost:3002/v0/scrape \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "url": "https://example.com",
    "pageOptions": {
      "onlyMainContent": true,
      "includeHtml": false
    }
  }'
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "content": "页面主要内容...",
    "metadata": {
      "title": "Example Domain",
      "description": "This domain is for use in illustrative examples",
      "sourceURL": "https://example.com"
    }
  }
}
```

#### **高级抓取 (v1)**
```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "url": "https://example.com",
    "pageOptions": {
      "onlyMainContent": true,
      "waitFor": 2000,
      "screenshot": false
    },
    "extractorOptions": {
      "mode": "llm-extraction"
    }
  }'
```

#### **抓取参数说明**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `url` | string | 必需 | 要抓取的网页URL |
| `pageOptions.onlyMainContent` | boolean | false | 只提取主要内容 |
| `pageOptions.includeHtml` | boolean | false | 包含原始HTML |
| `pageOptions.waitFor` | number | 0 | 等待时间(毫秒) |
| `pageOptions.screenshot` | boolean | false | 生成截图 |

### **2. 网页搜索功能**

#### **基础搜索**
```bash
curl -X POST http://localhost:3002/v0/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "query": "JavaScript frameworks 2024",
    "searchOptions": {
      "limit": 5,
      "country": "US"
    }
  }'
```

**响应示例**:
```json
{
  "success": true,
  "data": [
    {
      "content": "搜索结果内容...",
      "metadata": {
        "title": "Top JavaScript Frameworks 2024",
        "sourceURL": "https://example.com/js-frameworks",
        "description": "最新的JavaScript框架对比..."
      }
    }
  ]
}
```

#### **中文搜索支持**
```bash
curl -X POST http://localhost:3002/v0/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "query": "人工智能发展趋势 2024",
    "searchOptions": {
      "limit": 3,
      "country": "CN",
      "lang": "zh"
    }
  }'
```

#### **搜索参数说明**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `query` | string | 必需 | 搜索关键词 |
| `searchOptions.limit` | number | 5 | 返回结果数量 |
| `searchOptions.country` | string | "US" | 搜索地区代码 |
| `searchOptions.lang` | string | "en" | 搜索语言代码 |

### **3. 网站爬取功能**

#### **v0 爬取 (异步任务)**
```bash
# 提交爬取任务
curl -X POST http://localhost:3002/v0/crawl \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "url": "https://example.com",
    "crawlerOptions": {
      "limit": 10,
      "maxDepth": 2
    }
  }'
```

**响应示例**:
```json
{
  "success": true,
  "jobId": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### **查询任务状态**
```bash
curl -X GET http://localhost:3002/v0/crawl/status/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer your-api-key"
```

**状态响应**:
```json
{
  "success": true,
  "status": "completed",
  "current": 10,
  "total": 10,
  "data": [
    {
      "content": "页面内容...",
      "metadata": {
        "title": "页面标题",
        "sourceURL": "https://example.com/page1"
      }
    }
  ]
}
```

#### **v1 爬取 (同步响应)**
```bash
curl -X POST http://localhost:3002/v1/crawl \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "url": "https://example.com",
    "crawlerOptions": {
      "limit": 5,
      "maxDepth": 1,
      "allowExternalLinks": false
    },
    "pageOptions": {
      "onlyMainContent": true
    }
  }'
```

#### **爬取参数说明**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `url` | string | 必需 | 起始URL |
| `crawlerOptions.limit` | number | 100 | 最大页面数 |
| `crawlerOptions.maxDepth` | number | 2 | 最大爬取深度 |
| `crawlerOptions.allowExternalLinks` | boolean | false | 允许外部链接 |

---

## 🐳 **Docker 部署详细说明**

### **生产环境部署**

#### **1. 环境准备**
```bash
# 创建数据目录
mkdir -p /opt/firecrawl/{postgres,redis}
chmod 755 /opt/firecrawl/{postgres,redis}

# 设置环境变量
export FIRECRAWL_API_KEY="your-secure-api-key"
export POSTGRES_PASSWORD="your-secure-password"
export REDIS_PASSWORD="your-redis-password"
```

#### **2. 生产配置文件**
创建 `docker-compose.prod.yml`:
```yaml
version: '3.8'
services:
  langfuse-web:
    image: langfuse/langfuse:latest
    ports:
      - "3002:3002"
    environment:
      - NODE_ENV=production
      - API_KEY=${FIRECRAWL_API_KEY}
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/firecrawl
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
      - SERPER_API_KEY=${SERPER_API_KEY}
    depends_on:
      - db
      - redis
    restart: unless-stopped
    
  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=firecrawl
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - /opt/firecrawl/postgres:/var/lib/postgresql/data
    restart: unless-stopped
    
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - /opt/firecrawl/redis:/data
    restart: unless-stopped
```

#### **3. 启动生产环境**
```bash
# 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 设置开机自启
sudo systemctl enable docker
```

### **负载均衡配置**

#### **Nginx 配置示例**
```nginx
upstream firecrawl_backend {
    server 127.0.0.1:3002;
    server 127.0.0.1:3003;  # 如果有多个实例
}

server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://firecrawl_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### **监控和日志**

#### **日志收集**
```bash
# 查看实时日志
docker-compose logs -f --tail=100

# 导出日志到文件
docker-compose logs > firecrawl.log

# 日志轮转配置
echo '{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}' | sudo tee /etc/docker/daemon.json
```

#### **性能监控**
```bash
# 容器资源使用情况
docker stats

# 系统资源监控
htop
iostat -x 1
```

---

## 🔍 **常见问题解答**

### **部署相关问题**

#### **Q1: Docker 容器启动失败**
**A**: 检查以下几点：
1. 确认 Docker 和 Docker Compose 版本
2. 检查端口是否被占用：`netstat -tlnp | grep 3002`
3. 查看容器日志：`docker-compose logs langfuse-web`
4. 确认环境变量配置正确

#### **Q2: 数据库连接失败**
**A**: 常见解决方案：
```bash
# 检查数据库容器状态
docker-compose ps db

# 测试数据库连接
docker-compose exec db psql -U postgres -d firecrawl -c "SELECT 1;"

# 重置数据库
docker-compose down -v
docker-compose up -d
```

#### **Q3: Redis 连接问题**
**A**: 排查步骤：
```bash
# 检查 Redis 容器
docker-compose ps redis

# 测试 Redis 连接
docker-compose exec redis redis-cli ping

# 检查 Redis 配置
docker-compose exec redis redis-cli config get "*"
```

### **API 使用问题**

#### **Q4: API 返回 401 未授权错误**
**A**: 检查认证配置：
1. 确认 API Key 格式正确
2. 检查 Header 格式：`Authorization: Bearer your-api-key`
3. 验证 API Key 是否在环境变量中正确设置

#### **Q5: 抓取请求超时**
**A**: 优化建议：
1. 增加请求超时时间
2. 检查目标网站的访问速度
3. 考虑使用代理服务
4. 分批处理大量请求

#### **Q6: 搜索功能返回空结果**
**A**: 可能原因：
1. SERPER_API_KEY 未配置或无效
2. 搜索关键词过于具体
3. 地区限制导致无结果
4. API 配额已用完

### **性能优化问题**

#### **Q7: 系统响应速度慢**
**A**: 性能优化建议：
1. **增加系统资源**：
   - CPU: 升级到4核心以上
   - 内存: 增加到8GB以上
   - 存储: 使用SSD硬盘

2. **优化配置**：
   ```bash
   # 增加 Redis 内存限制
   redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
   
   # 优化 PostgreSQL 配置
   shared_buffers = 256MB
   effective_cache_size = 1GB
   ```

3. **启用缓存**：
   - 配置 Redis 缓存
   - 使用 CDN 加速
   - 启用 HTTP 缓存

#### **Q8: 高并发处理能力不足**
**A**: 扩展方案：
1. **水平扩展**：
   ```bash
   # 启动多个 API 实例
   docker-compose up --scale langfuse-web=3
   ```

2. **队列优化**：
   ```javascript
   // 增加队列工作进程
   const queue = new Bull('web-scraper', {
     redis: redisConfig,
     settings: {
       stalledInterval: 30000,
       maxStalledCount: 1,
     },
   });
   
   queue.process(10, processJob); // 并发处理10个任务
   ```

---

## 📊 **最佳实践建议**

### **1. 安全配置**
- 使用强密码和复杂的 API Key
- 启用 HTTPS 加密传输
- 定期更新依赖包和镜像
- 配置防火墙规则

### **2. 性能优化**
- 合理设置缓存策略
- 监控系统资源使用情况
- 定期清理日志和临时文件
- 使用连接池优化数据库访问

### **3. 运维管理**
- 设置自动备份策略
- 配置监控告警系统
- 建立故障恢复流程
- 定期进行性能测试

### **4. 开发集成**
- 使用版本控制管理配置
- 实现自动化部署流程
- 编写完整的测试用例
- 建立代码审查机制

---

## 📞 **技术支持**

### **获取帮助**
- **GitHub Issues**: https://github.com/ZooTi9er/coolcrawl/issues
- **文档更新**: 关注项目 README 和 docs 目录
- **社区讨论**: 通过 GitHub Discussions 参与讨论

### **报告问题**
提交问题时请包含：
1. 系统环境信息
2. 错误日志和堆栈信息
3. 复现步骤
4. 预期行为和实际行为

### **贡献代码**
欢迎提交 Pull Request：
1. Fork 项目仓库
2. 创建功能分支
3. 提交代码更改
4. 创建 Pull Request

---

**文档版本**: v1.1  
**最后更新**: 2025年7月15日 22:50 (UTC+8)  
**适用版本**: Firecrawl v1.0+
