# h09 现行机制资料对齐 Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve all unrelated working-tree changes. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 保留 h09 当前机制与玩家文案，只把旧设计资料和代码注释统一为“造成伤害时，移除敌方等量能量”。

**Architecture:** 不修改技能脚本行为、HeroData 玩家文案、HP 或旧 UI 三分类字段。仅修订现行设计说明与已经把 h09 误写成旧切换技能的注释，并用精确扫描确认旧说法不再冒充当前规则。

**Tech Stack:** Godot Resource、GDScript 注释、Markdown

## Global Constraints

- 玩家文案保持：`紫火【猴】对敌方造成伤害时，移除敌方等量的能量。`
- 当前机制保持：实际造成 1 点伤害移除 1 点能量，实际造成 2 点伤害移除 2 点能量；移除的能量不进入我方能量池。
- 新五类主定位为控制；旧 `HeroData.team_role` 分类字段不再作为当前 UI 依据。
- 不修改 HP、技能逻辑、技能名或 icon 资产。
- 用户未要求 commit 或 push，本计划不执行 Git 提交。

---

### Task 1: 对齐 h09 设计说明

**Files:**
- Modify: `design/heroes-redesign.md`

**Interfaces:**
- Consumes: `src/battle/skills/h09_liuzhaoyanluo.gd` 的现行按伤害等量削能行为。
- Produces: 与运行时一致的主定位、机制、combo、限制与设计依据。

- [x] **Step 1: 将固定削能旧说明改为按实际伤害等量削能**

- [x] **Step 2: 补充加伤、额外命中与压缩敌方费能动作的 combo 说明**

- [x] **Step 3: 删除“另存设计、待核对”旧状态，记录机制已获保留**

---

### Task 2: 清理过时的 h09 切换能力引用

**Files:**
- Modify: `docs/architecture/ADR-002-battle-core-v4-architecture.md`
- Modify: `docs/architecture/battlecore-risk-notes.md`
- Modify: `src/battle/hero_skill.gd`
- Modify: `src/battle/skills/h11_yingshou.gd`
- Modify: `src/battle/skills/h18_chanrao.gd`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`

**Interfaces:**
- Consumes: h09 当前为命中削能英雄，不再拥有旧版强制切换或连段状态。
- Produces: 当前切换示例改用 h21 枭阳或通用强制切换来源；测试标题不再使用废弃技能别名。

- [x] **Step 1: 删除架构资料中的 h09 旧连段与切换分支示例**

- [x] **Step 2: 将强制切换注释改为当前有效来源**

- [x] **Step 3: 将测试分组标题改为不依赖待重命名技能的中性说明**

---

### Task 3: 验证

**Files:**
- Verify only.

**Interfaces:**
- Consumes: Tasks 1–2 的全部变更。
- Produces: 玩家文案未变、旧引用清零、补丁格式有效的证据。

- [x] **Step 1: 精确检查 h09 HeroData 与 CSV 文案保持不变**

- [x] **Step 2: 扫描废弃的固定削能和旧强制切换说法**

- [x] **Step 3: 对本轮文件运行 `git diff --check`**
