FROM mcr.microsoft.com/playwright:v1.54.1-noble-arm64 AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
LABEL fly_launch_runtime="Node.js"

# 配置 npm 镜像源和网络设置
RUN npm config set registry https://registry.npmmirror.com/ && \
    npm config set fetch-retries 3 && \
    npm config set fetch-retry-factor 2 && \
    npm config set fetch-retry-mintimeout 10000 && \
    npm config set fetch-retry-maxtimeout 60000

# 安装 pnpm
RUN npm install -g pnpm@8.15.6 && \
    corepack enable

WORKDIR /app

# 复制 package 文件
COPY package.json pnpm-lock.yaml .npmrc* ./

# 安装生产依赖
RUN pnpm config set store-dir /tmp/pnpm-store && \
    pnpm install --prod --frozen-lockfile --no-optional && \
    rm -rf /tmp/pnpm-store

# 复制构建好的应用
COPY . .

# 构建应用
RUN pnpm config set store-dir /tmp/pnpm-store && \
    pnpm install --frozen-lockfile --no-optional && \
    pnpm run build && \
    rm -rf /tmp/pnpm-store

# 清理不必要的文件
RUN rm -rf node_modules/.cache && \
    rm -rf /tmp/* /var/tmp/*

EXPOSE 8080

# 配置 Playwright 环境变量
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# 配置 Puppeteer 使用 Playwright 的 Chromium
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

CMD [ "pnpm", "run", "worker:production" ]
