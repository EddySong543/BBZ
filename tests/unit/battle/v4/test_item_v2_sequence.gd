extends GutTest

const A := ActionDef.Action
const SEED := 9_020_026


func _hero(id: String, hp_value: int = 12) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_value
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(p0_id: String = "test_a", p1_id: String = "test_x") -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero(p0_id), _hero("test_b"), _hero("test_c")],
		[_hero(p1_id), _hero("test_y"), _hero("test_z")],
		SEED)
	battle.enable_item_v2([], [])
	battle.econ_init()
	battle.energy = [20, 20]
	return battle


func _equip(battle: BattleCore, player: int, ids: Array[String]) -> void:
	for slot_index: int in range(ids.size()):
		var wanted: String = ids[slot_index]
		var entry: Dictionary = {}
		for candidate_variant: Variant in battle.battle_backpacks[player]:
			var candidate: Dictionary = candidate_variant
			if String(candidate.get("item_id", "")) == wanted:
				entry = battle._take_bag_entry(player, int(candidate.get("uid", -1)))
				break
		assert_false(entry.is_empty(), wanted)
		assert_true(battle._put_entry_in_slot(player, slot_index, entry, true), wanted)


func _item(slot: int, target: int = -1) -> Dictionary:
	return {"kind": "item", "slot": slot, "target": target}


func _action(action: int, extras: Dictionary = {}) -> Dictionary:
	var step := {"kind": "action", "action": action, "target": -1}
	step.merge(extras, true)
	return step


func _submit_both(battle: BattleCore, p0: Array, p1: Array) -> Dictionary:
	assert_true(battle.submit_item_v2_command_sequence(0, p0))
	assert_true(battle.submit_item_v2_command_sequence(1, p1))
	return battle.resolve()


func test_validation_is_atomic_and_real_order_can_fund_a_later_item() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_cracked_shield"])
	battle.energy[0] = 0
	var before: Dictionary = battle.to_snapshot()
	assert_false(battle.submit_item_v2_command_sequence(
		0, [_item(0), _action(A.CHARGE)]), "道具在攒前无能量，必须拒绝")
	assert_eq(battle.to_snapshot(), before, "失败提交不得改变权威状态")
	assert_true(battle.submit_item_v2_command_sequence(
		0, [_action(A.CHARGE), _item(0)]), "攒先结算后可支付盾牌")
	assert_true(battle.submit_item_v2_command_sequence(1, [_action(A.CHARGE)]))
	var result: Dictionary = battle.resolve()
	assert_eq(battle.shield[0][0], 4)
	assert_eq(battle.slot_state(0, 0), BattleCore.SlotState.EMPTY)
	assert_eq(result["resolved_columns"].size(), 2)


func test_smoke_before_the_shared_action_reduces_that_attack() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_smoke_bottle"])
	var before_hp: int = battle.hp[0][0]
	_submit_both(battle,
		[_item(0), _action(A.CHARGE)],
		[_action(A.ATTACK)])
	assert_eq(battle.hp[0][0], before_hp,
		"0拍前的烟雾必须能削弱0拍攻击")
	assert_false(battle.item_v2_pending[1].has("attack_penalty"),
		"烟雾已被0拍攻击消费，不得错误留到下一次攻击")


func test_unequal_pre_action_item_counts_cannot_make_defend_miss_attack() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_whetstone"])
	var enemy_hp: int = battle.hp[1][0]
	var result: Dictionary = _submit_both(battle,
		[_item(0), _action(A.ATTACK)],
		[_action(A.DEFEND)])
	var columns: Array = result["resolved_columns"]

	assert_eq(columns.size(), 2)
	assert_eq(String(columns[0]["steps"][1].get("reason", "")),
		"action_alignment")
	assert_eq(int(columns[1]["steps"][0]["action"]), A.ATTACK)
	assert_eq(int(columns[1]["steps"][1]["action"]), A.DEFEND)
	assert_eq(battle.hp[1][0], enemy_hp,
		"主行动必须在0拍相遇，前置道具数量不能制造防空防")


