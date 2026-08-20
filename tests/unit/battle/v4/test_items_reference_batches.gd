extends GutTest

const A := ActionDef.Action
const SS := BattleCore.SlotState


func _hero(id: String, hp_points: int = 10) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_points
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(p0: String = "test_a", p1: String = "test_x") -> BattleCore:
	var battle := BattleCore.new()
	battle.setup([_hero(p0), _hero("test_b"), _hero("test_c")],
		[_hero(p1), _hero("test_y"), _hero("test_z")], 190_819)
	battle.econ_init()
	battle.energy = [20, 20]
	return battle


func _ready_slot(item_id: String) -> Dictionary:
	return {state = SS.CHARGING, item = ItemCatalog.make(item_id), since = -1,
		used = false, draft = [], upg_draft = [], draft_entry_uids = [],
		instance_uid = -1, temporary = false}


func _resolve(battle: BattleCore, p0_action: int, p1_action: int) -> Dictionary:
	assert_true(battle.select_action(0, p0_action))
	assert_true(battle.select_action(1, p1_action))
	return battle.resolve()


func test_gufeng_requires_being_the_only_ready_item_and_adds_two_damage() -> void:
	var battle := _battle()
	battle.slots[0][0] = _ready_slot("t1_gufeng_zhui")
	battle.slots[0][1] = _ready_slot("t1_xianshou")
	assert_false(battle.use_slot(0, 0))
	assert_true(battle.use_slot(0, 1))
	assert_true(battle.use_slot(0, 0))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 12, "波1 + 先手1 + 孤锋锥2")


func test_cuiyong_locks_an_unused_named_slot_for_the_next_turn_only() -> void:
	var battle := _battle()
	battle.slots[0][0] = _ready_slot("t2_cuiyong_pai")
	battle.slots[1][1] = _ready_slot("t1_xianshou")
	assert_true(battle.use_slot(0, 0, -1, 1))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_false(battle.slot_ready(1, 1))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_true(battle.slot_ready(1, 1))


func test_cuiyong_does_not_lock_the_item_if_it_was_used() -> void:
	var battle := _battle()
	battle.slots[0][0] = _ready_slot("t2_cuiyong_pai")
	battle.slots[1][1] = _ready_slot("t1_xianshou")
	assert_true(battle.use_slot(0, 0, -1, 1))
	assert_true(battle.use_slot(1, 1))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.slot_state(1, 1), SS.EMPTY)


func test_dingming_heals_to_three_but_respects_healing_block() -> void:
	var battle := _battle()
	battle.hp[0][0] = 2
	battle.slots[0][0] = _ready_slot("t2_dingming_wan")
	assert_true(battle.use_slot(0, 0))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.hp[0][0], 6)

	var blocked := _battle()
	blocked.hp[0][0] = 2
	blocked.slots[0][0] = _ready_slot("t2_dingming_wan")
	blocked.slots[1][0] = _ready_slot("t2_fengmai_zhen")
	assert_true(blocked.use_slot(0, 0))
	assert_true(blocked.use_slot(1, 0))
	_resolve(blocked, A.DEFEND, A.DEFEND)
	assert_eq(blocked.hp[0][0], 2)


func test_duyong_keeps_only_each_players_original_first_item_including_immediate_items() -> void:
	var battle := _battle()
	battle.energy = [0, 0]
	battle.slots[0][0] = _ready_slot("t2_duyong_feng")
	battle.slots[0][1] = _ready_slot("t2_mojing")
	battle.slots[1][0] = _ready_slot("t1_xianshou")
	battle.slots[1][1] = _ready_slot("t2_mojing")
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(0, 1))
	assert_true(battle.use_slot(1, 0))
	assert_true(battle.use_slot(1, 1))
	assert_eq(battle.energy, [6, 6], "选择期魔晶先即时到账")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.energy, [4, 4], "魔晶被原子回滚；只剩攒与回合被动")
	assert_false(battle.item_buffs[0].has("energy_debt_turns"))
	assert_false(battle.item_buffs[1].has("energy_debt_turns"))


