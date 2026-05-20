#!/bin/bash
# sync_configs.sh - 自动同步配置到 ~/.workbuddy/shared/ 并推送到 GitHub
# 用法: ./sync_configs.sh [--quiet]
# 每小时执行一次（cron）

set -e

SHARED_DIR="$HOME/.workbuddy/shared"
SCRIPTS_DIR="$HOME/.workbuddy/scripts"
SKILLS_DIR="$HOME/.workbuddy/skills"
LOG_FILE="$HOME/.workbuddy/logs/sync.log"
QUIET=false

[[ "$1" == "--quiet" ]] && QUIET=true

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    $QUIET || echo "$msg"
}

mkdir -p "$SHARED_DIR" "$(dirname "$LOG_FILE")"

cd "$SHARED_DIR"

# 确保是 Git 仓库
if [ ! -d ".git" ]; then
    git init
    git remote add origin git@github.com:yn46sy8h6d-cyber/workbuddy-shared-rules.git 2>/dev/null || true
fi

# ── 1. 同步脚本 ──
if [ -d "$SCRIPTS_DIR" ]; then
    mkdir -p scripts
    rsync -a --delete "$SCRIPTS_DIR/" scripts/
    log "✓ 同步脚本 $(ls scripts/ | wc -l) 个"
fi

# ── 2. 同步 Skill ──
if [ -d "$SKILLS_DIR" ]; then
    mkdir -p skills
    rsync -a --delete "$SKILLS_DIR/" skills/
    log "✓ 同步 Skills $(ls skills/ | wc -l) 个"
fi

# ── 3. 同步关键配置 ──
mkdir -p configs
[ -f "$HOME/.workbuddy/models.json" ]    && cp "$HOME/.workbuddy/models.json"    configs/
[ -f "$HOME/.workbuddy/mcp.json" ]       && cp "$HOME/.workbuddy/mcp.json"       configs/
[ -f "$HOME/.workbuddy/handoff.json" ]   && cp "$HOME/.workbuddy/handoff.json"   configs/ 2>/dev/null || true
log "✓ 同步配置 $(ls configs/ | wc -l) 个"

# ── 4. 同步记忆文件 ──
if [ -d "$HOME/.workbuddy/memory" ]; then
    mkdir -p memory
    # 只同步当月的 daily 文件和 MEMORY.md
    rsync -a --include="MEMORY.md" --include="20*.md" --exclude="*" "$HOME/.workbuddy/memory/" memory/
    log "✓ 同步记忆文件"
fi

# ── 5. 提交并推送 ──
# 检查是否有任何变更（含未跟踪文件）
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "~ 无变更，跳过提交"
else
    git add -A
    git commit -m "auto-sync $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || true
    
    if git push -q 2>&1; then
        log "✓ 推送成功"
    else
        log "⚠ 推送失败，请检查 SSH 密钥和网络"
    fi
fi

log "--- 同步完成 ---"
