extends GutTest

const A := ActionDef.Action
const SEED := 82409


func _hero(id: String, hp_points: int = 10) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = hp_points
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(energy: int = 20) -> BattleCore:
	return _battle_with_team(["test_a", "test_b", "test_c"], energy)


func _battle_with_team(ids: Array, energy: int = 20) -> BattleCore:
	return _battle_with_teams(ids, ["test_x", "test_y", "test_z"], energy)


func _battle_with_teams(p1_ids: Array, p2_ids: Array, energy: int = 20) -> BattleCore:
	var battle := BattleCore.new()
	var p1: Array = []
	for id in p1_ids:
		p1.append(_hero(String(id)))
	var p2: Array = []
	for id in p2_ids:
		p2.append(_hero(String(id)))
	battle.setup(p1, p2, SEED)
	battle.energy = [energy, energy]
	return battle


func _give_and_use(battle: BattleCore, player: int, id: String) -> void:
	var index: int = battle.give_item(player, ItemCatalog.make(id))
	assert_true(battle.use_item(player, index), "道具应可提交：%s" % id)


func _ready_slot(id: String) -> Dictionary:
	return {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make(id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


func _resolve(battle: BattleCore, p0_action: int, p1_action: int) -> void:
	assert_true(battle.select_action(0, p0_action))
	assert_true(battle.select_action(1, p1_action))
	battle.resolve()


func test_baolie_discount_is_visible_to_all_action_cost_queries() -> void:
	var battle := _battle_with_team(["h14", "h24", "test_c"], 2)
	_give_and_use(battle, 0, "t2_baolie")
	assert_eq(battle.action_cost(0, A.BIG_ATTACK), 2)
	assert_true(battle.can_afford(0, A.BIG_ATTACK))
	assert_true(battle.legal_actions(0).any(
		func(choice: Dictionary) -> bool: return int(choice["action"]) == A.BIG_ATTACK))
	battle.hp[0][0] = 2
	assert_true(battle.can_pay_action_with_blood(0, A.BIG_ATTACK))
	assert_true(battle.can_use_energy_cap_discount(0, A.BIG_ATTACK))
	assert_true(battle.select_action(0, A.BIG_ATTACK))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.energy[0], 2, "大波只应支付折后1点能量，再获得回合被动能量")


func test_mojing_is_immediate_and_repaid_before_next_selection() -> void:
	var battle := _battle(0)
	var index: int = battle.give_item(0, ItemCatalog.make("t2_mojing"))
	assert_true(battle.use_item(0, index))
	assert_eq(battle.energy[0], 6, "提交魔晶时立即获得3点能量")
	assert_true(battle.select_action(0, A.BIG_ATTACK), "即时产能应能支付同回合大波")
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.energy[0], 0, "回合被动能量到账后，下回合选招前偿还1点")
	assert_false(battle.can_afford(0, A.ATTACK), "偿还必须先于下一回合选择")


func test_dianjinshi_offers_three_t3_choices_and_locks_the_target_for_one_turn() -> void:
	var battle := _battle()
	battle.slots[0] = [_ready_slot("t2_dianjinshi"), _ready_slot("t1_feibiao")]
	assert_false(battle.use_slot(0, 0), "点金石必须明确选择另一件普通道具")
	var choices: Array = battle.begin_pointstone_draft(0, 0, 1)
	assert_eq(choices.size(), 3)
	var choice_ids: Array[String] = []
	var unique_ids: Dictionary = {}
	for data: ItemData in choices:
		assert_eq(data.tier, 3)
		choice_ids.append(data.item_id)
		unique_ids[data.item_id] = true
	assert_eq(unique_ids.size(), 3, "点金石的三个传说候选不得重复")
	var energy_before: int = battle.energy[0]
	assert_true(battle.use_slot(0, 0, -1, 1, 1))
	assert_true(bool(battle.slots[0][0]["used"]))
	assert_eq(String(battle.slots[0][1]["item"].item_id), choice_ids[1])
	assert_eq(battle.energy[0], energy_before, "点金石升级不得扣除能量")
	assert_false(battle.slot_ready(0, 1), "升级出的传说道具必须锁定一回合")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_true(battle.slot_ready(0, 1), "下一回合传说道具应解除锁定")


func test_dianjinshi_rejects_non_t1_target_and_missing_choice() -> void:
	var battle := _battle()
	battle.slots[0] = [_ready_slot("t2_dianjinshi"), _ready_slot("t2_feibiao")]
	assert_eq(battle.begin_pointstone_draft(0, 0, 1), [])
	assert_false(battle.use_slot(0, 0, -1, 1, 0))
	battle.slots[0][1] = _ready_slot("t1_feibiao")
	assert_eq(battle.begin_pointstone_draft(0, 0, 1).size(), 3)
	assert_false(battle.use_slot(0, 0, -1, 1), "选定普通道具后仍必须选择一个传说候选")


