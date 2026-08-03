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


## 摆一局有内容的中盘：状态/跨回合 buff/延迟伤害/道具/遗物/若干拍结算全非零。
func _midgame() -> BattleCore:
	var b := _battle()
	b.set_status(0, 0, "poison", 2)
	b.set_status(1, 1, "marked", 1)
	b.set_status(1, 2, "opening", 1)
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
	var missing_h04_state: Dictionary = before.duplicate(true)
	missing_h04_state.erase("attack_target")
	assert_false(b.from_snapshot(missing_h04_state), "缺房日基础攻击目标状态应拒")
	assert_false(b.from_snapshot({v = [], heroes = []}), "v 为数组不得炸脚本（类型门）")
	assert_eq_deep(b.to_snapshot(), before)
