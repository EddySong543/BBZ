extends GutTest

const A := ActionDef.Action
const SEED := 881_310


func _hero(id: String, hp_value: int = 10) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_value
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(first_p0: String = "test_a", energy_value: int = 20) -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero(first_p0), _hero("test_b"), _hero("test_c")],
		[_hero("test_x"), _hero("test_y"), _hero("test_z")],
		SEED)
	battle.energy = [energy_value, energy_value]
	return battle


func _item(id: String, overrides: Dictionary = {}) -> ItemData:
	var data: ItemData = ItemCatalog.make(id)
	data.params.merge(overrides, true)
	return data


func _use(battle: BattleCore, player: int, id: String,
		overrides: Dictionary = {}) -> bool:
	return battle.use_item(player, battle.give_item(player, _item(id, overrides)))


func _ready_slot(id: String, overrides: Dictionary = {}) -> Dictionary:
	return {
		state = BattleCore.SlotState.CHARGING,
		item = _item(id, overrides),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


func _resolve(battle: BattleCore, p0_action: int, p1_action: int) -> Dictionary:
	assert_true(battle.select_action(0, p0_action))
	assert_true(battle.select_action(1, p1_action))
	return battle.resolve()


func _pending_h07_switch_battle() -> BattleCore:
	var battle := BattleCore.new()
	battle.setup(
		[_hero("test_a"), _hero("test_b"), _hero("test_c")],
		[_hero("test_x"), _hero("h07"), _hero("test_z")],
		SEED)
	battle.energy = [20, 20]
	assert_true(_use(battle, 1, "t3_yemingzhu"))
	_resolve(battle, A.DEFEND, A.DEFEND)
	battle.set_status(1, 0, "vuln", 3)
	return battle


func test_budongmingwang_merges_charges_and_converts_one_whole_defense() -> void:
	var battle := _battle("h13")
	assert_true(_use(battle, 1, "t3_budongmingwang"))
	assert_true(_use(battle, 1, "t3_budongmingwang"))
	assert_eq(battle.relics[1].size(), 1, "同名遗物必须合并为一个状态区")
	assert_eq(int(battle.relics[1][0]["state"].get("charges", 0)), 6)
	assert_true(battle.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(battle.select_action(1, A.BIG_DEFEND))
	battle.resolve()
	assert_eq(battle.shield[1][0], 4, "h13双段大波按整次防御前总伤害只转一次护甲")
	assert_eq(int(battle.relics[1][0]["state"].get("charges", 0)), 5)


func test_budongmingwang_has_three_successful_defense_charges() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_budongmingwang"))
	for expected_charge in [2, 1, 0]:
		_resolve(battle, A.DEFEND, A.ATTACK)
		if expected_charge > 0:
			assert_eq(int(battle.relics[0][0]["state"].get("charges", -1)), expected_charge)
	assert_eq(battle.shield[0][0], 6, "三次波各转化2个半点护甲")
	assert_eq(battle.relics[0].size(), 0)


func test_judingsanhua_consumes_attack_actions_but_only_adds_effects_on_hit() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_judingsanhua"))
	_resolve(battle, A.ATTACK, A.DEFEND)
	assert_eq(int(battle.relics[0][0]["state"].get("charges", 0)), 2,
		"攻击行动即消耗次数；被挡下时只是没有附加效果可触发")
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(int(battle.relics[0][0]["state"].get("charges", 0)), 1)


func test_hedinghong_consumes_once_and_adds_one_point_per_poison_layer() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_hedinghong"))
	battle.set_status(1, 0, "poison", 3)
	_resolve(battle, A.BIG_ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 7, "大波4半点+毒3半点+鹤顶红6半点")
	assert_eq(battle.relics[0].size(), 0)


func test_shixinding_attacks_gain_damage_then_a_broken_streak_backlashes_and_ends() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_shixinding"))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 16)
	battle.hp[0][0] = 4
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_lte(battle.hp[0][0], 0)
	assert_true(battle.pending_death_switch[0], "反噬致死后必须再次进入统一死亡链")
	assert_eq(battle.relics[0].size(), 0)


func test_huanhundan_prevents_fatal_shixinding_backlash_once() -> void:
	var battle := _battle()
	battle.hp[0][0] = 6
	assert_true(_use(battle, 0, "t2_huanhundan"))
	assert_true(_use(battle, 0, "t3_shixinding"))
	_resolve(battle, A.ATTACK, A.CHARGE)
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.hp[0][0], 6, "噬心钉的致命生命失去应被还魂丹取消")
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 0)
	assert_eq(battle.relics[0].size(), 0, "反噬被阻止后噬心钉仍应结束")


