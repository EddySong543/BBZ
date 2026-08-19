extends GutTest

## 战局快照序列化 行为锁定测试（联机准备批②·2026-07-12）。
## 锁四条契约：①快照→恢复→再快照 逐位一致 ②恢复局与原局续打（同输入）事件流/状态逐位一致
## ③JSON.stringify→parse_string 线上往返后仍满足①②（int/float 归一 + rng 64 位字符串精度）
## ④版本不符拒绝恢复。白板英雄（无 .tres）与经济槽/状态/道具/遗物全部入样。

const A := ActionDef.Action
const SEED := 777
const SNAPSHOT_FUTURE_VERSION := 999


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	b.setup([_hero("test_a", 10), _hero("test_b", 10), _hero("test_c", 10)],
		[_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)], SEED)
	b.energy = [energy, energy]
	b.econ_init()
	return b


func _ready_item_slot(item_id: String) -> Dictionary:
	return {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make(item_id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


## 摆一局有内容的中盘：状态/跨回合 buff/延迟伤害/道具/遗物/若干拍结算全非零。
func _midgame() -> BattleCore:
	var b := _battle()
	b.set_status(0, 0, "poison", 2)
	b.set_status(1, 1, "marked", 1)
	b.set_status(1, 2, "broken_armor", 1)
	b.item_buffs[0]["next_atk_bonus"] = 2
	b.pending_damage[1][0] = 2
	b.give_item(0, ItemCatalog.make("t1_feibiao"))
	b.relics[1].append({data = ItemCatalog.make("t1_tongqian"), state = {ticks = 3}})
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)
	b.resolve()
	b.upgrade_next_wave[0] = true
	b.upgrade_next_wave[1] = true
	b.retained_big_defend[0] = true
	b.retained_big_defend[1] = false
	b.retained_big_defend_until_turn[0] = b.turn_number
	b.retained_big_defend_until_turn[1] = -1
	b.energy_burn_turn = b.turn_number + 1
	b.energy_max = [17, 12]
	b.relics[0].append({
		data = ItemCatalog.make("t3_budongmingwang"), state = {charges = 2},
	})
	b.relics[1].append({
		data = ItemCatalog.make("t3_xumingxiang"), state = {remaining_turns = 2},
	})
	b.item_buffs[0]["free_big_attack_until_turn"] = b.turn_number + 1
	b.add_timed_item_effect(1, {
		id = "yaohuo", target_slot = 0, due_turn = b.turn_number + 1,
		amount = 3, source_player = 0,
	})
	return b


func _resolve_pair(b: BattleCore, a0: int, a1: int) -> Dictionary:
	b.select_action(0, a0)
	b.select_action(1, a1)
	return b.resolve()


func test_battle_core_snapshot_roundtrip_preserves_state() -> void:
	# Arrange
	var b := _midgame()
	# Act
	var b2 := BattleCore.new()
	var ok := b2.from_snapshot(b.to_snapshot())
	# Assert：再快照逐位一致（含 rng 字符串）
	assert_true(ok, "恢复应成功")
	assert_eq_deep(b2.to_snapshot(), b.to_snapshot())


func test_snapshot_preserves_lianhuan_second_action_and_target() -> void:
	var b := _battle()
	b.slots[0][0] = _ready_item_slot("t3_lianhuan_gu")
	assert_true(b.use_slot(0, 0))
	assert_true(b.select_action(0, A.CHARGE))
	assert_true(b.select_second_action(0, A.ATTACK, -1))
	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()))
	assert_eq(b2.second_action(0), A.ATTACK)
	assert_eq_deep(b2.to_snapshot(), b.to_snapshot())


func test_snapshot_preserves_t3_relic_state_and_free_big_window_independently() -> void:
	var b := _midgame()
	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()))
	assert_eq(int(b2.relics[0][0]["state"].get("charges", 0)), 2)
	assert_eq(int(b2.relics[1][1]["state"].get("remaining_turns", 0)), 2)
	assert_eq(int(b2.item_buffs[0].get("free_big_attack_until_turn", -1)), b.turn_number + 1)

	b2.relics[0][0]["state"]["charges"] = 1
	b2.item_buffs[0]["free_big_attack_until_turn"] = -1
	assert_eq(int(b.relics[0][0]["state"].get("charges", 0)), 2,
		"恢复局修改遗物次数不得污染原局")
	assert_eq(int(b.item_buffs[0].get("free_big_attack_until_turn", -1)), b.turn_number + 1)


