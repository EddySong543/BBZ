extends GutTest

## AI 深层剪枝合法性回归（2026-07-17 审计修复）。
## 缺陷：_shortlist 的「攒恒合法」假设早于锁招机制（h17 阖眸成夜 v5）——锁招拍且锁定动作
## 可执行时攒非法；切换分支同样没过 can_afford。非法行进深层收益矩阵=估值失真。
## 修复=攒与切换均过 can_afford（与顶层 legal_actions 同一收口）。


func _hero(id: String, hp: int = 5) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(e: int = 8) -> BattleCore:
	var p0: Array = [_hero("test_a0"), _hero("test_a1"), _hero("test_a2")]
	var p1: Array = [_hero("test_b0"), _hero("test_b1"), _hero("test_b2")]
	var b := BattleCore.new()
	b.setup(p0, p1, 321)
	b.energy = [e, e]
	return b


func _acts(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append(int((d as Dictionary)["action"]))
	return out


func test_ai_shortlist_normal_turn_includes_charge_and_switch() -> void:
	# Arrange：无锁常态
	var b := _battle()
	var ai := BattleAI.new(1)

	# Act
	var acts := _acts(ai._shortlist(b, 0))

	# Assert：基线——攒/波/切换都在
	assert_has(acts, int(ActionDef.Action.CHARGE))
	assert_has(acts, int(ActionDef.Action.ATTACK))
	assert_has(acts, int(ActionDef.Action.SWITCH))


func test_ai_shortlist_action_lock_excludes_charge_and_switch() -> void:
	# Arrange：锁招拍·锁定「波」且可执行（能量足）→ can_afford 收口下仅波合法
	var b := _battle()
	b.action_lock_turn[0] = b.turn_number
	b.action_locked[0] = ActionDef.Action.ATTACK
	var ai := BattleAI.new(1)

	# Act
	var acts := _acts(ai._shortlist(b, 0))

	# Assert：非法的攒/切换不得进深层矩阵·锁定动作在
	assert_does_not_have(acts, int(ActionDef.Action.CHARGE), "锁招拍（锁波可执行）攒非法")
	assert_does_not_have(acts, int(ActionDef.Action.SWITCH), "锁招拍切换非法")
	assert_has(acts, int(ActionDef.Action.ATTACK))


func test_ai_shortlist_locked_action_unaffordable_falls_back_to_charge() -> void:
	# Arrange：锁「大波」但能量付不起 → 引擎兜底=只能攒（无死锁保证）
	var b := _battle(0)
	b.action_lock_turn[0] = b.turn_number
	b.action_locked[0] = ActionDef.Action.BIG_ATTACK
	var ai := BattleAI.new(1)

	# Act
	var acts := _acts(ai._shortlist(b, 0))

	# Assert：只剩攒
	assert_eq(acts, [int(ActionDef.Action.CHARGE)], "锁定动作不可执行=兜底只能攒")
