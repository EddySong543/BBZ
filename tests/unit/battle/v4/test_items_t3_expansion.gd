extends GutTest

const A := ActionDef.Action
const SS := BattleCore.SlotState
const SEED := 81626


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
		[_hero("test_a"), _hero("test_b"), _hero("test_c")],
		[_hero("test_x"), _hero("test_y"), _hero("test_z")],
		SEED)
	battle.energy = [10, 10]
	return battle


func _item(id: String) -> ItemData:
	return ItemCatalog.make(id)


func _use(battle: BattleCore, player: int, id: String, target: int = -1) -> bool:
	return battle.use_item(player, battle.give_item(player, _item(id)), target)


func _ready_slot(id: String) -> Dictionary:
	return {state = SS.CHARGING, item = _item(id), since = -1,
		used = false, draft = [], upg_draft = []}


func _resolve(battle: BattleCore, p0_action: int, p1_action: int) -> Dictionary:
	assert_true(battle.select_action(0, p0_action))
	assert_true(battle.select_action(1, p1_action))
	return battle.resolve()


func test_sanqi_zhong_ends_active_item_effects_but_not_hero_statuses_or_settled_values() -> void:
	var battle := _battle()
	battle.item_buffs[0]["free_big_attack_until_turn"] = 9
	battle.item_buffs[1]["sealed_item_turns"] = [{turn = 1, charges = 1}]
	battle.timed_item_effects[1].append({item_id = "t1_yaohuo", due_turn = 1, target_slot = 0})
	battle.set_status(0, 0, "poison", 2)
	assert_true(_use(battle, 0, "t3_qingyuanbaolian"))
	assert_true(_use(battle, 1, "t3_sanqi_zhong"))
	var before_energy: Array[int] = battle.energy.duplicate()
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.relics[0].size(), 0)
	assert_eq(battle.timed_item_effects[1].size(), 0)
	assert_false(battle.item_buffs[0].has("free_big_attack_until_turn"))
	assert_false(battle.item_buffs[1].has("sealed_item_turns"))
	assert_eq(int(battle.get_status(0, 0, "poison", 0)), 2, "英雄战斗状态不属于道具持续效果")
	assert_gte(battle.energy[0], before_energy[0], "散契钟不回滚已到账资源")


func test_zhaohun_fan_revives_a_dead_reserve_at_one_hp() -> void:
	var battle := _battle()
	battle.hp[0][2] = 0
	battle.shield[0][2] = 6
	battle.pending_damage[0][2] = 4
	battle._death_processed[0][2] = true
	assert_false(_use(battle, 0, "t3_zhaohun_fan", 1))
	assert_true(_use(battle, 0, "t3_zhaohun_fan", 2))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.hp[0][2], 2)
	assert_eq(battle.shield[0][2], 0)
	assert_eq(battle.pending_damage[0][2], 0)
	assert_false(battle._death_processed[0][2])
	assert_eq(battle.active_index[0], 0)


func test_lianhuan_gu_executes_two_different_public_actions_in_order() -> void:
	var battle := _battle()
	battle.energy[0] = 0
	assert_true(_use(battle, 0, "t3_lianhuan_gu"))
	assert_true(battle.select_action(0, A.CHARGE))
	assert_false(battle.select_second_action(0, A.CHARGE), "两个行动必须不同")
	assert_true(battle.select_second_action(0, A.ATTACK), "先攒后波应按顺序支付")
	assert_true(battle.select_action(1, A.DEFEND))
	var result := battle.resolve()
	assert_eq(battle.energy[0], 2, "攒得1能、波花1能、回合被动再得1能")
	assert_eq(battle.hp[1][0], 18, "第一阶段的防御不应跨阶段挡住第二行动的波")
	assert_true(result["events"].any(func(e: Dictionary) -> bool:
		return String(e.get("id", "")) == "lianhuan_second_action"))


func test_lianhuan_second_defense_only_applies_to_second_action_step() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t3_lianhuan_gu"))
	assert_true(_use(battle, 1, "t3_lianhuan_gu"))
	assert_true(battle.select_action(0, A.ATTACK))
	assert_true(battle.select_second_action(0, A.DEFEND))
	assert_true(battle.select_action(1, A.DEFEND))
	assert_true(battle.select_second_action(1, A.ATTACK))
	battle.resolve()
	assert_eq(battle.hp[0][0], 20)
	assert_eq(battle.hp[1][0], 20)


