extends GutTest

const A := ActionDef.Action
const SEED := 81326


func _hero(id: String, hp_points: int = 10) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_points
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(p0_ids: Array = ["test_a", "test_b", "test_c"],
		p1_ids: Array = ["test_x", "test_y", "test_z"]) -> BattleCore:
	var battle := BattleCore.new()
	var p0: Array[HeroData] = []
	var p1: Array[HeroData] = []
	for id in p0_ids:
		p0.append(_hero(String(id)))
	for id in p1_ids:
		p1.append(_hero(String(id)))
	battle.setup(p0, p1, SEED)
	battle.energy = [20, 20]
	return battle


func _use(battle: BattleCore, player: int, item_id: String, target: int = -1) -> bool:
	var index: int = battle.give_item(player, ItemCatalog.make(item_id))
	return battle.use_item(player, index, target)


func _resolve(battle: BattleCore, p0_action: int, p1_action: int,
		p0_target: int = -1, p1_target: int = -1) -> Dictionary:
	assert_true(battle.select_action(0, p0_action, p0_target))
	assert_true(battle.select_action(1, p1_action, p1_target))
	return battle.resolve()


func test_difeng_kou_converts_up_to_two_shield_into_whole_attack_damage() -> void:
	var battle := _battle()
	battle.shield[0][0] = 6
	assert_true(_use(battle, 0, "t2_difeng_kou"))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.shield[0][0], 2)
	assert_eq(battle.hp[1][0], 14, "波1点加转化护盾2点，总计造成3点伤害")


func test_fuying_suo_keeps_the_original_enemy_as_attack_target_after_switch() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t2_fuying_suo"))
	assert_true(battle.select_action(0, A.ATTACK))
	assert_true(battle.select_switch(1, 1))
	battle.resolve()
	assert_eq(battle.active_index[1], 1)
	assert_eq(battle.hp[1][0], 18, "攻击应追到已经下场的原出战英雄")
	assert_eq(battle.hp[1][1], 20)


func test_ningxue_gao_converts_all_healing_to_full_printed_shield_regardless_of_use_order() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t2_shengming"))
	assert_true(_use(battle, 0, "t2_ningxue_gao"))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.hp[0][0], 20)
	assert_eq(battle.shield[0][0], 4, "满血时2点治疗也应改为2点护盾")


func test_zhenwen_zhen_suppresses_enemy_hit_triggered_hero_skills_only() -> void:
	var battle := _battle(["test_a", "test_b", "test_c"], ["h06", "test_y", "test_z"])
	assert_true(_use(battle, 0, "t2_zhenwen_zhen"))
	_resolve(battle, A.CHARGE, A.ATTACK)
	assert_eq(battle.hp[0][0], 18, "波本身仍应造成伤害")
	assert_eq(int(battle.get_status(0, 0, "poison", 0)), 0,
		"由命中触发的h06英雄技能应无效")


func test_lianxin_suo_evenly_shares_next_attack_across_living_team_and_uses_each_shield() -> void:
	var battle := _battle()
	battle.shield[0] = [0, 2, 0]
	assert_true(_use(battle, 0, "t2_lianxin_suo"))
	_resolve(battle, A.CHARGE, A.BIG_ATTACK)
	assert_eq(battle.hp[0], [18, 20, 19])
	assert_eq(battle.shield[0], [0, 1, 0])


func test_lianxin_suo_rotates_half_point_remainder_across_split_attack_segments() -> void:
	var battle := _battle(["test_a", "test_b", "test_c"], ["h13", "test_y", "test_z"])
	assert_true(_use(battle, 0, "t2_lianxin_suo"))
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_action(1, A.BIG_ATTACK, -1, false, true))
	battle.resolve()
	assert_eq(battle.hp[0], [18, 19, 19], "双段总伤仍应尽量平均分摊")


func test_fencun_chi_caps_each_side_whole_attack_after_poison_and_vulnerability() -> void:
	var battle := _battle()
	battle.set_status(0, 0, "poison", 3)
	battle.set_status(1, 0, "vuln", 3)
	assert_true(_use(battle, 0, "t2_fencun_chi"))
	_resolve(battle, A.BIG_ATTACK, A.BIG_ATTACK)
	assert_eq(battle.hp[0][0], 18)
	assert_eq(battle.hp[1][0], 18)
	assert_eq(int(battle.get_status(0, 0, "poison", 0)), 0, "命中仍应正常引爆毒素")


func test_fencun_chi_caps_h13_split_big_wave_as_one_attack() -> void:
	var battle := _battle(["h13", "test_b", "test_c"])
	assert_true(_use(battle, 0, "t2_fencun_chi"))
	assert_true(battle.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[1][0], 18, "双段大波的整次总伤也只能为1点")


func test_yijia_huan_moves_all_team_shield_to_selected_living_hero() -> void:
	var battle := _battle()
	battle.shield[0] = [1, 2, 3]
	assert_true(_use(battle, 0, "t2_yijia_huan", 2))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.shield[0], [0, 0, 6])


func test_yijia_huan_rejects_dead_target() -> void:
	var battle := _battle()
	battle.hp[0][2] = 0
	assert_false(_use(battle, 0, "t2_yijia_huan", 2))


