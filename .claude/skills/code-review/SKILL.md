---
name: code-review
description: "审查当前改动（工作区 diff / PR）是否符合本项目编码标准——GDScript 静态类型、热路径零分配、UI 不持有游戏状态、数值数据驱动、命名规范、测试。输出按严重度排序的结构化问题清单（文件:行号 + 建议）。"
argument-hint: "[可选：要审查的文件或范围]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

当此技能被调用时：

1. **确定范围**：用 `git diff` / `git status` 取当前改动（或用户指定文件/范围）。

2. **对照项目标准逐项检查**（CLAUDE.md 引用的规则）：
   - 编码标准（`.claude/docs/coding-standards.md`）：公共 API 有文档注释 / 数值数据驱动（⛔ 硬编码伤害·血量）/ 依赖注入优于单例 / 验证驱动。
   - 技术偏好（`.claude/docs/technical-preferences.md`）：命名（类 PascalCase / 变量·函数 snake_case / 信号过去时 / 常量 UPPER_SNAKE）/ ⛔ 无类型变量·数组 / ⛔ 子调父（Signal Up, Call Down）。
   - 引擎代码（`.claude/rules/engine-code.md`）：热路径零分配（预分配/池化/复用）/ ⛔ `_process`·`_physics_process` 里 `get_node`/组查询 / 引擎不依赖游戏逻辑。
   - UI 代码（`.claude/rules/ui-code.md`）：UI 不持有/改游戏状态（命令/事件）/ 文本走本地化 / ⛔ 全屏滤镜 / 键鼠+手柄 / 动画可跳过 / 无障碍。
   - 测试（`.claude/rules/test-standards.md`）：命名 `test_[系统]_[场景]_[预期]` / Arrange-Act-Assert / 缺陷修复带回归测试。

3. **输出结构化清单**：按 🔴严重 / 🟡建议 / 🟢可选 分级，每条带 `文件:行号` + 问题 + 修复建议；先给摘要计数再列明细。

4. **不擅自改代码**：只审查报告；是否修、怎么修由用户定（除非用户明确要顺手修）。

> 注：本项目=1v1 同时回合制像素游戏·BattleCore 单核·"轻流程化个人项目"阶段；审查别为治理过度上纲。
