extends GutTest

## 同时结算归因回归测试（2026-07-17 审计修复①）。
## 缺陷：施加段固定 p0→p1 序，p0 的攻击若触发 p1 侧护主换人（active_index 中途变化），
## p1 已生成攻击的 on-hit 回调按旧代码读实时出战位 → 归因给顶班天狗而非出招英雄
## （先后手不对称·破坏公平/确定性）。修复=hit 生成时记 src_slot·施加按快照槽归因。
## 观察点：h20 罪已昭 on_deal_hit 附「vuln」——归因错则印丢失、归因对则印附上。

const A := ActionDef.Action


func _hero(id: String, hp: int = 5) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func test_simultaneous_lethal_rescue_keeps_attacker_attribution() -> void:
	# Arrange：P1 出战=h20（on-hit 附印）·替补=h23 天狗（护主）；P0=白板队先手施加。
	var p0: Array = [_hero("test_p0_0"), _hero("test_p0_1"), _hero("test_p0_2")]
	var p1: Array = [_hero("h20"), _hero("h23"), _hero("test_p1_2")]
	var b := BattleCore.new()
	b.setup(p0, p1, 777)
	b.energy = [8, 8]
	b.hp[1][0] = 1   # 测试夹具：h20 垫到一击必死 → P0 的波触发天狗护主

	# Act：双方同回合都出「波」——P0 的 hit 先施加（致死→天狗顶上→active_index[1] 变），
	# P1（h20）的 hit 后施加——归因必须仍是 h20 而非天狗。
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.ATTACK)
	var r: Dictionary = b.resolve()

	# Assert：护主确实触发（前提成立）
	var rescued := false
	for ev in r.get("events", []):
		if String((ev as Dictionary).get("id", "")) == "lethal_rescue":
			rescued = true
	assert_true(rescued, "前提：P0 的攻击应触发天狗护主")
	assert_eq(b.active_index[1], 1, "前提：天狗（槽1）顶班出战")

	# Assert：h20 的 on-hit 印记附在 P0 出战身上（归因给出招的 h20·修复前会丢=归给天狗）
	assert_gt(int(b.get_status(0, 0, "vuln", 0)), 0,
		"h20 的攻击命中必须附罪已昭印——归因不得因同拍护主换人漂给天狗")


func test_simultaneous_no_rescue_attribution_baseline() -> void:
	# Arrange：同队形但不垫致命（护主不触发）——基线：印照常附上（证明上例断言面本身有效）
	var p0: Array = [_hero("test_p0_0"), _hero("test_p0_1"), _hero("test_p0_2")]
	var p1: Array = [_hero("h20"), _hero("h23"), _hero("test_p1_2")]
	var b := BattleCore.new()
	b.setup(p0, p1, 777)
	b.energy = [8, 8]

	# Act
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.ATTACK)
	b.resolve()

	# Assert
	assert_gt(int(b.get_status(0, 0, "vuln", 0)), 0, "无护主时印照常附上（断言面有效性基线）")