func test_snapshot_roundtrip_after_mengdie_preserves_swapped_complete_item_bars() -> void:
	var b := _battle(8)
	b.slots[0][0] = _ready_item_slot("t1_feibiao")
	b.slots[0][1] = _ready_item_slot("t2_mojing")
	b.slots[1][0] = _ready_item_slot("t1_jiudun")
	b.slots[1][1] = _ready_item_slot("t2_nuanyu")
	b.items[0].append(ItemCatalog.make("t3_mengdie"))
	assert_true(b.use_item(0, b.items[0].size() - 1))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()

	assert_eq(b.slot_item(0, 0).item_id, "t1_jiudun")
	assert_eq(b.slot_item(0, 1).item_id, "t2_nuanyu")
	assert_eq(b.slot_item(1, 0).item_id, "t1_feibiao")
	assert_eq(b.slot_item(1, 1).item_id, "t2_mojing")
	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()))
	# ItemData 会从快照重建为新 Resource 实例；比较权威序列化值而不是实例身份。
	assert_eq_deep(b2.to_snapshot()["slots"], b.to_snapshot()["slots"])


func test_battle_core_snapshot_restored_resolves_identically() -> void:
	# Arrange
	var b := _midgame()
	var b2 := BattleCore.new()
	b2.from_snapshot(b.to_snapshot())
	# Act：同输入续打两拍
	var r1a := _resolve_pair(b, A.ATTACK, A.DEFEND)
	var r2a := _resolve_pair(b2, A.ATTACK, A.DEFEND)
	var r1b := _resolve_pair(b, A.BIG_ATTACK, A.CHARGE)
	var r2b := _resolve_pair(b2, A.BIG_ATTACK, A.CHARGE)
	# Assert：事件流与核心状态逐位一致
	assert_eq_deep(r2a, r1a)
	assert_eq_deep(r2b, r1b)
	assert_eq_deep(b2.hp, b.hp)
	assert_eq(b2.energy[0], b.energy[0])
	assert_eq(b2.energy[1], b.energy[1])
	assert_eq(b2.energy_max, b.energy_max, "动态能量上限必须随快照恢复")
	assert_eq(b2.rng.state, b.rng.state, "随机流须保持同步")


func test_battle_core_snapshot_survives_json_wire() -> void:
	# Arrange：走一遍真实网络文本编码
	var b := _midgame()
	var wire: String = JSON.stringify(b.to_snapshot())
	var parsed: Variant = JSON.parse_string(wire)
	# Act
	var b2 := BattleCore.new()
	var ok := b2.from_snapshot(parsed)
	# Assert：rng 64 位精度不丢 + 续打逐位一致
	assert_true(ok, "JSON 往返后恢复应成功")
	assert_eq(b2.rng.seed, b.rng.seed, "seed 走字符串不丢精度")
	assert_eq(b2.rng.state, b.rng.state, "state 走字符串不丢精度")
	var r1 := _resolve_pair(b, A.ATTACK, A.ATTACK)
	var r2 := _resolve_pair(b2, A.ATTACK, A.ATTACK)
	assert_eq_deep(r2, r1)
	assert_eq_deep(b2.to_snapshot(), b.to_snapshot())


func test_snapshot_preserves_h04_selected_attack_target() -> void:
	var b := BattleCore.new()
	b.setup([_hero("h04", 5), _hero("test_b", 10), _hero("test_c", 10)],
		[_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)], SEED)
	b.energy = [20, 20]
	assert_true(b.select_action(0, A.BIG_ATTACK, 2))

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "带 h04 攻击目标的快照应可恢复")
	b.select_action(1, A.CHARGE)
	b2.select_action(1, A.CHARGE)
	var result1: Dictionary = b.resolve()
	var result2: Dictionary = b2.resolve()

	assert_eq_deep(result2, result1)
	assert_eq(b2.hp[1][2], 16, "恢复局的大波应命中槽 2")
	assert_eq(b2.hp[1][0], 20, "恢复局不应误伤敌方出战位")


