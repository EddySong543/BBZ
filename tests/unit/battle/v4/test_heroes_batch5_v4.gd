extends GutTest

## ============================================================================
## BattleCore 英雄第五批（Step 2.2c）—— buff 型 / 伤害型主动技
##   h12 吞噬 —— 挂 buff → 下一次任意攻击命中吸血（execute_active + on_deal_damage）
##   h13 孤注 —— 挂 buff → 下一次任意攻击 66% 翻倍（execute_active + modify_outgoing）
##   h20 倾力 —— 耗光能量造等量伤（active_is_attack，穿防、被大防挡）
## ============================================================================

const ATTACK := ActionDef.Action.ATTACK
const BIG := ActionDef.Action.BIG_ATTACK
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


func _aa(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h12 吞噬（buff 型吸血）----

func test_h12_lifesteal_on_next_attack() -> void:
	var b := _battle2([["h12", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 4   # 残血
	b.select_active(0)            # 发动吞噬：挂 buff，本回合不攻击
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 20, "发动回合不造成伤害")
	assert_eq(b.hp[0][0], 4, "发动回合不回血")
	assert_true(b.get_status(0, 0, "tunshi_buff", false), "已挂吞噬 buff")
	_aa(b, ATTACK, CHARGE)        # 下一波命中 → 吸血
	assert_eq(b.hp[1][0], 18, "下一波造成 1.0 (20-2)")
	assert_eq(b.hp[0][0], 6, "命中回 1.0 (4+2)")
	assert_false(b.get_status(0, 0, "tunshi_buff", false), "buff 已消耗")


func test_h12_no_lifesteal_when_blocked() -> void:
	var b := _battle2([["h12", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 4
	b.select_active(0)            # 挂 buff
	b.select_action(1, CHARGE)
	b.resolve()
	_aa(b, ATTACK, DEFEND)        # 下一波被防挡 → 无实际伤害
	assert_eq(b.hp[1][0], 20, "波被防挡，无伤")
	assert_eq(b.hp[0][0], 4, "被挡无实际伤害 → 不回血")
	assert_false(b.get_status(0, 0, "tunshi_buff", false), "被挡也消耗 buff（白费）")


func test_h12_capped_at_3() -> void:
	var b := _battle2([["h12", 6], ["t01", 10], ["t02", 10]], [["t10", 20], ["t11", 10], ["t12", 10]])
	for i in range(3):
		assert_true(b.select_active(0), "第 %d 次吞噬可发动" % (i + 1))
		b.select_action(1, CHARGE)
		b.resolve()
	assert_false(b.select_active(0), "第 4 次超 cap(3)")


# ---- h13 孤注（buff 型翻倍）----

func test_h13_buffs_next_attack() -> void:
	var b := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)            # 发动孤注：挂 buff，本回合不攻击
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 20, "发动回合不造成伤害")
	assert_true(b.get_status(0, 0, "guzhu_buff", false), "已挂孤注 buff")
	_aa(b, ATTACK, CHARGE)        # 下一波 66% 翻倍：1.0(2半) 或 2.0(4半)
	var lost: int = 20 - int(b.hp[1][0])
	assert_true(lost == 2 or lost == 4, "波 1.0 或翻倍 2.0，实得 %d 半点" % lost)
	assert_false(b.get_status(0, 0, "guzhu_buff", false), "buff 已消耗")


func test_h13_doubles_big_wave() -> void:
	var b := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 20], ["t11", 10], ["t12", 10]])
	b.select_active(0)            # 挂 buff
	b.select_action(1, CHARGE)
	b.resolve()
	_aa(b, BIG, CHARGE)           # 下一大波 2.0 base，66% 翻倍 → 2.0 或 4.0
	var lost: int = 40 - int(b.hp[1][0])
	assert_true(lost == 4 or lost == 8, "大波 2.0 或翻倍 4.0，实得 %d 半点" % lost)


func test_h13_reproducible_with_seed() -> void:
	var outs: Array[int] = []
	for _r in range(2):
		var b := _battle2([["h13", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
		b.select_active(0)
		b.select_action(1, CHARGE)
		b.resolve()
		_aa(b, ATTACK, CHARGE)
		outs.append(int(b.hp[1][0]))
	assert_eq(outs[0], outs[1], "同 seed → 孤注豪赌结果可复现")


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
