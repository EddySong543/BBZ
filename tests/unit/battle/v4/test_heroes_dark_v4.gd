extends GutTest

## ============================================================================
## 黑暗面英雄（h13 黑暗子鼠 / h14 黑暗丑牛 / h15 黑暗寅虎）技能测试 —— 锁定【当前代码行为】。
##
## h13【鼠潮】= 能量：在场(含替补)时，己方每触发一次 combo 效果 → 团队 +0.5 能（每回合封顶 1.5）。
## h14【卸力反震】= 防御：防/大防挡下 → 反弹所挡 50% 真伤给攻击者（机制迁自磐牛·on_block 触发）。
## h15【血勇】= 进攻：出战时无法用防/大防（can_afford gate·下场即解）+ 波穿防（attack_penetration）。
##
## 经济基线（半能制）：1 能=2 半能；波 2 半能 / 大波 6 半能 / 大防 4 半能；HP 半点制(1.0=2 半点)。
## ============================================================================


func _hero(id: String, hp: int = 5) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


## P0 slot0 = 被测英雄；其余 plain（无技能）。e = 双方起手半能。
func _battle(hero_id: String, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = [_hero(hero_id, hp), _hero("test_p1_1"), _hero("test_p1_2")]
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


## 自定义 P0 队伍（被测英雄在指定槽，便于测出战 / 替补差异）。
func _battle_team(p0_ids: Array, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = []
	for id in p0_ids:
		p1.append(_hero(id, hp))
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


# ---- h13 黑暗子鼠 鼠潮（在场时己方每触发 combo 效果 → 团队 +0.5 能·每回合封顶 1.5）----

func test_h13_shuchao_combo_proc_grants_team_energy() -> void:
	# 龙(破甲·on_deal_hit)出战 + 暗鼠在替补 → 龙波命中 = 1 次 combo proc → 团队 +0.5 能(1 半能)
	var with_rat := _battle_team(["h05", "h13", "test_p0_2"], 5, 8)
	with_rat.select_action(0, ActionDef.Action.ATTACK)
	with_rat.select_action(1, ActionDef.Action.CHARGE)
	with_rat.resolve()
	# 对照：同样龙波破甲，但替补无暗鼠 → 无鼠潮返还
	var no_rat := _battle_team(["h05", "test_p0_1", "test_p0_2"], 5, 8)
	no_rat.select_action(0, ActionDef.Action.ATTACK)
	no_rat.select_action(1, ActionDef.Action.CHARGE)
	no_rat.resolve()
	assert_eq(with_rat.energy[0] - no_rat.energy[0], 1, "暗鼠在场 + 1 次 combo proc → 团队多 +0.5 能(1 半能)")
	assert_eq(with_rat._shuchao_procs[0], 1, "本回合计入 1 次 combo proc")
	assert_eq(no_rat._shuchao_procs[0], 0, "无暗鼠 → 不计 proc、不产能")


func test_h13_shuchao_whiteboard_attack_grants_nothing() -> void:
	# 暗鼠出战白板波(无任何连携效果) → 不产能；与无暗鼠的纯白板对照能量相同
	var rat := _battle_team(["h13", "test_p0_1", "test_p0_2"], 4, 8)
	rat.select_action(0, ActionDef.Action.ATTACK)
	rat.select_action(1, ActionDef.Action.CHARGE)
	rat.resolve()
	var plain := _battle_team(["test_p0_0", "test_p0_1", "test_p0_2"], 4, 8)
	plain.select_action(0, ActionDef.Action.ATTACK)
	plain.select_action(1, ActionDef.Action.CHARGE)
	plain.resolve()
	assert_eq(rat.energy[0], plain.energy[0], "纯白板波无 combo proc → 鼠潮不产能")
	assert_eq(rat._shuchao_procs[0], 0, "白板波不计 combo proc")


func test_h13_shuchao_caps_per_turn() -> void:
	# 一回合 4 个 proc 事件（毒爆 + 易伤 + 鸡剑意×2[虎双段]）→ 鼠潮每回合封顶 3 次(1.5 能)
	var b := _battle_team(["h03", "h13", "h10"], 5, 8)   # 虎出战(hc=2) + 暗鼠替补 + 鸡替补
	b.set_status(1, 0, "poison", 1)   # 敌出战预置毒(待引爆)
	b.set_status(1, 0, "marked", 1)   # 敌出战预置易伤
	b.select_action(0, ActionDef.Action.ATTACK)   # 虎波
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b._shuchao_procs[0], 3, "4 个 proc 事件(毒爆/易伤/鸡剑意×2) → 鼠潮封顶 3 次")


# ---- h14 黑暗丑牛 卸力反震（防/大防挡下 → 反弹所挡 50% 真伤给攻击者·迁自磐牛）----

func test_h14_fanzhen_reflects_half_blocked_wave() -> void:
	# 暗牛(P0 HP6=12 半点)防住对手波 → 反弹 50%(挡波 raw=2 → 反 1 半点)给攻击者
	var b := _battle("h14", 6, 8)
	b.select_action(0, ActionDef.Action.DEFEND)
	b.select_action(1, ActionDef.Action.ATTACK)
	b.resolve()
	assert_eq(b.hp[0][0], 12, "暗牛防住波、无伤(HP6=12 半点)")
	assert_eq(b.hp[1][0], 10 - 1, "反弹所挡波 50% = 1 半点(0.5HP)真伤给攻击者(plain HP5=10半)")


func test_h14_fanzhen_no_reflect_when_not_blocking() -> void:
	# 暗牛不防(挨打) → 不反弹
	var b := _battle("h14", 6, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "暗牛没防 → 无反弹、攻击者满血")
	assert_eq(b.hp[0][0], 12 - 2, "暗牛挨波 2 半点")


# ---- h15 黑暗寅虎 血勇（出战不能防御 + 波穿防）----

func test_h15_xueyong_cannot_defend() -> void:
	var b := _battle("h15", 7, 8)   # 暗虎出战；8 半能（够大防/大波）
	assert_false(b.can_afford(0, ActionDef.Action.DEFEND), "血勇：防不合法")
	assert_false(b.can_afford(0, ActionDef.Action.BIG_DEFEND), "血勇：大防不合法")
	assert_false(b.select_action(0, ActionDef.Action.DEFEND), "血勇：选防被拒")
	var acts: Array = []
	for c in b.legal_actions(0):
		acts.append(int(c["action"]))
	assert_does_not_have(acts, ActionDef.Action.DEFEND, "legal_actions 不含防")
	assert_does_not_have(acts, ActionDef.Action.BIG_DEFEND, "legal_actions 不含大防")
	assert_true(b.can_afford(0, ActionDef.Action.ATTACK), "血勇：波仍合法")
	assert_true(b.can_afford(0, ActionDef.Action.BIG_ATTACK), "血勇：大波仍合法")


func test_h15_xueyong_only_disables_while_active() -> void:
	# 暗虎在替补(slot1)、出战是 plain → 出战队友能正常防（下场即恢复）
	var b := _battle_team(["test_p0_0", "h15", "test_p0_2"], 5, 8)
	assert_true(b.can_afford(0, ActionDef.Action.DEFEND), "暗虎在替补 → 出战队友能防")
	assert_true(b.can_afford(0, ActionDef.Action.BIG_DEFEND), "暗虎在替补 → 出战队友能大防")


func test_h15_xueyong_wave_pierces_defend() -> void:
	# 暗虎(P0)波 vs plain(P1)防 → 穿防，plain 仍吃 2 半点
	var b := _battle("h15", 7, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "血勇波穿防：plain 出防仍吃 2 半点(1.0 HP)")


func test_h15_xueyong_wave_blocked_by_big_defend() -> void:
	# 大防仍挡得下血勇波（穿防只穿到大防为止）
	var b := _battle("h15", 7, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "血勇波被大防挡下：plain 无伤")
