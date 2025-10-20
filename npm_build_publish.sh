#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 包名
PACKAGE_NAME="@w154594742/claude-code-router"

echo "=========================================="
echo -e "${BLUE}NPM 构建和发布脚本${NC}"
echo "=========================================="
echo ""

# 1. 获取 npm 仓库中已发布的所有版本
echo -e "${YELLOW}正在获取 npm 仓库中已发布的版本...${NC}"
PUBLISHED_VERSIONS=$(npm view $PACKAGE_NAME versions --json 2>/dev/null)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 无法获取 npm 仓库信息,请检查网络连接${NC}"
    exit 1
fi

# 获取最新版本号
LATEST_VERSION=$(echo $PUBLISHED_VERSIONS | grep -o '"[0-9]\+\.[0-9]\+\.[0-9]\+"' | tail -1 | tr -d '"')
echo -e "${GREEN}✅ npm 仓库中当前最新版本: ${LATEST_VERSION}${NC}"
echo ""

# 2. 提示用户输入新版本号
while true; do
    echo -e "${BLUE}请输入要发布的新版本号 (格式: x.y.z):${NC}"
    read -p "> " NEW_VERSION

    # 验证版本号格式
    if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ 版本号格式错误! 请使用格式: x.y.z (例如: 1.1.1)${NC}"
        echo ""
        continue
    fi

    # 检查版本是否已存在
    if echo $PUBLISHED_VERSIONS | grep -q "\"$NEW_VERSION\""; then
        echo -e "${RED}❌ 版本 $NEW_VERSION 已存在于 npm 仓库中!${NC}"
        echo -e "${YELLOW}当前 npm 仓库中的最大版本号为: ${LATEST_VERSION}${NC}"
        echo -e "${YELLOW}请输入一个更高的版本号${NC}"
        echo ""
        continue
    fi

    # 版本号比较 (简单的字符串比较,适用于语义化版本)
    if [[ "$NEW_VERSION" < "$LATEST_VERSION" ]]; then
        echo -e "${YELLOW}⚠️  警告: 新版本号 $NEW_VERSION 小于当前最新版本 $LATEST_VERSION${NC}"
        read -p "是否继续? (y/n): " CONFIRM
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            echo ""
            continue
        fi
    fi

    break
done

echo ""
echo -e "${GREEN}✅ 将发布新版本: ${NEW_VERSION}${NC}"
echo ""

# 3. 更新 package.json 中的版本号
echo -e "${YELLOW}步骤 1/4: 更新 package.json 版本号...${NC}"
# 使用 sed 替换版本号 (兼容 macOS 和 Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" package.json
else
    sed -i "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" package.json
fi
echo -e "${GREEN}✅ package.json 已更新为版本 ${NEW_VERSION}${NC}"
echo ""

# 4. 构建项目
echo -e "${YELLOW}步骤 2/4: 构建项目...${NC}"
npm run build
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 构建失败!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 构建完成${NC}"
echo ""

# 5. 发布到 npm
echo -e "${YELLOW}步骤 3/4: 发布到 npm...${NC}"
npm publish --access public
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 发布失败!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 发布成功${NC}"
echo ""

# 6. Git 提交 (可选)
echo -e "${YELLOW}步骤 4/4: Git 提交...${NC}"
read -p "是否提交到 Git? (y/n): " GIT_COMMIT

if [[ $GIT_COMMIT =~ ^[Yy]$ ]]; then
    git add package.json
    git commit -m "release v${NEW_VERSION}"

    read -p "是否推送到远程仓库? (y/n): " GIT_PUSH
    if [[ $GIT_PUSH =~ ^[Yy]$ ]]; then
        git push
        echo -e "${GREEN}✅ 已推送到远程仓库${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  跳过 Git 提交${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ 发布完成!${NC}"
echo "=========================================="
echo ""
echo "版本: ${NEW_VERSION}"
echo "包名: ${PACKAGE_NAME}"
echo "查看: https://www.npmjs.com/package/${PACKAGE_NAME}"
echo ""
