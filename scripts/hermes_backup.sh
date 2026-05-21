#!/bin/bash
# hermes_backup.sh - 阿里云盘备份脚本
# 备份 ~/.hermes/ (4.7GB) + ~/.codex/ (161MB)
# 需要先登录阿里云盘: ~/Applications/aliyunpan login

ALIYUNPAN=~/Applications/aliyunpan
BACKUP_DIR="/备份/Hermes_$(date +%Y%m%d)"

echo "=== Hermes/Codex → 阿里云盘 备份 ==="
echo ""

# 检查是否已登录
$ALIYUNPAN who 2>/dev/null | grep -q "登录" || {
    echo "⚠ 未登录阿里云盘，请先运行:"
    echo "  $ALIYUNPAN login"
    exit 1
}

echo "📦 正在备份 ~/.hermes/ ..."
$ALIYUNPAN upload -n 3 ~/.hermes "$BACKUP_DIR/hermes/" 2>&1 | tail -3

echo ""
echo "📦 正在备份 ~/.codex/ ..."
$ALIYUNPAN upload -n 3 ~/.codex "$BACKUP_DIR/codex/" 2>&1 | tail -3

echo ""
echo "✅ 备份完成!"
echo "   远程路径: $BACKUP_DIR"