func test_fengyin_consumes_but_nullifies_first_legal_item_next_turn() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_fengyin")
	_resolve(battle, A.CHARGE, A.CHARGE)
	battle.slots[1] = [_ready_slot("t2_feibiao"), _ready_slot("t2_feibiao")]
	assert_true(battle.use_slot(1, 0), "被封道具仍应照常消耗")
	assert_true(bool(battle.slots[1][0]["used"]))
	assert_eq(battle.item_uses[1].size(), 0, "被封道具不能进入效果队列")
	assert_true(battle.use_slot(1, 1), "封印只抵消第一件合法道具")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.hp[0][0], 16, "只有第二枚2点飞镖造成伤害")


func test_unused_fengyin_expires_after_its_due_turn() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_fengyin")
	_resolve(battle, A.CHARGE, A.CHARGE)
	_resolve(battle, A.CHARGE, A.CHARGE)
	battle.slots[1] = [_ready_slot("t2_feibiao")]
	assert_true(battle.use_slot(1, 0))
	assert_eq(battle.item_uses[1].size(), 1, "未用封印不能延续到第三回合")


func test_shuangsheng_adds_one_whole_attack_trigger_not_one_per_h13_segment() -> void:
	var battle := _battle_with_team(["h13", "h10", "test_c"])
	_give_and_use(battle, 0, "t2_shuangsheng")
	assert_true(battle.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(int(battle.get_status(0, 1, "jianqi", 0)), 3,
		"玄冥两段自然触发2次，双生只为整次攻击额外增加1次")
	assert_eq(battle.hp[1][0], 14, "双波总伤害4点，双生整次攻击再加1点")


func test_hit_items_trigger_once_per_split_and_shuangsheng_adds_one() -> void:
	var baseline := _battle_with_team(["h13", "test_b", "test_c"])
	for slot in range(3):
		baseline.hp[0][slot] = 10
	_give_and_use(baseline, 0, "t2_jike")
	assert_true(baseline.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(baseline.select_action(1, A.CHARGE))
	baseline.resolve()
	assert_eq(baseline.hp[0], [12, 12, 12], "饥渴按整次双段攻击只触发一次")

	var doubled := _battle_with_team(["h13", "test_b", "test_c"])
	for slot in range(3):
		doubled.hp[0][slot] = 10
	_give_and_use(doubled, 0, "t2_jike")
	_give_and_use(doubled, 0, "t2_shuangsheng")
	assert_true(doubled.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(doubled.select_action(1, A.CHARGE))
	doubled.resolve()
	assert_eq(doubled.hp[0], [12, 12, 12], "双生只重复英雄技能，饥渴仍只触发一次")


func test_huoshou_uses_the_same_whole_attack_trigger_count() -> void:
	var battle := _battle_with_team(["h13", "test_b", "test_c"], 10)
	_give_and_use(battle, 0, "t2_huoshou")
	_give_and_use(battle, 0, "t2_shuangsheng")
	assert_true(battle.select_action(0, A.BIG_ATTACK, -1, false, true))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.energy[0], 9, "双生只重复英雄技能，护手仍只获得一次1.5能")


func test_lieyin_vulnerable_applies_to_all_damage_and_persists_until_switching_out() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_lieyin")
	_give_and_use(battle, 0, "t2_feibiao")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.hp[1][0], 13, "3层脆弱应放大独立道具伤害")
	assert_eq(int(battle.get_status(1, 0, "vuln", 0)), 3)
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 8, "3层脆弱应继续放大后续基础攻击")
	assert_eq(int(battle.get_status(1, 0, "vuln", 0)), 3)
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_switch(1, 1))
	battle.resolve()
	assert_eq(int(battle.get_status(1, 0, "vuln", 0)), 0, "目标换下场时脆弱清除")


func test_huanhundan_persists_and_nullifies_the_whole_fatal_hit() -> void:
	var battle := _battle_with_teams(
		["test_a", "test_b", "test_c"], ["h10", "test_y", "test_z"])
	battle.hp[0][0] = 2
	battle.shield[0][0] = 2
	_give_and_use(battle, 0, "t2_huanhundan")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 1,
		"未触发的致命免疫应保留到本局结束")
	_resolve(battle, A.CHARGE, A.BIG_ATTACK)
	assert_eq(battle.hp[0][0], 2, "致命整次伤害应归零")
	assert_eq(battle.shield[0][0], 2, "致命免疫不得消耗护甲")
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 0)
	assert_eq(int(battle.get_status(1, 0, "jianqi", 0)), 1, "免疫伤害仍然算命中")


