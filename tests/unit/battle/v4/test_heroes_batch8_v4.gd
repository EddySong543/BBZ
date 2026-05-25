extends GutTest

## ============================================================================
## BattleEngineV4 英雄第八批（收尾）—— 杂项
##   h26 死神 —— 变身（form+1.0 伤 / 击杀回血）
##   h28 恶魔 —— 契约（队友 +1.0 / 恶魔付 HP）
##   h31 月亮 —— 四相 turn%4（造成/受到 ×0.5 / ×2）
##   h14 梅开 —— 下一动作 ×2（攒/攻；切换不消耗）
##   h24 天平 —— HP 拉平均（扶倾）
##   h07 当先 —— 免费切换不占槽 + 同回合行动
## ============================================================================

const ATTACK := ActionDefV4.Action.ATTACK
const BIG := ActionDefV4.Action.BIG_ATTACK
const CHARGE := ActionDefV4.Action.CHARGE


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


func _battle2(p0: Array, p1: Array, e: int = 6) -> BattleEngineV4:
	var b := BattleEngineV4.new()
	b.setup(_team(p0), _team(p1), 555)
	b.energy = [e, e]
	return b


func _aa(b: BattleEngineV4, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h26 死神 ----

func test_h26_transform_boosts_damage() -> void:
	var b := _battle2([["h26", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 6)
	b.select_active(0)        # 变身（耗 4 能）
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.form[0][0], 1, "已变身收割形态")
	_aa(b, ATTACK, CHARGE)    # 波 +1.0 = 2.0
	assert_eq(b.hp[1][0], 16, "收割形态波 2.0（20-4）")


func test_h26_kill_heals_in_form() -> void:
	var b := _battle2([["h26", 4], ["t01", 10], ["t02", 10]], [["t10", 1], ["t11", 10], ["t12", 10]])
	b.form[0][0] = 1
	b.hp[0][0] = 4            # 残血以便看回血
	_aa(b, ATTACK, CHARGE)    # 波 2.0 杀掉 1.0 对手 → 击杀回 2.0
	assert_lte(b.hp[1][0], 0, "对手阵亡")
	assert_eq(b.hp[0][0], 8, "击杀回 2.0（4+4，cap 8）")


func test_h26_no_heal_before_transform() -> void:
	var b := _battle2([["h26", 4], ["t01", 10], ["t02", 10]], [["t10", 1], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 4            # 未变身（form 0）
	_aa(b, ATTACK, CHARGE)    # 波 1.0 杀 1.0 对手，但未变身 → 不回血
	assert_eq(b.hp[0][0], 4, "未变身不回血")


# ---- h28 恶魔 ----

func test_h28_contract_buffs_ally_and_costs_demon_hp() -> void:
	var b := _battle2([["t_ally", 10], ["h28", 6], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	assert_eq(int(b.link[0].get("contract", -1)), 0, "契约对象默认 slot0")
	_aa(b, ATTACK, CHARGE)    # 契约队友(slot0)出战攻击 → +1.0，恶魔付 1.0HP
	assert_eq(b.hp[1][0], 16, "契约队友波 2.0（20-4）")
	assert_eq(b.hp[0][1], 10, "恶魔付 1.0 HP（12-2）")


func test_h28_no_buff_when_demon_dead() -> void:
	var b := _battle2([["t_ally", 10], ["h28", 6], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0            # 恶魔阵亡
	_aa(b, ATTACK, CHARGE)
	assert_eq(b.hp[1][0], 18, "恶魔亡 → 契约失效，波 1.0（20-2）")


# ---- h31 月亮 ----

func test_h31_yin_halves_outgoing() -> void:
	var b := _battle2([["h31", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, ATTACK, CHARGE)    # turn0 阴：造成减半 波 1.0→0.5
	assert_eq(b.hp[1][0], 19, "阴相造成减半（20-1）")


func test_h31_qing_doubles_outgoing() -> void:
	var b := _battle2([["h31", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, CHARGE)    # turn0
	_aa(b, ATTACK, CHARGE)    # turn1 晴：造成翻倍 波 1.0→2.0
	assert_eq(b.hp[1][0], 16, "晴相造成翻倍（20-4）")


func test_h31_yuan_halves_incoming() -> void:
	var b := _battle2([["h31", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, CHARGE)    # turn0
	_aa(b, CHARGE, CHARGE)    # turn1
	_aa(b, CHARGE, BIG)       # turn2 圆：受到减半 大波 2.0→1.0
	assert_eq(b.hp[0][0], 8, "圆相受到减半（10-2）")


func test_h31_que_doubles_incoming() -> void:
	var b := _battle2([["h31", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, CHARGE)    # turn0
	_aa(b, CHARGE, CHARGE)    # turn1
	_aa(b, CHARGE, CHARGE)    # turn2
	_aa(b, CHARGE, ATTACK)    # turn3 缺：受到翻倍 波 1.0→2.0
	assert_eq(b.hp[0][0], 6, "缺相受到翻倍（10-4）")


# ---- h14 梅开二度 ----

func test_h14_doubles_next_attack() -> void:
	var b := _battle2([["h14", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)        # 梅开（耗 2 能，置 meikai）
	b.select_action(1, CHARGE)
	b.resolve()
	_aa(b, ATTACK, CHARGE)    # 下一动作=波 → 执行 2 次
	assert_eq(b.hp[1][0], 16, "波 ×2 = 2.0（20-4）")
	assert_false(b.get_status(0, 0, "meikai", false), "已消耗")


func test_h14_doubles_charge() -> void:
	var b := _battle2([["h14", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)        # 梅开（6-2=4）
	b.select_action(1, CHARGE)
	b.resolve()
	_aa(b, CHARGE, CHARGE)    # 攒 ×2 = +2
	assert_eq(b.energy[0], 6, "攒 ×2（4+2）")


func test_h14_switch_does_not_consume() -> void:
	var b := _battle2([["h14", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	b.select_switch(0, 1)     # 切换不消耗 meikai
	b.select_action(1, CHARGE)
	b.resolve()
	assert_true(b.get_status(0, 0, "meikai", false), "切换不消耗，meikai 保留")


# ---- h24 天平 ----

func test_h24_balances_hp_to_average() -> void:
	var b := _battle2([["h24", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 4            # 正义 2.0
	# 对手出战 20 半点(10.0)
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 12, "拉平均(4+20)/2=12，正义封顶 max 12")
	assert_eq(b.hp[1][0], 12, "对手出战也拉到 12")


func test_h24_caps_at_max() -> void:
	var b := _battle2([["h24", 3], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 2           # 正义 max=6半点, 当前 1.0
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 6, "平均(2+20)/2=11 但正义封顶 max 6")
	assert_eq(b.hp[1][0], 11, "对手拉到 11")


# ---- h07 当先 ----

func test_h07_free_switch_then_act_same_turn() -> void:
	var b := _battle2([["h07", 5], ["t_atk", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	assert_true(b.free_switch(0, 1), "免费切换成功")
	assert_eq(b.active_index[0], 1, "已换到 slot1")
	assert_eq(int(b.get_status(0, 0, "dangxian_uses", 0)), 1, "计 1 次")
	_aa(b, ATTACK, CHARGE)    # 换上来的英雄同回合行动
	assert_eq(b.hp[1][0], 18, "免费切后仍能行动：波 1.0（20-2）")


func test_h07_cap_2() -> void:
	var b := _battle2([["h07", 5], ["t_atk", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "dangxian_uses", 2)
	assert_false(b.can_free_switch(0), "用满 2 次后不可免费切")


func test_h07_only_dangxian_can_free_switch() -> void:
	var b := _battle2([["t_plain", 10], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	assert_false(b.can_free_switch(0), "非当先英雄无免费切")