func test_morihuozhong_is_permanent_and_only_buffs_last_survivor_actions() -> void:
	var battle := _battle()
	battle.hp[0][1] = 0
	battle.hp[0][2] = 0
	assert_true(_use(battle, 0, "t3_morihuozhong"))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 16)
	_resolve(battle, A.DEFEND, A.ATTACK)
	assert_eq(battle.shield[0][0], 2)
	assert_eq(battle.relics[0].size(), 1)


func test_qingyuanbaolian_grants_now_and_on_the_next_two_turns() -> void:
	var battle := _battle("test_a", 0)
	assert_true(_use(battle, 0, "t3_qingyuanbaolian"))
	assert_eq(battle.energy[0], 3, "本回合的1.5能必须在提交时立即可用")
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy[0], 5, "激活回合只再获得被动1能")
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy[0], 10)
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy[0], 15)
	assert_eq(battle.relics[0].size(), 0)


func test_xumingxiang_heals_current_living_active_for_three_turns_without_reviving() -> void:
	var battle := _battle()
	battle.hp[0][0] = 10
	assert_true(_use(battle, 0, "t3_xumingxiang"))
	for _turn in range(3):
		_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.hp[0][0], 19)
	assert_eq(battle.relics[0].size(), 0)
	battle.hp[0][1] = 0
	assert_eq(battle._heal(0, 1, 3), 0)
	assert_eq(battle.hp[0][1], 0, "治疗不得复活0HP英雄")


func test_jianyi_arms_only_on_hit_and_makes_next_turn_big_wave_free() -> void:
	var battle := _battle("test_a", 6)
	assert_true(_use(battle, 0, "t3_jianyi"))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(int(battle.item_buffs[0].get("free_big_attack_until_turn", -1)), 1)
	assert_eq(battle.action_cost(0, A.BIG_ATTACK), 0)
	var before: int = battle.energy[0]
	_resolve(battle, A.BIG_ATTACK, A.CHARGE)
	assert_eq(battle.energy[0], before + 2, "免费大波只获得回合被动能量，不扣3能")
	assert_false(battle.item_buffs[0].has("free_big_attack_until_turn"))


func test_jianyi_does_not_arm_when_wave_is_blocked() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_jianyi"))
	_resolve(battle, A.ATTACK, A.DEFEND)
	assert_false(battle.item_buffs[0].has("free_big_attack_until_turn"))


func test_longxi_only_exhausts_after_an_actual_big_defend_block() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_longxi"))
	assert_true(_use(battle, 0, "t2_shitiechong"))
	_resolve(battle, A.BIG_ATTACK, A.BIG_DEFEND)
	assert_eq(battle.hp[1][0], 12, "大防被降级后没有实际挡下龙息")
	assert_false(bool(battle.item_buffs[0].get("exhausted_next", false)))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 10, "未被有效大防挡下时，下回合攻击照常执行")


func test_upper_potions_use_the_approved_immediate_values() -> void:
	var battle := _battle("test_a", 0)
	assert_true(_use(battle, 0, "t3_fali"))
	assert_eq(battle.energy[0], 8)
	battle.hp[0][0] = 10
	assert_true(_use(battle, 0, "t3_shengming"))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.hp[0][0], 16)


