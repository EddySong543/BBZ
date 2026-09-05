extends GutTest

const A := ActionDef.Action
const SEED := 9_040_026


func _hero(id: String, hp_value: int = 12) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_value
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle() -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("test_a"), _hero("test_b"), _hero("test_c")],
		[_hero("test_x"), _hero("test_y"), _hero("test_z")],
		SEED)
	battle.enable_item_v2([], [])
	battle.econ_init()
	battle.energy = [10, 10]
	return battle


func _equip(battle: BattleCore, player: int, item_id: String) -> void:
	var entry: Dictionary = {}
	for candidate_variant: Variant in battle.battle_backpacks[player]:
		var candidate: Dictionary = candidate_variant
		if String(candidate.get("item_id", "")) == item_id:
			entry = battle._take_bag_entry(player, int(candidate.get("uid", -1)))
			break
	assert_false(entry.is_empty(), item_id)
	assert_true(battle._put_entry_in_slot(player, 0, entry, true), item_id)


func _item(slot: int = 0) -> Dictionary:
	return {"kind": "item", "slot": slot, "target": -1}


func _action(action: int) -> Dictionary:
	return {"kind": "action", "action": action, "target": -1}


func _submit_both(battle: BattleCore, p0: Array, p1: Array) -> Dictionary:
	assert_true(battle.submit_item_v2_command_sequence(0, p0))
	assert_true(battle.submit_item_v2_command_sequence(1, p1))
	return battle.resolve()


func test_active_death_cancels_both_players_unstarted_items_without_cost() -> void:
	var battle := _battle()
	_equip(battle, 0, "v2_t1_cracked_shield")
	_equip(battle, 1, "v2_t1_cracked_shield")
	battle.hp[1][0] = 2
	var durability_before: Array[int] = [
		int(battle.slots[0][0]["current_durability"]),
		int(battle.slots[1][0]["current_durability"]),
	]
	var result: Dictionary = _submit_both(battle,
		[_action(A.ATTACK), _item()],
		[_action(A.CHARGE), _item()])

	assert_true(battle.pending_death_switch[1])
	assert_eq((result["events"] as Array).filter(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "force_switch_prompt" \
				and int(event.get("player", -1)) == 1
	).size(), 1, "逐拍检查与回合收尾不能重复弹出同一个死亡换人提示")
	assert_eq(result["resolved_columns"].size(), 1)
	for player: int in [0, 1]:
		assert_eq(int(battle.slots[player][0]["current_durability"]),
			durability_before[player])
		assert_true(battle.used_item_history[player].is_empty())
	assert_false((result["events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "item_v2_used"))
	assert_eq((result["sequence_events"] as Array).filter(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "sequence_step_cancelled"
	).size(), 2)


func test_both_same_beat_attacks_finish_before_death_truncates_followups() -> void:
	var battle := _battle()
	_equip(battle, 0, "v2_t1_cracked_shield")
	_equip(battle, 1, "v2_t1_cracked_shield")
	battle.hp[0][0] = 2
	battle.hp[1][0] = 2
	var result: Dictionary = _submit_both(battle,
		[_action(A.ATTACK), _item()],
		[_action(A.ATTACK), _item()])

	assert_true(battle.hp[0][0] <= 0)
	assert_true(battle.hp[1][0] <= 0)
	assert_true(battle.pending_death_switch[0])
	assert_true(battle.pending_death_switch[1])
	assert_eq((result["events"] as Array).filter(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "damage_taken"
	).size(), 2, "同一拍已经启动的双方攻击必须全部落账")
	assert_eq(result["resolved_columns"].size(), 1)


func test_dead_reserve_does_not_truncate_living_active_sequence() -> void:
	var battle := _battle()
	_equip(battle, 0, "v2_t1_cracked_shield")
	battle.energy[0] = 0
	battle.hp[0][1] = 2
	battle.pending_damage[0][1] = 2
	var result: Dictionary = _submit_both(battle,
		[_action(A.CHARGE), _item()],
		[_action(A.CHARGE)])

	assert_eq(battle.hp[0][1], 0)
	assert_eq(battle.shield[0][0], 4)
	assert_eq(result["resolved_columns"].size(), 2)
	assert_false((result["sequence_events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "sequence_truncated"))


func test_deferred_active_death_cancels_sequence_before_first_beat() -> void:
	var battle := _battle()
	_equip(battle, 0, "v2_t1_cracked_shield")
	_equip(battle, 1, "v2_t1_cracked_shield")
	battle.energy = [0, 0]
	battle.hp[0][0] = 2
	battle.pending_damage[0][0] = 2
	var result: Dictionary = _submit_both(battle,
		[_action(A.CHARGE), _item()],
		[_action(A.CHARGE), _item()])

	assert_true(battle.pending_death_switch[0])
	assert_true((result["resolved_columns"] as Array).is_empty())
	assert_false((result["events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "charge_gain"))
	assert_eq(battle.energy, [ActionDef.PASSIVE_ENERGY_GAIN,
		ActionDef.PASSIVE_ENERGY_GAIN])
	assert_eq((result["sequence_events"] as Array).filter(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == "sequence_step_cancelled"
	).size(), 4)
