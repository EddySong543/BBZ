#!/bin/bash
# Claude Code SubagentStart 钩子: 记录代理(Agent)调用以生成审计追踪
# 跟踪哪些代理(Agent)正在被使用以及何时使用
#
# 输入格式 (SubagentStart):
# { "agent_id": "agent-abc123", "agent_name": "game-designer", ... }

INPUT=$(cat)

# 解析代理(Agent)名称 -- 优先使用 jq，退回使用 grep
if command -v jq >/dev/null 2>&1; then
    AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null)
else
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"agent_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"agent_name"[[:space:]]*:[[:space:]]*"//;s/"$//')
    [ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_DIR="production/session-logs"

mkdir -p "$SESSION_LOG_DIR" 2>/dev/null

echo "$TIMESTAMP | 代理(Agent)调用: $AGENT_NAME" >> "$SESSION_LOG_DIR/agent-audit.log" 2>/dev/null

exit 0
