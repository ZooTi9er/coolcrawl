FROM node:20-slim

# 设置环境变量
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV NODE_ENV=production
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium"

# 启用 pnpm
RUN corepack enable

# 安装系统依赖
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    chromium \
    chromium-sandbox \
    curl \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

WORKDIR /app

# 复制项目文件
COPY . .

# 安装依赖并构建
RUN pnpm install --frozen-lockfile
RUN pnpm run build

# 清理开发依赖
RUN pnpm prune --prod

EXPOSE 3002

# 启动应用
CMD [ "pnpm", "run", "start:production" ]