func test_whetstone_before_attack_applies_but_after_attack_waits() -> void:
	var before := _battle()
	_equip(before, 0, ["v2_t1_whetstone"])
	var enemy_hp: int = before.hp[1][0]
	_submit_both(before,
		[_item(0), _action(A.ATTACK)],
		[_action(A.CHARGE)])
	assert_eq(before.hp[1][0], enemy_hp - 4)
	assert_false(before.item_v2_pending[0].has("wave_bonus"))

	var after := _battle()
	_equip(after, 0, ["v2_t1_whetstone"])
	enemy_hp = after.hp[1][0]
	_submit_both(after,
		[_action(A.ATTACK), _item(0)],
		[_action(A.CHARGE)])
	assert_eq(after.hp[1][0], enemy_hp - 2)
	assert_eq(int(after.item_v2_pending[0].get("wave_bonus", 0)), 2)


func test_h02_upgraded_wave_is_big_wave_and_only_consumes_big_wave_bonus() -> void:
	var battle := _battle("h02")
	battle.item_v2_pending[0] = {"wave_bonus": 2, "big_wave_bonus": 2}
	battle.upgrade_next_wave[0] = true
	var enemy_hp: int = battle.hp[1][0]
	_submit_both(battle, [_action(A.ATTACK)], [_action(A.CHARGE)])
	assert_eq(battle.hp[1][0], enemy_hp - 6)
	assert_eq(int(battle.item_v2_pending[0].get("wave_bonus", 0)), 2)
	assert_false(battle.item_v2_pending[0].has("big_wave_bonus"))


func test_h13_split_is_two_waves_and_first_wave_consumes_waiting_states() -> void:
	var battle := _battle("h13")
	battle.item_v2_pending[0] = {
		"wave_bonus": 2,
		"big_wave_bonus": 2,
		"attack_bonus": 2,
		"attack_any_target": 1,
	}
	var active_hp: int = battle.hp[1][0]
	var reserve_hp: int = battle.hp[1][1]
	_submit_both(battle,
		[_action(A.BIG_ATTACK, {"split_big_wave": true, "target": 1})],
		[_action(A.CHARGE)])
	assert_eq(battle.hp[1][1], reserve_hp - 6,
		"猎鹰羽毛只把玄冥第一段波送往锁定后备")
	assert_eq(battle.hp[1][0], active_hp - 2,
		"第二段恢复普通目标规则并命中当前出战位")
	assert_false(battle.item_v2_pending[0].has("wave_bonus"))
	assert_false(battle.item_v2_pending[0].has("attack_bonus"))
	assert_false(battle.item_v2_pending[0].has("attack_any_target"))
	assert_eq(int(battle.item_v2_pending[0].get("big_wave_bonus", 0)), 2)


func test_silver_mana_acid_three_item_chain_walks_all_costs() -> void:
	var battle := _battle()
	_equip(battle, 0, [
		"v2_t1_silver_coin",
		"v2_t1_mana_potion",
		"v2_t3_acid_jar",
	])
	battle.energy[0] = 0
	battle.shield[0][0] = 8
	battle.shield[1][0] = 6
	_submit_both(battle,
		[_item(0), _item(1), _item(2), _action(A.CHARGE)],
		[_action(A.CHARGE)])
	assert_eq(battle.shield[0][0], 0)
	assert_eq(battle.shield[1][0], 0)
	assert_eq(battle.energy[0], 4,
		"银币令药水免费；药水供酸罐2能；攒和被动各留下1能")


func test_same_column_dispel_does_not_delete_a_new_same_column_effect() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t3_dispelling_bell"])
	_equip(battle, 1, ["v2_t1_whetstone"])
	_submit_both(battle,
		[_item(0), _action(A.CHARGE)],
		[_item(0), _action(A.CHARGE)])
	assert_eq(int(battle.item_v2_pending[1].get("wave_bonus", 0)), 2)


func test_revive_target_must_already_be_dead_when_sequence_is_submitted() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t3_revive_stone"])
	assert_false(battle.submit_item_v2_command_sequence(
		0, [_item(0, 1), _action(A.CHARGE)]))
	battle.hp[0][1] = 0
	assert_true(battle.submit_item_v2_command_sequence(
		0, [_item(0, 1), _action(A.CHARGE)]))
	assert_true(battle.submit_item_v2_command_sequence(1, [_action(A.CHARGE)]))
	battle.resolve()
	assert_eq(battle.hp[0][1], 2)


