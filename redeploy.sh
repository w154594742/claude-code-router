#!/bin/bash

set -e

# 项目配置
PROJECT_NAME="claude-code-router"
CONTAINER_NAME="claude-code-router"
IMAGE_NAME="${PROJECT_NAME}:latest"
COMPOSE_FILE="docker-compose.yml"
BRANCH="dev"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要工具
check_requirements() {
    log_info "检查必要工具..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        log_error "Git 未安装"
        exit 1
    fi

    log_success "所有必要工具已安装"
}

# 检查项目文件
check_project_files() {
    log_info "检查项目文件..."

    if [ ! -f "package.json" ]; then
        log_error "package.json 不存在"
        exit 1
    fi

    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "$COMPOSE_FILE 不存在"
        exit 1
    fi

    log_success "项目文件检查通过"
}

# Git 拉取最新代码
git_pull_latest() {
    log_info "从 GitHub 拉取最新代码..."

    # 检查是否在 Git 仓库中
    if [ ! -d ".git" ]; then
        log_warning "当前目录不是 Git 仓库，尝试初始化..."
        git init
        git remote add origin https://github.com/w154594742/claude-code-router.git
    fi

    # 检查当前分支
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    log_info "当前分支: $current_branch"

    # 切换到目标分支（如果需要）
    if [ "$current_branch" != "$BRANCH" ]; then
        log_info "切换到 $BRANCH 分支..."
        git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null || git checkout "$BRANCH" 2>/dev/null || {
            log_warning "无法切换到 $BRANCH 分支，尝试创建新分支"
            git checkout -b "$BRANCH"
        }
    fi

    # 获取最新代码
    git fetch origin "$BRANCH"

    # 重置到远程分支的最新状态
    git reset --hard "origin/$BRANCH"

    # 清理未跟踪的文件
    git clean -fd

    log_success "代码已更新到最新版本"
}

# 创建多阶段 Dockerfile
create_multistage_dockerfile() {
    log_info "创建多阶段 Dockerfile..."

    cat > Dockerfile << 'DOCKERFILE_EOF'
FROM node:20-alpine as builder

WORKDIR /app

# 复制package.json和package-lock.json
COPY package*.json ./

# 安装所有依赖（包括开发依赖）
RUN npm install

# 复制源代码
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
COPY --from=builder /app/ui/dist ./dist

# 复制启动脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 创建软链接,模拟全局安装的ccr命令
RUN ln -s /app/dist/cli.js /usr/local/bin/ccr && \
    chmod +x /app/dist/cli.js

EXPOSE 3456

CMD ["/usr/local/bin/entrypoint.sh"]
DOCKERFILE_EOF

    log_success "多阶段 Dockerfile 已创建"
}

# 停止并删除现有容器
stop_containers() {
    log_info "停止现有容器..."

    if [ -f "$COMPOSE_FILE" ]; then
        # 使用 docker-compose 或 docker compose
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "$COMPOSE_FILE" down
        else
            docker compose -f "$COMPOSE_FILE" down
        fi
    else
        # 如果没有 compose 文件，直接停止容器
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi

    log_success "容器已停止"
}

# 构建新镜像
build_image() {
    log_info "构建新镜像..."

    if [ -f "$COMPOSE_FILE" ]; then
        # 使用 docker-compose 或 docker compose
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "$COMPOSE_FILE" build --no-cache
        else
            docker compose -f "$COMPOSE_FILE" build --no-cache
        fi
    else
        # 如果没有 compose 文件，直接构建镜像
        docker build -t "$IMAGE_NAME" .
    fi

    log_success "镜像构建完成"
}

