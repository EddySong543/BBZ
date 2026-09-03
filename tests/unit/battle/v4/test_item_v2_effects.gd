extends GutTest

const A := ActionDef.Action


func _hero(id: String, hp_value: int = 12) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_value
	return hero


func _battle() -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("a"), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 712_212)
	battle.enable_item_v2([], [])
	battle.econ_init()
	battle.energy = [20, 20]
	return battle


func _equip(battle: BattleCore, player: int, ids: Array[String]) -> void:
	for slot_index: int in range(ids.size()):
		var entry: Dictionary = {}
		for candidate_variant: Variant in battle.battle_backpacks[player]:
			var candidate: Dictionary = candidate_variant
			if String(candidate.get("item_id", "")) == ids[slot_index]:
				entry = battle._take_bag_entry(player, int(candidate["uid"]))
				break
		assert_false(entry.is_empty(), ids[slot_index])
		assert_true(battle._put_entry_in_slot(player, slot_index, entry, true))


func _item(slot: int, target: int = -1) -> Dictionary:
	return {"kind": "item", "slot": slot, "target": target}


func _action(action: int, target: int = -1) -> Dictionary:
	return {"kind": "action", "action": action, "target": target}


func _resolve(battle: BattleCore, p0: Array, p1: Array) -> Dictionary:
	assert_true(battle.submit_item_v2_command_sequence(0, p0))
	assert_true(battle.submit_item_v2_command_sequence(1, p1))
	return battle.resolve()


func test_teleport_and_targeted_salve_use_real_friendly_targets() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t2_teleport_scroll", "v2_t1_healing_salve"])
	battle.hp[0][2] -= 6
	_resolve(battle,
		[_item(0, 1), _item(1, 2), _action(A.CHARGE)],
		[_action(A.CHARGE)])
	assert_eq(battle.active_index[0], 1)
	assert_eq(battle.hp[0][2], battle.max_hp[0][2] - 2)


func test_heart_guard_turns_defend_into_big_defend_for_later_column() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_heart_guard"])
	_equip(battle, 1, ["v2_t1_silver_coin"])
	var hp_before: int = battle.hp[0][0]
	_resolve(battle,
		[_item(0), _action(A.DEFEND)],
		[_item(0), _action(A.BIG_ATTACK)])
	assert_eq(battle.hp[0][0], hp_before)
	assert_false(battle.item_v2_pending[0].has("defend_upgrade"))


func test_hammer_then_iron_eater_removes_and_steals_exact_armor() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_armor_hammer", "v2_t2_iron_eater"])
	battle.shield[1][0] = 6
	_resolve(battle,
		[_item(0), _item(1), _action(A.CHARGE)],
		[_action(A.CHARGE)])
	assert_eq(battle.shield[1][0], 0)
	assert_eq(battle.shield[0][0], 2)


func test_horn_and_salamander_oil_stack_on_a_later_big_wave() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t2_war_horn", "v2_t1_salamander_oil"])
	var hp_before: int = battle.hp[1][0]
	_resolve(battle,
		[_item(0), _item(1), _action(A.BIG_ATTACK)],
		[_action(A.CHARGE)])
	assert_eq(battle.hp[1][0], hp_before - 8)
	assert_eq(int(battle.slots[0][0]["current_durability"]), 2)


func test_falcon_feather_targets_a_living_reserve() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t2_falcon_feather"])
	var active_hp: int = battle.hp[1][0]
	var reserve_hp: int = battle.hp[1][1]
	_resolve(battle,
		[_item(0), _action(A.ATTACK, 1)],
		[_action(A.CHARGE)])
	assert_eq(battle.hp[1][0], active_hp)
	assert_eq(battle.hp[1][1], reserve_hp - 2)


func test_thorn_bracer_retaliates_only_after_a_later_connected_attack() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_thorn_bracer"])
	_equip(battle, 1, ["v2_t1_silver_coin"])
	var attacker_hp: int = battle.hp[1][0]
	_resolve(battle,
		[_item(0), _action(A.CHARGE)],
		[_item(0), _action(A.ATTACK)])
	assert_eq(battle.hp[1][0], attacker_hp - 2)
	assert_false(battle.item_v2_pending[0].has("hit_thorns"))


func test_heart_knot_swaps_armor_and_crucible_can_spend_new_armor() -> void:
	var battle := _battle()
	_equip(battle, 0, [
		"v2_t2_heart_knot",
		"v2_t1_cracked_shield",
		"v2_t1_alchemy_crucible",
	])
	battle.shield[0][0] = 2
	battle.shield[0][1] = 8
	battle.energy[0] = 4
	_resolve(battle,
		[_item(0, 1), _item(1), _item(2), _action(A.CHARGE)],
		[_action(A.CHARGE)])
	assert_eq(battle.shield[0][0], 10,
		"连心结换入8甲，小盾加2甲，坩埚再消耗1甲")
	assert_eq(battle.shield[0][1], 2)


func test_blood_medicine_heals_active_and_breaks_at_one_durability() -> void:
	var battle := _battle()
	_equip(battle, 0, ["v2_t1_blood_medicine"])
	battle.hp[0][0] -= 6
	_resolve(battle, [_item(0), _action(A.CHARGE)], [_action(A.CHARGE)])
	assert_eq(battle.hp[0][0], battle.max_hp[0][0] - 2)
	assert_eq(battle.slot_state(0, 0), BattleCore.SlotState.EMPTY)
