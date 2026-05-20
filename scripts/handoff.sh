#!/bin/bash
# CodeBuddy → WorkBuddy 任务交接脚本
# 在 CodeBuddy 完成第一阶段后调用，把任务成果写入交接目录
#
# 用法: handoff <任务标题> <描述或文件路径>
# 示例: handoff "公众号排版完成" "/path/to/draft.md"
# 示例: handoff "选题库整理完成" "已完成30个选题的初步筛选"

HANDOFF_DIR="$HOME/Documents/AI工作交接/待处理"
DONE_DIR="$HOME/Documents/AI工作交接/已完成"

mkdir -p "$HANDOFF_DIR" "$DONE_DIR"

TITLE="$1"
DESC="$2"
SOURCE="CodeBuddy"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TASK_ID="task_$(date '+%Y%m%d_%H%M%S')_$$"

if [ -z "$TITLE" ]; then
    echo "用法: handoff \"任务标题\" \"任务描述或文件路径\""
    echo ""
    echo "说明: 把 CodeBuddy 的工作成果交接给 WorkBuddy"
    echo "  - 任务会写入 ~/Documents/AI工作交接/待处理/"
    echo "  - WorkBuddy 会自动检测并执行第二阶段"
    exit 0
fi

# 如果描述是一个文件路径，读取文件内容
if [ -f "$DESC" ]; then
    FILE_PATH="$DESC"
    FILE_NAME=$(basename "$DESC")
    FILE_CONTENT=$(head -c 50000 "$DESC")  # 限制 50KB
    # 复制文件到交接目录
    cp "$DESC" "$HANDOFF_DIR/${TASK_ID}_${FILE_NAME}" 2>/dev/null
    DESC="[附件] $FILE_NAME（已复制到交接目录）"
fi

# 写入任务 JSON
TASK_FILE="$HANDOFF_DIR/${TASK_ID}.json"
cat > "$TASK_FILE" << EOF
{
  "task_id": "$TASK_ID",
  "title": "$TITLE",
  "description": "$DESC",
  "source": "$SOURCE",
  "timestamp": "$TIMESTAMP",
  "status": "pending",
  "attachments": []
}

EOF

# 如果有附件，记录到 JSON
if [ -n "$FILE_PATH" ]; then
    python3 -c "
import json
with open('$TASK_FILE', 'r') as f:
    d = json.load(f)
d['attachments'].append({
    'filename': '$FILE_NAME',
    'path': '$HANDOFF_DIR/${TASK_ID}_${FILE_NAME}'
})
with open('$TASK_FILE', 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
" 2>/dev/null
fi

echo "[交接] 任务已创建"
echo "  ID: $TASK_ID"
echo "  标题: $TITLE"
echo "  来源: $SOURCE"
echo "  时间: $TIMESTAMP"
echo "  文件: $TASK_FILE"
echo ""
echo "WorkBuddy 将自动检测并执行第二阶段"