func test_snapshot_preserves_xunxing_queued_item_and_selected_wave_target() -> void:
	var b := BattleCore.new()
	b.setup([_hero("test_a", 5), _hero("test_b", 10), _hero("test_c", 10)],
		[_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)], SEED)
	b.energy = [20, 20]
	b.econ_init()
	b.slots[0][0] = {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make("t1_xunxing_zhui"),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}
	assert_true(b.use_slot(0, 0))
	# 排除英雄样本 test_z 映射到 h20 时的常驻脆弱；本例只锁快照字段与寻星伤害。
	b.set_status(1, 2, "vuln", 0)
	assert_true(b.select_action(0, A.ATTACK, 2))

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "寻星坠的待结算道具与波目标应可恢复")
	b.select_action(1, A.CHARGE)
	b2.select_action(1, A.CHARGE)
	var result1: Dictionary = b.resolve()
	var result2: Dictionary = b2.resolve()

	assert_eq_deep(result2, result1)
	assert_eq(b2.hp[1][2], 19, "恢复局的减伤波应命中指定后排")
	assert_eq(b2.hp[1][0], 20, "恢复局不得改打敌方出战位")


func test_snapshot_preserves_h05_empowered_wave_choice() -> void:
	var b := BattleCore.new()
	b.setup([_hero("test_a", 5), _hero("h05", 5), _hero("test_c", 5)],
		[_hero("test_x", 5), _hero("test_y", 5), _hero("test_z", 5)], SEED)
	b.energy = [8, 8]
	assert_true(b.select_action(0, A.ATTACK, -1, true))

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "带龙御极强化波选择的快照应可恢复")
	b.select_action(1, A.CHARGE)
	b2.select_action(1, A.CHARGE)
	var result1: Dictionary = b.resolve()
	var result2: Dictionary = b2.resolve()

	assert_eq_deep(result2, result1)
	assert_eq(b2.hp[1][0], 6, "恢复局应按强化波造成 2 点伤害")


func test_snapshot_preserves_h13_split_big_wave_choice() -> void:
	var b := BattleCore.new()
	b.setup([_hero("h13", 4), _hero("test_b", 5), _hero("test_c", 5)],
		[_hero("test_x", 5), _hero("test_y", 5), _hero("test_z", 5)], SEED)
	b.energy = [8, 8]
	assert_true(b.select_action(0, A.BIG_ATTACK, -1, false, true))

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "带玄冥双波选择的快照应可恢复")
	b.select_action(1, A.CHARGE)
	b2.select_action(1, A.CHARGE)
	var result1: Dictionary = b.resolve()
	var result2: Dictionary = b2.resolve()

	assert_eq_deep(result2, result1)
	assert_eq(b2.hp[1][0], 6, "恢复局应按两次波共造成 2 点伤害")


func test_snapshot_preserves_h14_blood_payment_choice() -> void:
	var b := BattleCore.new()
	b.setup([_hero("h14", 6), _hero("h07", 6), _hero("h17", 7)],
		[_hero("test_x", 5), _hero("test_y", 5), _hero("test_z", 5)], SEED)
	b.energy = [0, 0]
	assert_true(b.set_blood_payment_active(0, true))
	assert_true(b.free_switch(0, 1))
	assert_true(b.select_action(0, A.BIG_ATTACK, -1, false, false, true))

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "带蚩尤生命支付选择的快照应可恢复")
	assert_eq(b2.active_index[0], 1, "快照应保留免费切换后的出战槽")
	assert_eq(b2.free_switch_usage_turn, b.free_switch_usage_turn, "快照应保留免费切换回合")
	assert_eq(b2.free_switch_uses, b.free_switch_uses, "快照应保留本回合免费切换次数")
	assert_eq(b2.blood_payment_source(0), 0, "快照应保留原槽蚩尤为付款者")
	b.select_action(1, A.CHARGE)
	b2.select_action(1, A.CHARGE)
	var result1: Dictionary = b.resolve()
	var result2: Dictionary = b2.resolve()

	assert_eq_deep(result2, result1)
	assert_eq(b2.hp[0][0], 6, "恢复局应由原槽蚩尤支付星日大波的 3 点生命")