# 启动新容器
start_containers() {
    log_info "启动新容器..."

    if [ -f "$COMPOSE_FILE" ]; then
        # 使用 docker-compose 或 docker compose
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "$COMPOSE_FILE" up -d
        else
            docker compose -f "$COMPOSE_FILE" up -d
        fi
    else
        # 如果没有 compose 文件，直接运行容器
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart unless-stopped \
            -p "3456:3456" \
            -v "$HOME/.claude-code-router:/root/.claude-code-router" \
            --env-file .env \
            -e "APIKEY=${APIKEY}" \
            --add-host "host.docker.internal:host-gateway" \
            "$IMAGE_NAME"
    fi

    log_success "容器已启动"
}

# 清理旧镜像
cleanup_old_images() {
    log_info "清理旧镜像..."

    # 查找并删除旧的镜像（除了最新的）
    old_images=$(docker images "$PROJECT_NAME" --format "{{.ID}}" | tail -n +2)

    if [ -n "$old_images" ]; then
        echo "$old_images" | xargs -r docker rmi -f 2>/dev/null || true
        log_success "旧镜像已清理"
    else
        log_info "没有找到需要清理的旧镜像"
    fi

    # 清理悬空镜像
    docker image prune -f
}

# 检查容器状态
check_container_status() {
    log_info "检查容器状态..."

    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        log_success "$CONTAINER_NAME 容器正在运行"

        # 显示容器状态
        echo ""
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
        echo ""

        # 显示最近日志
        log_info "最近日志："
        docker logs --tail 10 "$CONTAINER_NAME"
    else
        log_error "$CONTAINER_NAME 容器未运行"

        # 显示所有容器状态
        echo ""
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
        echo ""

        # 显示容器日志（如果有）
        if docker ps -a --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
            log_info "容器日志："
            docker logs --tail 20 "$CONTAINER_NAME"
        fi

        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -b, --branch BRANCH 指定要拉取的分支 (默认: dev)"
    echo "  --skip-git          跳过 Git 拉取步骤"
    echo "  --skip-build        跳过构建步骤"
    echo "  --skip-cleanup      跳过清理旧镜像"
    echo ""
    echo "示例:"
    echo "  $0                  # 使用默认设置重新部署"
    echo "  $0 -b main          # 从 main 分支拉取并部署"
    echo "  $0 --skip-git       # 使用当前代码重新部署"
}

# 主函数
main() {
    # 解析命令行参数
    SKIP_GIT=false
    SKIP_BUILD=false
    SKIP_CLEANUP=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--branch)
                BRANCH="$2"
                shift 2
                ;;
            --skip-git)
                SKIP_GIT=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-cleanup)
                SKIP_CLEANUP=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 显示部署信息
    echo ""
    echo "=========================================="
    echo "    Claude Code Router 部署脚本"
    echo "=========================================="
    echo "项目名称: $PROJECT_NAME"
    echo "容器名称: $CONTAINER_NAME"
    echo "镜像名称: $IMAGE_NAME"
    echo "目标分支: $BRANCH"
    echo "跳过 Git 拉取: $SKIP_GIT"
    echo "跳过构建: $SKIP_BUILD"
    echo "跳过清理: $SKIP_CLEANUP"
    echo "=========================================="
    echo ""

    # 执行部署步骤
    check_requirements
    check_project_files

    if [ "$SKIP_GIT" = false ]; then
        git_pull_latest
        create_multistage_dockerfile
    fi

    stop_containers

    if [ "$SKIP_BUILD" = false ]; then
        build_image
    fi

    start_containers

    if [ "$SKIP_CLEANUP" = false ]; then
        cleanup_old_images
    fi

    # 检查最终状态
    echo ""
    if check_container_status; then
        log_success "部署完成！"
        echo ""
        echo "服务访问地址:"
        echo "  - 本地访问: http://localhost:3456"
        echo "  - 服务器访问: http://$(hostname -I | awk '{print $1}'):3456"
        echo ""
        echo "管理命令:"
        echo "  - 查看状态: docker ps"
        echo "  - 查看日志: docker logs $CONTAINER_NAME"
        echo "  - 停止服务: docker-compose down"
        echo ""
    else
        log_error "部署失败，请检查日志"
        exit 1
    fi
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi