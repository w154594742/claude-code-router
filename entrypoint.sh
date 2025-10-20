#!/bin/sh

# 启动脚本：在启动应用前注入环境变量到配置文件

set -e

CONFIG_DIR="/root/.claude-code-router"
CONFIG_FILE="$CONFIG_DIR/config.json"

# 确保配置目录存在
mkdir -p "$CONFIG_DIR"

# 如果配置文件存在，用环境变量替换其中的占位符
if [ -f "$CONFIG_FILE" ]; then
    # 将 ${APIKEY} 替换为实际的环境变量值
    if [ -n "$APIKEY" ]; then
        # 使用 sed 进行替换，避免特殊字符问题
        # 这里使用 | 作为分隔符以支持包含 / 的 APIKEY
        sed -i "s|\"\${APIKEY}\"|\"$APIKEY\"|g" "$CONFIG_FILE"
    fi
fi

# 启动应用
exec ccr start