func test_huanhundan_is_limited_to_once_per_hero_and_stops_fatal_life_loss() -> void:
	var battle := _battle()
	var first: int = battle.give_item(0, ItemCatalog.make("t2_huanhundan"))
	var second: int = battle.give_item(0, ItemCatalog.make("t2_huanhundan"))
	assert_true(battle.use_item(0, first))
	assert_false(battle.use_item(0, second), "同一英雄同一局不能提交第二颗还魂丹")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 1)
	assert_eq(int(battle.get_status(0, 0, "huanhun_used", 0)), 1)
	var events: Array = []
	var lost: int = battle.lose_life(0, 0, 20, events, "rule_execution")
	assert_eq(lost, 0)
	assert_eq(battle.hp[0][0], 20)
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 0)
	assert_false(battle.use_item(0, second), "保险触发后也不能为该英雄再次使用还魂丹")
	var restored := BattleCore.new()
	assert_true(restored.from_snapshot(battle.to_snapshot()))
	assert_false(restored.use_item(0, second), "快照恢复后仍必须保留每名英雄限用一次的权威记录")
	assert_true(battle.use_item(0, second, 1), "另一名英雄仍可使用自己的1次还魂丹")


func test_daijia_boosts_base_attack_then_executes_current_active_hero() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_daijia")
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.hp[1][0], 14, "波应获得2点整次总加伤")
	assert_eq(battle.hp[0][0], 0, "统一死亡结算前，当时的出战英雄应死亡")
	assert_true(battle.pending_death_switch[0])


func test_daijia_execution_is_prevented_by_huanhundan() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_huanhundan")
	_give_and_use(battle, 0, "t2_daijia")
	_resolve(battle, A.DEFEND, A.CHARGE)
	assert_eq(battle.hp[0][0], 20, "还魂丹应令力量代价的致命处决整次无效")
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 0)
	assert_false(battle.pending_death_switch[0])


func test_huanhundan_prevents_fatal_blood_payment_but_action_still_resolves() -> void:
	var battle := _battle_with_team(["h14", "test_b", "test_c"], 0)
	battle.hp[0][0] = 2
	_give_and_use(battle, 0, "t2_huanhundan")
	assert_true(battle.select_action(0, A.ATTACK, -1, false, false, true))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[0][0], 2, "致命生命支付应被还魂丹整次取消")
	assert_eq(battle.hp[1][0], 18, "已经提交的波仍应正常结算")
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 0)


func test_fatal_blood_payment_triggers_tail_needle_without_huanhundan() -> void:
	var battle := _battle_with_team(["h14", "test_b", "test_c"], 0)
	battle.hp[0][0] = 2
	_give_and_use(battle, 0, "t1_weihouzhen")
	assert_true(battle.select_action(0, A.ATTACK, -1, false, false, true))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_lte(battle.hp[0][0], 0)
	assert_eq(battle.hp[1][0], 14, "生命支付致死后，波与尾后针应分别结算")


func test_huanhundan_protects_switched_out_hero_from_fatal_h11_chase() -> void:
	var battle := _battle_with_teams(
		["test_a", "test_b", "test_c"], ["h11", "test_y", "test_z"])
	battle.hp[0][0] = 4
	_give_and_use(battle, 0, "t2_huanhundan")
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[0][0], 4, "还魂丹最低层保险也应覆盖切换离场时的致命穷追")
	assert_eq(int(battle.get_status(0, 0, "fatal_damage_immunity", 0)), 0)


func test_nuanyu_requires_a_base_attack_to_be_fully_blocked() -> void:
	var item_only := _battle()
	item_only.hp[0] = [10, 12, 14]
	_give_and_use(item_only, 0, "t2_nuanyu")
	_give_and_use(item_only, 1, "t2_feibiao")
	_resolve(item_only, A.DEFEND, A.CHARGE)
	assert_eq(item_only.hp[0], [10, 12, 14], "挡下独立道具伤害不算暖玉的成功防御")

	var shield_only := _battle()
	shield_only.hp[0][0] = 10
	shield_only.shield[0][0] = 4
	_give_and_use(shield_only, 0, "t2_nuanyu")
	_resolve(shield_only, A.CHARGE, A.ATTACK)
	assert_eq(shield_only.hp[0][0], 10, "仅由护甲吸收也不算成功防御")

	var blocked := _battle()
	blocked.hp[0] = [10, 12, 14]
	_give_and_use(blocked, 0, "t2_nuanyu")
	_resolve(blocked, A.DEFEND, A.ATTACK)
	assert_eq(blocked.hp[0], [12, 14, 16], "成功防御后所有存活英雄各回复1点")

	var dead_ally := _battle()
	dead_ally.hp[0] = [10, 0, 14]
	_give_and_use(dead_ally, 0, "t2_nuanyu")
	_resolve(dead_ally, A.DEFEND, A.ATTACK)
	assert_eq(dead_ally.hp[0], [12, 0, 16], "暖玉不能复活阵亡英雄")


