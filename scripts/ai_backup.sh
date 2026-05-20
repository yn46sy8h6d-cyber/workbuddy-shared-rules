#!/bin/bash
# AI 工作流日志统一归档脚本
# 每次运行将各 AI 工具的关键数据增量备份到 ~/Documents/AI工作备份/
# 建议通过 crontab 或 LaunchAgent 每小时自动运行一次

BACKUP_ROOT="$HOME/Documents/AI工作备份"
LOG_FILE="$BACKUP_ROOT/backup.log"
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%Y-%m-%d_%H%M%S')

mkdir -p "$BACKUP_ROOT"/{workbuddy,codebuddy,qclaw,autoclaw,coze}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "===== 开始归档 ====="

# 1. WorkBuddy — memory 目录
WB_SRC="$HOME/.workbuddy/memory"
WB_DST="$BACKUP_ROOT/workbuddy"
if [ -d "$WB_SRC" ]; then
    rsync -a --delete "$WB_SRC/" "$WB_DST/memory/" 2>/dev/null
    log "WorkBuddy memory 已同步"
else
    log "WorkBuddy memory 目录不存在，跳过"
fi

# 2. CodeBuddy — 会话数据库 + 用户数据
CB_SRC="$HOME/Library/Application Support/CodeBuddy CN"
CB_DST="$BACKUP_ROOT/codebuddy"
if [ -d "$CB_SRC" ]; then
    # 会话数据库
    if [ -f "$CB_SRC/codebuddy-sessions.vscdb" ]; then
        cp "$CB_SRC/codebuddy-sessions.vscdb" "$CB_DST/codebuddy-sessions-${TIME}.vscdb" 2>/dev/null
        # 只保留最近 5 个备份
        ls -t "$CB_DST"/codebuddy-sessions-*.vscdb 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
    fi
    # 用户配置和 globalStorage
    if [ -d "$CB_SRC/User" ]; then
        rsync -a "$CB_SRC/User/" "$CB_DST/User/" 2>/dev/null
    fi
    # automations
    if [ -d "$CB_SRC/automations" ]; then
        rsync -a "$CB_SRC/automations/" "$CB_DST/automations/" 2>/dev/null
    fi
    log "CodeBuddy 已同步"
else
    log "CodeBuddy 目录不存在，跳过"
fi

# 3. QClaw — 对话数据库 + Local Storage
QC_SRC="$HOME/Library/Application Support/QClaw"
QC_DST="$BACKUP_ROOT/qclaw"
if [ -d "$QC_SRC" ]; then
    # 对话数据库
    if [ -f "$QC_SRC/qclaw.db" ]; then
        cp "$QC_SRC/qclaw.db" "$QC_DST/qclaw-db-${TIME}.db" 2>/dev/null
        ls -t "$QC_DST"/qclaw-db-*.db 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
    fi
    # Local Storage
    if [ -d "$QC_SRC/Local Storage" ]; then
        rsync -a "$QC_SRC/Local Storage/" "$QC_DST/Local Storage/" 2>/dev/null
    fi
    # openclaw 数据
    if [ -d "$QC_SRC/openclaw" ]; then
        rsync -a "$QC_SRC/openclaw/" "$QC_DST/openclaw/" 2>/dev/null
    fi
    log "QClaw 已同步"
else
    log "QClaw 目录不存在，跳过"
fi

# 4. AutoClaw — Local Storage
AC_SRC="$HOME/Library/Application Support/autoclaw"
AC_DST="$BACKUP_ROOT/autoclaw"
if [ -d "$AC_SRC" ]; then
    if [ -d "$AC_SRC/Local Storage" ]; then
        rsync -a "$AC_SRC/Local Storage/" "$AC_DST/Local Storage/" 2>/dev/null
    fi
    # Preferences
    if [ -f "$AC_SRC/Preferences" ]; then
        cp "$AC_SRC/Preferences" "$AC_DST/Preferences-${TIME}" 2>/dev/null
    fi
    log "AutoClaw 已同步"
else
    log "AutoClaw 目录不存在，跳过"
fi

# 5. Coze — 网页端，通过豆包的 IndexedDB 备份
DDB_SRC="$HOME/Library/Containers/com.bot.neotix.doubao/Data/Library/Application Support/Doubao/Default/IndexedDB"
CZ_DST="$BACKUP_ROOT/coze"
if [ -d "$DDB_SRC" ]; then
    rsync -a "$DDB_SRC/" "$CZ_DST/IndexedDB/" 2>/dev/null
    log "Coze/Doubao IndexedDB 已同步"
else
    log "Coze/Doubao 数据目录不存在，跳过"
fi

# 清理日志，只保留最近 30 天
if [ -f "$LOG_FILE" ]; then
    tmp=$(mktemp)
    awk -v cutoff="$(date -v-30d '+%Y-%m-%d')" '$0 >= "["cutoff' "$LOG_FILE" > "$tmp"
    mv "$tmp" "$LOG_FILE"
fi

log "===== 归档完成 ====="
