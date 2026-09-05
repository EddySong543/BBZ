extends GutTest

## 加时赛（Q5·2026-07-03 Eddy 定；2026-07-05 修订：不限回合 → 30 回合骤死）行为锁定测试。
## 规则：主局平局/打满上限 → 各自队伍 3 选 1 → 满血白板 1v1（禁技能·禁道具）·
##   被动能量与正常局一致·上限 OVERTIME_TURN_CAP=30 回合：打满 → 双方出战同时扣血等量
##   （=较低者当前 HP）→ 低血者归零判负、等血同归 = 真平局。
## 触发与选人流程在调用方（run_sim / battle_screen）；本文件锁 create_overtime 战局本体 + AI 选人。

const A := ActionDef.Action


func _hero(id: String, hp: int, skill_desc: String = "") -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	h.skill_description = skill_desc
	return h


func test_overtime_is_fullhp_vanilla_1v1() -> void:
	# Arrange：两个有技能的英雄（h01 步虚无有乡 / h15 魇镇八极）
	var a := _hero("h01", 5, "步虚无有乡")
	var x := _hero("h15", 6, "魇镇八极")
	# Act
	var d := BattleCore.create_overtime(a, x, 42)
	# Assert：1v1、满血、白板、无道具经济
	assert_eq(d.heroes[0].size(), 1, "P0 只有 1 名英雄")
	assert_eq(d.heroes[1].size(), 1, "P1 只有 1 名英雄")
	assert_eq(d.hp[0][0], 10, "满血上场（5HP=10 半点）")
	assert_eq(d.hp[1][0], 12, "满血上场（6HP=12 半点）")
	assert_null(d.get_skill(0, 0), "技能被剥离（白板波波攒）")
	assert_null(d.get_skill(1, 0), "技能被剥离（白板波波攒）")
	assert_eq(d.slots[0].size(), 0, "无道具经济（未 econ_init）")
	assert_eq(d.heroes[0][0].hero_name, "h01", "名字保留（UI 展示用）")


func test_overtime_strips_skill_gates() -> void:
	# 魇镇八极（h15）正常局禁防；加时白板后防/大防恢复合法。
	var d := BattleCore.create_overtime(_hero("h15", 6, "魇镇八极"), _hero("h01", 5, "步虚无有乡"), 42)
	d.energy = [10, 10]
	assert_true(d.can_afford(0, A.DEFEND), "白板后魇镇八极也能防")
	assert_true(d.can_afford(0, A.BIG_DEFEND), "白板后魇镇八极也能大防")


func test_overtime_passive_energy_same_as_normal() -> void:
	# 加时被动与正常局一致（Eddy 回调：+1 能/回合·非此前口头的 +2）。
	var d := BattleCore.create_overtime(_hero("a", 5), _hero("x", 5), 42)
	d.select_action(0, A.CHARGE)
	d.select_action(1, A.CHARGE)
	d.resolve()
	assert_eq(d.energy[0], ActionDef.INITIAL_ENERGY + 4, "攒 +2 + 被动 +2（与正常局同）")
	assert_eq(d.energy[1], ActionDef.INITIAL_ENERGY + 4)


func test_overtime_duel_plays_to_victory() -> void:
	# 1v1 没有替补：出战阵亡 = 直接分胜负（无死亡换人）。
	var d := BattleCore.create_overtime(_hero("a", 5), _hero("x", 1), 42)   # x 仅 1HP=2 半点
	d.energy = [10, 10]
	d.select_action(0, A.ATTACK)
	d.select_action(1, A.CHARGE)
	d.resolve()
	assert_true(d.game_over, "1v1 击倒即终局")
	assert_eq(d.winner, BattleCore.WINNER_P1)
	assert_false(d.pending_death_switch[1], "无替补 → 不进死亡换人")


func test_overtime_roster_and_bench() -> void:
	# UI 场景重载路径：overtime_roster 组 3 人白板组（选中者 slot0）→ apply_overtime_bench 板凳置 0 血。
	var team: Array = [_hero("a", 4, "技"), _hero("b", 7, "技"), _hero("c", 5)]
	var r0: Array[HeroData] = BattleCore.overtime_roster(team, 1)
	assert_eq(r0[0].hero_name, "b", "选中者放 slot0")
	assert_eq(r0[0].hero_id, "", "白板化（无技能注册）")
	var b := BattleCore.new()
	b.setup(r0, BattleCore.overtime_roster(team, 0), 7)
	b.apply_overtime_bench()
	assert_eq(b.hp[0][0], 14, "出战满血（7HP=14 半点）")
	assert_eq(b.hp[0][1], 0, "板凳 0 血（同归余烬）")
	assert_eq(b.hp[0][2], 0)
	assert_eq(b.alive_count(0), 1, "唯一存活 = 出战位")


