# h08 不坠神言 Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve all unrelated working-tree changes. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 h08 鬼金【羊】从旧版替补回血重做为【不坠神言】：其未挡到基础攻击的「大防」由队伍保留，直到实际挡住一次「波」或「大波」。

**Architecture:** 复用 BattleCore 现有防御门，不另建伤害旁路。新增队伍级持久状态 `retained_big_defend`；当前回合选择的防御先结算，只有它未能挡下基础攻击时才由保留大防补位并消耗。HeroSkill 只提供无状态能力声明，持久状态进入 clone 与快照。

**Tech Stack:** Godot 4.7、GDScript、GUT、Godot Resource、CSV、Markdown

## Global Constraints

- 正式文案：`鬼金【羊】的「大防」未挡到攻击时，由我方保留，直到挡住一次攻击。`
- 文案中的“攻击”只指基础「波」和「大波」，不包含道具伤害、主动技、反击、毒素或延迟伤害。
- 保留大防属于队伍，换人后继续存在；不可叠加。
- 当前行动的「防 / 大防」先结算；保留大防只在当前防御未挡住时补位，避免被自动浪费。
- 穿透「大防」的攻击不会消耗保留状态。
- 不修改 h08 HP；不生成或替换图标资产。
- 用户未要求 commit 或 push，本计划不执行 Git 提交。

---

### Task 1: 用测试锁定保留大防契约

**Files:**
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`
- Modify: `tests/unit/battle/ai/test_battle_clone_ai.gd`

**Interfaces:**
- Consumes: `BattleCore.retained_big_defend: Array[bool]`
- Produces: 空放建状态、当前防御优先、跨换人消费、非基础伤害不消费、clone/快照保存的行为锁定。

- [x] **Step 1: 将 h08 旧回血测试替换为不坠神言测试**

覆盖以下场景：

```gdscript
func test_h08_unused_big_defend_is_retained_for_team() -> void
func test_h08_big_defend_that_blocks_attack_is_not_retained() -> void
func test_h08_retained_big_defend_survives_switch_and_blocks_big_wave() -> void
func test_h08_current_defend_blocks_before_retained_big_defend() -> void
func test_h08_retained_big_defend_ignores_non_base_strike() -> void
func test_h08_retained_big_defend_is_nonstacking() -> void
func test_h08_retained_big_defend_protects_reserve_targeted_by_h04() -> void
func test_h08_retained_big_defend_is_not_consumed_by_big_defend_pierce() -> void
func test_h08_retained_big_defend_blocks_every_hit_of_one_base_attack() -> void
```

- [x] **Step 2: 扩充 clone 与快照测试**

在中盘样本中将双方 `retained_big_defend` 设为非默认值；断言 clone 深拷、快照 JSON 往返保持一致，并断言缺失 `retained_big_defend` 的快照被 schema 门拒绝。

- [x] **Step 3: 运行测试确认旧实现失败**

运行：

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

预期：新 h08 / clone / snapshot 断言失败，证明测试能捕获旧机制缺失。

---

### Task 2: 接入既有防御门并删除旧回血旁路

**Files:**
- Modify: `src/battle/hero_skill.gd`
- Modify: `src/battle/battle_core.gd`
- Move: h08 旧技能脚本及其 UID → `src/battle/skills/h08_buzhuishenyan.gd` 及对应 UID

**Interfaces:**
- Produces: `HeroSkill.retains_unused_big_defend() -> bool`
- Produces: `BattleCore.retained_big_defend: Array[bool]`
- Produces events: `buzhui_shenyan_retained`、`buzhui_shenyan_consumed`

- [x] **Step 1: 替换 HeroSkill 声明**

删除仅服务旧 h08 替补治疗的 hook，新增：

```gdscript
func retains_unused_big_defend() -> bool:
	return false
```

- [x] **Step 2: 重写 h08 技能组件**

保留原 UID，文件改为 `h08_buzhuishenyan.gd`，只 override：

```gdscript
func retains_unused_big_defend() -> bool:
	return true
```

- [x] **Step 3: 新增持久状态与原子结算候选**

`retained_big_defend` 进入 setup、clone、快照 schema、导出与恢复；resolve 开始时记录由未沉默 h08 选择的「大防」候选。

- [x] **Step 4: 在防御门中追加保留大防后备判定**

现有 `eff_def` 先判断；若未挡住、`is_base_attack == true`、保留状态存在且攻击未穿透大防，则按 `BIG_DEFEND` 结算、消费状态，并继续走既有 block event / on_block / on_base_attack_blocked 链。

- [x] **Step 5: 在攻击结算后建立未兑现状态**

若 h08 的本回合「大防」没有实际挡住基础攻击，则将团队状态置 true 并发出 `buzhui_shenyan_retained`；重复空放只刷新同一个布尔状态。

- [x] **Step 6: 删除 Phase 5.6 替补回血**

删除旧回血循环、旧 hook 与旧治疗事件，确保运行时不再存在旧机制。

---

### Task 3: 同步名称、文案与全局设计资料

**Files:**
- Modify: `assets/data/heroes/h08.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/heroes-dark-h21-h24.md`
- Modify: `design/heroes-schools.md`
- Modify: `design/gdd/game-concept.md`
- Modify: `design/naming-bank.md`
- Modify: `src/battle/skills/h14_fanzhen.gd`
- Modify: `src/battle/skills/h23_huzhu.gd`

**Interfaces:**
- Produces: 玩家可见名称【不坠神言】与唯一正式文案。

- [x] **Step 1: 更新 HeroData 与 CSV**

保持 HP=6，更新名称和正式文案。

- [x] **Step 2: 更新现行设计文档**

将 h08 定位写为防守 / 团队后备大防；说明羊祭司的祷愿在真正回应一次攻击前不会消散。

- [x] **Step 3: 清理旧机制引用**

全局清除旧技能名、旧脚本名、旧治疗 hook、旧治疗事件及误导性的现行替补治疗说明。

---

### Task 4: 验证

**Files:**
- Verify only.

**Interfaces:**
- Consumes: Tasks 1–3 的全部变更。
- Produces: 可复核的测试与残留扫描结果。

- [x] **Step 1: 全局残留扫描**

用旧版的技能名、脚本名、治疗 hook 与事件名执行全仓精确扫描。

预期：零结果。

- [x] **Step 2: 运行完整 GUT**

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

结果：h08、clone、snapshot 相关测试全部通过。完整套件 574 项中 571 项通过；3 项失败均位于本轮未改动的 Boot / Scene4 UI 测试，按日志精确报告、不越权修改。