func test_lianhuan_second_attack_connects_to_turn_items_and_dragon_breath() -> void:
	var afterhand := _battle()
	assert_true(_use(afterhand, 0, "t1_houshou"))
	assert_true(_use(afterhand, 1, "t3_lianhuan_gu"))
	assert_true(afterhand.select_action(0, A.CHARGE))
	assert_true(afterhand.select_action(1, A.CHARGE))
	assert_true(afterhand.select_second_action(1, A.ATTACK))
	afterhand.resolve()
	assert_eq(afterhand.hp[0][0], 18)
	assert_eq(afterhand.shield[0][0], 3,
		"敌方只在第二行动攻击时，后手仍应在攻击完成后获得1.5点护盾")

	var breath := _battle()
	assert_true(_use(breath, 0, "t3_lianhuan_gu"))
	assert_true(_use(breath, 0, "t3_longxi"))
	assert_true(breath.select_action(0, A.ATTACK))
	assert_true(breath.select_second_action(0, A.BIG_ATTACK))
	assert_true(breath.select_action(1, A.DEFEND))
	breath.resolve()
	assert_eq(breath.hp[1][0], 12,
		"第一行动的波被防挡下后，第二行动的大波应单独获得龙息翻倍")


func test_lianhuan_second_defense_triggers_last_stand_fire_shield() -> void:
	var battle := _battle()
	battle.hp[0][1] = 0
	battle.hp[0][2] = 0
	assert_true(_use(battle, 0, "t3_morihuozhong"))
	assert_true(_use(battle, 0, "t3_lianhuan_gu"))
	assert_true(battle.select_action(0, A.CHARGE))
	assert_true(battle.select_second_action(0, A.DEFEND))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.shield[0][0], 2, "末日火种应识别连环鼓第二阶段的防御")


func test_jubao_pen_refills_one_empty_slot_after_economy_cleanup() -> void:
	var battle := _battle()
	battle.econ_init()
	battle.slots[0][0] = _ready_slot("t3_jubao_pen")
	battle.slots[0][1] = _ready_slot("t1_feibiao")
	battle.slots[0][2] = {state = SS.EMPTY, item = null, since = -1,
		used = false, draft = [], upg_draft = []}
	assert_true(battle.use_slot(0, 0))
	_resolve(battle, A.DEFEND, A.DEFEND)
	var filled := 0
	for slot_variant in battle.slots[0]:
		var slot: Dictionary = slot_variant
		if slot.get("item", null) != null:
			filled += 1
	assert_eq(filled, 2, "聚宝盆自身槽清空后，每回合只补入一件T1")
	assert_true(battle.relics[0].size() == 1)


func test_sheming_quan_grants_energy_now_and_forces_next_turn_charge() -> void:
	var battle := _battle()
	battle.energy[0] = 0
	assert_true(_use(battle, 0, "t3_sheming_quan"))
	assert_eq(battle.energy[0], 12)
	_resolve(battle, A.BIG_ATTACK, A.DEFEND)
	assert_true(battle.select_action(0, A.ATTACK))
	assert_true(battle.select_action(1, A.DEFEND))
	var result := battle.resolve()
	assert_eq(int(result["p1_action"]), A.CHARGE)


func test_huanming_qi_swaps_active_and_selected_reserve_hp_and_shield() -> void:
	var battle := _battle()
	battle.hp[0] = [4, 14, 20]
	battle.shield[0] = [6, 2, 0]
	assert_true(_use(battle, 0, "t3_huanming_qi", 1))
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.hp[0], [14, 4, 20])
	assert_eq(battle.shield[0], [2, 6, 0])
	assert_eq(battle.active_index[0], 0)


func test_jieming_deng_fills_energy_before_action_and_lowers_active_to_one_hp() -> void:
	var battle := _battle()
	battle.energy[0] = 0
	assert_true(_use(battle, 0, "t3_jieming_deng"))
	assert_eq(battle.energy[0], battle.energy_max[0])
	assert_true(battle.select_action(0, A.BIG_ATTACK))
	assert_true(battle.select_action(1, A.DEFEND))
	battle.resolve()
	assert_eq(battle.hp[0][0], 2)


func test_qingnang_huopen_burns_only_ready_unused_items_for_one_energy_each() -> void:
	var battle := _battle()
	battle.econ_init()
	battle.energy = [0, 0]
	battle.slots[0][0] = _ready_slot("t3_qingnang_huopen")
	battle.slots[0][1] = _ready_slot("t1_feibiao")
	battle.slots[0][2] = _ready_slot("t1_jiudun")
	battle.slots[1][0] = _ready_slot("t1_feibiao")
	battle.slots[1][1] = _ready_slot("t1_jiudun")
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(0, 1), "已选择使用的道具不被火盆重复烧毁")
	_resolve(battle, A.DEFEND, A.DEFEND)
	assert_eq(battle.energy[0], 4, "烧1件得1能，再加回合被动1能")
	assert_eq(battle.energy[1], 6, "烧2件得2能，再加回合被动1能")


func test_junneng_dou_equalizes_after_current_action_costs() -> void:
	var battle := _battle()
	battle.energy = [12, 2]
	assert_true(_use(battle, 0, "t3_junneng_dou"))
	assert_true(battle.select_action(0, A.BIG_ATTACK))
	assert_true(battle.select_action(1, A.ATTACK))
	battle.resolve()
	assert_eq(battle.energy, [5, 5], "先各自支付6/2半能，再合并8半能均分，最后各得2半能被动")
