# h08「不坠神言」一回合保留 Implementation Plan

> **For agentic workers:** 本计划在当前会话内直接执行；工作树包含其他任务改动，不提交、不暂存、不改动无关文件。

**Goal:** 将 h08 的未命中「大防」从永久保留改为仅持续至下一回合结束。

**Architecture:** 保留现有队伍级布尔状态 `retained_big_defend`，新增到期回合 `retained_big_defend_until_turn`。空放大防时记录 `turn_number + 1`；状态在该回合完整结算期间仍有效，若没有挡住攻击且没有被新一次空放大防刷新，则在回合末清除。

**Tech Stack:** Godot 4、GDScript、GUT、BattleCore 快照、CSV i18n。

## Global Constraints

- 正式文案固定为：`鬼金【羊】的「大防」未挡到攻击时，由我方保留至下一回合结束。`
- 当前回合的「防 / 大防」仍优先于保留大防。
- 状态仍属于全队、不可叠加、挡住一次基础攻击后立即消耗。
- 连续空放大防会用新的一次刷新期限，使其持续至再下一回合结束。
- 道具、主动技、反击、毒素与穿大防攻击仍不消费状态。
- 不改 h08 的 6 点生命与防守定位。

---

### Task 1: 锁定到期与刷新行为

**Files:**
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/ai/test_battle_clone_ai.gd`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`
- Modify: `tests/unit/battle/ai/test_battle_eval_v1.gd`

- [x] 增加“下一回合仍可挡招，回合末未使用则到期”的测试。
- [x] 改写“当前防优先”测试，确认普通防挡住波后保留大防会在该回合末到期。
- [x] 增加连续空放刷新到期回合测试。
- [x] 锁定消费、穿透、多段、换人、h04 指定替补等原有边界。
- [x] clone、快照与 AI 估值同时覆盖到期回合。

### Task 2: 实现回合时限

**Files:**
- Modify: `src/battle/battle_core.gd`
- Modify: `src/battle/ai/battle_eval.gd`
- Modify: `src/battle/skills/h08_buzhuishenyan.gd`

- [x] 新增 `retained_big_defend_until_turn: Array[int]` 与 `has_retained_big_defend(player)`。
- [x] 同步 setup、clone、快照 schema、导出与恢复，并提升快照版本。
- [x] 空放时设置 `turn_number + 1`；消费时同时清除布尔状态和期限。
- [x] 在 Phase 4.8 清除本回合到期但未被刷新/消费的状态。
- [x] AI 状态资产只在有效期内计入保留大防。

### Task 3: 同步所有当前真相源

**Files:**
- Modify: `assets/data/heroes/h08.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/heroes.md`（暗批局部内容已并入主英雄文档）
- Modify: `design/heroes-schools.md`
- Modify: `design/gdd/game-concept.md`
- Modify: `design/items.md`
- Modify: `design/naming-bank.md`

- [x] 所有现行文案改为“保留至下一回合结束”。
- [x] 删除现行“永久、直到挡住、后续回合一直存在”的说明；历史计划保留。

### Task 4: 验证

- [x] 运行 Godot Import（exit 0）。
- [x] 运行完整 GUT：h08 与战斗核心相关测试全部通过；全套 592/593，唯一失败为无关的 Scene2 层级断言。
- [x] 全局扫描旧文案，只允许历史计划命中。
- [x] 运行 `git diff --check` 并确认未覆盖无关改动。