func test_caoren_is_self_protection_and_works_through_sage_book() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_caoren")
	_give_and_use(battle, 1, "t1_hushenfu")
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_action(1, A.ATTACK))
	battle.resolve()
	assert_eq(battle.active_index[0], 1)
	assert_eq(battle.hp[0][1], 20, "草人不是对敌debuff，不应被圣贤书拦截")


func test_caoren_recognizes_an_h07_free_switch_already_made_in_selection() -> void:
	var battle := _battle_with_team(["h07", "test_b", "test_c"])
	assert_true(battle.free_switch(0, 1))
	_give_and_use(battle, 0, "t2_caoren")
	_resolve(battle, A.CHARGE, A.ATTACK)
	assert_eq(battle.hp[0][1], 20, "先免费切换、后提交草人也应让敌方攻击落空")


func test_dingshen_blocks_current_and_next_turn_switches_but_not_death_replacement() -> void:
	var battle := _battle_with_teams(
		["test_a", "test_b", "test_c"], ["h07", "test_y", "test_z"])
	_give_and_use(battle, 0, "t2_dingshen")
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_switch(1, 1), "揭示前仍可提交切换，结算时应判无效")
	battle.resolve()
	assert_eq(battle.active_index[1], 0)
	assert_false(battle.can_switch(1), "下回合仍在定身期限内")
	assert_false(battle.select_switch(1, 1))
	assert_false(battle.free_switch(1, 1), "免费切换也必须无效")
	assert_false(battle.legal_actions(1).any(
		func(choice: Dictionary) -> bool: return int(choice["action"]) == A.SWITCH),
		"AI与模拟合法动作也不得枚举切换")
	battle.hp[1][0] = 0
	battle.pending_death_switch[1] = true
	assert_true(battle.execute_death_switch(1, 1), "死亡补位不属于切换，必须允许")


func test_dingshen_blocks_forced_switch_and_expires_after_next_turn() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_dingshen")
	battle.request_forced_pull(1, 1)
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.active_index[1], 0, "当前回合强制换位也应无效")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_true(battle.can_switch(1), "下回合结束后定身应过期")
	assert_true(battle.select_switch(1, 1))


func test_shitiechong_expires_even_when_no_defense_was_used() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_shitiechong")
	_resolve(battle, A.CHARGE, A.CHARGE)
	_resolve(battle, A.BIG_ATTACK, A.BIG_DEFEND)
	assert_eq(battle.hp[1][0], 20, "未触发的降防不能保留到下一回合")


func test_base_attack_only_modifiers_do_not_boost_independent_item_damage() -> void:
	var battle := _battle()
	battle.shield[1][0] = 4
	_give_and_use(battle, 0, "t2_qiubite")
	_give_and_use(battle, 0, "t2_feibiao")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.hp[1][0], 20, "心脏魔法的加伤与穿甲不能作用独立飞镖")
	assert_eq(battle.shield[1][0], 0)


func test_qiubite_changes_the_next_base_attack_to_true_damage() -> void:
	var battle := _battle()
	battle.shield[1][0] = 4
	_give_and_use(battle, 0, "t2_qiubite")
	_resolve(battle, A.ATTACK, A.BIG_DEFEND)
	assert_eq(battle.hp[1][0], 18, "真实伤害应穿过大防并无视护甲")
	assert_eq(battle.shield[1][0], 4)


func test_qiubite_expires_at_end_of_turn_without_an_attack() -> void:
	var battle := _battle()
	_give_and_use(battle, 0, "t2_qiubite")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_false(bool(battle.item_buffs[0].get("next_base_attack_true_damage", false)))
	battle.shield[1][0] = 4
	_resolve(battle, A.ATTACK, A.BIG_DEFEND)
	assert_eq(battle.hp[1][0], 20, "心脏掌握魔法不能跨回合等待下一次攻击")
	assert_eq(battle.shield[1][0], 4)
