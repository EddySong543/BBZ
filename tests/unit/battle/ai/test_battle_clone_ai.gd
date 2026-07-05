extends GutTest

## ============================================================================
## BattleCore AI 支持方法 —— clone() / legal_actions() / apply_choice()
##   验证：克隆状态独立、克隆推演不污染原局、rng 状态复制保真（概率技可复现）、
##         合法动作枚举正确（能量门 / 切换目标 / 主动技）、apply_choice 分派正确。
## ============================================================================

const CHARGE := ActionDef.Action.CHARGE
const ATTACK := ActionDef.Action.ATTACK
const DEFEND := ActionDef.Action.DEFEND
const BIG := ActionDef.Action.BIG_ATTACK
const BIG_DEFEND := ActionDef.Action.BIG_DEFEND
const SWITCH := ActionDef.Action.SWITCH
const ACTIVE := ActionDef.ACTIVE


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
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


## 提取 legal_actions 结果里的 action int 列表。
func _actions_of(la: Array) -> Array:
	var out: Array = []
	for entry in la:
		out.append(int(entry["action"]))
	return out


# ---- clone：状态独立 ----

func test_clone_state_is_independent() -> void:
	# Arrange
	var b := _battle2([["h01", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])

	# Act：克隆后篡改克隆体
	var c := b.clone()
	c.hp[0][0] = 999
	c.energy[0] = 17
	c.set_status(0, 0, "foo", 42)
	c.info_distortion[0]["bar"] = 7

	# Assert：原局完全不受影响
	assert_eq(b.hp[0][0], 8, "原局 hp 不随克隆改动（4HP=8 半点）")
	assert_eq(b.energy[0], 6, "原局能量不随克隆改动")
	assert_eq(int(b.get_status(0, 0, "foo", -1)), -1, "原局 status 不随克隆改动")
	assert_false(b.info_distortion[0].has("bar"), "原局 info_distortion 不随克隆改动")


# ---- clone：推演不污染原局 ----

func test_clone_resolve_does_not_mutate_original() -> void:
	# Arrange
	var b := _battle2([["h01", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	var hp_before: Array = b.hp.duplicate(true)
	var energy_before: Array = b.energy.duplicate()
	var turn_before: int = b.turn_number
	var rng_state_before: int = b.rng.state

	# Act：在克隆体上完整结算一回合
	var c := b.clone()
	c.select_action(0, ATTACK)
	c.select_action(1, CHARGE)
	c.resolve()

	# Assert：原局 hp / 能量 / 回合 / rng 序列均不变；克隆体已推进
	assert_eq(b.hp, hp_before, "原局 hp 不被克隆推演改动")
	assert_eq(b.energy, energy_before, "原局能量不被克隆推演改动")
	assert_eq(b.turn_number, turn_before, "原局回合数不被克隆推演改动")
	assert_eq(b.rng.state, rng_state_before, "克隆推演不消耗原局 rng 序列")
	assert_eq(c.turn_number, turn_before + 1, "克隆体回合已推进")


# ---- clone：rng 状态复制保真（概率道具 / AI 推演可复现）----

func test_clone_reproduces_rng_state() -> void:
	# Arrange：推进原局 rng 到某状态（模拟战局已消耗若干随机数）
	var b := _battle2([["h01", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.rng.randi()

	# Act：从同一原局克隆两份
	var c1 := b.clone()
	var c2 := b.clone()

	# Assert：相同 rng 状态 → 两克隆下一个随机数一致
	assert_eq(c1.rng.randi(), c2.rng.randi(),
		"克隆 rng 状态保真 → 概率推演确定可复现")


# ---- legal_actions：能量门 + 切换目标 ----

func test_legal_actions_respects_energy_gate() -> void:
	# Arrange：能量 2 半能（= 1.0 能）——半能制下波费 2、大波 6、大防 4
	var b := _battle2([["h02", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 2)

	# Act
	var acts: Array = _actions_of(b.legal_actions(0))

	# Assert：0 费动作 + 波(2 半能)可用；大波(6)/大防(4)不可用
	assert_true(CHARGE in acts, "攒恒合法")
	assert_true(ATTACK in acts, "能量 2 半能 可出波(费 2)")
	assert_true(DEFEND in acts, "防 0 费可用")
	assert_false(BIG in acts, "能量 2 半能 不足以大波(费 6)")
	assert_false(BIG_DEFEND in acts, "能量 2 半能 不足以大防(费 4)")


func test_legal_actions_lists_switch_targets() -> void:
	# Arrange：两个存活替补
	var b := _battle2([["h02", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])

	# Act
	var switches: Array = []
	for entry in b.legal_actions(0):
		if int(entry["action"]) == SWITCH:
			switches.append(int(entry["target"]))

	# Assert
	assert_eq(switches.size(), 2, "两个存活替补 → 两个切换选项")
	assert_true(1 in switches and 2 in switches, "切换目标为替补槽 1 / 2")


func test_legal_actions_includes_available_active() -> void:
	# Arrange：h10 昴日 拔剑一闪（主动 2 能·需剑气>0·helper 默认 6 半能足够）
	var b := _battle2([["h10", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "jianqi", 1)   # 有剑气 → 主动可用

	# Assert
	assert_true(ACTIVE in _actions_of(b.legal_actions(0)), "可用主动技应在合法动作内")

	# h01 盾枢 纯被动 → 无 ACTIVE
	var b2 := _battle2([["h01", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	assert_false(ACTIVE in _actions_of(b2.legal_actions(0)), "纯被动英雄无主动技选项")


# ---- apply_choice：分派正确 ----

func test_apply_choice_dispatches_switch_and_active() -> void:
	# Arrange：h10 昴日 有主动技（需剑气>0）
	var b := _battle2([["h10", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "jianqi", 1)

	# 切换
	assert_true(b.apply_choice(0, {action = SWITCH, target = 2}), "切换 choice 合法")
	assert_eq(b.selected_action[0], SWITCH, "selected_action = SWITCH")
	assert_eq(b._switch_to[0], 2, "切换目标 = 槽 2")

	# 主动技
	assert_true(b.apply_choice(0, {action = ACTIVE, target = -1}), "主动 choice 合法")
	assert_eq(b.selected_action[0], ACTIVE, "selected_action = ACTIVE")

	# 基础动作
	assert_true(b.apply_choice(0, {action = ATTACK, target = -1}), "基础 choice 合法")
	assert_eq(b.selected_action[0], ATTACK, "selected_action = ATTACK")
