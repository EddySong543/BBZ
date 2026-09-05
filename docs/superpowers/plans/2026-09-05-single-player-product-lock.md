# 单机产品线收束 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前产品线固定为单机 PvE，并移除项目内不再服务当前产品的多人扩展入口、规则、代理配置和失效引用。

**Architecture:** 保留 BattleCore、敌方 AI、远征和本地 UI；删除仅服务多人扩展的运行时边界与项目代理配置。旧物品素材、旧物品目录和旧物品代码属于后续物品任务，本计划明确不处理。

**Tech Stack:** Godot 4、GDScript、GUT、Markdown、CSV、本地项目代理配置。

## Global Constraints

- 当前产品只保留单机 PvE 入口和实现。
- 不改变 BattleCore、远征、敌方 AI、英雄、道具运行时行为。
- `design/items.md`、`design/items-list.md`、`design/items-firstrelease.md`、`src/battle/item_catalog.gd` 和 `assets/sprites/items/` 按任务 4 保留。
- 不删除 `ref/`、`res/` 或 Godot `.godot/` 缓存。
- 删除后必须复核死引用、导入、i18n 和测试结果。

---

### Task 1: 清除项目级多人专用代理配置

**Files:**
- Delete: `.claude/agents/network-programmer.md`
- Delete: `.claude/agents/ue-replication-specialist.md`
- Delete: `.claude/rules/network-code.md`
- Modify: `.claude/docs/agent-roster.md`
- Modify: `.claude/docs/agent-coordination-map.md`
- Modify: `.claude/agents/gameplay-programmer.md`
- Modify: `.claude/agents/lead-programmer.md`
- Modify: `.claude/agents/technical-director.md`
- Modify: `.claude/docs/rules-reference.md`

- [x] 删除不再适用于本项目的代理与规则文件。
- [x] 从名册、协调图、委派映射和规则索引移除对应条目。
- [x] 保留 AI、引擎、UI、工具和本地存档相关职责。

### Task 2: 清除纯多人引擎参考与历史计划残留

**Files:**
- Delete: `docs/engine-reference/godot/modules/networking.md`
- Modify: `docs/superpowers/plans/2026-08-09-hero-skill-icons-and-h13-branch.md`
- Modify: `docs/superpowers/plans/2026-08-09-h23-energy-cap.md`
- Modify: `docs/WORKFLOW-GUIDE.md`

- [x] 删除纯多人 API 参考页。
- [x] 将旧计划中的测试和协议表述改为本地 BattleCore / snapshot / AI 测试。
- [x] 从通用工作流模板移除本项目不再采用的多人开发入口。

### Task 3: 统一当前文档与历史交接口径

**Files:**
- Modify: `docs/README.md`
- Modify: `design/gdd/game-concept.md`
- Modify: `docs/reports/2026-08-31-item-design-complete-retrospective-and-handoff.md`
- Modify: `docs/reports/2026-09-05-item-enemy-design-retrospective-and-handoff.md`

- [x] 当前文档只描述单机 PvE，不保留未启用产品分支的入口描述。
- [x] 历史复盘保留设计结论，但去除会被误读为当前架构的多人实现语义。
- [x] 旧物品条目与历史设计保留；仅移除其中的旧多人分支语义，不重做物品机制。

### Task 4: 复核与验证

**Files:**
- Verify: current source, tests, tools, assets, design and docs trees.

- [x] 扫描旧入口、网络类名、专用资源名和失效路径。
- [x] 运行 `git diff --check`。
- [x] 运行 i18n 扫描和 Godot 导入。
- [x] 运行受影响的定向测试，并记录全量测试中的既有基线失败。
