extends GutTest

## ============================================================================
## 黑暗面英雄（h13 黑暗子鼠 / h14 黑暗丑牛 / h15 黑暗寅虎）技能测试 —— 锁定【当前代码行为】。
##
## h13【鼠潮】= 能量：在场(含替补)时，己方每触发一次 combo 效果 → 团队 +0.5 能（每回合封顶 1.5）。
## h14【卸力反震】= 防御：防/大防挡下 → 反弹所挡 50% 真伤给攻击者（机制迁自磐牛·on_block 触发）。
## h15【血勇】= 进攻：出战时无法用防/大防（can_afford gate·下场即解）+ 波穿防（attack_penetration）。
## h16【疾风】= 节奏：在场(含替补)时，己方每局 2 次可把同一动作再做一次（波/大波/攒·技能/切换/防除外）。
## h17【逼战】= 干扰：出战时，对手本回合若不攻击它，则失去本回合被动 +1 能。
## h18【缠绕】= 状态：出战时，对手无法主动切换（含午马免费切换）；死亡换人不受影响。
## h19【践踏】= 进攻：攻击命中时，这一击超过 1.0HP 的溢出部分碾到敌方最高血替补（封顶 1.0）。
## h20【圣剑·断罪】= 状态·主动技：烙「断罪印」，印记目标出战血量 ≤1.0HP 即斩杀（处决）。
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


# ---- h16 黑暗卯兔 疾风（每局 2 次把同一动作再做一次·波/大波/攒·技能/切换/防除外）----

func test_h16_jifeng_double_wave_hits_twice() -> void:
	# 暗兔(P0)波 + 附加 → 敌出战吃两次波(2×2=4 半点)；消耗 1 次疾风
	var b := _battle("h16", 4, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	assert_true(b.can_double(0), "波可附加(在场暗兔 + 能量够双份)")
	b.select_double(0, true)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "双波：敌吃 2×2=4 半点(2.0HP)")
	assert_eq(int(b.get_status(0, 0, "jifeng_uses", 0)), 1, "消耗 1 次疾风")


func test_h16_jifeng_double_charge_doubles_gain() -> void:
	# 暗兔攒 + 附加 → 攒两次(+2+2)，外加被动 +2 → 8→14
	var b := _battle("h16", 4, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_double(0, true)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.energy[0], 14, "双攒：+2 +2 + 被动 +2 = +6 半能(8→14)")


func test_h16_jifeng_cap_two_per_game() -> void:
	# 每局上限 2 次：第 3 次不可附加
	var b := _battle("h16", 4, 20)
	for i in range(2):
		b.select_action(0, ActionDef.Action.CHARGE)
		assert_true(b.select_double(0, true), "前 2 次可附加")
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
	assert_eq(int(b.get_status(0, 0, "jifeng_uses", 0)), 2, "已用满 2 次")
	b.select_action(0, ActionDef.Action.CHARGE)
	assert_false(b.can_double(0), "第 3 次：cap 满 → 不可附加")
	assert_false(b.select_double(0, true), "第 3 次附加被拒")


func test_h16_jifeng_requires_dark_rabbit() -> void:
	# 队中无暗兔 → 不可附加
	var b := _battle("test_p0_0", 4, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	assert_false(b.can_double(0), "无暗兔 → 波不可附加")


func test_h16_jifeng_defend_doubleable_switch_excluded() -> void:
	# 防可附加(Eddy"防也算上"·虽二元挡无额外效果)；切换不可附加
	var b := _battle("h16", 4, 8)
	b.select_action(0, ActionDef.Action.DEFEND)
	assert_true(b.can_double(0), "防可附加(防也算上)")
	var b2 := _battle_team(["h16", "test_p1_1", "test_p1_2"], 4, 8)
	b2.select_switch(0, 1)
	assert_false(b2.can_double(0), "切换不可附加")


func test_h16_jifeng_apply_choice_double() -> void:
	# AI 路径：apply_choice 带 double=true → 内部 select_double → 双波
	var b := _battle("h16", 4, 8)
	b.apply_choice(0, {action = ActionDef.Action.ATTACK, target = -1, double = true})
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "apply_choice double=true → 双波 4 半点")
	assert_eq(int(b.get_status(0, 0, "jifeng_uses", 0)), 1, "消耗 1 次疾风")


func test_h16_jifeng_works_from_reserve() -> void:
	# 暗兔在替补、出战是 plain → 仍可附加（在场含替补·cap 计在暗兔身上）
	var b := _battle_team(["test_p0_0", "h16", "test_p0_2"], 4, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	assert_true(b.can_double(0), "暗兔在替补 → 出战队友仍可附加")
	b.select_double(0, true)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "双波 4 半点")
	assert_eq(int(b.get_status(0, 1, "jifeng_uses", 0)), 1, "cap 计在暗兔(替补 slot1)")


# ---- h17 黑暗辰龙 逼战（出战时对手本回合不攻击它 → 失去被动 +1 能）----

func test_h17_bizhan_starves_non_attacker() -> void:
	# 暗龙(P0 出战) vs P1；P1 攒(不攻龙) → P1 失去本回合被动 +2 半能
	var b := _battle_team(["h17", "test_p0_1", "test_p0_2"], 6, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)   # P1 攒·没攻击龙
	b.resolve()
	assert_eq(b.energy[1], 8 + 2, "P1 攒(不攻龙) → 只得攒 +2、被动被逼战吞掉(8→10)")


