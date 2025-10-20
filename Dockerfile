FROM node:20-alpine

# 接收构建参数
ARG HTTP_PROXY
ARG HTTPS_PROXY

# 配置 npm 代理并安装
# 注意: 在 Docker 容器内,宿主机代理需要用 host.docker.internal 访问
RUN if [ -n "$HTTP_PROXY" ]; then \
      # 如果代理是 127.0.0.1,转换为 host.docker.internal (仅用于容器内)
      if [ "$HTTP_PROXY" = "http://127.0.0.1:7890" ] || [ "$HTTP_PROXY" = "http://127.0.0.1:7890/" ]; then \
        HTTP_PROXY="http://host.docker.internal:7890"; \
        HTTPS_PROXY="http://host.docker.internal:7890"; \
      fi; \
      npm config set proxy $HTTP_PROXY && \
      npm config set https-proxy $HTTPS_PROXY; \
    fi && \
    npm install -g @w154594742/claude-code-router --registry=https://registry.npmjs.org/ && \
    npm config delete proxy && \
    npm config delete https-proxy

# 复制启动脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3456

CMD ["/usr/local/bin/entrypoint.sh"]
