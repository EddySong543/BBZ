# Combat Copy Terminology Implementation Plan

> ⚠️ **历史实施计划。**其中 H03“攻击优先结算”文案与机制已于 2026-08-30 退役，正文只作当时术语迁移记录；当前 H03 规则见 [`2026-08-30-h03-sequence-shift-design.md`](../specs/2026-08-30-h03-sequence-shift-design.md)。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 固定“攻击／伤害／成功防御”的玩家文案含义，并把 h02、h03、h04 的技能小字缩短为已批准版本，不改变任何战斗机制。

**Architecture:** `design/copy-style-guide.md` 作为术语与写法基准；英雄 `.tres` 作为游戏内技能文案真相源；`design/heroes.md`、i18n 与资源断言测试逐项镜像。完整机制边界继续保留在英雄重设计文档、技能脚本和行为测试中，不塞回玩家小字。

**Tech Stack:** Godot 4 Resource、GDScript/GUT、Markdown、CSV i18n。

## Global Constraints

- “攻击”仅指英雄使用基础动作「波」或「大波」。
- “成功防御”仅指「防」或「大防」完整挡下一次攻击。
- “伤害”是结果概念，可来自攻击、主动技能、道具、反击或持续效果。
- 独立主动技能和独立道具伤害不属于“攻击”；附着在攻击上的附加效果随该次攻击结算。
- h02、h03、h04 只改玩家可见文案，不改现行机制。
- 不修改 h04 的常驻被动形态，不增加能量费用。
- 不 commit、不 push。

---

### Task 1: 固定术语与文案基准

**Files:**
- Modify: `design/copy-style-guide.md`
- Modify: `design/heroes-schools.md`

- [ ] **Step 1: 在统一术语中定义攻击、防御与伤害**

写明“攻击”只等于「波／大波」，“成功防御”只等于完整挡下攻击，“伤害”包含更广来源；明确独立主动技和独立道具伤害不属于攻击。

- [ ] **Step 2: 更新 h02–h04 范例**

使用三条已批准文案，并注明短文案依赖统一术语，复杂边界进入规则说明而非技能小字。

### Task 2: 同步发布文案

**Files:**
- Modify: `tests/unit/battle/v4/test_hero_team_role.gd`
- Modify: `assets/data/heroes/h02.tres`
- Modify: `assets/data/heroes/h03.tres`
- Modify: `assets/data/heroes/h04.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/heroes.md`

- [ ] **Step 1: 先更新发布文案断言**

锁定：

```text
牛金【牛】成功防御时，我方下一次的「波」升级为「大波」。
双方同时攻击时，尾火【虎】的攻击优先结算。
房日【兔】的攻击可以指定任意一名敌方英雄。
```

- [ ] **Step 2: 同步资源、i18n 与英雄文档**

逐字使用测试中的三条文案；不修改技能名、HP、定位或脚本。

### Task 3: 验证

**Files:**
- Verify only

- [ ] **Step 1: 扫描旧玩家文案**

确认旧长句不再出现在 `.tres`、i18n、`design/heroes.md`、文案规范和发布数据测试中。

- [ ] **Step 2: 运行 Godot 导入与完整 GUT**

```powershell
& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

- [ ] **Step 3: 差异检查**

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo diff --check
```
