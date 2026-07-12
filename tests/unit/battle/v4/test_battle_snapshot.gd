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
