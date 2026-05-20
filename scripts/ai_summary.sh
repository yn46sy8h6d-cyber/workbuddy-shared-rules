#!/bin/bash
# AI 工作流可读摘要生成器
# 从各工具的备份数据中提取关键信息，生成人类可读的 Markdown 摘要
# 配合 ai_backup.sh 使用，在备份后运行

BACKUP_ROOT="$HOME/Documents/AI工作备份"
TODAY=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')
SUMMARY_FILE="$BACKUP_ROOT/工作日志_${TODAY}.md"

mkdir -p "$BACKUP_ROOT"

cat > "$SUMMARY_FILE" << EOFHEADER
# AI 工作日志 — ${TODAY}
> 自动生成于 ${TODAY} ${TIME}

EOFHEADER

# ===== WorkBuddy =====
echo "---" >> "$SUMMARY_FILE"
echo "## WorkBuddy" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# 读取 memory 目录下的所有 md 文件
WB_MEM="$BACKUP_ROOT/workbuddy/memory"
if [ -d "$WB_MEM" ]; then
    echo "### 工作记忆" >> "$SUMMARY_FILE"
    for f in "$WB_MEM"/*.md; do
        if [ -f "$f" ]; then
            echo "" >> "$SUMMARY_FILE"
            echo "**$(basename "$f")**" >> "$SUMMARY_FILE"
            echo '```' >> "$SUMMARY_FILE"
            cat "$f" >> "$SUMMARY_FILE"
            echo '```' >> "$SUMMARY_FILE"
        fi
    done
fi

# 读取全局 memory
WB_GLOBAL="$HOME/.workbuddy/memory"
if [ -d "$WB_GLOBAL" ]; then
    for f in "$WB_GLOBAL"/*.md; do
        if [ -f "$f" ] && [ -s "$f" ]; then
            echo "" >> "$SUMMARY_FILE"
            echo "**全局/$(basename "$f")**" >> "$SUMMARY_FILE"
            echo '```' >> "$SUMMARY_FILE"
            cat "$f" >> "$SUMMARY_FILE"
            echo '```' >> "$SUMMARY_FILE"
        fi
    done
fi

# ===== CodeBuddy =====
echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "## CodeBuddy" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# 提取最近的工作空间
CB_USER="$BACKUP_ROOT/codebuddy/User"
if [ -d "$CB_USER" ]; then
    echo "### 最近工作空间" >> "$SUMMARY_FILE"
    # workspaceStorage 记录
    if [ -d "$CB_USER/workspaceStorage" ]; then
        echo "- 工作空间数量: $(ls "$CB_USER/workspaceStorage" 2>/dev/null | wc -l | tr -d ' ')" >> "$SUMMARY_FILE"
        # 最近修改的几个工作空间
        echo "- 最近活跃:" >> "$SUMMARY_FILE"
        ls -lt "$CB_USER/workspaceStorage" 2>/dev/null | head -6 | while read line; do
            dir=$(echo "$line" | awk '{print $NF}')
            if [ -d "$CB_USER/workspaceStorage/$dir" ]; then
                # 尝试读取工作空间名称
                name=""
                if [ -f "$CB_USER/workspaceStorage/$dir/workspace.json" ]; then
                    name=$(python3 -c "
import json
try:
    with open('$CB_USER/workspaceStorage/$dir/workspace.json') as f:
        d = json.load(f)
    print(d.get('folder','unknown'))
except: print('unknown')
" 2>/dev/null)
                fi
                echo "  - $name ($dir)" >> "$SUMMARY_FILE"
            fi
        done
    fi
fi

# ===== QClaw =====
echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "## QClaw / OpenClaw" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

QC_BACKUP="$BACKUP_ROOT/qclaw"
if [ -d "$QC_BACKUP/openclaw" ]; then
    # 提取 openclaw 中的对话摘要
    echo "### 对话记录" >> "$SUMMARY_FILE"
    find "$QC_BACKUP/openclaw" -name "*.json" -newer "$QC_BACKUP/openclaw" -mtime -1 2>/dev/null | head -10 | while read f; do
        echo "- $(basename "$f")" >> "$SUMMARY_FILE"
    done
    if [ -d "$QC_BACKUP/openclaw" ]; then
        echo "- 数据条目数: $(find "$QC_BACKUP/openclaw" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')" >> "$SUMMARY_FILE"
    fi
fi

# QClaw Local Storage 中的最近 key
QC_LS="$QC_BACKUP/Local Storage/leveldb"
if [ -d "$QC_LS" ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "### Local Storage 最近更新" >> "$SUMMARY_FILE"
    ls -lt "$QC_LS"/*.ldb "$QC_LS"/*.log 2>/dev/null | head -5 | while read line; do
        fname=$(echo "$line" | awk '{print $NF}')
        fsize=$(echo "$line" | awk '{print $5}')
        if [ -f "$fname" ] && [ "$fsize" != "0" ]; then
            echo "- $(basename "$fname") ($(numfmt --to=iec --suffix=B "$fsize" 2>/dev/null || echo "${fsize}B"))" >> "$SUMMARY_FILE"
        fi
    done
fi

# ===== AutoClaw =====
echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "## AutoClaw" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

AC_LS="$BACKUP_ROOT/autoclaw/Local Storage/leveldb"
if [ -d "$AC_LS" ]; then
    echo "### Local Storage" >> "$SUMMARY_FILE"
    echo "- 文件数: $(ls "$AC_LS" 2>/dev/null | wc -l | tr -d ' ')" >> "$SUMMARY_FILE"
    ls -lt "$AC_LS" 2>/dev/null | head -3 | while read line; do
        echo "- $(echo "$line" | awk '{print $NF}')" >> "$SUMMARY_FILE"
    done
else
    echo "暂无备份数据" >> "$SUMMARY_FILE"
fi

# ===== Coze =====
echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "## Coze (网页端)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

CZ_DIR="$BACKUP_ROOT/coze/IndexedDB"
if [ -d "$CZ_DIR" ]; then
    echo "- IndexedDB 文件数: $(find "$CZ_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')" >> "$SUMMARY_FILE"
    ls -lt "$CZ_DIR" 2>/dev/null | head -5 | while read line; do
        fname=$(echo "$line" | awk '{print $NF}')
        echo "- $(basename "$fname")" >> "$SUMMARY_FILE"
    done
else
    echo "暂无本地数据（Coze 为网页端应用）" >> "$SUMMARY_FILE"
    echo "如需备份 Coze 对话，建议手动导出或截图" >> "$SUMMARY_FILE"
fi

# ===== 终端操作记录 =====
echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "## 终端操作记录 (最近 50 条)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo '```' >> "$SUMMARY_FILE"

if [ -f "$HOME/.zsh_history" ]; then
    # zsh EXTENDED_HISTORY 格式: ": timestamp:duration;command"
    tail -50 "$HOME/.zsh_history" 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" == :*:*\;* ]]; then
            cmd="${line#*;}"
            ts="${line#*:}"
            ts="${ts%%:*}"
            if [ -n "$ts" ]; then
                dt=$(date -r "$ts" '+%H:%M:%S' 2>/dev/null)
                echo "[$dt] $cmd"
            else
                echo "$cmd"
            fi
        else
            echo "$line"
        fi
    done >> "$SUMMARY_FILE"
else
    echo "暂无历史记录" >> "$SUMMARY_FILE"
fi

echo '```' >> "$SUMMARY_FILE"

echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "✅ 日志生成完成。文件位置: \`$SUMMARY_FILE\`" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "崩溃恢复指南：打开对应目录查看备份数据 → 从上述摘要中找到上次工作的上下文 → 在任意 AI 工具中粘贴上下文即可接续" >> "$SUMMARY_FILE"

echo "摘要已生成: $SUMMARY_FILE"
