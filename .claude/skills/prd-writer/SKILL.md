---
name: prd-writer
description: 生成/修改 icu 项目的 PRD 文档
argument-hint: "[PRD 主题，如：PRD 1.0 用户认证模块]"
allowed-tools: Read, Write, Edit, Bash
---

# PRD 文档编写

你是 icu 项目的 PRD 文档助手。

## 文档主题

$ARGUMENTS

## 目录结构

```
~/Documents/Obsidian Vault/个性项目/icu/prd/
```

## 文件命名

格式：`prd-{版本号}-{简述}.md`
示例：`prd-1.0-用户认证.md`

## 删除线留痕规范

**所有对已有文档的修改，必须用删除线保留原文，新内容写在下方。**

格式：
```markdown
~~原文内容~~ ← {日期} {修改原因}
新的正确内容
```

## 写作风格

- 中文为主，技术术语保留英文
- 参数名用 `code` 格式
- 对比用表格
- Obsidian callout: `> [!warning]` / `> [!info]` / `> [!note]`

## 流程

1. 从 `$ARGUMENTS` 提取版本号和主题
2. 用 Read 工具加载模板：`.claude/skills/prd-writer/templates/prd.md`
3. `ls` 检查目标目录，确认文件名不冲突
4. 修改已有文档前先完整读取原文
5. 按模板结构生成/修改文档
