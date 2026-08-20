extends GutTest

const A := ActionDef.Action
const SS := BattleCore.SlotState


func _hero(id: String) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = id
	hero.hero_name = id
	hero.max_hp = 10
	hero.skill_type = HeroData.SkillType.PASSIVE
	return hero


func _battle(bag0: Array = [], bag1: Array = []) -> BattleCore:
	var battle := BattleCore.new()
	battle.setup([_hero("a"), _hero("b"), _hero("c")],
		[_hero("x"), _hero("y"), _hero("z")], 190826)
	battle.configure_battle_backpacks(bag0, bag1)
	battle.econ_init()
	battle.energy = [20, 20]
	return battle


func _ready_slot(item_id: String, since: int = -1) -> Dictionary:
	return {state = SS.CHARGING, item = ItemCatalog.make(item_id), since = since,
		used = false, draft = [], upg_draft = [], draft_entry_uids = [],
		instance_uid = -1, temporary = false}


func _resolve(battle: BattleCore, a0: int = A.CHARGE, a1: int = A.CHARGE) -> Dictionary:
	assert_true(battle.select_action(0, a0))
	assert_true(battle.select_action(1, a1))
	return battle.resolve()


func _bag_ids(battle: BattleCore, player: int) -> Array[String]:
	var out: Array[String] = []
	for entry_variant in battle.battle_backpacks[player]:
		out.append(String((entry_variant as Dictionary).get("item_id", "")))
	return out


func test_backpack_mode_draws_physical_candidates_and_keeps_unchosen_items() -> void:
	var battle := _battle(
		["t1_feibiao", "t1_jiudun", "t1_lzhi_shengming"],
		["t1_xianshou"])
	assert_eq(battle.slot_state(0, 0), SS.EMPTY)
	var before_energy: int = battle.energy[0]
	var options: Array = battle.start_refill(0, 0)
	assert_eq(options.size(), 3)
	assert_eq(battle.energy[0], before_energy - BattleCore.ITEM_REFILL_COST)
	var picked_id: String = (options[1] as ItemData).item_id
	assert_true(battle.pick_draft(0, 0, 1))
	assert_eq((battle.slot_item(0, 0) as ItemData).item_id, picked_id)
	assert_eq(battle.battle_backpacks[0].size(), 2)
	assert_false(_bag_ids(battle, 0).has(picked_id))
	assert_false(battle.slot_ready(0, 0), "标准抽取结果锁定本回合")


func test_legacy_draft_filters_items_that_require_a_battle_backpack() -> void:
	var battle := BattleCore.new()
	battle.setup([_hero("a")], [_hero("x")], 190827)
	battle.econ_init()
	for _sample in range(100):
		battle.slots[0][1]["state"] = SS.OPENED
		battle.slots[0][1]["since"] = -1
		battle.slots[0][1]["draft"] = []
		for option_variant in battle.begin_draft(0, 1):
			assert_false(bool((option_variant as ItemData).params.get("requires_backpack", false)))


func test_jicun_returns_target_to_bag_and_gains_one_energy() -> void:
	var battle := _battle([], [])
	battle.energy[0] = 0
	battle.slots[0][0] = _ready_slot("t1_jicun_pai")
	battle.slots[0][1] = _ready_slot("t1_feibiao")
	assert_true(battle.use_slot(0, 0, -1, 1))
	assert_eq(battle.energy[0], 2)
	assert_true(_bag_ids(battle, 0).has("t1_feibiao"))
	_resolve(battle)
	assert_eq(battle.slot_state(0, 0), SS.EMPTY)
	assert_eq(battle.slot_state(0, 1), SS.EMPTY)


func test_yawu_rewards_only_when_the_named_enemy_slot_is_used() -> void:
	var hit := _battle([], [])
	hit.energy = [0, 0]
	hit.slots[0][0] = _ready_slot("t2_yawu_piao")
	hit.slots[1][1] = _ready_slot("t1_xianshou")
	assert_true(hit.use_slot(0, 0, -1, 1))
	assert_true(hit.use_slot(1, 1))
	_resolve(hit)
	assert_eq(hit.energy[0], 8, "押中2能，加攒1能和回合被动1能")

	var miss := _battle([], [])
	miss.energy = [0, 0]
	miss.slots[0][0] = _ready_slot("t2_yawu_piao")
	miss.slots[1][1] = _ready_slot("t1_xianshou")
	assert_true(miss.use_slot(0, 0, -1, 1))
	_resolve(miss)
	assert_eq(miss.energy[0], 4, "未使用被押道具时只有攒和回合被动")


