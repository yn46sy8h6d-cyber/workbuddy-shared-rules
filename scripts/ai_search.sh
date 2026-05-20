#!/bin/bash
# AI 工作历史搜索工具
# 用法: ai_search "关键词" [天数，默认30]

KEYWORD="$1"
DAYS="${2:-30}"
BACKUP_ROOT="$HOME/Documents/AI工作备份"

if [ -z "$KEYWORD" ]; then
    echo "用法: ai_search \"关键词\" [天数]"
    echo "示例: ai_search \"公众号排版\" 10"
    exit 0
fi

CUTOFF=$(python3 -c "
import datetime
d = datetime.datetime.now() - datetime.timedelta(days=$DAYS)
print(d.strftime('%Y-%m-%d'))
")

is_recent() {
    python3 -c "print('yes' if '$1' >= '$CUTOFF' else 'no')"
}

echo "============================================"
echo " 搜索: $KEYWORD (最近 ${DAYS} 天)"
echo "============================================"
echo ""

found=0

# 1. 工作日志
echo "[1] 工作日志"
echo "----------------------------"
for f in "$BACKUP_ROOT"/工作日志_*.md; do
    [ -f "$f" ] || continue
    fdate=$(basename "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
    [ -n "$fdate" ] || continue
    test "$(is_recent "$fdate")" = "yes" || continue
    matches=$(grep -n -i "$KEYWORD" "$f" 2>/dev/null)
    if [ -n "$matches" ]; then
        echo "[HIT] $f"
        echo "$matches" | head -5
        echo ""
        found=1
    fi
done

# 2. WorkBuddy memory
echo "[2] WorkBuddy 工作记忆"
echo "----------------------------"
for dir in "$HOME/.workbuddy/memory" "$BACKUP_ROOT/workbuddy/memory"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null)
        test "$(is_recent "$mtime")" = "yes" || continue
        matches=$(grep -n -i "$KEYWORD" "$f" 2>/dev/null)
        if [ -n "$matches" ]; then
            echo "[HIT] $f"
            echo "$matches" | head -5
            echo ""
            found=1
        fi
    done
done

# 3. 终端历史
echo "[3] 终端命令历史"
echo "----------------------------"
if [ -f "$HOME/.zsh_history" ]; then
    grep -i "$KEYWORD" "$HOME/.zsh_history" | tail -10 | while IFS= read -r line; do
        if [[ "$line" == :*:*\;* ]]; then
            cmd="${line#*;}"
            ts="${line#*:}"
            ts="${ts%%:*}"
            if [ -n "$ts" ]; then
                dt=$(date -r "$ts" '+%Y-%m-%d %H:%M' 2>/dev/null)
                echo "  [$dt] $cmd"
                found=1
            fi
        fi
    done
fi

# 4. QClaw 审计日志
echo "[4] QClaw 操作记录"
echo "----------------------------"
QC_DB="$HOME/Library/Application Support/QClaw/qclaw.db"
if [ -f "$QC_DB" ]; then
    result=$(python3 -c "
import sqlite3, datetime
conn = sqlite3.connect('$QC_DB')
c = conn.cursor()
kw = '$KEYWORD'
c.execute('SELECT created_at, detail FROM qclaw_audit_log WHERE detail LIKE ? ORDER BY created_at DESC LIMIT 10', (f'%{kw}%',))
rows = c.fetchall()
for ts, detail in rows:
    dt = datetime.datetime.fromtimestamp(ts/1000).strftime('%Y-%m-%d %H:%M')
    print(f'  [{dt}] {detail[:150]}')
conn.close()
" 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result"
        found=1
    fi
fi

# 5. CodeBuddy 备份数据
echo "[5] CodeBuddy 数据"
echo "----------------------------"
if [ -d "$BACKUP_ROOT/codebuddy" ]; then
    find "$BACKUP_ROOT/codebuddy" -name "*.json" -type f 2>/dev/null | while IFS= read -r m; do
        if grep -qi "$KEYWORD" "$m" 2>/dev/null; then
            echo "  [HIT] $m"
            found=1
        fi
    done
fi

echo ""
echo "============================================"
if [ $found -eq 1 ]; then
    echo " 找到记录。告诉 AI: 帮我接着做上面的任务"
else
    echo " 未找到 (扩大范围: ai_search \"$KEYWORD\" 90)"
fi
echo "============================================"
