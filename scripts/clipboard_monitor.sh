#!/bin/bash
# clipboard_monitor.sh - 剪贴板监测守护（launchd 常驻）
# 每 2 秒检查剪贴板变化，复制内容后自动路由模型
# 启动: launchctl load ~/Library/LaunchAgents/com.modelroute.clipboard.plist

LOGDIR="$HOME/.workbuddy/logs"
LOGFILE="$LOGDIR/route_history.json"
CACHEFILE="/tmp/.clipboard_monitor_last"
SELF_LOG="$LOGDIR/clipboard_monitor.log"

mkdir -p "$LOGDIR"

# ─── 路由规则 ───
route_model() {
    local lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    [[ "$lower" == *"代码"* || "$lower" == *"debug"* || "$lower" == *"函数"* || "$lower" == *"api"* || "$lower" == *"sql"* || "$lower" == *"json"* || "$lower" == *"python"* || "$lower" == *"bug"* || "$lower" == *"编程"* || "$lower" == *"class "* || "$lower" == *"shell"* || "$lower" == *"报错"* ]] && { echo "Qwen3-Coder-30B|编程/代码任务"; return; }
    [[ "$lower" == *"看图"* || "$lower" == *"截图"* || "$lower" == *"图片"* || "$lower" == *"图像"* || "$lower" == *"识别"* || "$lower" == *"这张"* ]] && { echo "Qwen3-VL-32B|图片/视觉任务"; return; }
    [[ "$lower" == *"分析"* || "$lower" == *"对比"* || "$lower" == *"推理"* || "$lower" == *"评估"* || "$lower" == *"策略"* || "$lower" == *"报告"* || "$lower" == *"总结"* || "$lower" == *"深度"* ]] && { echo "Qwen3.6-35B|深度分析任务"; return; }
    echo "DeepSeek-V4-Flash|通用任务"
}

# ─── JSON 转义 ───
json_escape() {
    python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1" 2>/dev/null || echo "\"$1\""
}

# ─── 写日志（Python 处理 JSON 更稳） ───
log_route() {
    local model="$1" reason="$2" content="$3"
    local preview="${content:0:60}"
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    
    python3 -c "
import json, os
path = '$LOGFILE'
entry = {'timestamp': '$ts', 'model': json.loads('$(json_escape "$model")'), 'reason': json.loads('$(json_escape "$reason")'), 'preview': json.loads('$(json_escape "$preview")')}
if os.path.exists(path):
    with open(path) as f: data = json.load(f)
else:
    data = []
data.append(entry)
if len(data) > 200: data = data[-200:]
with open(path, 'w') as f: json.dump(data, f, indent=2, ensure_ascii=False)
" 2>/dev/null
    
    echo "[$(date '+%H:%M:%S')] → $model ($reason): $preview" >> "$SELF_LOG"
}

# ─── 主循环 ───
echo "[$(date '+%Y-%m-%d %H:%M:%S') 启动] clipboard_monitor.sh" >> "$SELF_LOG"

last_content=$(cat "$CACHEFILE" 2>/dev/null || echo "")

while true; do
    content=$(osascript -e 'the clipboard' 2>/dev/null)
    
    if [ -n "$content" ] && [ "$content" != "$last_content" ]; then
        last_content="$content"
        echo "$content" > "$CACHEFILE"
        
        result=$(route_model "$content")
        model="${result%%|*}"
        reason="${result#*|}"
        
        log_route "$model" "$reason" "$content"
        
        # 通知
        osascript -e "display notification \"$reason\n内容: ${content:0:50}\" with title \"建议: $model\"" 2>/dev/null &
    fi
    
    sleep 2
done
