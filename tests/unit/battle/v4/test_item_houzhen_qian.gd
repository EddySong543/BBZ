extends GutTest

const A := ActionDef.Action


func _hero(id: String, hp_points: int = 10) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_points
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle() -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("a"), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 81626)
	battle.energy = [20, 20]
	return battle


func _use(battle: BattleCore, target: int) -> bool:
	var index: int = battle.give_item(0, ItemCatalog.make("t1_houzhen_qian"))
	return battle.use_item(0, index, target)


func _resolve(battle: BattleCore, p0_action: int = A.CHARGE,
		p1_action: int = A.CHARGE) -> Dictionary:
	assert_true(battle.select_action(0, p0_action))
	assert_true(battle.select_action(1, p1_action))
	return battle.resolve()


func test_houzhen_qian_requires_a_living_reserve() -> void:
	var battle := _battle()
	assert_false(_use(battle, 0), "不能选择当前出战英雄")
	battle.hp[0][2] = 0
	assert_false(_use(battle, 2), "不能选择已阵亡替补")
	assert_true(_use(battle, 1))


func test_houzhen_qian_enters_only_after_this_turn_actions_finish() -> void:
	var battle := _battle()
	assert_true(_use(battle, 1))
	var result := _resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.active_index[0], 1)
	assert_eq(battle.hp[1][0], 18, "本回合的波应由原出战英雄先完成")
	var events: Array = result["events"]
	var attack_index: int = events.find_custom(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "damage_taken")
	var entry_index: int = events.find_custom(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "houzhen_entry")
	assert_true(attack_index >= 0 and entry_index > attack_index,
		"候阵签必须在本回合攻击结算之后登场")


func test_houzhen_qian_uses_the_real_switch_chain() -> void:
	var battle := _battle()
	var clasp: int = battle.give_item(0, ItemCatalog.make("t1_huanfang_kou"))
	assert_true(_use(battle, 2))
	assert_true(battle.use_item(0, clasp))
	_resolve(battle)
	assert_eq(battle.active_index[0], 2)
	assert_eq(battle.shield[0][2], 2, "候阵登场应触发换防扣的切换连携")
	assert_eq(int(battle.item_buffs[0].get("next_atk_total_bonus", 0)), 0)


func test_houzhen_qian_obeys_switch_locks() -> void:
	var battle := _battle()
	battle.item_buffs[0]["switch_lock_until_turn"] = battle.turn_number
	assert_true(_use(battle, 1))
	var result := _resolve(battle)
	assert_eq(battle.active_index[0], 0)
	assert_true((result["events"] as Array).any(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "switch_locked"))


func test_multiple_houzhen_qian_resolve_in_use_order() -> void:
	var battle := _battle()
	assert_true(_use(battle, 1))
	assert_true(_use(battle, 2))
	_resolve(battle)
	assert_eq(battle.active_index[0], 2)


func test_houzhen_qian_skips_a_target_that_died_before_end_of_turn() -> void:
	var battle := _battle()
	assert_true(_use(battle, 2))
	battle.hp[0][2] = 0
	_resolve(battle)
	assert_eq(battle.active_index[0], 0)


func test_houzhen_qian_can_complete_a_planned_death_replacement() -> void:
	var battle := _battle()
	battle.hp[0][0] = 2
	assert_true(_use(battle, 2))
	var result := _resolve(battle, A.CHARGE, A.ATTACK)
	assert_eq(battle.active_index[0], 2)
	assert_false(battle.pending_death_switch[0])
	assert_eq(battle.shield[0][2], 0, "死亡补位本身不应伪造切换触发")
	assert_false((result["events"] as Array).any(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "force_switch_prompt" \
			and int(event.get("player", -1)) == 0), "自动补位后不得留下过期的选替补提示")
