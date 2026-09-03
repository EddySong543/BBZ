extends GutTest

const A := ActionDef.Action


func _hero(id: String) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = 10
	return hero


func _battle(ids: Array[String] = []) -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("a"), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 82_031)
	battle.enable_item_v2(ids, ids)
	battle.econ_init()
	return battle


func test_draw_is_once_per_turn_public_locked_and_keeps_real_uid() -> void:
	var battle := _battle()
	var options: Array[ItemData] = battle.begin_item_v2_draw(0)
	assert_eq(options.size(), 3)
	var candidate_uids: Array = battle.item_v2_draw_candidate_uids[0].duplicate()
	assert_eq(candidate_uids.duplicate().reduce(
		func(accum: Dictionary, uid: Variant) -> Dictionary:
			accum[int(uid)] = true
			return accum, {}).size(), 3, "三选一必须是不放回的三个真实实体")
	var chosen_id: String = options[1].item_id
	var chosen_uid: int = int(candidate_uids[1])
	assert_true(battle.pick_item_v2_draw(0, 1, 2))
	assert_eq(battle.slot_item(0, 2).item_id, chosen_id)
	assert_eq(int(battle.slots[0][2]["instance_uid"]), chosen_uid)
	assert_false(battle.can_item_v2_draw(0))
	assert_false(battle.slot_ready(0, 2), "取得回合锁定")
	assert_eq(String(battle.item_v2_public_history[-1]["id"]), "item_v2_acquired")
	assert_eq(int(battle.item_v2_public_history[-1]["instance_uid"]), chosen_uid)
	assert_false(battle.battle_backpacks[0].any(
		func(entry: Dictionary) -> bool:
			return int(entry.get("uid", -1)) == chosen_uid))
	for unchosen_uid: int in [int(candidate_uids[0]), int(candidate_uids[2])]:
		assert_true(battle.battle_backpacks[0].any(
			func(entry: Dictionary) -> bool:
				return int(entry.get("uid", -1)) == unchosen_uid))

	assert_true(battle.submit_item_v2_command_sequence(
		0, [{"kind": "action", "action": A.CHARGE, "target": -1}]))
	assert_true(battle.submit_item_v2_command_sequence(
		1, [{"kind": "action", "action": A.CHARGE, "target": -1}]))
	battle.resolve()
	assert_true(battle.slot_ready(0, 2), "下一回合开始可用")


func test_minimum_uid_ab_modes_only_pad_runtime_backpacks() -> void:
	for minimum: int in [0, 6, 9]:
		var battle := BattleCore.new()
		battle.setup(
			[_hero("a"), _hero("b"), _hero("c")],
			[_hero("x"), _hero("y"), _hero("z")], 90 + minimum)
		battle.enable_item_v2(["v2_t1_whetstone"], ["v2_t1_whetstone"], minimum)
		assert_eq(battle.battle_backpacks[0].size(), maxi(1, minimum))
		assert_eq(ItemCatalog.prototype_ids().size(), 20,
			"0/6/9只改变检索背包，不改变冻结目录")


func test_two_durability_item_persists_then_clears_after_second_use() -> void:
	var battle := _battle(["v2_t1_whetstone"])
	battle.energy = [20, 20]
	var entry: Dictionary = battle._take_bag_entry(
		0, int(battle.battle_backpacks[0][0]["uid"]))
	assert_true(battle._put_entry_in_slot(0, 0, entry, true))
	for expected_remaining: int in [1, 0]:
		assert_true(battle.submit_item_v2_command_sequence(0, [
			{"kind": "item", "slot": 0, "target": -1},
			{"kind": "action", "action": A.ATTACK, "target": -1},
		]))
		assert_true(battle.submit_item_v2_command_sequence(1, [
			{"kind": "action", "action": A.CHARGE, "target": -1}]))
		battle.resolve()
		if expected_remaining > 0:
			assert_eq(battle.slot_state(0, 0), BattleCore.SlotState.CHARGING)
			assert_eq(int(battle.slots[0][0]["current_durability"]), 1)
			assert_true(battle.slot_ready(0, 0))
		else:
			assert_eq(battle.slot_state(0, 0), BattleCore.SlotState.EMPTY)
			assert_null(battle.slot_item(0, 0))


func test_v2_uid_durability_draw_and_pending_state_survive_snapshot_roundtrip() -> void:
	var battle := _battle()
	battle.begin_item_v2_draw(0)
	assert_true(battle.pick_item_v2_draw(0, 0, 1))
	battle.item_v2_pending[0] = {"wave_bonus": 2}
	var wire: Dictionary = JSON.parse_string(JSON.stringify(battle.to_snapshot()))
	var restored := BattleCore.new()
	assert_true(restored.from_snapshot(wire))
	assert_true(restored.item_v2_enabled)
	assert_eq(restored.item_v2_draw_used_turn, battle.item_v2_draw_used_turn)
	assert_eq(restored.item_v2_pending, battle.item_v2_pending)
	assert_eq(int(restored.slots[0][1]["instance_uid"]),
		int(battle.slots[0][1]["instance_uid"]))
	assert_eq(int(restored.slots[0][1]["current_durability"]),
		int(battle.slots[0][1]["current_durability"]))
