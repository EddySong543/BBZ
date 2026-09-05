# 道具全面审计后续优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 Eddy 已确认的方案同步优化暖玉、还魂丹、鹤顶红、天罗地网、尾后针、心脏掌握魔法和血魔的獠牙，并清理过期文本。

**Architecture:** 保留现有 `ItemData -> ItemEffect -> BattleCore` 结构。单件效果继续由道具脚本登记，跨伤害类型的致命保险、整次攻击触发次数、成功防御团队治疗及天罗首件事务裁决由 `BattleCore` 统一收口；本地核心通过可快照的道具事务日志重放首件之后的提交，不新增额外字段。

**Tech Stack:** Godot 4.x、GDScript、GUT、现有 `tools/run_godot.ps1` 启动器。

## Global Constraints

- 玩家文案严格采用 Eddy 确认的原句，不擅自增删条件。
- 暖玉成功防御后为所有存活英雄各回复 1 点生命。
- 还魂丹每名英雄整局限用 1 次，并阻止致命伤害、生命支付、生命失去和规则处决。
- 心脏掌握魔法只在使用回合有效；未攻击则回合结束失效。
- 天罗地网只令敌方首件道具和本回合切换无效，后续道具必须正常结算。
- 尾后针响应绑定英雄本回合内的任何死亡；还魂丹阻止死亡时不触发。
- 不新增长期状态小图标；保留头像悬停查询，图标任务后续独立处理。
- 三选一隐性加权升级只记录为道具池补全后的后期任务，本轮不实装。
- 不执行 commit 或 push。

---

### Task 1: 目录文案与道具脚本

**Files:**
- Modify: `src/battle/item_catalog.gd`
- Modify: `src/battle/items/t1_xixie_yaya.gd`
- Modify: `src/battle/items/t1_weihouzhen.gd`
- Modify: `src/battle/items/t2_huanhundan.gd`
- Modify: `src/battle/items/t2_nuanyu.gd`
- Modify: `src/battle/items/t2_qiubite.gd`
- Modify: `src/battle/items/t3_hedinghong.gd`
- Modify: `src/battle/item_effect.gd`
- Test: `tests/unit/battle/v4/test_items_t1.gd`
- Test: `tests/unit/battle/v4/test_items_t2_rebase_core.gd`
- Test: `tests/unit/battle/v4/test_items_t3_rebase_core.gd`

**Interfaces:**
- Consumes: `ItemEffect.on_base_attack_resolved` 的 `context.damage_total` 与 `context.hit_effect_triggers`。
- Produces: `ItemEffect.can_use(battle, player, target, data) -> bool`；暖玉修正器 `t2_block_team_heal`；英雄状态 `huanhun_used`。

- [ ] **Step 1: 写失败测试**

```gdscript
func test_fang_repeats_with_whole_attack_hit_effects() -> void:
	# 波总伤害与命中附效次数共同决定獠牙总治疗。
	assert_eq(battle.hp[0][0], expected_hp)

func test_huanhun_is_limited_once_per_hero() -> void:
	assert_false(battle.use_item(0, second_huan_index, 0))
```

- [ ] **Step 2: 运行定向测试确认 RED**

Run: `& .\tools\run_godot.ps1 -Mode Test -TestPaths 'res://tests/unit/battle/v4/test_items_t1.gd,res://tests/unit/battle/v4/test_items_t2_rebase_core.gd,res://tests/unit/battle/v4/test_items_t3_rebase_core.gd'`

Expected: 新增的团队治疗、限用一次、全类致死保护、附效倍增和鹤顶红数值断言失败。

- [ ] **Step 3: 实现最小脚本改动**

```gdscript
func can_use(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> bool:
	return true

var triggers: int = maxi(1, int(context.get("hit_effect_triggers", 1)))
battle._heal(player, slot, int(context.get("damage_total", 0)) * triggers)
```

- [ ] **Step 4: 复跑三组定向测试**

Run: `& .\tools\run_godot.ps1 -Mode Test -TestPaths 'res://tests/unit/battle/v4/test_items_t1.gd,res://tests/unit/battle/v4/test_items_t2_rebase_core.gd,res://tests/unit/battle/v4/test_items_t3_rebase_core.gd'`

Expected: 三组全部通过。

### Task 2: BattleCore 致命保险与首件天罗事务

**Files:**
- Modify: `src/battle/battle_core.gd`
- Modify: `src/battle/skills/h11_yingshou.gd`
- Test: `tests/unit/battle/v4/test_items_t2_rebase_core.gd`
- Test: `tests/unit/battle/v4/test_items_t3_rebase_core.gd`
- Test: `tests/unit/battle/v4/test_battle_snapshot.gd`

**Interfaces:**
- Consumes: `ItemEffect.can_use`；现有选择期事务快照、槽位 pack/unpack 与 `request_tianluo`。
- Produces: 首件提交重放日志 `_item_transaction_actions`；统一 `_consume_fatal_damage_immunity` 保护入口。

- [ ] **Step 1: 锁定首件而非全栏的失败测试**

```gdscript
assert_true(battle.use_slot(1, first_slot))
assert_true(battle.use_slot(1, second_slot))
battle.resolve()
assert_true(first_effect_was_cancelled)
assert_true(second_effect_was_preserved)
```

