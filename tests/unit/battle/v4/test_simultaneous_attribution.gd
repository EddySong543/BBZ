extends GutTest

## 基础攻击来源槽归因回归测试（2026-07-17 审计修复①）。
## 结算必须使用 hit 生成时保存的 src_slot，而不能读取可能已变化的实时 active_index；
## 否则换人或未来的中途登场机制会把 on-hit 归因给错误英雄。
## 观察点：h20 罪已昭 on_deal_hit 施加「vuln」——归因错则状态丢失、归因对则状态附上。

const A := ActionDef.Action


func _hero(id: String, hp: int = 5) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func test_saved_source_slot_keeps_attacker_attribution_after_active_index_changes() -> void:
	# hit 的来源是 P1 slot0=h20；施加前把实时出战位改成白板 slot1，模拟结算中途换位。
	var p0: Array = [_hero("test_p0_0"), _hero("test_p0_1"), _hero("test_p0_2")]
	var p1: Array = [_hero("h20"), _hero("test_p1_1"), _hero("test_p1_2")]
	var b := BattleCore.new()
	b.setup(p0, p1, 777)
	b.energy = [8, 8]
	b.active_index[1] = 1

	# attacker_slot=0 锁定出手槽；is_base_attack=true 走基础攻击 on-hit。
	b._apply_damage(0, 2, 1, A.ATTACK, ActionDef.Pen.NORMAL, A.CHARGE,
		[], [], "action", 0, -1, true)

	# on-hit 仍应归给保存的 h20，而不是实时白板。
	assert_gt(int(b.get_status(0, 0, "vuln", 0)), 0,
		"h20 的攻击命中必须施加脆弱——归因不得随实时出战位漂移")


func test_simultaneous_no_rescue_attribution_baseline() -> void:
	# 标准同步攻击基线：没有中途换位时，h20 仍正常施加脆弱。
	var p0: Array = [_hero("test_p0_0"), _hero("test_p0_1"), _hero("test_p0_2")]
	var p1: Array = [_hero("h20"), _hero("test_p1_1"), _hero("test_p1_2")]
	var b := BattleCore.new()
	b.setup(p0, p1, 777)
	b.energy = [8, 8]

	# Act
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.ATTACK)
	b.resolve()

	# Assert
	assert_gt(int(b.get_status(0, 0, "vuln", 0)), 0, "标准同步攻击应正常施加脆弱")
