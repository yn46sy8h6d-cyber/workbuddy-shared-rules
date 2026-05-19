# Hermes 配置验收清单

> 生成时间：2025-05-19 16:13
> 用途：验收上午（2025-05-19）Hermes 全部配置修改是否生效
> 执行者：ClaudeCode / 任何 Agent

---

## 验收总览

| # | 检查项 | 期望值 | 状态 |
|---|---|---|---|
| 1 | 主模型 (model.default) | deepseek-v4-flash | ⬜ |
| 2 | 主模型 provider | openai | ⬜ |
| 3 | 主模型 base_url | https://api.deepseek.com/v1 | ⬜ |
| 4 | 主模型 api_key | 非空且有效 | ⬜ |
| 5 | vision 模型 | deepseek-v4-flash（或支持视觉的模型） | ⬜ |
| 6 | vision api_key | 非空 | ⬜ |
| 7 | vision base_url | https://api.deepseek.com/v1 | ⬜ |
| 8 | auxiliary compression 模型 | deepseek-v4-flash | ⬜ |
| 9 | auxiliary mcp 模型 | deepseek-v4-flash | ⬜ |
| 10 | auxiliary skills_hub 模型 | deepseek-v4-flash | ⬜ |
| 11 | auxiliary session_search 模型 | deepseek-v4-flash | ⬜ |
| 12 | auxiliary title_generation 模型 | deepseek-v4-flash | ⬜ |
| 13 | auxiliary flush_memories 模型 | deepseek-v4-flash | ⬜ |
| 14 | 微信 (weixin.enabled) | false（已禁用，方案A用Web UI） | ⬜ |
| 15 | QQBot (qqbot.enabled) | false | ⬜ |
| 16 | Webhook (webhook.enabled) | true | ⬜ |
| 17 | API Server (api_server.enabled) | true, port 8642 | ⬜ |
| 18 | providers.deepseek.api_key | 有效 DeepSeek key | ⬜ |
| 19 | providers.minimax.api_key | 有效 MiniMax key | ⬜ |
| 20 | .env DASHSCOPE_API_KEY | 通义千问 key（备用） | ⬜ |
| 21 | .env GLM_API_KEY | 智谱 key（已配置） | ⬜ |
| 22 | .env MINIMAX_API_KEY | MiniMax key（已配置） | ⬜ |
| 23 | .env OPENROUTER_API_KEY | OpenRouter key（已配置） | ⬜ |
| 24 | Gateway 进程 | 运行中 | ⬜ |
| 25 | Gateway API (8642) | health ok | ⬜ |
| 26 | WebUI 进程 | 运行中（端口 9999 或其他） | ⬜ |
| 27 | config.yaml 文件权限 | 可读写（无 uchg 锁） | ⬜ |
| 28 | system_prompt | 包含 SMART_RULES / 图片识别规则 | ⬜ |

---

## 执行步骤

### Step 1: 读取 config.yaml 并逐项比对

```bash
# 读取完整 config
cat ~/.hermes/config.yaml
```

对以上 28 项逐一核对，标记 ✅ PASS 或 ❌ FAIL。

### Step 2: 读取 .env 并验证关键 Key

```bash
# 检查关键 key 是否存在且非空
grep -E '(DASHSCOPE_API_KEY|GLM_API_KEY|MINIMAX_API_KEY|OPENROUTER_API_KEY)' ~/.herms/.env
```

### Step 3: 进程和端口检查

```bash
# Hermes Gateway
ps aux | grep "hermes_cli.main gateway" | grep -v grep

# API Health
curl -s http://localhost:8642/health

# WebUI
ps aux | grep "hermes-web-ui" | grep -v grep

# 文件权限
ls -laO@ ~/.hermes/config.yaml
```

### Step 4: 功能性冒烟测试（可选）

```bash
# 测试主模型是否能正常调用
curl -s http://localhost:8642/health

# 如果有 chat API，可以发一条简单消息测试
# curl -X POST http://localhost:8642/api/chat ...
```

---

## 输出格式

请按以下格式输出验收报告：

```markdown
## 验收报告

**执行时间**: [时间]
**执行者**: [Agent 名称]

### 总览
- 通过：X/28
- 失败：Y/28
- 跳过：Z/28

### PASS 列表
| # | 项目 | 实际值 |

### FAIL 列表
| # | 项目 | 期望值 | 实际值 | 原因分析 |

### 建议操作（针对 FAIL 项）
[每项给出修复建议]
```

---

## 已知问题记录（供参考）

1. **vision 配置曾被清空** — 2025-05-19 下午发现 auxiliary.vision 的 api_key/model/base_url 全为空，已于 16:08 修复写入 DeepSeek 配置
2. **config.yaml 曾被 macOS uchg 锁定** — 文件被设为 immutable flag，导致所有写入失败。已于 16:07 解锁
3. **微信通道已禁用** — weixin.enabled = false，当前使用 Web UI 方案
4. **clawbot 未设置好** — 微信/Clawbot 通道尚未完成配置

---

*此文件位于 ~/.workbuddy/shared/verify-hermes-20250519.md*
*ClaudeCode 可以直接读取此文件并执行验收*
