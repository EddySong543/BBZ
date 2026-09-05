# 锁泉塞与回照镜 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实装两件已批准T2道具，并同步全部运行时、玩家表层与真相源。

**Architecture:** 锁泉塞使用 `item_buffs` 保存目标回合，由统一 `_gain_energy` 入口判定；回照镜通过 ItemEffect 的纯查询充能接口，在天罗裁定后由核心按敌方提交顺序过滤敌向道具。复用现有快照、克隆与本地权威提交结构，不扩展额外字段。

**Tech Stack:** Godot 4.7、GDScript、GUT、现有 BattleCore/ItemEffect/ItemCatalog。

## Global Constraints

- 玩家文案逐字采用用户批准版本，不增加隐藏条件。
- “攻击/命中/道具伤害”边界保持现状。
- 不修改英雄机制，不做无关重构，不commit或push。
- 正式池计数更新为79=T1 30/T2 32/T3 17。

---

### Task 1: 核心失败测试

**Files:**
- Modify: `tests/unit/battle/v4/test_items_t2_expansion.gd`

**Interfaces:**
- Consumes: `BattleCore._gain_energy`, `BattleCore.resolve`, `BattleCore.use_item`。
- Produces: 锁泉塞时序与回照镜过滤行为的回归断言。

- [ ] 写锁泉塞当前回合/下回合/恢复、圣贤书和重复件测试。
- [ ] 写回照镜敌向/自向、伤害、双镜、双方镜与槽消耗测试。
- [ ] 运行全量GUT并确认新增断言在实现前失败。

### Task 2: 核心与道具脚本

**Files:**
- Modify: `src/battle/item_effect.gd`
- Modify: `src/battle/battle_core.gd`
- Create: `src/battle/items/t2_suoquan_sai.gd`
- Create: `src/battle/items/t2_huizhao_jing.gd`

**Interfaces:**
- Produces: `ItemEffect.hostile_item_counter_charges() -> int`；`BattleCore`对下一回合禁得能和敌向道具反制的权威结算。

- [ ] 为ItemEffect增加无状态反制充能查询。
- [ ] 在 `_gain_energy` 收口锁泉塞时序，不触碰花费与交换。
- [ ] 在天罗裁定后、普通道具预设前按提交序过滤被反制道具并发事件。
- [ ] 实现两件无状态脚本与圣贤书兼容。
- [ ] 运行新增核心测试直至通过。

### Task 3: 目录、AI与玩家表层

**Files:**
- Modify: `src/battle/item_catalog.gd`
- Modify: `src/battle/ai/battle_ai.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/unit/battle/ai/test_battle_ai_items.gd`
- Modify: `tests/unit/ui/test_battle_item_target_selection.gd`

**Interfaces:**
- Consumes: `item_buffs.energy_gain_lock_turn` 与 `item_countered` 事件。
- Produces: AI防浪费、头像悬停状态与反制提示。

- [ ] 加入两件T2定义、拼音顺序和ev=4。
- [ ] AI避免同拍重复使用锁泉塞，并只在敌方有敌向道具时使用回照镜。
- [ ] 头像悬停显示禁得能期限，结算事件显示“反制”。
- [ ] 补目录、AI和UI断言。

### Task 4: 文档、i18n与占位资产

**Files:**
- Modify: `design/items-firstrelease.md`
- Modify: `design/items-list.md`
- Modify: `design/items.md`
- Modify: `design/build-design-framework.md`
- Modify: `design/gdd/game-concept.md`
- Modify: `docs/architecture/ADR-003-item-system.md`
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `assets/sprites/items/README.md`
- Modify: `assets/sprites/items/_name_id_map.md`
- Create: `assets/sprites/items/锁泉塞.png`
- Create: `assets/sprites/items/回照镜.png`

- [ ] 同步79/130计数和两件正式文案。
- [ ] 以现有占位图生成两张可导入PNG并重建名称映射。
- [ ] 运行i18n扫描与图标审计。

### Task 5: 最终验证

**Files:**
- Test: `tests/unit/battle/v4/test_items_t2_expansion.gd`
- Test: `tests/unit/battle/ai/test_battle_ai_items.gd`
- Test: `tests/unit/ui/test_battle_item_target_selection.gd`

- [ ] 运行Godot Import并检查无Parse Error。
- [ ] 运行全量GUT并区分本任务失败与既有Scene失败。
- [ ] 运行1920×1080状态与反制事件探针。
- [ ] 运行`git diff --check`并确认无临时探针残留。