func test_yemingzhu_only_triggers_on_eligible_switches_and_uses_normal_damage() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_yemingzhu"))
	var forced_events: Array = []
	battle._perform_switch(0, 0, 1, forced_events)
	assert_eq(battle.hp[1][0], 20)
	assert_eq(int(battle.relics[0][0]["state"].get("charges", 0)), 3,
		"追击/强制换位不消耗夜明珠")
	assert_true(battle.select_switch(0, 2))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[1][0], 18)
	assert_eq(battle.shield[0][2], 2)
	assert_eq(int(battle.relics[0][0]["state"].get("charges", 0)), 2)


func test_yemingzhu_damage_does_not_count_as_a_hero_attack_hit() -> void:
	var battle := _battle("h10")
	assert_true(_use(battle, 0, "t3_yemingzhu"))
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[1][0], 18, "夜明珠的独立道具伤害仍正常结算")
	assert_eq(int(battle.get_status(0, 0, "jianqi", 0)), 0,
		"夜明珠伤害不能冒充攻击命中为昴日积累剑气")


func test_tinglong_damage_does_not_count_as_a_hero_attack_hit() -> void:
	var battle := _battle("h10", 8)
	assert_true(_use(battle, 0, "t3_tinglong"))
	_resolve(battle, A.DEFEND, A.CHARGE)
	assert_eq(battle.hp[1][0], 16, "停龙剑的独立道具伤害仍正常结算")
	assert_eq(int(battle.get_status(0, 0, "jianqi", 0)), 0,
		"停龙剑伤害不能冒充攻击命中为昴日积累剑气")


func test_mengdie_swaps_post_payment_energy_and_complete_slots_but_not_hp() -> void:
	var battle := _battle()
	battle.energy = [6, 10]
	battle.hp[0][0] = 9
	battle.hp[1][0] = 15
	battle.slots = [
		[_ready_slot("t3_mengdie"), _ready_slot("t1_feibiao")],
		[_ready_slot("t3_fali")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.select_action(0, A.BIG_ATTACK))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.energy, [14, 2], "先扣大波费用/结算攒，再交换剩余能量，最后各得被动能量")
	assert_eq(battle.hp[0][0], 9, "梦蝶不交换生命")
	assert_eq(battle.hp[1][0], 11, "原本已合法的大波在交换后仍完成")
	assert_eq(String((battle.slots[0][0]["item"] as ItemData).item_id), "t3_fali")
	assert_eq(int(battle.slots[1][0]["state"]), BattleCore.SlotState.EMPTY,
		"用掉的梦蝶随完整栏交换后在对方栏变为空槽")
	assert_eq(String((battle.slots[1][1]["item"] as ItemData).item_id), "t1_feibiao")


func test_two_effective_mengdie_requests_cancel_each_other() -> void:
	var battle := _battle()
	battle.energy = [4, 10]
	battle.slots = [[_ready_slot("t3_mengdie")], [_ready_slot("t3_mengdie")]]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy, [6, 12], "双梦蝶偶数次抵消，只剩双方被动能量")


func test_tianluo_rolls_back_immediate_energy_and_falls_unaffordable_action_to_charge() -> void:
	var battle := _battle("test_a", 0)
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t3_fali")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0))
	assert_eq(battle.energy[1], 8)
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_action(1, A.BIG_ATTACK))
	battle.resolve()
	assert_eq(battle.hp[0][0], 20, "天罗取消即时能量后，付不起的大波回退为攒")
	assert_eq(battle.energy[1], 4, "回滚到0能后执行攒+1能，并获得被动+1能")
	assert_eq(int(battle.slots[1][0]["state"]), BattleCore.SlotState.EMPTY,
		"效果被取消，道具来源槽仍照常消耗")


func test_tianluo_only_invalidates_first_submitted_item_and_preserves_later_items() -> void:
	var battle := _battle("test_a", 0)
	battle.hp[1][0] = 10
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t2_shengming"), _ready_slot("t3_fali")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 1), "先提交的上等法力药水应成为首件")
	assert_true(battle.use_slot(1, 0), "后提交的普通生命药水应保留效果")
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy[1], 2, "首件上等法力药水失效，只剩回合被动能量")
	assert_eq(battle.hp[1][0], 14, "第二件普通生命药水仍应回复2点生命")
	assert_eq(int(battle.slots[1][0]["state"]), BattleCore.SlotState.EMPTY)
	assert_eq(int(battle.slots[1][1]["state"]), BattleCore.SlotState.EMPTY)