func test_pianfeng_wave_still_connects_but_deals_zero_and_big_wave_gains_two() -> void:
	var wave := _battle()
	wave.set_status(1, 0, "poison", 2)
	wave.slots[1][0] = _ready_slot("t2_pianfeng_jia")
	assert_true(wave.use_slot(1, 0))
	_resolve(wave, A.ATTACK, A.CHARGE)
	assert_eq(wave.hp[1][0], 20)
	assert_eq(int(wave.get_status(1, 0, "poison", 0)), 0,
		"偏锋甲不是防御，波仍命中并引爆命中成果")

	var big := _battle()
	big.slots[1][0] = _ready_slot("t2_pianfeng_jia")
	assert_true(big.use_slot(1, 0))
	_resolve(big, A.BIG_ATTACK, A.CHARGE)
	assert_eq(big.hp[1][0], 12, "大波2 + 偏锋甲2")


func test_xiling_disables_positive_and_restrictive_skills_for_both_sides() -> void:
	var battle := _battle("h01", "h15")
	battle.energy = [0, 0]
	battle.slots[0][0] = _ready_slot("t3_xiling_ling")
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_action(1, A.DEFEND), "穷奇的禁防也属于英雄技能，应同时失效")
	battle.resolve()
	assert_eq(battle.energy[0], 4, "虚日的主动得能加成失效，只获得攒1能和被动1能")


func test_jingwen_clears_only_pending_hit_generated_hero_effects() -> void:
	var battle := _battle()
	for side in [0, 1]:
		battle.set_status(side, 0, "poison", 3)
		battle.set_status(side, 1, "jianqi", 2)
		battle.set_status(side, 2, "vuln", 1)
	battle.set_status(0, 0, "fatal_damage_immunity", 1)
	battle.slots[0][0] = _ready_slot("t2_jingwen_zhou")
	assert_true(battle.use_slot(0, 0))
	_resolve(battle, A.DEFEND, A.DEFEND)
	for side in [0, 1]:
		for key in ["poison", "jianqi", "vuln"]:
			for slot in range(3):
				assert_eq(int(battle.get_status(side, slot, key, 0)), 0)
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 1)


func test_yiyuan_sacrifices_active_heals_chosen_reserve_and_spends_the_action() -> void:
	var battle := _battle()
	battle.hp[0] = [2, 4, 20]
	battle.slots[0][0] = _ready_slot("t3_yiyuan_deng")
	assert_true(battle.use_slot(0, 0, 1))
	var result := _resolve(battle, A.BIG_ATTACK, A.CHARGE)
	assert_eq(battle.hp[0][0], 0)
	assert_eq(battle.hp[0][1], 20)
	assert_eq(battle.active_index[0], 1)
	assert_eq(battle.hp[1][0], 20, "本回合无法行动，不应打出已选择的大波")
	assert_eq(int(result["p1_action"]), -2)


func test_yiyuan_is_stopped_by_fatal_immunity_but_still_spends_the_action() -> void:
	var battle := _battle()
	battle.hp[0] = [2, 4, 20]
	battle.set_status(0, 0, "fatal_damage_immunity", 1)
	battle.slots[0][0] = _ready_slot("t3_yiyuan_deng")
	assert_true(battle.use_slot(0, 0, 1))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[0][0], 2)
	assert_eq(battle.hp[0][1], 4)
	assert_eq(battle.active_index[0], 0)
	assert_eq(battle.hp[1][0], 20)


func test_huiliu_refunds_two_energy_after_an_action_exactly_spends_the_pool() -> void:
	var battle := _battle()
	battle.energy[0] = 2
	battle.slots[0][0] = _ready_slot("t2_huiliu_zhu")
	assert_true(battle.use_slot(0, 0))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.energy[0], 6, "行动后返2能，再获得回合被动1能")
