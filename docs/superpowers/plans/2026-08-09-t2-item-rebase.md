# 稀有道具最终改版 Implementation Plan

> **历史实施计划，禁止作为现行规格继续执行。** 其中点金石升 T3、旧抽取 / 使用经济及旧池数量均已被 [`2026-08-30-item-system-current-standard.md`](../specs/2026-08-30-item-system-current-standard.md) 取代。

> **For agentic workers:** REQUIRED SUB-SKILL: Use bounded subagents by file ownership; shared worktree edits must not overlap.

**Goal:** 将用户在 2026-08-10 确认的 21 件正式 T2 机制完整同步到运行时、UI、联机、AI、测试、i18n和设计真相源。

**Architecture:** BattleCore 继续作为唯一权威状态机。一次性脚本只登记效果；跨回合定身、英雄绑定致命免疫和点金石候选缓存进入可快照的核心容器。点金石复用既有三选一弹窗和私有候选传输，但在提交回合中增加来源槽、目标槽和选择索引的权威校验。

**Tech Stack:** Godot 4.x、GDScript、GUT、现有 MatchClient/MatchRoom/NetProtocol。

## Global Constraints

- 不修改英雄设计；英雄只用于兼容和回归测试。
- 未点名的 T2 沿用上一版提基机制。
- 删除命运骰子、巫毒娃娃、凶药；正式数量改为 T1 19 / T2 21 / T3 17。
- 不重构成熟战斗 UI；只扩展点金石三选一和状态反馈所需入口。
- 不 commit、不 push。

---

### Task 1: 正式数据与删除同步

**Files:** `src/battle/item_catalog.gd`、三件删除脚本及图标、`assets/i18n/strings_zh.csv`、`design/items*.md`、目录测试。

**Interfaces:** `ItemCatalog.all_for_tier(2)` 返回 21 件；三条失效 T1 `upgrade_to` 清空；`DISPLAY_ORDER` 不含删除 ID。

- [ ] 更新21条T2文案与参数：毒素3、暖玉4半点、魔晶6半能、力量加伤4半点、脆弱3层。
- [ ] 删除 `t2_shaizi`、`t2_wudouwawa`、`t2_xiongyao` 的运行时定义、脚本、图标和i18n。
- [ ] 在历史废案记录保留三件名称与删除结论，避免未来换皮回流。
- [ ] 更新正式数量、首发列表、升级映射与固定拼音顺序测试。

### Task 2: 核心结算

**Files:** `src/battle/battle_core.gd`、`src/battle/item_effect.gd`、保留的 `src/battle/items/t2_*.gd`、核心测试。

**Interfaces:**

- `begin_pointstone_draft(player:int, source_slot:int, target_slot:int) -> Array`
- `use_slot(player:int, slot:int, target_override:int=-1, item_slot_target:int=-1, item_choice:int=-1) -> bool`
- `switch_locked(player:int) -> bool`
- `grant_lethal_damage_immunity(player:int, slot:int, charges:int=1) -> void`

- [ ] 先写点金石、两回合定身、永久致命免疫、献祭死亡的失败测试。
- [ ] 点金石在来源槽缓存三个T3候选；选择后目标换件并 `since=turn_number`，不扣能。
- [ ] 所有非死亡补位换位入口共用 `switch_locked`；死亡补位显式绕过。
- [ ] 致命伤害判定在实际消耗护甲前完成；触发时整次伤害和护甲消耗均归零但保留命中语义。
- [ ] 力量的代价在统一死亡结算前把当时出战英雄置0，`killer=-1`。
- [ ] 猎物印记改为累计 `vuln += 3`；心脏掌握魔法设置基础攻击 `TRUE_DMG`；其余数值按最终稿修改。

### Task 3: UI、联机与AI

**Files:** `src/ui/battle_screen.gd`、`src/net/net_protocol.gd`、`src/net/match_client.gd`、`src/net/match_room.gd`、`src/battle/ai/*.gd`、`tools/sim/run_sim.gd`及对应测试。

**Interfaces:** 提交包为每个 `item_slots[i]` 同步 `item_slot_targets[i]` 与 `item_slot_choices[i]`；缺省选择索引为 `-1`。

- [ ] 点金石配对后在确认提交前显示一次T3三选一；取消保留来源槽候选，防止重抽。
- [ ] 联机由服务器生成并私发点金石候选；提交时服务器复核来源、目标、候选索引和槽位就绪状态。
- [ ] AI只选择可用T1目标，并在三个T3候选中按现有评估器选择最高价值项。
- [ ] 删除三件道具的AI权重、模拟统计和旧UI目标语义。
- [ ] 保留熔炉“消耗目标”与点金石“变换目标”的互斥高亮和原有战斗布局。

### Task 4: 验证与交付

**Files:** 相关 GUT 测试、运行探针。

- [ ] 运行 `tools/run_godot.ps1 -Mode Import`，要求退出码0且无Parse/SCRIPT错误。
- [ ] 运行全量 `tools/run_godot.ps1 -Mode Test`，记录总数与任何既有无关失败。
- [ ] 运行模拟器烟测，确认21件T2均能进入池且无非法提交。
- [ ] 用1920×1080实际BattleScreen探针验证点金石选目标、T3三选一、锁定文案和取消重入。
- [ ] 运行 `git diff --check`，检查任务树无仍在运行的已完成子任务，并汇报未commit/push。