func test_tianluo_invalidates_huanhundan_effect_but_not_its_once_per_hero_use() -> void:
	var battle := _battle()
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t2_huanhundan")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(int(battle.get_status(1, 0, "fatal_damage_immunity", 0)), 0,
		"天罗应让首件还魂丹的保险效果无效")
	assert_eq(int(battle.get_status(1, 0, "huanhun_used", 0)), 1,
		"道具已被消耗，即使效果无效也要用掉该英雄的唯一使用资格")
	var retry: int = battle.give_item(1, ItemCatalog.make("t2_huanhundan"))
	assert_false(battle.use_item(1, retry), "被天罗抵消后也不能为该英雄再用还魂丹")


func test_sage_book_counters_tianluo_and_preserves_same_turn_items() -> void:
	var battle := _battle("test_a", 0)
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t3_fali"), _ready_slot("t1_hushenfu")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0))
	assert_true(battle.use_slot(1, 1))
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_action(1, A.BIG_ATTACK))
	battle.resolve()
	assert_eq(battle.hp[0][0], 16)
	assert_eq(battle.energy[1], 4, "上等法力药水未被回滚：8-6+被动2")


func test_tianluo_rolls_back_furnace_energy_without_burning_its_fuel() -> void:
	var battle := _battle("test_a", 0)
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t1_ronglu"), _ready_slot("t1_feibiao")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0, -1, 1))
	assert_eq(battle.energy[1], 4)
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy[1], 2, "熔炉即时能量被回滚，只剩回合被动能量")
	assert_eq(int(battle.slots[1][0]["state"]), BattleCore.SlotState.EMPTY,
		"天罗仍消耗熔炉本体")
	assert_eq(String((battle.slots[1][1]["item"] as ItemData).item_id), "t1_feibiao",
		"燃料的烧毁属于熔炉效果，必须被天罗撤销")
	assert_true(battle.slot_ready(1, 1))


func test_tianluo_rolls_back_pointstone_upgrade_but_consumes_pointstone() -> void:
	var battle := _battle()
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t2_dianjinshi"), _ready_slot("t1_feibiao")],
	]
	var choices: Array = battle.begin_pointstone_draft(1, 0, 1)
	assert_eq(choices.size(), 3)
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0, -1, 1, 0))
	assert_ne(String((battle.slots[1][1]["item"] as ItemData).item_id), "t1_feibiao")
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(int(battle.slots[1][0]["state"]), BattleCore.SlotState.EMPTY)
	assert_eq(String((battle.slots[1][1]["item"] as ItemData).item_id), "t1_feibiao",
		"升级和新道具锁定都必须回滚")
	assert_true(battle.slot_ready(1, 1))


func test_tianluo_removes_relic_registered_during_the_selection_transaction() -> void:
	var battle := _battle("test_a", 0)
	battle.slots = [
		[_ready_slot("t3_tianluodiwang")],
		[_ready_slot("t3_qingyuanbaolian")],
	]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0))
	assert_eq(battle.relics[1].size(), 1)
	assert_eq(battle.energy[1], 3)
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.relics[1].size(), 0)
	assert_eq(battle.energy[1], 2)


func test_double_tianluo_resolves_symmetrically_and_invalidates_both_switches() -> void:
	var battle := _battle()
	battle.slots = [[_ready_slot("t3_tianluodiwang")], [_ready_slot("t3_tianluodiwang")]]
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(1, 0))
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_switch(1, 1))
	battle.resolve()
	assert_eq(battle.active_index, [0, 0])
	assert_eq(int(battle.slots[0][0]["state"]), BattleCore.SlotState.EMPTY)
	assert_eq(int(battle.slots[1][0]["state"]), BattleCore.SlotState.EMPTY)


