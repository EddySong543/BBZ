extends GutTest

## ============================================================================
## BattleEngineV4 英雄第六批（Step 2.2c）—— 状态 debuff
##   h32 太阳 —— 燃烧（易伤 +1.0 / 禁回血 / 2 回合 tick）
##   h15 女祭司 —— 沉默（被动失效）+ 抹除叠层
##   h17 皇帝 —— 禁用动作系列（下回合）
## ============================================================================

const ATTACK := ActionDefV4.Action.ATTACK
const BIG := ActionDefV4.Action.BIG_ATTACK
const CHARGE := ActionDefV4.Action.CHARGE
const DEFEND := ActionDefV4.Action.DEFEND
const SWITCH := ActionDefV4.Action.SWITCH


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


# ---- h32 太阳（燃烧）----

func test_h32_applies_burn() -> void:
	var b := _battle2([["h32", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "burn", 0)), 1, "燃烧附着（初值 2，本回合 tick 到 1）")
	assert_eq(b.energy[0], 5, "太阳耗 1 能")


func test_h32_burn_adds_vulnerability() -> void:
	var b := _battle2([["h32", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()                       # 施燃烧
	_aa(b, ATTACK, CHARGE)            # 太阳波打燃烧的敌人
	assert_eq(b.hp[1][0], 16, "波 1.0 + 易伤 1.0 = 2.0（20-4）")


func test_h32_burn_blocks_heal() -> void:
	var b := _battle2([["h32", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "burn", 2)
	b.hp[0][0] = 4
	var healed: int = b._heal(0, 0, ActionDefV4.HP_UNIT)
	assert_eq(healed, 0, "燃烧期间禁回血")
	assert_eq(b.hp[0][0], 4, "HP 未变")


func test_h32_burn_expires() -> void:
	var b := _battle2([["h32", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()                       # burn 2 → 1
	_aa(b, CHARGE, CHARGE)            # burn 1 → 0
	assert_eq(int(b.get_status(1, 0, "burn", 0)), 0, "燃烧 2 回合后消失")


# ---- h15 女祭司（沉默）----

func test_h15_silences_passive_and_clears_combo() -> void:
	var b := _battle2([["h15", 10], ["t01", 10], ["t02", 10]], [["h09", 4], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, ATTACK)            # 凶兽 1.0，combo→1
	_aa(b, CHARGE, ATTACK)            # 凶兽 2.0，combo→2
	b.select_active(0)               # P0 三缄：沉默 + 清叠层
	b.select_action(1, ATTACK)       # 凶兽被沉默 → 只打基础 1.0
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "combo", 0)), 0, "连段被清、沉默下不再累积")
	assert_eq(b.hp[0][0], 12, "20 -2 -4 -2：第三波因沉默只造成 1.0")


func test_h15_clears_stack_status() -> void:
	var b := _battle2([["h15", 10], ["t01", 10], ["t02", 10]], [["h03", 5], ["t11", 10], ["t12", 10]])
	b.set_status(1, 0, "xuexue", 2)
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "xuexue", 0)), 0, "三缄抹除渴血叠层")


# ---- h17 皇帝（禁用动作）----

func test_h17_disables_attack_group_next_turn() -> void:
	var b := _battle2([["h17", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_true(b.is_action_disabled(1, ATTACK), "下回合波被禁")
	assert_true(b.is_action_disabled(1, BIG), "下回合大波被禁")
	assert_false(b.select_action(1, ATTACK), "选攻击被拒")
	assert_true(b.select_action(1, CHARGE), "攒不受禁")


func test_h17_cannot_disable_charge_or_switch() -> void:
	var b := _battle2([["h17", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_false(b.is_action_disabled(1, CHARGE), "攒不可禁")
	assert_false(b.is_action_disabled(1, SWITCH), "切换不可禁")


func test_h17_disable_expires_after_one_turn() -> void:
	var b := _battle2([["h17", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()                       # 君命（turn0）→ 禁 turn1
	_aa(b, CHARGE, CHARGE)            # turn1：禁令生效，P1 攒
	assert_false(b.is_action_disabled(1, ATTACK), "禁令仅一回合，turn2 解除")
