FROM node:20-alpine

WORKDIR /app

# 复制package.json和package-lock.json
COPY package*.json ./

# 安装依赖
RUN npm install --production

# 复制构建后的代码和资源
COPY dist ./dist
COPY ui/dist ./dist

# 复制启动脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 创建软链接,模拟全局安装的ccr命令
RUN ln -s /app/dist/cli.js /usr/local/bin/ccr && \
    chmod +x /app/dist/cli.js

EXPOSE 3456

CMD ["/usr/local/bin/entrypoint.sh"]
