# Agent 协作规范（全局规则）

> 位置：`~/.workbuddy/shared/AGENT_RULES.md`
> 最后更新：2026-05-19 18:34
> **所有本地 Agent 必须遵守**

---

## 🤝 交叉验证机制（防 Hermes 自欺欺人）

### 原则
Hermes 有持续幻觉倾向（已记录）。**任何 Agent 修改了 Hermes 配置后，必须由第三方验证。**

### 触发条件（自动触发）
以下情况必须启动交叉验证：
1. 修改 `~/.hermes/config.yaml`
2. 修改 `~/.hermes/.env`
3. 修改 Hermes 的 system_prompt
4. Hermes 报告"配置修改成功"但功能异常时
5. 用户要求验收时

### 验证流程
```
操作者 Agent（Hermes/WorkBuddy/Codex）
  → 写验收清单到 ~/.workbubby/shared/verify-{任务名}-{日期}.md
  → 通知验证者 Agent（ClaudeCode）读取并执行
  → 验证者 输出报告到 ~/.workbuddy/shared/report-{任务名}-{日期}.md
  → 操作者 读取报告，确认通过或修复 FAIL 项
```

### 当前 Agent 能力矩阵

| Agent | 擅长 | 不擅长 | 可调用 |
|---|---|---|---|
| WorkBuddy (Auto/我) | 系统运维、文件操作、调度 | 不确定（我是执行者） | execute_command, 文件读写, Codex exec |
| Claude Code | 代码审查、配置校验、逻辑分析 | 系统命令执行需确认 | 通过 CLI 手动触发 |
| Codex | 代码编写、文件修改 | 中文 prompt 受限 | codex exec（无空格限制） |
| Hermes | 微信交互、自主任务执行 | ⚠️ 有幻觉倾向，不可信 | Gateway API |

## ⚠️ config.yaml 操作安全规范

### uchg 锁问题
- **现象**: QClaw/Hermes 写入 config.yaml 后，文件会被 macOS 加 uchg（不可变）锁
- **症状**: 所有后续写入报 `Operation not permitted`
- **解锁**: `chflags nouchg ~/.hermes/config.yaml`
- **规则**:
  1. 改之前：先解锁
  2. 改之后：验证内容 + 保持解锁
  3. 不要依赖 hermes config set CLI（它也会触发锁）

### 改后验证模板
```python
import yaml
with open('/Users/iii/.hermes/config.yaml') as f:
    c = yaml.safe_load(f)
# 检查关键项
v = c.get('auxiliary',{}).get('vision',{})
assert v.get('api_key') != '', 'FAIL: vision api_key empty'
assert c['model']['default'] == 'deepseek-v4-flash', 'FAIL: wrong model'
print('Config OK ✅')
```

## 🔒 防 Hermes 自改配置

### 问题
Hermes 的 system_prompt 中写了「禁止修改 config.yaml」，但这只是 prompt 层面的约束。
Hermes 如果产生幻觉或被 prompt injection，可能自行修改配置。

### 防护层（由外到内）

| 层级 | 措施 | 有效性 |
|---|---|---|
| L1: Prompt 规则 | system_prompt 写明禁止 | 🟡 弱（可被绕过） |
| L2: 文件权限 | uchg 只读保护 | 🟢 强（但影响协作） |
| L3: 交叉验证 | 改后必须第三方验收 | ✅ **最强（推荐）** |
| L4: Git 版本控制 | config.yaml 纳入 git，变更可追踪 | ✅ 强（可回滚） |
| L5: 定期巡检 | 定时对比 config 快照，异常告警 | ✅ 强（主动发现） |

### 推荐：L3 + L4 组合
1. **每次改配置必须有另一个 Agent 验收**
2. **config.yaml 加入 git 仓库**，每次修改留痕
3. 如果 Hermes 自行修改了 config 且没有验证报告 → **视为异常事件**

---

*此文件是全局共享规则。所有 Agent 在操作前应阅读。*
*备份位置：见下方存储策略*