func test_huzhen_ding_grants_two_shield_only_to_selected_living_reserve() -> void:
	var battle := _battle()
	assert_false(_use(battle, 0, "t2_huzhen_ding", 0), "出战英雄不是合法目标")
	assert_true(_use(battle, 0, "t2_huzhen_ding", 2))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.shield[0], [0, 0, 4])


func test_fengmai_zhen_blocks_both_teams_healing_but_ningxue_conversion_still_works() -> void:
	var blocked := _battle()
	blocked.hp[0][0] = 10
	blocked.hp[1][0] = 10
	assert_true(_use(blocked, 0, "t2_shengming"))
	assert_true(_use(blocked, 1, "t2_shengming"))
	assert_true(_use(blocked, 0, "t2_fengmai_zhen"))
	_resolve(blocked, A.CHARGE, A.CHARGE)
	assert_eq(blocked.hp[0][0], 10)
	assert_eq(blocked.hp[1][0], 10)

	var converted := _battle()
	converted.hp[0][0] = 10
	assert_true(_use(converted, 0, "t2_shengming"))
	assert_true(_use(converted, 0, "t2_fengmai_zhen"))
	assert_true(_use(converted, 0, "t2_ningxue_gao"))
	_resolve(converted, A.CHARGE, A.CHARGE)
	assert_eq(converted.hp[0][0], 10)
	assert_eq(converted.shield[0][0], 4,
		"治疗先被凝血膏改为护盾，因此不受无法回复生命影响")


func test_suoquan_sai_blocks_only_the_enemy_next_turn_energy_gains() -> void:
	var battle := _battle()
	battle.energy = [0, 0]
	assert_true(_use(battle, 0, "t2_suoquan_sai"))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.energy[1], 2,
		"使用当回合的攒仍获得1能，但为下回合准备的被动能量被锁泉塞阻止")

	assert_true(_use(battle, 1, "t3_fali"))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.energy[1], 4,
		"被锁回合的上等法力药水与攒均不得能，仅回合末为再下一回合获得1点被动能量")

	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.energy[1], 8, "再下一回合应恢复攒与被动得能")


func test_suoquan_sai_is_blocked_by_sage_book_and_duplicate_copies_do_not_extend() -> void:
	var protected := _battle()
	protected.energy = [0, 0]
	assert_true(_use(protected, 1, "t1_hushenfu"))
	assert_true(_use(protected, 0, "t2_suoquan_sai"))
	_resolve(protected, A.CHARGE, A.CHARGE)
	assert_eq(protected.energy[1], 4, "圣贤书应使锁泉塞无效")

	var duplicated := _battle()
	duplicated.energy = [0, 0]
	assert_true(_use(duplicated, 0, "t2_suoquan_sai"))
	assert_true(_use(duplicated, 0, "t2_suoquan_sai"))
	_resolve(duplicated, A.CHARGE, A.CHARGE)
	_resolve(duplicated, A.CHARGE, A.CHARGE)
	_resolve(duplicated, A.CHARGE, A.CHARGE)
	assert_eq(duplicated.energy[1], 8, "重复件不得把禁能延长到第二个完整回合")


func test_huizhao_jing_counters_first_enemy_target_item_but_not_self_item() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t2_huizhao_jing"))
	assert_true(_use(battle, 1, "t2_jiandun"))
	assert_true(_use(battle, 1, "t2_feibiao"))
	assert_true(_use(battle, 1, "t2_duyao"))
	var result: Dictionary = _resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.shield[1][0], 4, "敌方自向增益不消耗反制")
	assert_eq(battle.hp[0][0], 20, "第一件敌向伤害道具应被反制")
	assert_eq(int(battle.get_status(0, 0, "poison", 0)), 3,
		"第二件敌向道具应正常生效")
	assert_true(result["events"].any(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "item_countered" \
			and String(event.get("item_id", "")) == "t2_feibiao"))


func test_multiple_huizhao_jing_and_two_sided_mirrors_resolve_independently() -> void:
	var stacked := _battle()
	assert_true(_use(stacked, 0, "t2_huizhao_jing"))
	assert_true(_use(stacked, 0, "t2_huizhao_jing"))
	assert_true(_use(stacked, 1, "t2_feibiao"))
	assert_true(_use(stacked, 1, "t2_duyao"))
	_resolve(stacked, A.CHARGE, A.CHARGE)
	assert_eq(stacked.hp[0][0], 20)
	assert_eq(int(stacked.get_status(0, 0, "poison", 0)), 0)

	var mirrored := _battle()
	assert_true(_use(mirrored, 0, "t2_huizhao_jing"))
	assert_true(_use(mirrored, 1, "t2_huizhao_jing"))
	assert_true(_use(mirrored, 0, "t2_feibiao"))
	assert_true(_use(mirrored, 1, "t2_duyao"))
	_resolve(mirrored, A.CHARGE, A.CHARGE)
	assert_eq(mirrored.hp[1][0], 20)
	assert_eq(int(mirrored.get_status(0, 0, "poison", 0)), 0)
