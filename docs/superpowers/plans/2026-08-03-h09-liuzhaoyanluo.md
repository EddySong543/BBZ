# h09「六爪阎罗」全局名称迁移 Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve all unrelated working-tree changes. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变 h09 数值、机制、玩家文案与图标资产的前提下，将已确认技能名全局迁移为「六爪阎罗」。

**Architecture:** HeroData 是玩家可见名称真相源；中文索引、设计文档、技能脚本注释、技能预载路径与测试标识同步更新。技能脚本及其 UID 一并改名，保持 Godot 资源身份与运行时逻辑不变。

**Tech Stack:** Godot Resource、GDScript、CSV、Markdown

## Global Constraints

- 仅修改 h09 技能名称及其派生标识，不调整 HP、定位、技能逻辑、技能描述或 icon。
- 保留工作区内其他任务的未提交改动。
- 不执行 commit 或 push。

---

### Task 1: 迁移玩家可见名称

**Files:**
- Modify: `assets/data/heroes/h09.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`

- [x] **Step 1: 将 h09 技能名统一为「六爪阎罗」**

---

### Task 2: 迁移派生代码标识

**Files:**
- Rename: `src/battle/skills/h09_liezhao.gd` → `src/battle/skills/h09_liuzhaoyanluo.gd`
- Rename: `src/battle/skills/h09_liezhao.gd.uid` → `src/battle/skills/h09_liuzhaoyanluo.gd.uid`
- Modify: `src/battle/battle_core.gd`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `docs/superpowers/plans/2026-08-03-h09-doc-alignment.md`

- [x] **Step 1: 同步脚本文件名、预载路径、注释、测试名与历史计划路径**

---

### Task 3: 验证

**Files:**
- Verify only.

- [x] **Step 1: 扫描旧技能名与旧派生标识残留**
- [x] **Step 2: 运行 h09 针对性 GUT 测试**
- [x] **Step 3: 运行 `git diff --check`**
