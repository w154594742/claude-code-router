FROM node:20-alpine as builder

WORKDIR /app

# 安装 pnpm 和构建依赖,配置国内镜像源
RUN corepack enable && corepack prepare pnpm@latest --activate && \
    apk add --no-cache python3 make g++ && \
    npm config set registry https://registry.npmmirror.com && \
    pnpm config set registry https://registry.npmmirror.com

# 复制package.json和package-lock.json
COPY package*.json ./

# 安装主项目依赖
RUN npm install

# 复制 UI 项目的 package.json
COPY ui/package.json ui/pnpm-lock.yaml* ./ui/

# 安装 UI 项目依赖(使用 pnpm)
WORKDIR /app/ui
RUN pnpm install --frozen-lockfile || pnpm install

# 复制所有源代码
WORKDIR /app
COPY . .

# 构建项目
RUN npm run build

# 生产阶段
FROM node:20-alpine

WORKDIR /app

# 复制package.json和package-lock.json
COPY package*.json ./

# 只安装生产依赖
RUN npm install --production

# 从builder阶段复制构建产物
COPY --from=builder /app/dist ./dist

# 复制启动脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 创建软链接,模拟全局安装的ccr命令
RUN ln -s /app/dist/cli.js /usr/local/bin/ccr && \
    chmod +x /app/dist/cli.js

EXPOSE 3456

CMD ["/usr/local/bin/entrypoint.sh"]
