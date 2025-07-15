FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
LABEL fly_launch_runtime="Node.js"

# 配置 npm 镜像源和网络设置
RUN npm config set registry https://registry.npmmirror.com/ && \
    npm config set fetch-retries 3 && \
    npm config set fetch-retry-factor 2 && \
    npm config set fetch-retry-mintimeout 10000 && \
    npm config set fetch-retry-maxtimeout 60000

RUN corepack enable

# 先复制 package 文件以利用 Docker 层缓存
COPY package.json pnpm-lock.yaml .npmrc* ./
WORKDIR /app
COPY package.json pnpm-lock.yaml .npmrc* ./

FROM base AS prod-deps
# 禁用缓存挂载，避免缓存损坏问题
# 跳过 Puppeteer 下载
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
# RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile
RUN pnpm config set store-dir /tmp/pnpm-store && \
    pnpm install --prod --frozen-lockfile --no-optional && \
    rm -rf /tmp/pnpm-store

FROM base AS build
# 复制完整项目文件
COPY . .
# 跳过 Puppeteer 下载
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN pnpm config set store-dir /tmp/pnpm-store && \
    pnpm install --frozen-lockfile --no-optional && \
    pnpm run build && \
    rm -rf /tmp/pnpm-store

FROM base

# 配置中国镜像源和网络优化
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 配置 apt 重试和超时设置
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::https::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::ftp::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf.d/80-retries

# 安装基础工具和 Chromium
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        curl \
        wget \
        gnupg \
        ca-certificates \
        chromium \
        chromium-sandbox \
        fonts-liberation \
        fonts-noto-cjk \
        libxss1 \
        libgconf-2-4 \
        libxtst6 \
        libxrandr2 \
        libasound2 \
        libpangocairo-1.0-0 \
        libatk1.0-0 \
        libcairo-gobject2 \
        libgtk-3-0 \
        libgdk-pixbuf2.0-0 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app /app

EXPOSE 8080
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium"
CMD [ "pnpm", "run", "worker:production" ]

