#!/bin/bash
# handoff-executor.sh — 读取 handoff → ccb 执行 → git commit
# 触发：fswatch 文件事件触发，或手动运行
# 用法: ./handoff-executor.sh                    # 处理最新一个 handoff
#       ./handoff-executor.sh /path/to/handoff.md # 处理指定 handoff

set -euo pipefail

HANDOFFS_DIR="$HOME/.hermes/at/handoffs"
CCB_CMD="$HOME/.local/bin/ccb"
DEEPSEEK_KEY="${DEEPSEEK_API_KEY:-}"

# ── 1. 确定目标 handoff ──
if [ $# -ge 1 ]; then
    HANDOFF="$1"
else
    HANDOFF=$(ls -t "$HANDOFFS_DIR"/*.md 2>/dev/null | head -1)
fi

[ -z "$HANDOFF" ] && echo "[handoff-executor] 无 handoff 文件" && exit 0
[ ! -f "$HANDOFF" ] && echo "[handoff-executor] 文件不存在: $HANDOFF" && exit 1

# ── 2. 检查是否已处理 ──
if grep -q "^## Status: done\|^## Status: failed" "$HANDOFF" 2>/dev/null; then
    echo "[handoff-executor] 已处理，跳过: $HANDOFF"
    exit 0
fi

echo "[handoff-executor] 处理: $HANDOFF"

# ── 3. 提取目标目录（自动查找 git 根目录） ──
# 从 ## Targets 下找以 - 开头的路径
TARGET_DIRS=""
while IFS= read -r line; do
    path=$(echo "$line" | sed 's/^\s*- \s*//')
    # 找 git root（无论传文件还是目录都能定位到仓库根目录）
    if git_root=$(git -C "$(dirname "$path")" rev-parse --show-toplevel 2>/dev/null); then
        TARGET_DIRS="$TARGET_DIRS$git_root"$'\n'
    elif [ -d "$path" ]; then
        TARGET_DIRS="$TARGET_DIRS$path"$'\n'
    fi
done < <(sed -n '/^## Targets/,/^## /p' "$HANDOFF" | grep '^\s*- ')

TARGET_DIRS=$(echo "$TARGET_DIRS" | sort -u | sed '/^$/d')

if [ -z "$TARGET_DIRS" ]; then
    echo "[handoff-executor] 未指定目标目录，默认 hermes-desk"
    TARGET_DIRS="$HOME/hermes-desk"
fi

echo "[handoff-executor] 目标目录: $(echo "$TARGET_DIRS" | tr '\n' ' ')"

# ── 4. Git stash 未提交的改动 ──
for DIR in $TARGET_DIRS; do
    git -C "$DIR" stash push -m "auto-stash before handoff $(date +%Y%m%d%H%M)" 2>/dev/null || true
done

# ── 5. 调用 ccb 执行 ──
FIRST_DIR=$(echo "$TARGET_DIRS" | head -1)
cd "$FIRST_DIR"

PROMPT=$(cat "$HANDOFF")
echo "[handoff-executor] 调用 ccb (DeepSeek)..."

export OPENAI_API_KEY="$DEEPSEEK_KEY"
export CLAUDE_CODE_USE_OPENAI=true
export OPENAI_BASE_URL="https://api.deepseek.com/v1"

# -p (print) 模式 → 非交互式执行
# --dangerously-skip-permissions → 跳过权限询问
# --model deepseek-v4-flash → 指定 DeepSeek 模型（ccb 默认发 gpt-4o 会被拒）
if ! $CCB_CMD -p "$PROMPT" --dangerously-skip-permissions --model deepseek-v4-flash 2>&1; then
    echo "[handoff-executor] ❌ ccb 执行失败"
    echo "## Status: failed" >> "$HANDOFF"
    echo "## Failed at: $(date '+%Y-%m-%d %H:%M')" >> "$HANDOFF"
    exit 1
fi

echo "[handoff-executor] ✅ ccb 执行完成"

# ── 6. Git add + commit ──
TASK_NAME=$(grep "^## Task" "$HANDOFF" | head -1 | sed 's/^## Task[:\s]*//' | xargs)
[ -z "$TASK_NAME" ] && TASK_NAME="handoff execution"

COMMITTED=0
for DIR in $TARGET_DIRS; do
    git -C "$DIR" add -A
    if ! git -C "$DIR" diff --cached --quiet 2>/dev/null; then
        git -C "$DIR" commit -m "handoff: $TASK_NAME"
        echo "[handoff-executor] ✅ git commit $DIR"
        echo "    commit: $(git -C "$DIR" rev-parse --short HEAD)"
        git -C "$DIR" log --oneline -1
        COMMITTED=$((COMMITTED + 1))
    else
        echo "[handoff-executor] ⚠️ 无变更可提交: $DIR"
    fi
done

# ── 7. 标记完成 ──
HANDOFF_NAME=$(basename "$HANDOFF")
echo "" >> "$HANDOFF"
echo "## Status: done" >> "$HANDOFF"
echo "## Done at: $(date '+%Y-%m-%d %H:%M')" >> "$HANDOFF"
echo "## Committed: $COMMITTED repos" >> "$HANDOFF"

echo "[handoff-executor] ✅ 完成: $HANDOFF_NAME (committed: $COMMITTED)"