func test_snapshot_preserves_h24_energy_cap_discount_choice() -> void:
	var b := BattleCore.new()
	b.setup([_hero("test_a", 5), _hero("h24", 6), _hero("test_c", 5)],
		[_hero("test_x", 5), _hero("test_y", 5), _hero("test_z", 5)], SEED)
	b.energy = [4, 4]
	assert_true(b.select_action(0, A.BIG_ATTACK, -1, false, false, false, true))

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "带并封减费选择的快照应可恢复")
	assert_true(b2.energy_cap_discount_selected(0))
	b.select_action(1, A.CHARGE)
	b2.select_action(1, A.CHARGE)
	assert_eq_deep(b2.resolve(), b.resolve())
	assert_eq(b2.energy_max[0], 18, "恢复局应正常支付 1 点能量上限")


func test_snapshot_preserves_h17_transformed_identity_and_skill() -> void:
	var h17 := load("res://assets/data/heroes/h17.tres") as HeroData
	var h15 := load("res://assets/data/heroes/h15.tres") as HeroData
	var b := BattleCore.new()
	b.setup([h17, _hero("test_b", 5), _hero("test_c", 5)],
		[h15, _hero("test_y", 5), _hero("test_z", 5)], SEED)
	b.energy = [8, 8]
	b.hp[1][0] = 9
	b.shield[1][0] = 3
	b.set_status(1, 0, "vuln", 1)
	assert_true(b.select_active(0))
	b.select_action(1, A.CHARGE)
	b.resolve()

	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(b.to_snapshot()), "转变后的战局快照应可恢复")
	assert_eq((b2.heroes[0][0] as HeroData).hero_id, "h15")
	assert_eq(b2.hp[0][0], 9)
	assert_eq(b2.shield[0][0], 3)
	assert_eq(int(b2.get_status(0, 0, "vuln", 0)), 1)
	assert_false(b2.get_skill(0, 0).can_defend(), "恢复后应重建目标英雄的技能组件")
	assert_eq_deep(b2.to_snapshot(), b.to_snapshot())


func test_battle_core_snapshot_rng_stream_continues_identically() -> void:
	# Arrange
	var b := _midgame()
	var b2 := BattleCore.new()
	b2.from_snapshot(b.to_snapshot())
	# Act + Assert：恢复后的随机序列与原局完全同步（抽卡/加权 draft 的地基）
	for i in 5:
		assert_eq(b2.rng.randi(), b.rng.randi(), "第 %d 个随机数应一致" % i)


func test_battle_core_snapshot_version_mismatch_rejected() -> void:
	# Arrange
	var b := _midgame()
	var d := b.to_snapshot()
	d["v"] = SNAPSHOT_FUTURE_VERSION
	# Act
	var b2 := BattleCore.new()
	var ok := b2.from_snapshot(d)
	# Assert
	assert_false(ok, "版本不符必须拒绝（网络消息版本化规则）")


