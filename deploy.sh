#!/bin/bash
set -e

echo "=========================================="
echo "Claude Code Router - Docker 部署脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 从 .env 文件加载配置
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 代理配置
PROXY_URL="http://127.0.0.1:7890"

# 0. 设置 npm 代理
echo -e "${YELLOW}步骤 0/8: 配置 npm 代理...${NC}"
npm config set proxy $PROXY_URL
npm config set https-proxy $PROXY_URL
echo -e "${GREEN}✅ npm 代理配置完成${NC}"
echo ""

# 1. 检查 npm 仓库最新版本
echo -e "${YELLOW}步骤 1/8: 检查 npm 仓库最新版本...${NC}"
LATEST_NPM_VERSION=$(npm view @w154594742/claude-code-router version 2>/dev/null)
if [ -z "$LATEST_NPM_VERSION" ]; then
    echo -e "${RED}❌ 无法获取 npm 仓库版本信息${NC}"
    exit 1
fi
echo -e "${GREEN}✅ npm 仓库最新版本: ${LATEST_NPM_VERSION}${NC}"
echo ""

# 2. 停止并清理现有环境
echo -e "${YELLOW}步骤 2/8: 停止并清理现有Docker环境...${NC}"
docker-compose down -v 2>/dev/null || true
docker rmi claude-code-router-claude-code-router 2>/dev/null || true
echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

# 3. 清理Docker缓存(可选)
echo -e "${YELLOW}步骤 3/8: 清理Docker缓存...${NC}"
docker system prune -f
echo -e "${GREEN}✅ 缓存清理完成${NC}"
echo ""

# 4. 完全重新构建镜像(带代理参数)
echo -e "${YELLOW}步骤 4/8: 开始构建Docker镜像(这可能需要5-10分钟)...${NC}"
echo -e "${BLUE}将从 npm 安装版本: ${LATEST_NPM_VERSION}${NC}"
docker-compose build --no-cache \
  --build-arg HTTP_PROXY=$PROXY_URL \
  --build-arg HTTPS_PROXY=$PROXY_URL
echo -e "${GREEN}✅ 镜像构建完成${NC}"
echo ""

# 5. 启动服务
echo -e "${YELLOW}步骤 5/8: 启动服务...${NC}"
docker-compose up -d
echo -e "${GREEN}✅ 服务已启动${NC}"
echo ""

# 6. 等待服务启动
echo -e "${YELLOW}步骤 6/8: 等待服务完全启动...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://localhost:${CCR_HOST_PORT:-3456}/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 服务已启动${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        sleep 1
        echo -n "."
    fi
done
echo ""

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${YELLOW}⚠️  服务启动检查超时,继续部署...${NC}"
fi
echo ""

# 7. 验证服务状态和版本
echo -e "${YELLOW}步骤 7/8: 验证服务状态和版本...${NC}"
echo ""
echo "=== 容器状态 ==="
docker-compose ps
echo ""

echo "=== 最近日志 ==="
docker-compose logs --tail=20
echo ""

echo "=== 实际安装的版本 ==="
INSTALLED_VERSION=$(docker-compose exec -T claude-code-router ccr -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$INSTALLED_VERSION" ]; then
    echo -e "${YELLOW}⚠️  无法获取容器内安装的版本${NC}"
else
    echo -e "${GREEN}容器内安装版本: ${INSTALLED_VERSION}${NC}"
    if [ "$INSTALLED_VERSION" = "$LATEST_NPM_VERSION" ]; then
        echo -e "${GREEN}✅ 版本匹配 - 已成功安装最新版本${NC}"
    else
        echo -e "${RED}⚠️  版本不匹配!${NC}"
        echo -e "${RED}   期望版本: ${LATEST_NPM_VERSION}${NC}"
        echo -e "${RED}   实际版本: ${INSTALLED_VERSION}${NC}"
        echo -e "${YELLOW}   提示: npm CDN 缓存可能还未同步,请等待2-3分钟后重新部署${NC}"
    fi
fi
echo ""

# 8. 测试健康检查
echo -e "${YELLOW}步骤 8/8: 测试服务健康状态...${NC}"
if curl -sf http://localhost:${CCR_HOST_PORT:-3456}/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ 服务健康检查通过${NC}"
else
    echo -e "${YELLOW}⚠️  服务健康检查未响应${NC}"
    echo -e "${YELLOW}提示: 服务可能还在启动中,请稍候片刻后手动检查${NC}"
    echo -e "${YELLOW}手动检查命令: curl http://localhost:${CCR_HOST_PORT:-3456}/health${NC}"
fi
echo ""

# 9. 清理 npm 代理配置(可选)
echo -e "${YELLOW}清理 npm 代理配置...${NC}"
npm config delete proxy
npm config delete https-proxy
echo -e "${GREEN}✅ npm 代理配置已清理${NC}"
echo ""

# 完成
echo "=========================================="
echo -e "${GREEN}✅ 部署完成!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}部署信息:${NC}"
echo "  npm 仓库版本: ${LATEST_NPM_VERSION}"
if [ -n "$INSTALLED_VERSION" ]; then
    echo "  容器安装版本: ${INSTALLED_VERSION}"
fi
echo ""
echo "访问地址: http://localhost:${CCR_HOST_PORT:-3456}/ui/"
echo ""
echo "提示:"
echo "  1. 使用 .env 文件中配置的 APIKEY 登录"
echo "  2. 查看日志: docker-compose logs -f"
echo "  3. 停止服务: docker-compose down"
echo "  4. 重启服务: docker-compose restart"
echo ""
