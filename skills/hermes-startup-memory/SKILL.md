# Hermes Startup Memory Loader

## 触发条件
Hermes 每次新会话开始时自动执行。

## 执行步骤

### 1. 读取索引
读取 `~/.hermes/memory/INDEX.md`，了解有哪些记忆文件。

### 2. 按需加载
根据当前会话上下文，按需读取：
- `~/.hermes/memory/cli-rules.md` — CLI会话规则
- `~/.hermes/memory/user-prefs.md` — 用户偏好
- `~/.hermes/memory/project-status.md` — 项目状态
- `~/.hermes/memory/system-config.md` — 系统配置

### 3. 读取最近会话存档
检查 `~/.hermes/cli-sessions/` 下最近的文件，读取最后一轮对话摘要。

### 4. 向用户报告
输出：
```
📚 外部记忆已加载：
- 用户偏好：<简述>
- 最近项目：<简述>
- 上次会话：<时间> <摘要>
```

## 注意事项
- 不要加载全部文件，按当前会话需要选择
- 如果 INDEX.md 不存在，告知用户
- 如果最近的 cli-sessions 有未完成事项，标记出来