func test_h17_bizhan_attacker_keeps_passive() -> void:
	# P1 攻击龙(波) → 保留被动 +1 能
	var b := _battle_team(["h17", "test_p0_1", "test_p0_2"], 6, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)   # P1 攻龙
	b.resolve()
	assert_eq(b.energy[1], 8 - 2 + 2, "P1 攻龙 → 付波费 2、保留被动 +2(8→8)")
	assert_eq(b.hp[0][0], 12 - 2, "暗龙(HP6=12半)挨 P1 波 2 半点")


func test_h17_bizhan_only_while_active() -> void:
	# 暗龙在替补、出战是 plain → 无逼战（对手不攻也不挨饿·下场即解）
	var b := _battle_team(["test_p0_0", "h17", "test_p0_2"], 6, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.energy[1], 8 + 2 + 2, "暗龙在替补 → 无逼战、P1 正常得攒+被动(8→12)")


# ---- h18 黑暗巳蛇 缠绕（出战时对手无法主动切换；死亡换人不受影响）----

func test_h18_chanrao_locks_enemy_switch() -> void:
	# 暗蛇(P0 出战) → P1 无法主动切换；暗蛇自己一方不受影响
	var b := _battle("h18", 4, 8)
	assert_false(b.can_afford(1, ActionDef.Action.SWITCH), "对手出战是暗蛇 → P1 切换不合法")
	assert_false(b.select_switch(1, 1), "P1 主动切换被拒")
	var has_switch := false
	for c in b.legal_actions(1):
		if int(c["action"]) == ActionDef.Action.SWITCH:
			has_switch = true
	assert_false(has_switch, "P1 legal_actions 不含切换")
	assert_true(b.can_afford(0, ActionDef.Action.SWITCH), "暗蛇自己一方不受缠绕、正常能切")


func test_h18_chanrao_only_while_active() -> void:
	# 暗蛇在 P0 替补、出战是 plain → P1 不被缠（能切）
	var b := _battle_team(["test_p0_0", "h18", "test_p0_2"], 4, 8)
	assert_true(b.can_afford(1, ActionDef.Action.SWITCH), "暗蛇在替补 → P1 能切换")


func test_h18_chanrao_locks_free_switch() -> void:
	# P0 出战午马(有免费切换) + P1 出战暗蛇 → 午马的免费切换也被缠绕锁住
	var p1: Array = [_hero("h07", 5), _hero("test_a", 5), _hero("test_b", 5)]
	var p2: Array = [_hero("h18", 4), _hero("test_c", 5), _hero("test_d", 5)]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [8, 8]
	assert_false(b.is_free_switch_target(0, 1), "P1 暗蛇缠绕 → P0 午马免费切换被锁")
	assert_false(b.can_afford(0, ActionDef.Action.SWITCH), "P0 普通切换也被锁")


func test_h18_chanrao_allows_death_switch() -> void:
	# 缠绕只锁【主动】切换；死亡换人（强制补位）不受影响
	var p1: Array = [_hero("test_a", 5), _hero("test_b", 5), _hero("test_c", 5)]
	var p2: Array = [_hero("h18", 4), _hero("test_d", 5), _hero("test_e", 5)]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.hp[0][0] = 0                      # P0 出战阵亡
	b.pending_death_switch[0] = true
	assert_true(b.execute_death_switch(0, 1), "缠绕下死亡换人仍可执行（强制补位不受锁）")
	assert_eq(b.active_index[0], 1, "已补位")


# ---- h19 黑暗午马 践踏（攻击溢出 1.0HP 的部分碾到最高血替补）----

func test_h19_jianta_overflow_tramples_reserve() -> void:
	# 午马大波(4半=2.0HP)命中 → 溢出(4−2=2半)碾到最高血替补
	var b := _battle("h19", 5, 12)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "大波 4 半点命中出战")
	assert_eq(b.hp[1][1], 10 - 2, "溢出 2 半点(1.0HP)踏到最高血替补(slot1)")
	assert_eq(b.hp[1][2], 10, "另一替补未受影响")


func test_h19_jianta_normal_wave_no_trample() -> void:
	# 波(2半=1.0HP)不溢出 → 替补不受踏
	var b := _battle("h19", 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "波 2 半点命中出战")
	assert_eq(b.hp[1][1], 10, "波不溢出(1.0≤1.0) → 替补不受踏")


func test_h19_jianta_blocked_no_trample() -> void:
	# 大防挡下大波(dealt=0) → on_deal_hit 不触发 → 不踏
	var b := _battle("h19", 5, 12)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "大防挡下大波·出战无伤")
	assert_eq(b.hp[1][1], 10, "被挡 → 替补不受踏")


# ---- h20 黑暗未羊 圣剑·断罪（主动技烙印·印记目标出战血量≤1.0HP 即处决）----

func test_h20_duanzui_executes_marked_low_hp() -> void:
	# 暗羊用断罪标记 P1 出战(残血 1.0HP=2半·≤阈值) → 同回合处决
	var b := _battle("h20", 5, 8)
	b.hp[1][0] = 2
	assert_true(b.select_active(0), "断罪主动技可用(费2能·cap)")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.hp[1][0] <= 0, "印记目标血量≤阈值(2半) → 被断罪处决")


func test_h20_duanzui_spares_above_threshold() -> void:
	# 印记目标血量 > 阈值 → 不处决、印记悬着
	var b := _battle("h20", 5, 8)
	b.hp[1][0] = 3   # 1.5HP·>阈值2
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 3, "血量>阈值 → 不处决")
	assert_eq(int(b.get_status(1, 0, "duanzui", 0)), 1, "断罪印已烙上、悬着")


func test_h20_duanzui_no_mark_no_execute() -> void:
	# 没烙印记 → 残血也不处决
	var b := _battle("h20", 5, 8)
	b.hp[1][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)   # 暗羊不用断罪
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 2, "没断罪印 → 残血也不处决")
