extends GutTest

## ============================================================================
## BattleCore 切换 + 死亡结算测试（Step 2.2b）
##
## 切换时机 = 【甲】（2026-05-25 Eddy 裁定）：切换先于伤害结算，
##   攻击打到换【上来】的新英雄 → 切换可垫刀/调度。
## 覆盖：切换改 active / 0 能 / 甲时机 / 非法目标拒绝 / 死亡待切换 / 执行死亡换人 / 全灭判负。
## ============================================================================

const E_INIT := 6
const HP_INIT := 10
const HP_HALF := 20
const ATK := 2
const BIG := 4


func _make_hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(e: int = E_INIT, hp: int = HP_INIT) -> BattleCore:
	var p1: Array = []
	var p2: Array = []
	for i in range(3):
		p1.append(_make_hero("test_p1_%d" % i, hp))
		p2.append(_make_hero("test_p2_%d" % i, hp))
	var b := BattleCore.new()
	b.setup(p1, p2, 777)
	b.energy = [e, e]
	return b


# ---- 切换基础 ----

func test_switch_changes_active_and_costs_zero() -> void:
	var b := _battle()
	assert_true(b.select_switch(0, 1), "切换到存活替补合法")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "出战切到 slot 1")
	assert_eq(b.energy[0], E_INIT, "切换 0 能消耗·被动已去除")


func test_switch_works_at_zero_energy() -> void:
	var b := _battle(0)   # 0 能也能切
	assert_true(b.select_switch(0, 2), "0 能切换合法")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 2)


func test_switch_to_self_rejected() -> void:
	var b := _battle()
	assert_false(b.select_switch(0, 0), "切到当前出战位非法")


func test_switch_to_dead_slot_rejected() -> void:
	var b := _battle()
	b.hp[0][1] = 0
	assert_false(b.select_switch(0, 1), "切到阵亡替补非法")


# ---- 甲时机：攻击打到换上来的新英雄 ----

func test_jia_attack_hits_newly_switched_in_hero() -> void:
	# P0 切 slot0 → slot1；P1 波。甲 = 伤害落在新上场的 slot1，旧 slot0 安全。
	var b := _battle()
	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.ATTACK)
	b.resolve()
	assert_eq(b.active_index[0], 1, "已切到 slot1")
	assert_eq(b.hp[0][1], HP_HALF - ATK, "新上场英雄(slot1)承受 1.0 伤（甲）")
	assert_eq(b.hp[0][0], HP_HALF, "换下去的旧英雄(slot0)毫发无损")


func test_both_switch_no_damage() -> void:
	var b := _battle()
	b.select_switch(0, 1)
	b.select_switch(1, 1)
	b.resolve()
	assert_eq(b.active_index[0], 1)
	assert_eq(b.active_index[1], 1)
	assert_eq(b.hp[0][1], HP_HALF)
	assert_eq(b.hp[1][1], HP_HALF)


# ---- 死亡结算 + 强制换人 ----

func test_active_death_with_reserves_sets_pending_switch() -> void:
	var b := _battle()
	b.hp[0][0] = 2   # 出战英雄残血 1.0
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)  # 2.0 伤 → 致死
	b.resolve()
	assert_lte(b.hp[0][0], 0, "出战英雄阵亡")
	assert_true(b.pending_death_switch[0], "有替补 → 待玩家选替补")
	assert_false(b.game_over, "尚有替补，游戏未结束")


func test_execute_death_switch_brings_in_reserve() -> void:
	var b := _battle()
	b.hp[0][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()
	assert_true(b.execute_death_switch(0, 1), "选 slot1 上场成功")
	assert_eq(b.active_index[0], 1)
	assert_false(b.pending_death_switch[0], "待切换已清除")


func test_execute_death_switch_to_dead_rejected() -> void:
	var b := _battle()
	b.hp[0][0] = 2
	b.hp[0][2] = 0   # slot2 已死
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()
	assert_false(b.execute_death_switch(0, 2), "不能选阵亡替补上场")


func test_all_heroes_dead_is_game_over() -> void:
	var b := _battle()
	b.hp[0][1] = 0   # 两替补已死
	b.hp[0][2] = 0
	b.hp[0][0] = 2   # 出战残血
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()
	assert_true(b.game_over, "P0(player0) 全灭 → 游戏结束")
	assert_eq(b.winner, BattleCore.WINNER_P2, "player0 全灭 → 对手 player1 胜 = WINNER_P2")
	assert_false(b.pending_death_switch[0], "无替补可换 → 不挂起")
