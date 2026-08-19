# h10「太初万法剑」全局名称迁移 Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve all unrelated working-tree changes.

**Goal:** 在不改变 h10 数值、机制、技能描述与图标资产的前提下，将已确认技能名全局迁移为「太初万法剑」。

**Architecture:** HeroData 是玩家可见名称真相源；中文索引、设计文档、技能脚本注释、预载路径、测试标识与引用该路径的历史计划同步更新。技能脚本及 UID 一并改名，保持 Godot 资源身份不变。

**Tech Stack:** Godot Resource、GDScript、CSV、Markdown

## Global Constraints

- 仅修改 h10 技能名称及其派生标识。
- 保留剑气、拔剑一闪、费用、HP、定位、玩家文案与 icon。
- 保留工作区内其他任务的未提交改动。
- 不执行 commit 或 push。

## Tasks

- [x] 将 HeroData、中文索引和两份英雄文档统一为「太初万法剑」。
- [x] 将技能脚本及 UID 迁移为 `h10_taichuwanfa`，同步预载路径、注释、测试名与历史路径引用。
- [x] 扫描旧技能名与旧路径残留。
- [x] 运行 Godot 导入、相关战斗测试和 `git diff --check`。
