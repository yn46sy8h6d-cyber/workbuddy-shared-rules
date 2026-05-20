#!/bin/bash
# 开机自动打开公众号和视频号平台
# 等待网络就绪后打开，浏览器会自动使用已保存的密码和 Cookie

# 等待网络连接就绪（最多等 60 秒）
for i in $(seq 1 30); do
    if ping -c 1 -q weixin.qq.com &>/dev/null; then
        break
    fi
    sleep 2
done

sleep 3  # 额外等几秒确保网络稳定

# 打开公众号管理后台
open -a "Chromite Browser" "https://mp.weixin.qq.com"

sleep 2

# 打开视频号管理后台
open -a "Chromite Browser" "https://channels.weixin.qq.com/platform"