- [ ] **Step 2: 用事务重放实现首件取消**

```gdscript
func _restore_first_item_transaction(player: int, events: Array) -> void:
	var snapshot: Dictionary = item_buffs[player][_ITEM_TX_SNAPSHOT]
	var actions: Array = item_buffs[player][_ITEM_TX_ACTIONS].duplicate(true)
	energy[player] = int(snapshot["energy"])
	item_buffs[player] = (snapshot["item_buffs"] as Dictionary).duplicate(true)
	slots[player] = _snap_unpack_slots(snapshot["slots"])
	relics[player] = _snap_unpack_relics(snapshot["relics"])
	item_uses[player] = _snap_unpack_uses(snapshot["item_uses"])
	for index in range(actions.size()):
		_replay_item_transaction_action(player, actions[index], index == 0)
	events.append({id = "tianluo_first_item_rolled_back", player = player})
```

`_replay_item_transaction_action` 对槽位道具、兼容 `items[]`、即时能量、遗物、熔炉、点金石、封印与普通 `item_uses` 按记录的原始参数重放。

- [ ] **Step 3: 统一致命保险**

```gdscript
if amount >= hp[player][slot] and _consume_fatal_damage_immunity(player, slot, amount, events):
	return 0
```

该判断接入伤害、`lose_life`、h14 生命支付、力量的代价处决、妖火/延期直扣和娄金直接真伤；保险阻止死亡后不进入尾后针。

- [ ] **Step 4: 运行核心、快照与本地回放测试**

Run: `& .\tools\run_godot.ps1 -Mode Test -TestPaths 'res://tests/unit/battle/v4/test_items_t2_rebase_core.gd,res://tests/unit/battle/v4/test_items_t3_rebase_core.gd,res://tests/unit/battle/v4/test_battle_snapshot.gd'`

Expected: 全部通过，且天罗结果与玩家编号、提交顺序和快照恢复无关。

### Task 3: AI、悬停文案、模拟与正式文档

**Files:**
- Modify: `src/battle/ai/battle_ai.gd`
- Modify: `src/battle/ai/battle_eval.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tools/sim/run_sim.gd`
- Modify: `design/items-firstrelease.md`
- Modify: `design/items-list.md`
- Modify: `design/items.md`
- Modify: `design/gdd/game-concept.md`
- Modify: `design/build-design-framework.md`
- Modify: `docs/architecture/ADR-003-item-system.md`
- Regenerate: `assets/i18n/strings_zh.csv`
- Test: `tests/unit/battle/ai/test_battle_ai_items.gd`
- Test: `tests/unit/battle/ai/test_battle_eval_v1.gd`
- Test: `tests/unit/ui/test_battle_item_target_selection.gd`

**Interfaces:**
- Consumes: `huanhun_used`、单层 `fatal_damage_immunity`、鹤顶红每层 2 半点附加伤害、天罗首件语义。
- Produces: AI 不浪费重复还魂丹或无治疗目标的暖玉；悬停显示还魂保险/已使用状态；正式真相源和 i18n 无旧句。

- [ ] **Step 1: 更新AI与测试**

```gdscript
"t2_huanhundan":
	return int(b.get_status(side, active, "huanhun_used", 0)) <= 0
```

暖玉只随防御动作提交且至少有一名存活英雄受伤；天罗估值只计算首件道具与本回合切换价值；鹤顶红逐层价值翻倍。

- [ ] **Step 2: 同步玩家文案和历史边界**

当前正式池、首发池、i18n 与 GDD 使用新文案；`design/items.md` 明确记录隐性加权为池补全后的后期任务；历史废案记录保留，不误删历史证据。

- [ ] **Step 3: 清理残留文本**

删除替身草人对已删除巫毒娃娃的风味引用、死键 `气`、旧暖玉/鹤顶红/天罗/尾后针/心脏掌握魔法句式和已过期数值注释。

- [ ] **Step 4: 重新扫描 i18n**

Run: `& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/i18n_scan.gd'`

Expected: 新玩家句式各有唯一正式来源，旧句与删除风味不再出现在生成 CSV。

### Task 4: 全量验证与自检

**Files:**
- Verify only: all task files above

**Interfaces:**
- Consumes: Tasks 1-3 全部结果。
- Produces: 可交付的导入、全量GUT、模拟冒烟、静态旧文本扫描与差异检查证据。

- [ ] **Step 1: Godot 导入**

Run: `& .\tools\run_godot.ps1 -Mode Import`

Expected: exit code 0，无 parse/script 错误。

- [ ] **Step 2: 全量 GUT**

Run: `& .\tools\run_godot.ps1 -Mode Test`

Expected: 0 failures。

- [ ] **Step 3: 模拟冒烟与静态检查**

Run: `& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/sim/run_sim.gd' -- --games 1`

Run: `git -c safe.directory=$Repo -C $Repo diff --check`

Expected: 模拟完成；差异无空白错误。

- [ ] **Step 4: 逐条规格自检**

核对七件机制、还魂与尾后针优先级、天罗首件重放、AI/快照、正式文案、i18n、延后加权记录和未新增状态图标；存在任何缺口时继续修复，不提交。
