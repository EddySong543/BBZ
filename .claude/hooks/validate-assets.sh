#!/bin/bash
# Claude Code PostToolUse 钩子: Write/Edit 后验证资产文件
# 检查 assets/ 目录中文件的命名规范
# 退出码 0 = 成功 (非阻断，PostToolUse 无法阻断)

HOOK_DIR=$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd)
. "$HOOK_DIR/hook-common.sh"
hook_enter_project || exit 0

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

if ! echo "$FILE_PATH" | grep -qE '(^|/)assets/'; then
    exit 0
fi

FILENAME=$(basename "$FILE_PATH")
WARNINGS=""

if echo "$FILENAME" | grep -qE '[A-Z[:space:]-]'; then
    WARNINGS="$WARNINGS\n命名: $FILE_PATH 必须为小写加下划线 (当前: $FILENAME)"
fi

if echo "$FILE_PATH" | grep -qE '(^|/)assets/data/.*\.json$'; then
    if [ -f "$FILE_PATH" ]; then
        PYTHON_CMD=""
        for cmd in python python3 py; do
            if command -v "$cmd" >/dev/null 2>&1; then
                PYTHON_CMD="$cmd"
                break
            fi
        done
        if [ -n "$PYTHON_CMD" ]; then
            if ! "$PYTHON_CMD" -m json.tool "$FILE_PATH" > /dev/null 2>&1; then
                WARNINGS="$WARNINGS\n格式: $FILE_PATH 不是有效的 JSON"
            fi
        fi
    fi
fi

if [ -n "$WARNINGS" ]; then
    echo -e "=== 资产验证 ===$WARNINGS\n========================" >&2
fi

exit 0
