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


func test_clone_preserves_energy_max_independently() -> void:
	var b := _battle2([["h23", 6], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 10], ["t12", 10]])
	b.energy_max = [18, 12]

	var c := b.clone()
	assert_eq(c.energy_max, [18, 12], "克隆体应保留双方动态能量上限")
	c.energy_max[1] = 6
	assert_eq(b.energy_max[1], 12, "克隆体修改能量上限不得污染原局")


func test_clone_preserves_h02_team_wave_upgrade_and_keeps_array_independent() -> void:
	var b := _battle2([["h02", 7], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 10], ["t12", 10]])
	b.upgrade_next_wave[0] = true
	b.upgrade_next_wave[1] = true

	var c := b.clone()
	assert_true(c.upgrade_next_wave[0], "克隆体应保留己方下一次波升级")
	assert_true(c.upgrade_next_wave[1], "克隆体应保留敌方下一次波升级")

	c.upgrade_next_wave[0] = false
	c.upgrade_next_wave[1] = false
	assert_true(b.upgrade_next_wave[0], "克隆体消费升级不得污染原局")
	assert_true(b.upgrade_next_wave[1], "克隆体消费敌方升级不得污染原局")


func test_clone_preserves_h05_empowered_wave_choice_and_keeps_array_independent() -> void:
	var b := _battle2([["t00", 5], ["h05", 5], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 8)
	assert_true(b.select_action(0, ATTACK, -1, true))

	var c := b.clone()
	assert_true(c.empowered_wave_selected(0), "克隆体应保留已提交的龙御极强化波")
	assert_true(c.select_empowered_wave(0, false), "克隆体可独立取消强化")
	assert_true(b.empowered_wave_selected(0), "克隆体取消不得污染原局")


func test_clone_preserves_h13_split_big_wave_choice_and_keeps_array_independent() -> void:
	var b := _battle2([["h13", 4], ["t01", 5], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 8)
	assert_true(b.select_action(0, BIG, -1, false, true))

	var c := b.clone()
	assert_true(c.split_big_wave_selected(0), "克隆体应保留玄冥双波选择")
	assert_true(c.select_split_big_wave(0, false), "克隆体可独立取消双波")
	assert_true(b.split_big_wave_selected(0), "克隆体取消不得污染原局")


func test_clone_preserves_h14_blood_payment_choice_and_keeps_array_independent() -> void:
	var b := _battle2([["h14", 6], ["h07", 6], ["h17", 7]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 0)
	assert_true(b.set_blood_payment_active(0, true))
	assert_true(b.free_switch(0, 1))
	assert_true(b.select_action(0, BIG, -1, false, false, true))

	var c := b.clone()
	assert_true(c.blood_payment_selected(0), "克隆体应保留蚩尤生命支付选择")
	assert_eq(c.active_index[0], 1, "克隆体应保留免费切换后的出战槽")
	assert_eq(c.free_switch_usage_turn, b.free_switch_usage_turn, "克隆体应保留免费切换回合")
	assert_eq(c.free_switch_uses, b.free_switch_uses, "克隆体应保留本回合免费切换次数")
	assert_eq(c.blood_payment_source(0), 0, "克隆体应保留原槽蚩尤为付款者")
	c.free_switch_uses[0] = 0
	assert_eq(b.free_switch_uses[0], 1, "克隆体修改免费切换次数不得污染原局")
	assert_true(c.select_blood_payment(0, false), "克隆体可独立取消生命支付")
	assert_true(b.blood_payment_selected(0), "克隆体取消不得污染原局")
	assert_eq(b.blood_payment_source(0), 0, "克隆体取消不得污染原局付款来源")


func test_clone_preserves_h24_energy_cap_discount_choice_and_keeps_array_independent() -> void:
	var b := _battle2([["t00", 5], ["h24", 6], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 4)
	assert_true(b.select_action(0, BIG, -1, false, false, false, true))

	var c := b.clone()
	assert_true(c.energy_cap_discount_selected(0), "克隆体应保留并封减费选择")
	assert_true(c.select_energy_cap_discount(0, false), "克隆体可独立取消并封减费")
	assert_true(b.energy_cap_discount_selected(0), "克隆体取消不得污染原局")


func test_clone_preserves_h08_retained_big_defend_and_keeps_array_independent() -> void:
	var b := _battle2([["h08", 6], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_action(0, BIG_DEFEND)
	b.select_action(1, CHARGE)
	b.resolve()

	var c := b.clone()
	assert_true(c.retained_big_defend[0], "克隆体应保留己方不坠神言")
	assert_false(c.retained_big_defend[1], "克隆体应保留敌方默认状态")
	assert_eq(c.retained_big_defend_until_turn[0], b.retained_big_defend_until_turn[0],
		"克隆体应保留不坠神言的到期回合")

	c.retained_big_defend[0] = false
	c.retained_big_defend[1] = true
	c.retained_big_defend_until_turn[0] = -1
	c.retained_big_defend_until_turn[1] = 99
	assert_true(b.retained_big_defend[0], "克隆体消费保留大防不得污染原局")
	assert_false(b.retained_big_defend[1], "克隆体建立状态不得污染原局")
	assert_ne(b.retained_big_defend_until_turn[0], -1, "克隆体修改期限不得污染原局")
	assert_ne(b.retained_big_defend_until_turn[1], 99, "期限数组必须深拷")


func test_clone_preserves_h22_energy_burn_deadline_independently() -> void:
	var b := _battle2([["h22", 5], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 10], ["t12", 10]])
	b.energy_burn_turn = b.turn_number + 1

	var c := b.clone()
	assert_eq(c.energy_burn_turn, b.energy_burn_turn,
		"克隆体应保留焚天火兆的全局归零期限")

	c.energy_burn_turn = -1
	assert_ne(b.energy_burn_turn, -1, "克隆体清除期限不得污染原局")


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
	# Arrange：h10 昴日 飞洒天星（主动 2 能·需剑气>0·helper 默认 6 半能足够）
	var b := _battle2([["h10", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "jianqi", 1)   # 有剑气 → 主动可用

	# Assert
	assert_true(ACTIVE in _actions_of(b.legal_actions(0)), "可用主动技应在合法动作内")

	# h01 步虚无有乡为纯被动 → 无 ACTIVE
	var b2 := _battle2([["h01", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	assert_false(ACTIVE in _actions_of(b2.legal_actions(0)), "纯被动英雄无主动技选项")


func test_legal_actions_enumerates_pull_targets() -> void:
	# 批③④(2026-07-05)：带敌方目标的主动技（h21 调虎离山）→ 每个敌方存活替补一个独立选项，
	# 搜索自己挑最优揪谁（旧枚举只有 target=-1=随机揪·用后率 0.27 的病根）。
	var b := _battle2([["h21", 8], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 6], ["t12", 4]])
	var targets: Array = []
	for c in b.legal_actions(0):
		if int(c["action"]) == ACTIVE:
			targets.append(int(c["target"]))
	assert_eq(targets.size(), 2, "敌方 2 个存活替补 → 2 个揪选项（无 -1 随机项）")
	assert_true(1 in targets and 2 in targets, "目标 = 敌方替补槽 1 / 2")
	assert_true(b.apply_choice(0, {action = ACTIVE, target = 2}), "带目标主动 choice 合法")
	assert_eq(b.active_target(0), 2, "揪目标已登记（execute_active 将定向揪槽 2）")


func test_legal_actions_enumerates_h04_attack_targets() -> void:
	var b := _battle2([["h04", 5], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 6], ["t12", 4]], 20)
	b.hp[1][2] = 0
	var wave_targets: Array[int] = []
	var big_wave_targets: Array[int] = []
	for choice in b.legal_actions(0):
		if int(choice["action"]) == ATTACK:
			wave_targets.append(int(choice["target"]))
		elif int(choice["action"]) == BIG:
			big_wave_targets.append(int(choice["target"]))

	assert_eq(wave_targets, [0, 1], "波应为每个存活敌方英雄生成独立目标选项")
	assert_eq(big_wave_targets, [0, 1], "大波应为每个存活敌方英雄生成独立目标选项")


func test_xunxing_pendant_enumerates_wave_targets_but_not_big_wave_targets() -> void:
	var b := _battle2([["t00", 5], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 6], ["t12", 4]], 20)
	b.econ_init()
	b.slots[0][0] = {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make("t1_xunxing_zhui"),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}
	assert_true(b.use_slot(0, 0), "就绪寻星坠应可提交")
	var wave_targets: Array[int] = []
	var big_wave_targets: Array[int] = []
	for choice in b.legal_actions(0):
		if int(choice["action"]) == ATTACK:
			wave_targets.append(int(choice["target"]))
		elif int(choice["action"]) == BIG:
			big_wave_targets.append(int(choice["target"]))

	assert_eq(wave_targets, [0, 1, 2], "寻星坠为波枚举全部存活敌方")
	assert_eq(big_wave_targets, [-1], "寻星坠不得扩张到大波")
	assert_false(b.select_action(0, ATTACK, 3), "越界或不存在的目标槽必须拒绝")


func test_legal_actions_enumerates_h05_normal_and_empowered_wave_choices() -> void:
	var rich := _battle2([["t00", 5], ["h05", 5], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 4)
	var normal := 0
	var empowered := 0
	for choice in rich.legal_actions(0):
		if int(choice["action"]) != ATTACK:
			continue
		if bool(choice.get("empowered_wave", false)):
			empowered += 1
		else:
			normal += 1
	assert_eq(normal, 1, "普通波仍是独立合法选项")
	assert_eq(empowered, 1, "有亢金且有 2 能时应追加一个强化波选项")

	var poor := _battle2([["t00", 5], ["h05", 5], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 2)
	for choice in poor.legal_actions(0):
		assert_false(bool(choice.get("empowered_wave", false)), "只有 1 能时合法集不得出现强化波")


func test_legal_actions_enumerates_h13_normal_and_split_big_wave_choices() -> void:
	var b := _battle2([["h13", 4], ["t01", 5], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 8)
	var normal_big := 0
	var split_big := 0
	for choice in b.legal_actions(0):
		if int(choice["action"]) != BIG:
			continue
		if bool(choice.get("split_big_wave", false)):
			split_big += 1
		else:
			normal_big += 1
	assert_eq(normal_big, 1, "玄冥应保留普通大波 choice")
	assert_eq(split_big, 1, "玄冥应额外获得双波 choice")


func test_legal_actions_enumerates_h14_blood_paid_actions_when_energy_is_empty() -> void:
	var b := _battle2([["h14", 6], ["t01", 5], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 0)
	var blood_wave := 0
	var blood_big_wave := 0
	for choice in b.legal_actions(0):
		if not bool(choice.get("blood_payment", false)):
			continue
		if int(choice["action"]) == ATTACK:
			blood_wave += 1
		elif int(choice["action"]) == BIG:
			blood_big_wave += 1

	assert_eq(blood_wave, 1, "0 能量时 AI 仍应看到生命支付的波")
	assert_eq(blood_big_wave, 1, "0 能量时 AI 仍应看到生命支付的大波")


func test_legal_actions_enumerates_h24_discounted_actions() -> void:
	var b := _battle2([["t00", 5], ["h24", 6], ["t02", 5]],
		[["t10", 5], ["t11", 5], ["t12", 5]], 4)
	var discounted_big := 0
	var normal_big := 0
	for choice in b.legal_actions(0):
		if int(choice["action"]) != BIG:
			continue
		if bool(choice.get("energy_cap_discount", false)):
			discounted_big += 1
		else:
			normal_big += 1
	assert_eq(discounted_big, 1, "只有 2 能时，AI 应看到并封减费后的大波")
	assert_eq(normal_big, 0, "付不起原价时不得伪造普通大波")


func test_h04_attack_target_survives_clone_and_apply_choice() -> void:
	var b := _battle2([["h04", 5], ["t01", 10], ["t02", 10]],
		[["t10", 10], ["t11", 6], ["t12", 4]], 20)
	assert_true(b.apply_choice(0, {action = ATTACK, target = 2}), "h04 带目标基础攻击 choice 合法")
	var c := b.clone()
	b.select_action(1, CHARGE)
	c.select_action(1, CHARGE)
	var original_result: Dictionary = b.resolve()
	var clone_result: Dictionary = c.resolve()

	assert_eq_deep(clone_result, original_result)
	assert_eq(c.hp[1][2], 6, "克隆中的攻击应命中槽 2")
	assert_eq(c.hp[1][0], 20, "克隆中的敌方出战位不应被误伤")


func test_xunxing_target_and_queued_item_survive_clone() -> void:
	# 使用不会映射到正式技能ID的夹具英雄，隔离选敌道具自身的 0.5 点伤害。
	var b := _battle2([["fixture_a0", 5], ["fixture_a1", 10], ["fixture_a2", 10]],
		[["fixture_b0", 10], ["fixture_b1", 6], ["fixture_b2", 4]], 20)
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
	assert_true(b.apply_choice(0, {action = ATTACK, target = 2}))
	var c := b.clone()
	b.select_action(1, CHARGE)
	c.select_action(1, CHARGE)
	var original_result: Dictionary = b.resolve()
	var clone_result: Dictionary = c.resolve()

	assert_eq_deep(clone_result, original_result)
	assert_eq(c.hp[1][2], 7, "寻星坠的减伤波应在克隆中命中指定后排")
	assert_eq(c.hp[1][0], 20, "未指定出战位不得被误伤")


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