func test_overtime_sudden_death_higher_hp_wins() -> void:
	# 骤死裁决（2026-07-05）：打满 30 回合 → 同时扣血 → 高血者胜。
	var d := BattleCore.create_overtime(_hero("a", 5), _hero("x", 5), 42)
	d.hp[1][0] = 6   # P1 先失 2.0 血（10 → 6 半点）
	for _t in range(BattleCore.OVERTIME_TURN_CAP):
		d.select_action(0, A.CHARGE)
		d.select_action(1, A.CHARGE)
		d.resolve()
		if d.game_over:
			break
	assert_true(d.game_over, "打满 30 回合 → 骤死裁决终局")
	assert_eq(d.winner, BattleCore.WINNER_P1, "高血者胜")
	assert_eq(d.hp[0][0], 10 - 6, "P0 同时扣血 6 半点后余 4")
	assert_eq(d.hp[1][0], 0, "P1 扣至归零")


func test_overtime_sudden_death_equal_hp_true_draw() -> void:
	# 骤死裁决：等血同归 = 真平局。
	var d := BattleCore.create_overtime(_hero("a", 5), _hero("x", 5), 42)
	for _t in range(BattleCore.OVERTIME_TURN_CAP):
		d.select_action(0, A.CHARGE)
		d.select_action(1, A.CHARGE)
		d.resolve()
		if d.game_over:
			break
	assert_true(d.game_over, "打满 30 回合 → 骤死裁决终局")
	assert_eq(d.winner, BattleCore.WINNER_DRAW, "等血同归 = 真平")
	assert_eq(d.hp[0][0], 0)
	assert_eq(d.hp[1][0], 0)


func test_normal_battle_has_no_sudden_death() -> void:
	# 正常局（非加时）不触发骤死：龟 30+ 回合照常继续。
	var b := BattleCore.new()
	b.setup([_hero("a", 5)], [_hero("x", 5)], 42)
	for _t in range(BattleCore.OVERTIME_TURN_CAP + 2):
		b.select_action(0, A.CHARGE)
		b.select_action(1, A.CHARGE)
		b.resolve()
	assert_false(b.game_over, "非加时局无骤死裁决")
	assert_eq(b.hp[0][0], 10, "血量原封不动")


func test_choose_overtime_pick_takes_max_hp() -> void:
	# 白板 1v1 英雄差异只剩血量上限 → AI 选最大 HP（满血复活，故不看当前血量）。
	var b := BattleCore.new()
	b.setup([_hero("a", 4), _hero("b", 7), _hero("c", 5)],
		[_hero("x", 6), _hero("y", 3), _hero("z", 6)], 99)
	b.hp[0][1] = 0   # 最大 HP 英雄已阵亡也不妨碍（加时满血复活）
	assert_eq(BattleAI.choose_overtime_pick(b, 0), 1, "P0 选 7HP 的 b（阵亡也可选·满血复活）")
	assert_eq(BattleAI.choose_overtime_pick(b, 1), 0, "P1 血量并列取靠前的 x")


func test_overtime_sudden_death_emits_standard_events() -> void:
	# 审计修复（2026-07-17 三轮⑥）：骤死直写 HP 原本不发 damage_taken/hero_died——
	# UI 演出全靠这两个事件驱动（A3a）·缺了=血条突跳无掉血/死亡演出。
	var d := BattleCore.create_overtime(_hero("a", 5), _hero("x", 5), 42)
	d.hp[1][0] = 6   # P1 低血 → 骤死归零判负
	var last: Dictionary = {}
	for _t in range(BattleCore.OVERTIME_TURN_CAP):
		d.select_action(0, A.CHARGE)
		d.select_action(1, A.CHARGE)
		last = d.resolve()
		if d.game_over:
			break
	var dmg_n := 0
	var died_n := 0
	for ev in last.get("events", []):
		if String(ev.get("id", "")) == "damage_taken" and String(ev.get("src", "")) == "overtime":
			dmg_n += 1
		elif String(ev.get("id", "")) == "hero_died":
			died_n += 1
	assert_eq(dmg_n, 2, "骤死拍双方各一条 damage_taken（UI 掉血演出/飘字靠它）")
	assert_eq(died_n, 1, "归零方应发 hero_died（死亡演出靠它）")
