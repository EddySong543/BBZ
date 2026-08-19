extends GutTest

const A := ActionDef.Action
const SS := BattleCore.SlotState
const SEED := 81426


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


func _ready_slot(item_id: String) -> Dictionary:
	return {state = SS.CHARGING, item = ItemCatalog.make(item_id), since = -1,
		used = false, draft = [], upg_draft = []}


func _use(battle: BattleCore, player: int, item_id: String, target: int = -1) -> bool:
	var index: int = battle.give_item(player, ItemCatalog.make(item_id))
	return battle.use_item(player, index, target)


func _resolve(battle: BattleCore, p0_action: int, p1_action: int) -> Dictionary:
	assert_true(battle.select_action(0, p0_action))
	assert_true(battle.select_action(1, p1_action))
	return battle.resolve()


func test_shizhi_jiasuo_delays_only_an_enemy_locked_item_slot() -> void:
	var battle := _battle()
	battle.econ_init()
	battle.slots[0][0] = _ready_slot("t2_shizhi_jiasuo")
	battle.slots[1][1] = _ready_slot("t2_feibiao")
	battle.slots[1][1]["since"] = battle.turn_number
	assert_false(battle.slot_ready(1, 1))
	assert_true(battle.use_slot(0, 0, -1, 1))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(int(battle.slots[1][1]["since"]), 1)
	assert_false(battle.slot_ready(1, 1), "延迟后的道具在下一选择回合仍应锁定")
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_true(battle.slot_ready(1, 1))


func test_shizhi_jiasuo_rejects_ready_empty_and_own_slot_targets() -> void:
	var battle := _battle()
	battle.econ_init()
	battle.slots[0][0] = _ready_slot("t2_shizhi_jiasuo")
	battle.slots[1][0] = _ready_slot("t2_feibiao")
	assert_false(battle.use_slot(0, 0, -1, 0), "敌方就绪道具不是锁定目标")


func test_jieyin_pei_borrows_only_the_selected_reserve_mark_once() -> void:
	var snake := _battle(["test_a", "h06", "test_c"])
	assert_true(_use(snake, 0, "t2_jieyin_pei", 1))
	_resolve(snake, A.ATTACK, A.CHARGE)
	assert_eq(int(snake.get_status(1, 0, "poison", 0)), 1)

	var chicken := _battle(["test_a", "h10", "test_c"])
	assert_true(_use(chicken, 0, "t2_jieyin_pei", 1))
	_resolve(chicken, A.ATTACK, A.CHARGE)
	assert_eq(int(chicken.get_status(0, 1, "jianqi", 0)), 2,
		"h10原本监听全队命中1次，借印再额外结算其印记1次")

	var xiezhi := _battle(["test_a", "h20", "test_c"])
	assert_true(_use(xiezhi, 0, "t2_jieyin_pei", 1))
	_resolve(xiezhi, A.ATTACK, A.CHARGE)
	assert_eq(int(xiezhi.get_status(1, 0, "vuln", 0)), 1)


func test_jieyin_pei_does_not_resolve_when_attack_is_blocked() -> void:
	var battle := _battle(["test_a", "h06", "test_c"])
	assert_true(_use(battle, 0, "t2_jieyin_pei", 1))
	_resolve(battle, A.ATTACK, A.DEFEND)
	assert_eq(int(battle.get_status(1, 0, "poison", 0)), 0)


func test_dianjiang_gu_forces_lowest_hp_living_reserve_to_enter_after_hit() -> void:
	var battle := _battle()
	battle.hp[1] = [20, 8, 6]
	assert_true(_use(battle, 0, "t2_dianjiang_gu"))
	_resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.active_index[1], 2)


func test_dianjiang_gu_directly_replaces_an_enemy_defeated_by_that_attack() -> void:
	var battle := _battle()
	battle.hp[1] = [2, 8, 6]
	assert_true(_use(battle, 0, "t2_dianjiang_gu"))
	var result := _resolve(battle, A.ATTACK, A.CHARGE)
	assert_eq(battle.active_index[1], 2)
	assert_false(battle.pending_death_switch[1])
	assert_true((result["events"] as Array).any(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "dianjiang_forced_entry"))


func test_daishang_san_redirects_the_enemy_next_attack_to_selected_reserve() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t2_daishang_san", 2))
	_resolve(battle, A.CHARGE, A.ATTACK)
	assert_eq(battle.hp[0], [20, 20, 18])


func test_guiying_pai_heals_the_next_living_hero_that_actually_switches_out() -> void:
	var battle := _battle()
	battle.hp[0][0] = 10
	assert_true(_use(battle, 0, "t2_guiying_pai"))
	assert_true(battle.select_switch(0, 1))
	assert_true(battle.select_action(1, A.CHARGE))
	battle.resolve()
	assert_eq(battle.hp[0][0], 14)
	assert_eq(battle.active_index[0], 1)


func test_xingjun_yaonang_heals_only_a_selected_living_reserve() -> void:
	var battle := _battle()
	battle.hp[0][2] = 10
	assert_false(_use(battle, 0, "t2_xingjun_yaonang", 0))
	assert_true(_use(battle, 0, "t2_xingjun_yaonang", 2))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_eq(battle.hp[0][2], 14)


func test_miwu_doupeng_hides_until_a_later_item_is_used() -> void:
	var battle := _battle()
	assert_true(_use(battle, 0, "t2_miwu_doupeng"))
	_resolve(battle, A.CHARGE, A.CHARGE)
	assert_true(bool(battle.info_distortion[0].get("hide_item_bar", false)))
	assert_true(_use(battle, 0, "t2_jiandun"))
	assert_false(bool(battle.info_distortion[0].get("hide_item_bar", false)),
		"之后实际提交任一道具时立即揭开旧斗篷")