func test_snapshot_malformed_rejected_without_mutation() -> void:
	# 终审修复（2026-07-17）：畸形快照原会在硬索引处炸脚本错误且半恢复污染现状——
	# schema 门=必需键全量核对·缺键拒绝且本实例纹丝不动·调用方按返回值兜底。
	var b := BattleCore.new()
	var h1: Array = []
	var h2: Array = []
	for i in 3:
		var h := HeroData.new()
		h.hero_id = ""
		h.hero_name = "t%d" % i
		h.max_hp = 5
		h1.append(h)
		var g := HeroData.new()
		g.hero_id = ""
		g.hero_name = "u%d" % i
		g.max_hp = 5
		h2.append(g)
	b.setup(h1, h2, 99)
	var before: Dictionary = b.to_snapshot()

	# Act / Assert：空快照、只带版本、缺 heroes 的半截快照——全拒且状态不变
	assert_false(b.from_snapshot({}), "空快照应拒")
	assert_false(b.from_snapshot({v = BattleCore.SNAPSHOT_VERSION}), "缺必需键应拒")
	var half: Dictionary = before.duplicate(true)
	half.erase("heroes")
	assert_false(b.from_snapshot(half), "缺 heroes 应拒")
	var missing_h02_state: Dictionary = before.duplicate(true)
	missing_h02_state.erase("upgrade_next_wave")
	assert_false(b.from_snapshot(missing_h02_state), "缺牛金团队波升级状态应拒")
	var missing_h08_state: Dictionary = before.duplicate(true)
	missing_h08_state.erase("retained_big_defend")
	assert_false(b.from_snapshot(missing_h08_state), "缺鬼金团队保留大防状态应拒")
	var missing_h08_expiry: Dictionary = before.duplicate(true)
	missing_h08_expiry.erase("retained_big_defend_until_turn")
	assert_false(b.from_snapshot(missing_h08_expiry), "缺鬼金保留大防到期回合应拒")
	var missing_h22_deadline: Dictionary = before.duplicate(true)
	missing_h22_deadline.erase("energy_burn_turn")
	assert_false(b.from_snapshot(missing_h22_deadline), "缺毕方全局能量归零期限应拒")
	var missing_energy_max: Dictionary = before.duplicate(true)
	missing_energy_max.erase("energy_max")
	assert_false(b.from_snapshot(missing_energy_max), "缺动态能量上限状态应拒")
	var missing_h05_state: Dictionary = before.duplicate(true)
	missing_h05_state.erase("empowered_wave")
	assert_false(b.from_snapshot(missing_h05_state), "缺龙御极强化波选择状态应拒")
	var missing_h13_state: Dictionary = before.duplicate(true)
	missing_h13_state.erase("split_big_wave")
	assert_false(b.from_snapshot(missing_h13_state), "缺玄冥双波选择状态应拒")
	var missing_h14_state: Dictionary = before.duplicate(true)
	missing_h14_state.erase("blood_payment")
	assert_false(b.from_snapshot(missing_h14_state), "缺蚩尤生命支付选择状态应拒")
	var missing_h14_source: Dictionary = before.duplicate(true)
	missing_h14_source.erase("blood_payment_source")
	assert_false(b.from_snapshot(missing_h14_source), "缺蚩尤生命支付来源槽应拒")
	var missing_h24_state: Dictionary = before.duplicate(true)
	missing_h24_state.erase("energy_cap_discount")
	assert_false(b.from_snapshot(missing_h24_state), "缺并封减费选择状态应拒")
	var missing_h07_turn: Dictionary = before.duplicate(true)
	missing_h07_turn.erase("free_switch_usage_turn")
	assert_false(b.from_snapshot(missing_h07_turn), "缺千里自在风计数回合应拒")
	var missing_h07_uses: Dictionary = before.duplicate(true)
	missing_h07_uses.erase("free_switch_uses")
	assert_false(b.from_snapshot(missing_h07_uses), "缺千里自在风本回合使用次数应拒")
	var missing_h04_state: Dictionary = before.duplicate(true)
	missing_h04_state.erase("attack_target")
	assert_false(b.from_snapshot(missing_h04_state), "缺房日基础攻击目标状态应拒")
	var missing_second_action: Dictionary = before.duplicate(true)
	missing_second_action.erase("second_action")
	assert_false(b.from_snapshot(missing_second_action), "缺连环鼓第二行动状态应拒")
	var missing_second_target: Dictionary = before.duplicate(true)
	missing_second_target.erase("second_attack_target")
	assert_false(b.from_snapshot(missing_second_target), "缺连环鼓第二目标状态应拒")
	assert_false(b.from_snapshot({v = [], heroes = []}), "v 为数组不得炸脚本（类型门）")
	assert_eq_deep(b.to_snapshot(), before)
