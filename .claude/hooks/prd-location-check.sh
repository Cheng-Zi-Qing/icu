#!/bin/bash
# PRD 文件位置检查 Hook

# 正确的 PRD 目录
CORRECT_PRD_DIR="$HOME/Documents/Obsidian Vault/个性项目/icu/prd"

# 检查是否在操作 PRD 文件
if echo "$CLAUDE_TOOL_INPUT" | grep -q "prd.*\.md"; then
    # 提取文件路径
    FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | grep -o '"file_path"[^"]*"[^"]*"' | cut -d'"' -f4)

    # 检查是否在正确目录
    if [[ -n "$FILE_PATH" && "$FILE_PATH" != "$CORRECT_PRD_DIR"* ]]; then
        echo "❌ 错误：PRD 文件必须在 Obsidian Vault 目录"
        echo "正确位置：$CORRECT_PRD_DIR"
        echo "当前位置：$FILE_PATH"
        exit 1
    fi
fi

exit 0
