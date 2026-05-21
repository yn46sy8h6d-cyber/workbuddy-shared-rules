#!/bin/bash
# install_clipboard_monitor.sh - 在用户终端环境注册剪贴板监测
# 用法: 在真实 Terminal 中运行: bash ~/.workbuddy/scripts/install_clipboard_monitor.sh

PLIST="$HOME/Library/LaunchAgents/com.modelroute.clipboard.plist"
SCRIPT="$HOME/.workbuddy/scripts/clipboard_monitor.sh"

# 先卸载旧的
launchctl unload "$PLIST" 2>/dev/null

# 确保脚本可执行
chmod +x "$SCRIPT"

# 加载
launchctl load "$PLIST" 2>&1

# 确认运行
sleep 2
if pgrep -f clipboard_monitor > /dev/null; then
    echo ""
    echo "✅ 剪贴板监测已启动！"
    echo ""
    echo "现在去任意 App 选中文字 → ⌘C 复制"
    echo "如果弹出权限请求对话框，请点击「允许」"
else
    echo "⚠ 启动失败，检查: launchctl list | grep modelroute"
fi
