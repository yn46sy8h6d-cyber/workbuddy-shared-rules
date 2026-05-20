#!/bin/bash
# startup.sh - 开机自动打开 Chrome 工作台
# 包含：公众号 + 视频号 + 小红书 + Coze + MiniMax + ChatGLM
# Chrome 会自动保持已登录状态（Cookie 持久化）

echo "🚀 启动 Chrome 工作台..."

# 等待网络就绪（最多 60 秒）
for i in $(seq 1 30); do
    if ping -c 1 -q weixin.qq.com &>/dev/null; then
        break
    fi
    sleep 2
done
sleep 3

# 启动 Chrome（如果未运行）
open -a "Google Chrome" 2>/dev/null
sleep 2

# 工作平台
open -a "Google Chrome" "https://mp.weixin.qq.com/"
sleep 0.5
open -a "Google Chrome" "https://channels.weixin.qq.com/"
sleep 0.5
open -a "Google Chrome" "https://creator.xiaohongshu.com/new/home"
sleep 0.5

# AI 工具
open -a "Google Chrome" "https://www.coze.cn/"
sleep 0.5
open -a "Google Chrome" "https://agent.minimaxi.com/"
sleep 0.5
open -a "Google Chrome" "https://chatglm.cn/main/alltoolsdetail?lang=zh&cid=69671baba335090596335596"
sleep 0.5

echo "✅ Chrome 工作台启动完成：公众号 + 视频号 + 小红书 + Coze + MiniMax + ChatGLM"