func test_huigou_adds_a_temporary_copy_of_a_used_t1_to_the_bag() -> void:
	var battle := _battle([], [])
	battle.slots[0][0] = _ready_slot("t1_feibiao")
	assert_true(battle.use_slot(0, 0))
	_resolve(battle)
	battle.slots[0][0] = _ready_slot("t2_huigou_quan")
	var options: Array = battle.begin_repurchase_draft(0, 0)
	assert_eq(options.size(), 1)
	assert_eq((options[0] as ItemData).item_id, "t1_feibiao")
	assert_true(battle.use_slot(0, 0, -1, -1, 0))
	assert_eq(_bag_ids(battle, 0), ["t1_feibiao"])
	assert_true(bool((battle.battle_backpacks[0][0] as Dictionary)["temporary"]))


func test_baojia_returns_a_countered_target_item_to_the_bag() -> void:
	var battle := _battle([], [])
	battle.slots[0][0] = _ready_slot("t2_baojia_feng")
	battle.slots[0][1] = _ready_slot("t1_yaohuo")
	battle.slots[1][0] = _ready_slot("t2_huizhao_jing")
	assert_true(battle.use_slot(0, 0, -1, 1))
	assert_true(battle.use_slot(0, 1))
	assert_true(battle.use_slot(1, 0))
	var result: Dictionary = _resolve(battle)
	assert_true(_bag_ids(battle, 0).has("t1_yaohuo"))
	assert_true((result["events"] as Array).any(func(event: Dictionary) -> bool:
		return String(event.get("id", "")) == "insured_item_returned"))


func test_yingji_replaces_itself_with_random_t1_and_the_result_is_ready() -> void:
	var battle := _battle(["t1_feibiao", "t2_jiandun"], [])
	battle.slots[0][0] = _ready_slot("t2_yingji_xiang")
	assert_true(battle.use_slot(0, 0))
	assert_eq((battle.slot_item(0, 0) as ItemData).item_id, "t1_feibiao")
	assert_true(battle.slot_ready(0, 0))
	assert_false(_bag_ids(battle, 0).has("t1_feibiao"))


func test_huanqian_accepts_a_locked_target_and_replaces_it_with_a_locked_choice() -> void:
	var battle := _battle(["t1_feibiao", "t1_jiudun"], [])
	battle.slots[0][0] = _ready_slot("t2_huanqian_tong")
	battle.slots[0][1] = _ready_slot("t1_xianshou", battle.turn_number)
	var options: Array = battle.begin_exchange_draft(0, 0, 1)
	assert_eq(options.size(), 3, "目标先放回背包后参与免费三选一")
	assert_true(battle.use_slot(0, 0, -1, 1, 0))
	assert_not_null(battle.slot_item(0, 1))
	assert_false(battle.slot_ready(0, 1))
	assert_eq(int(battle.slots[0][1]["since"]), battle.turn_number)


func test_tingxia_reveals_at_most_three_enemy_bag_items_only_to_the_user() -> void:
	var battle := _battle([], ["t1_feibiao", "t1_jiudun", "t1_xianshou", "t2_fali"])
	battle.slots[0][0] = _ready_slot("t1_tingxia_tong")
	assert_true(battle.use_slot(0, 0))
	_resolve(battle)
	assert_eq(battle.revealed_backpack_items_for(0, 1).size(), 3)
	assert_eq(battle.revealed_backpack_items_for(1, 0), [])


func test_chenglu_converts_all_overheal_to_energy_one_for_one_without_cap() -> void:
	var battle := _battle([], [])
	battle.energy[0] = 0
	battle.hp[0][0] = battle.max_hp[0][0]
	battle.slots[0][0] = _ready_slot("t2_chenglu_zhan")
	battle.slots[0][1] = _ready_slot("t3_shengming")
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(0, 1))
	_resolve(battle)
	assert_eq(battle.energy[0], 10, "上等药水溢出3能量，加攒1能和回合被动1能")


func test_naying_converts_all_overflow_energy_to_lowest_living_hero_healing() -> void:
	var battle := _battle([], [])
	battle.energy[0] = battle.energy_max[0]
	battle.hp[0] = [20, 2, 8]
	battle.slots[0][0] = _ready_slot("t2_naying_hulu")
	battle.slots[0][1] = _ready_slot("t2_mojing")
	assert_true(battle.use_slot(0, 0))
	assert_true(battle.use_slot(0, 1))
	_resolve(battle)
	assert_eq(battle.hp[0][1], 10, "魔晶3能与本回合攒1能的溢出均转为生命")