func test_tianluo_cancels_h07_free_switch_before_any_switch_side_effect() -> void:
	var battle := _pending_h07_switch_battle()
	assert_true(_use(battle, 0, "t3_tianluodiwang"))
	assert_true(battle.free_switch(1, 1))
	assert_eq(battle.active_index[1], 1, "选择期仍预览免费切换后的出战英雄")
	var result := _resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.active_index[1], 0, "天罗令选择期免费切换的位置变化无效")
	assert_eq(battle.hp[0][0], 20, "h07 入场冲撞不得先发生再回滚")
	assert_eq(battle.shield[1][1], 0, "夜明珠护甲不得先发生再回滚")
	assert_eq(int(battle.relics[1][0]["state"].get("charges", 0)), 3,
		"夜明珠次数不得消耗")
	assert_eq(int(battle.get_status(1, 0, "vuln", 0)), 3,
		"原出战英雄的离场清状态副作用不得发生")
	assert_eq(battle.free_switch_uses[1], 0, "被天罗取消后应恢复免费切换次数")
	var cancel_event: Dictionary = {}
	for event_variant in result.get("events", []):
		var event: Dictionary = event_variant
		if String(event.get("id", "")) == "free_switch_cancelled" \
				and int(event.get("player", -1)) == 1:
			cancel_event = event
			break
	assert_eq(int(cancel_event.get("from", -1)), 0,
		"取消事件必须携带恢复后的原出战槽")
	assert_eq(int(cancel_event.get("hp_before", -1)), 20,
		"取消事件必须携带裁定时原出战槽的半点生命基线")


func test_sage_book_blocks_tianluo_then_h07_free_switch_commits_once() -> void:
	var battle := _pending_h07_switch_battle()
	assert_true(_use(battle, 0, "t3_tianluodiwang"))
	assert_true(_use(battle, 1, "t1_hushenfu"))
	assert_true(battle.free_switch(1, 1))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.active_index[1], 1)
	assert_eq(battle.hp[0][0], 17, "圣贤书抵消天罗后，h07冲撞与夜明珠伤害各结算一次")
	assert_eq(battle.shield[1][1], 2)
	assert_eq(int(battle.relics[1][0]["state"].get("charges", 0)), 2)
	assert_eq(int(battle.get_status(1, 0, "vuln", 0)), 0)
	assert_eq(battle.free_switch_uses[1], 1)


func test_tianluo_h07_free_switch_result_is_submission_order_independent() -> void:
	var tianluo_first := _pending_h07_switch_battle()
	assert_true(_use(tianluo_first, 0, "t3_tianluodiwang"))
	assert_true(tianluo_first.free_switch(1, 1))
	_resolve(tianluo_first, A.DEFEND, A.DEFEND)

	var switch_first := _pending_h07_switch_battle()
	assert_true(switch_first.free_switch(1, 1))
	assert_true(_use(switch_first, 0, "t3_tianluodiwang"))
	_resolve(switch_first, A.DEFEND, A.DEFEND)
	assert_eq(switch_first.to_snapshot(), tianluo_first.to_snapshot(),
		"先提交天罗或先预览免费切换，权威结果必须一致")


func test_pending_h07_free_switch_survives_snapshot_until_tianluo_adjudication() -> void:
	var battle := _pending_h07_switch_battle()
	assert_true(battle.free_switch(1, 1))
	var cloned := battle.clone()
	assert_true(_use(cloned, 0, "t3_tianluodiwang"))
	_resolve(cloned, A.DEFEND, A.DEFEND)
	assert_eq(cloned.active_index[1], 0, "clone必须独立保留并裁定免费切换意图")
	assert_eq(battle.active_index[1], 1, "clone结算不得污染原局的选择期预览")
	var restored := BattleCore.new()
	assert_true(restored.from_snapshot(battle.to_snapshot()))
	assert_eq(restored.active_index[1], 1)
	assert_true(_use(restored, 0, "t3_tianluodiwang"))
	_resolve(restored, A.DEFEND, A.DEFEND)
	assert_eq(restored.active_index[1], 0)
	assert_eq(restored.hp[0][0], 20)
	assert_eq(int(restored.relics[1][0]["state"].get("charges", 0)), 3)