func test_h03_inserts_a_visible_wait_only_before_unstarted_enemy_steps() -> void:
	var battle := _battle("h03")
	_equip(battle, 0, ["v2_t1_silver_coin"])
	_equip(battle, 1, ["v2_t1_whetstone", "v2_t1_silver_coin"])
	var result: Dictionary = _submit_both(battle,
		[_action(A.ATTACK), _item(0)],
		[_item(0), _action(A.CHARGE), _item(1)])
	var columns: Array = result["resolved_columns"]
	assert_eq(columns.size(), 4)
	assert_eq(int(columns[1]["steps"][1]["action"]), A.CHARGE,
		"旧白额雷音不得推走已经对齐到0拍的敌方主行动")
	assert_eq(String(columns[2]["steps"][1]["kind"]), "wait")
	assert_eq(String(columns[3]["steps"][1]["item_id"]), "v2_t1_silver_coin")
	assert_eq((result["sequence_events"] as Array).filter(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "sequence_shifted").size(), 1)


func test_h21_still_interrupts_the_enemy_basic_action_at_the_shared_anchor() -> void:
	var battle := _battle("h21")
	battle.energy[1] = 4
	var hp_before: int = battle.hp[0][0]
	var result: Dictionary = _submit_both(battle,
		[_action(ActionDef.ACTIVE, {"target": 1})],
		[_action(A.ATTACK)])

	assert_eq(battle.hp[0][0], hp_before,
		"惊蛰的既有打断语义不能因0拍对齐而静默失效")
	assert_eq(battle.active_index[1], 1)
	assert_eq(battle.energy[1], 4,
		"波费用已经支付且不返还，回合被动只补回正常1能")
	assert_true((result["events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "item_v2_action_cancelled" \
				and int(event.get("player", -1)) == 1))


func test_h21_cancelled_charge_does_not_grant_energy() -> void:
	var battle := _battle("h21")
	battle.energy[1] = 0
	_submit_both(battle,
		[_action(ActionDef.ACTIVE, {"target": 1})],
		[_action(A.CHARGE)])

	assert_eq(battle.energy[1], ActionDef.PASSIVE_ENERGY_GAIN,
		"惊蛰取消攒后，只能获得正常回合被动能量")


func test_h21_does_not_cancel_a_same_anchor_switch() -> void:
	var battle := _battle("h21")
	var result: Dictionary = _submit_both(battle,
		[_action(ActionDef.ACTIVE, {"target": 2})],
		[_action(A.SWITCH, {"target": 1})])

	assert_eq(battle.active_index[1], 2,
		"对手先完成主动切换，再被惊蛰替换为指定英雄")
	assert_false((result["events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "h21_action_cancelled"),
		"惊蛰不得把已经完成的公共切换伪报成被打断")


func test_h17_transforms_before_same_anchor_attack_damage() -> void:
	var battle := _battle("h17")
	var copied_hp: int = battle.hp[1][0]
	_submit_both(battle,
		[_action(ActionDef.ACTIVE)],
		[_action(A.ATTACK)])

	assert_eq(battle.heroes[0][0].hero_id, "test_x")
	assert_eq(battle.hp[0][0], copied_hp - 2,
		"烛阴应先完成转变，再由新形态承受同拍攻击；伤害不能被事后复制抹掉")


func test_h22_started_active_persists_when_defeated_at_the_shared_anchor() -> void:
	var battle := _battle("h22")
	battle.hp[0][0] = 2
	_submit_both(battle,
		[_action(ActionDef.ACTIVE)],
		[_action(A.ATTACK)])

	assert_eq(battle.energy_burn_turn, battle.turn_number,
		"毕方同拍阵亡也不能吞掉已经启动的火兆")


func test_h21_replaces_h17_only_after_h17_active_has_completed() -> void:
	var battle := _battle("h21", "h17")
	var result: Dictionary = _submit_both(battle,
		[_action(ActionDef.ACTIVE, {"target": 1})],
		[_action(ActionDef.ACTIVE)])

	assert_eq(battle.heroes[1][0].hero_id, "h21",
		"烛阴应先复制敌方出战英雄")
	assert_eq(battle.active_index[1], 1,
		"惊蛰随后替换已经完成主动技的烛阴")
	assert_false((result["events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "h21_action_cancelled"),
		"惊蛰不得取消敌方主动技")
