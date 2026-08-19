extends GutTest

const A := ActionDef.Action


func _hero(id: String, max_hp: int = 10) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = max_hp
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(energy_value: int = 20) -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("a"), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 130813)
	battle.energy = [energy_value, energy_value]
	return battle


func _use(battle: BattleCore, player: int, item_id: String) -> void:
	var item_index: int = battle.give_item(player, ItemCatalog.make(item_id))
	assert_true(battle.use_item(player, item_index), item_id)


func _resolve(battle: BattleCore, p0_action: int, p1_action: int,
		p0_target: int = -1, p1_target: int = -1) -> Dictionary:
	assert_true(battle.select_action(0, p0_action, p0_target))
	assert_true(battle.select_action(1, p1_action, p1_target))
	return battle.resolve()


func test_deneng_hufu_triggers_once_on_active_energy_gain_not_passive() -> void:
	var battle := _battle(0)
	_use(battle, 0, "t1_deneng_hufu")
	_resolve(battle, A.CHARGE, A.DEFEND)
	assert_eq(battle.shield[0][0], 2)
	var shield_before: int = battle.shield[0][0]
	_resolve(battle, A.CHARGE, A.DEFEND)
	assert_eq(battle.shield[0][0], shield_before, "一次性护符不能跨回合再次触发")

	var h12 := BattleCore.new()
	h12.setup([_hero("h12", 7), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 130814)
	h12.energy = [0, 20]
	_use(h12, 0, "t1_deneng_hufu")
	_resolve(h12, A.DEFEND, A.BIG_ATTACK)
	assert_eq(h12.shield[0][0], 2, "室火受伤转化的能量不是回合被动，应触发得能护符")


func test_fentong_redirects_one_damage_to_highest_hp_ally_but_defense_does_not_consume() -> void:
	var blocked := _battle()
	blocked.hp[0] = [6, 10, 8]
	_use(blocked, 0, "t1_fentong_mupai")
	_resolve(blocked, A.DEFEND, A.ATTACK)
	assert_eq(blocked.hp[0], [6, 10, 8])

	var connected := _battle()
	connected.hp[0] = [6, 10, 8]
	_use(connected, 0, "t1_fentong_mupai")
	_resolve(connected, A.CHARGE, A.ATTACK)
	assert_eq(connected.hp[0], [6, 8, 8])


func test_huanfang_and_tengman_apply_on_actual_switch() -> void:
	var battle := _battle()
	_use(battle, 0, "t1_huanfang_kou")
	_use(battle, 1, "t1_tengman_xianjing")
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.shield[0][1], 2)
	assert_eq(battle.hp[0][0], 18)

	var death_switch := _battle()
	death_switch.hp[0][0] = 0
	death_switch.pending_death_switch[0] = true
	assert_true(death_switch.execute_death_switch(0, 1))
	assert_eq(death_switch.shield[0][1], 0, "死亡补位不是切换，不应触发换防扣")


func test_sage_book_blocks_vine_trap_non_damage_effect() -> void:
	var battle := _battle()
	_use(battle, 0, "t1_hushenfu")
	_use(battle, 1, "t1_tengman_xianjing")
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[0][0], 20)


func test_jijiu_ling_heals_lowest_living_hero_only_after_connection() -> void:
	var blocked := _battle()
	blocked.hp[0] = [10, 4, 6]
	_use(blocked, 0, "t1_jijiu_ling")
	_resolve(blocked, A.ATTACK, A.DEFEND)
	assert_eq(blocked.hp[0][1], 4)
	var connected := _battle()
	connected.hp[0] = [10, 4, 6]
	_use(connected, 0, "t1_jijiu_ling")
	_resolve(connected, A.ATTACK, A.CHARGE)
	assert_eq(connected.hp[0][1], 6)


func test_yazhen_zhui_only_drains_when_big_defend_blocks_original_wave() -> void:
	var battle := _battle(8)
	_use(battle, 0, "t1_yazhen_zhui")
	_resolve(battle, A.BIG_DEFEND, A.ATTACK)
	assert_eq(battle.energy[1], 6, "敌方波先支付1能，再被扣1能，回合被动返1能")

	var retained := _battle(8)
	retained.retained_big_defend[0] = true
	retained.retained_big_defend_until_turn[0] = retained.turn_number
	_use(retained, 0, "t1_yazhen_zhui")
	_resolve(retained, A.CHARGE, A.ATTACK)
	assert_eq(retained.energy[1], 8, "旧的大防保留不是本回合使用大防，不应触发压阵坠")


func test_huifeng_qiao_compensates_blocked_wave_not_big_wave() -> void:
	var battle := _battle()
	_use(battle, 0, "t1_huifeng_qiao")
	_resolve(battle, A.ATTACK, A.DEFEND)
	assert_eq(battle.shield[0][0], 3)


func test_xuzhen_qi_arms_next_death_replacement() -> void:
	var battle := _battle()
	battle.hp[0][0] = 2
	_use(battle, 0, "t1_xuzhen_qi")
	_resolve(battle, A.CHARGE, A.ATTACK)
	assert_true(battle.pending_death_switch[0])
	assert_true(battle.execute_death_switch(0, 1))
	assert_eq(battle.shield[0][1], 4)


func test_xuedu_jie_pays_life_and_heals_lowest_other_hero() -> void:
	var battle := _battle()
	battle.hp[0] = [8, 2, 6]
	_use(battle, 0, "t1_xuedu_jie")
	var result: Dictionary = _resolve(battle, A.DEFEND, A.CHARGE)
	assert_eq(battle.hp[0], [6, 6, 6])
	assert_true((result.events as Array).any(func(event: Dictionary) -> bool:
		return event.get("id", "") == "life_lost" \
			and event.get("src", "") == "t1_xuedu_jie"))

	var stacked := _battle()
	stacked.hp[0] = [2, 2, 6]
	_use(stacked, 0, "t1_xuedu_jie")
	_use(stacked, 0, "t1_xuedu_jie")
	_resolve(stacked, A.DEFEND, A.CHARGE)
	assert_eq(stacked.hp[0], [0, 6, 6],
		"出战英雄已被前一件血渡结支付致死后，后一件不得零成本治疗")


func test_jiedu_clears_poison_before_vulnerability_and_heals() -> void:
	var battle := _battle()
	battle.hp[0][0] = 6
	battle.set_status(0, 0, "poison", 3)
	battle.set_status(0, 0, "vuln", 2)
	_use(battle, 0, "t1_jiedu_yaoshui")
	_resolve(battle, A.DEFEND, A.CHARGE)
	assert_eq(int(battle.get_status(0, 0, "poison", 0)), 0)
	assert_eq(int(battle.get_status(0, 0, "vuln", 0)), 2)
	assert_eq(battle.hp[0][0], 8)


func test_xunxing_zhui_targets_reserve_for_wave_and_reduces_total_damage() -> void:
	var battle := _battle()
	_use(battle, 0, "t1_xunxing_zhui")
	_resolve(battle, A.ATTACK, A.CHARGE, 1)
	assert_eq(battle.hp[1][0], 20)
	assert_eq(battle.hp[1][1], 19, "波1点减0.5后应造成0.5点")


func test_xunxing_zhui_never_unlocks_big_wave_targeting() -> void:
	var battle := _battle()
	_use(battle, 0, "t1_xunxing_zhui")
	assert_false(battle.select_action(0, A.BIG_ATTACK, 1))
