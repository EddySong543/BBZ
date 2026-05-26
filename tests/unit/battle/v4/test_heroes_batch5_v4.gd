extends GutTest

## ============================================================================
## BattleCore 英雄第五批（Step 2.2c）—— 伤害型主动技（走伤害管线）
##   h12 吞噬 —— 一次"波"+ 命中吸血（active_is_attack + on_active_attack_resolved）
##   h13 孤注 —— 66% 翻倍豪赌（RNG，穿防）
##   h20 倾力 —— 耗光能量造等量伤（穿防、被大防挡）
## ============================================================================

const CHARGE := ActionDef.Action.CHARGE
const DEFEND := ActionDef.Action.DEFEND
const BIG_DEFEND := ActionDef.Action.BIG_DEFEND


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	h.passive_id = ""
	h.extra_action_id = -1
	return h


func _team(specs: Array) -> Array:
	var t: Array = []
	for s in specs:
		t.append(_hero(s[0], s[1]))
	return t


func _battle2(p0: Array, p1: Array, e: int = 6) -> BattleCore:
	var b := BattleCore.new()
	b.setup(_team(p0), _team(p1), 555)
	b.energy = [e, e]
	return b


# ---- h12 吞噬 ----

func test_h12_lifesteal_on_hit() -> void:
	var b := _battle2([["h12", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 4   # 残血
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18, "波造成 1.0 (20-2)")
	assert_eq(b.hp[0][0], 6, "吸血回 1.0 (4+2)")


func test_h12_no_lifesteal_when_blocked() -> void:
	var b := _battle2([["h12", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 4
	b.select_active(0)
	b.select_action(1, DEFEND)   # 波被防挡
	b.resolve()
	assert_eq(b.hp[1][0], 20, "被防挡，无伤")
	assert_eq(b.hp[0][0], 4, "被挡 → 不吸血")


func test_h12_capped_at_3() -> void:
	var b := _battle2([["h12", 6], ["t01", 10], ["t02", 10]], [["t10", 20], ["t11", 10], ["t12", 10]])
	for i in range(3):
		assert_true(b.select_active(0), "第 %d 次吞噬可用" % (i + 1))
		b.select_action(1, CHARGE)
		b.resolve()
	assert_false(b.select_active(0), "第 4 次超 cap(3)")


# ---- h13 孤注 ----

func test_h13_deals_2_or_4() -> void:
	var b := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	var lost: int = 20 - int(b.hp[1][0])
	assert_true(lost == 4 or lost == 8, "造成 2.0(4半) 或 4.0(8半)，实得 %d 半点" % lost)


func test_h13_reproducible_with_seed() -> void:
	var b1 := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b1.select_active(0)
	b1.select_action(1, CHARGE)
	b1.resolve()
	var b2 := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b2.select_active(0)
	b2.select_action(1, CHARGE)
	b2.resolve()
	assert_eq(b1.hp[1][0], b2.hp[1][0], "同 seed → 孤注结果可复现")


func test_h13_pierces_defend() -> void:
	var b := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, DEFEND)   # 防挡不住大波级孤注
	b.resolve()
	assert_lt(b.hp[1][0], 20, "孤注穿防，对手受伤")


func test_h13_blocked_by_big_defend() -> void:
	var b := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 20, "大防挡住孤注")


# ---- h20 倾力 ----

func test_h20_dumps_all_energy_as_damage() -> void:
	var b := _battle2([["h20", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 5)
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "5 能 → 5.0 伤 (20-10)")
	assert_eq(b.energy[0], 0, "能量耗光")


func test_h20_pierces_defend() -> void:
	var b := _battle2([["h20", 5], ["t01", 10], ["t02", 10]], [["t10", 20], ["t11", 10], ["t12", 10]], 3)
	b.select_active(0)
	b.select_action(1, DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 40 - 6, "倾力穿防：3 能 = 3.0 伤")


func test_h20_blocked_by_big_defend_wastes_energy() -> void:
	var b := _battle2([["h20", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 5)
	b.select_active(0)
	b.select_action(1, BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 20, "大防挡住")
	assert_eq(b.energy[0], 0, "能量照样耗光（高风险）")


func test_h20_needs_energy() -> void:
	var b := _battle2([["h20", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 0)
	assert_false(b.can_use_active(0), "0 能不可用")
