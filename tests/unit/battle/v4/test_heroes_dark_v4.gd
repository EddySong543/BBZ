extends GutTest

## ============================================================================
## 黑暗面英雄（h13 玄冥 / h14 蚩尤 / h15 穷奇）技能测试 —— 锁定【当前代码行为】。
##
## h13【鼠潮】= 能量：在场(含替补)时，我方每触发一次 combo 效果 → 团队 +0.5 能（无封顶·2026-07-01 去刹车）。
## h14【卸力反震】= 防御：防/大防挡下 → 反弹所挡 50% 真伤给攻击者（机制迁自磐牛·on_block 触发）。
## h15【血勇】= 进攻：出战时无法用防/大防（can_afford gate·下场即解）+ 波穿防（attack_penetration）。
## h16【疾风】= 节奏：在场(含替补)时，己方每局 2 次可把同一动作再做一次（波/大波/攒·技能/切换/防除外）。
## h17【镇压】= 干扰·主动技：占动作+费2能+每局2次，沉默对手出战英雄 unique 2 回合（下回合起算）。
## h18【缠绕】= 状态：出战时，对手无法主动切换（含星日免费切换）；死亡换人不受影响。
## h19【践踏】= 进攻：攻击命中时，这一击超过 1.0HP 的溢出部分碾到敌方随机替补（无封顶）。
## h20【罪已昭】= 状态·被动：命中敌方出战附「易伤印」(vuln)，被印英雄受伤 +0.5，直到换下场（换下清）。
## h21【调虎离山】= 干扰·主动技：占动作+费2能+每局2次+须出战，强制对手换人、揪其存活替补中血量最低者上场。
## h23【护主】= 防御：替补席存活时，我方英雄受致命伤害 → 天狗顶替登场承受这一击、原 carry 退替补获救（每局一次·天狗可能吃死）。
## h24【饕餮】= 能量：在场(含替补)时，战场任一英雄阵亡(敌我皆可) → 你方团队 +2.0 能（4 半能）。
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


# ---- h13 玄冥 鼠潮（在场时己方每触发 combo 效果 → 团队 +0.5 能·每回合封顶 1.5）----

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


func test_h13_shuchao_no_cap_per_turn() -> void:
	# 一回合 4 个 proc 事件（毒爆 + 易伤 + 鸡剑意×2[虎双段]）→ 无封顶 → 4 次全计入(2.0 能)
	var b := _battle_team(["h03", "h13", "h10"], 5, 8)   # 虎出战(hc=2) + 暗鼠替补 + 鸡替补
	b.set_status(1, 0, "poison", 1)   # 敌出战预置毒(待引爆)
	b.set_status(1, 0, "marked", 1)   # 敌出战预置易伤
	b.select_action(0, ActionDef.Action.ATTACK)   # 虎波
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b._shuchao_procs[0], 4, "4 个 proc 事件(毒爆/易伤/鸡剑意×2) → 无封顶·全计 4 次(旧封顶 3)")


# ---- h14 蚩尤 卸力反震（防/大防挡下 → 反弹所挡 50% 真伤给攻击者·迁自磐牛）----

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


# ---- h15 穷奇 血勇（出战不能防御 + 波穿防）----

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


# ---- h16 广寒 疾风（每局 2 次把同一动作再做一次·波/大波/攒·技能/切换/防除外）----

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
	# 暗兔攒 + 附加 → 攒两次(+2+2)·被动已去除 → 8→12
	var b := _battle("h16", 4, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_double(0, true)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.energy[0], 12, "双攒：+2 +2 = +4 半能·被动已去除(8→12)")


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


# ---- h17 烛阴【镇压】(主动技·沉默对手出战 unique 2 回合·2026-06-24 重设计) ----

## 自定义双队对局（P0 队 + P1 队），便于测"沉默对手指定英雄"。
func _battle_vs(p0_ids: Array, p1_ids: Array, hp: int = 6, e: int = 8) -> BattleCore:
	var t0: Array = []
	for id in p0_ids:
		t0.append(_hero(id, hp))
	var t1: Array = []
	for id in p1_ids:
		t1.append(_hero(id, hp))
	var b := BattleCore.new()
	b.setup(t0, t1, 555)
	b.energy = [e, e]
	return b


func test_h17_zhenya_silences_enemy_passive() -> void:
	# 暗龙(P0)镇压 → 沉默 P1 出战的虚日。cast 当回合虚日仍生效，【下回合起】囤鼠加成失效。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h01", "test_p1_1", "test_p1_2"], 6, 8)
	# 回合1：P0 镇压(费2能=4半能)、P1 攒(虚日未沉默 → +3：攒2+囤鼠1)
	assert_true(b.select_active(0), "暗龙可发动镇压(敌出战存活)")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "silenced", 0)), 2, "P1 虚日被烙沉默=2 回合")
	assert_eq(b.energy[0], 8 - 4, "镇压费 2 能(4 半能)")
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 1, "镇压计 1 次使用")
	assert_eq(b.energy[1], 8 + 3, "cast 当回合虚日仍生效：攒+2 +囤鼠+1 = +3")
	# 回合2：双攒 → 虚日已沉默 → P1 只 +2(囤鼠失效)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.energy[1], 11 + 2, "虚日被沉默：攒只 +2、囤鼠加成失效")
	assert_eq(int(b.get_status(1, 0, "silenced", 0)), 1, "沉默递减 → 剩 1 回合")


func test_h17_zhenya_silence_expires_after_two_turns() -> void:
	# 沉默恰好 2 个完整回合(回合2、3)，回合4 囤鼠恢复。起手 4 能(避开 MAX_ENERGY=20 截顶)。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h01", "test_p1_1", "test_p1_2"], 6, 4)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()                                   # 回合1：cast(虚日仍生效 +3)
	for _t in range(2):                           # 回合2、3：沉默中，各 +2
		b.select_action(0, ActionDef.Action.CHARGE)
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
	assert_eq(int(b.get_status(1, 0, "silenced", 0)), 0, "2 回合后沉默到期")
	var before: int = b.energy[1]
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()                                   # 回合4：虚日恢复 → +3
	assert_eq(b.energy[1] - before, 3, "沉默到期 → 囤鼠恢复，攒 +3")


func test_h17_zhenya_disables_enemy_active_and_caps() -> void:
	# ① 被沉默英雄的主动技不可用 ② 镇压每局上限 2 次。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h21", "test_p1_1", "test_p1_2"], 6, 20)
	b.select_active(0)                            # 回合1：镇压沉默 P1 暗猴(h21 调虎离山)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_false(b.can_use_active(1), "被沉默的暗猴：调虎离山主动技不可用")
	# 上限：回合2 再镇压 → 第3次应被拒(cap=2)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 2, "镇压已用 2 次")
	assert_false(b.can_use_active(0), "镇压每局上限 2 → 第 3 次不可用")


# ---- h18 相柳 缠绕（出战时对手无法主动切换；死亡换人不受影响）----

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
	# P0 出战星日(有免费切换) + P1 出战暗蛇 → 星日的免费切换也被缠绕锁住
	var p1: Array = [_hero("h07", 5), _hero("test_a", 5), _hero("test_b", 5)]
	var p2: Array = [_hero("h18", 4), _hero("test_c", 5), _hero("test_d", 5)]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [8, 8]
	assert_false(b.is_free_switch_target(0, 1), "P1 暗蛇缠绕 → P0 星日免费切换被锁")
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


# ---- h19 乌骓 践踏（攻击溢出 1.0HP 的部分碾到最高血替补）----

func test_h19_jianta_overflow_tramples_reserve() -> void:
	# 大波(4半=2.0HP)命中 → 溢出(4−2=2半)碾到随机一名存活替补(全额·无封顶)
	var b := _battle("h19", 5, 12)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "大波 4 半点命中出战")
	# 溢出 2 半点落到随机一名替补：两替补总血 -2、且恰一人被踏
	assert_eq(b.hp[1][1] + b.hp[1][2], 20 - 2, "溢出 2 半点碾到随机替补(总血 -2)")
	assert_true((b.hp[1][1] == 8 and b.hp[1][2] == 10) or (b.hp[1][1] == 10 and b.hp[1][2] == 8), "恰一名替补被踏 2 半点")


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


# ---- h20 触邪 罪已昭（持续易伤：命中敌方出战附印·被印受伤 +0.5·换下场清）----

func test_h20_zuiyizhao_marks_and_amplifies() -> void:
	# 触邪波命中敌方出战 → 附易伤印；此后对该目标的攻击 +0.5(1 半点)
	var b := _battle("h20", 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)   # 触邪波命中 → 附印（附印那击不放大自己）
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "首击 2 半点·未放大")
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 1, "敌方出战已附易伤印")
	# 第二回合再波 → 这次受易伤放大 +0.5：2 + 1 = 3 半点
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 8 - 3, "被印后受伤 +0.5 → 波打 3 半点")


func test_h20_zuiyizhao_amplifies_any_attacker() -> void:
	# 易伤对全队生效：直接给敌方出战附印，普通英雄的波也 +0.5
	var b := _battle("test_p0_0", 5, 8)
	b.set_status(1, 0, "vuln", 1)                 # 手动附易伤印
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 3, "被印目标受任意攻击 +0.5 → 波打 3 半点")


func test_h20_zuiyizhao_cleared_on_switch_out() -> void:
	# 被印敌方英雄换下场 → 易伤印清除（换回来需重新烙）
	var b := _battle("h20", 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)   # 触邪命中 P1 出战 → 附印
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 1, "P1 出战已附印")
	b._perform_switch(1, 0, 1, [])                # 模拟 P1 把 slot0 换下
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 0, "换下场 → 易伤印清除")


# ---- h21 枭阳 调虎离山（主动技·强制对手换人·揪存活替补血量最低者）----

func test_h21_diaohu_pulls_lowest_hp_reserve() -> void:
	# 暗猴(P0 出战) vs P1 出战 + 2 替补(slot1 残血=揪目标 / slot2 高血)。猴调虎离山 → P1 被强制揪上 slot1。
	var b := _battle_vs(["h21", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	b.hp[1][1] = 2   # P1 slot1 残血（脆皮 carry）
	b.hp[1][2] = 8   # P1 slot2 高血
	assert_true(b.select_active(0), "暗猴可调虎离山（敌有存活替补）")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[1], 1, "对手被强制揪上血量最低的替补（slot1）")
	assert_eq(b.energy[0], 8 - 4, "调虎离山费 2 能（4 半能）")
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 1, "计 1 次使用")


func test_h21_diaohu_requires_enemy_reserve() -> void:
	# 对手只剩出战（替补全死）→ 无人可揪 → 主动技不可用
	var b := _battle_vs(["h21", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	b.hp[1][1] = 0
	b.hp[1][2] = 0
	assert_false(b.can_use_active(0), "对手无存活替补 → 调虎离山不可用")


func test_h21_diaohu_caps_two_per_game() -> void:
	# 每局上限 2 次（对手始终 3 满血 → 总有替补可揪）
	var b := _battle_vs(["h21", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 20)
	for _i in range(2):
		assert_true(b.select_active(0), "前 2 次可调虎离山")
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 2, "已用满 2 次")
	assert_false(b.can_use_active(0), "每局上限 2 → 第 3 次不可用")


# ---- h23 天狗 护主（替补狗替死·完全免除·carry 留前线·每局一次）----

func test_h23_huzhu_protects_carry_by_swapping_in() -> void:
	# P0 出战 carry 残血(1.0HP=2半) + 替补天狗(slot1 满血10半)。对手大波致死 →
	#   天狗立刻登场顶替、carry 退居替补获救、这一击改落天狗(10-4=6·天狗吃住没死)。
	var b := _battle_team(["test_p0_0", "h23", "test_p0_2"], 5, 12)
	b.hp[0][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)   # 大波 4 半点 ≥ 2 → 致死
	b.resolve()
	assert_eq(b.hp[0][0], 2, "carry 获救·退居替补·血量不变")
	assert_eq(b.active_index[0], 1, "天狗顶替登场为出战")
	assert_eq(b.hp[0][1], 10 - 4, "这一击改落天狗(10-4=6·天狗吃住没死)")
	assert_eq(int(b.get_status(0, 1, "huzhu_uses", 0)), 1, "护主计 1 次")


func test_h23_huzhu_once_per_game() -> void:
	# 天狗只顶替一次：首次致死 → 天狗登场救 carry；此后天狗已在场·护主用尽 → 天狗自己被打死无人再救
	var b := _battle_team(["test_p0_0", "h23", "test_p0_2"], 5, 20)
	b.hp[0][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()   # 首次：天狗顶替登场·carry 获救
	assert_eq(b.active_index[0], 1, "首次：天狗顶替登场")
	assert_eq(b.hp[0][0], 2, "首次：carry 获救退替补")
	assert_eq(b.hp[0][1], 10 - 4, "首次：天狗吃这下(6)")
	# 再连打天狗至致死 → 护主已用尽·无人顶替 → 天狗死、carry 始终安全
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()   # 天狗 6-4=2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()   # 天狗 2-4 → 死·无二次顶替
	assert_true(b.hp[0][1] <= 0, "护主只一次 → 天狗自己被致死不再有人顶替")
	assert_eq(b.hp[0][0], 2, "carry 始终安全在替补")


func test_h23_huzhu_not_lethal_no_trigger() -> void:
	# 非致命伤害 → 不触发护主（天狗不登场）
	var b := _battle_team(["test_p0_0", "h23", "test_p0_2"], 5, 12)
	# carry 满血(10)，挨一记波(2 半点)非致命
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)
	b.resolve()
	assert_eq(b.hp[0][0], 10 - 2, "非致命 → carry 正常吃伤")
	assert_eq(b.active_index[0], 0, "未触发 → carry 仍出战")
	assert_eq(b.hp[0][1], 10, "护主未触发（天狗仍在替补·满血）")
	assert_eq(int(b.get_status(0, 1, "huzhu_uses", 0)), 0, "护主未计数")


# ---- h24 并封 饕餮（任一英雄阵亡敌我皆可 → 团队 +2.0 能）----

func test_h24_taotie_feasts_on_ally_death() -> void:
	# P0 出战 carry 残血 + 替补暗猪。对手致死 carry → P0 团队 +2.0 能（对照无猪）。
	var b := _battle_team(["test_p0_0", "h24", "test_p0_2"], 5, 8)
	b.hp[0][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()
	var nb := _battle_team(["test_p0_0", "test_p0_1", "test_p0_2"], 5, 8)
	nb.hp[0][0] = 2
	nb.select_action(0, ActionDef.Action.CHARGE)
	nb.select_action(1, ActionDef.Action.BIG_ATTACK)
	nb.resolve()
	assert_true(b.hp[0][0] <= 0, "carry 被大波致死")
	assert_eq(b.energy[0] - nb.energy[0], 4, "暗猪在场 → 队友阵亡喂 +2.0 能（4 半能）")


func test_h24_taotie_feasts_on_enemy_death() -> void:
	# 敌方英雄阵亡也喂猪：暗猪波打死 P1 残血出战 → P0 +2.0 能（敌我皆吃）。
	var b := _battle_vs(["h24", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	b.hp[1][0] = 2
	var ctrl := _battle_vs(["test_p0_0", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	ctrl.hp[1][0] = 2
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	ctrl.select_action(0, ActionDef.Action.ATTACK)
	ctrl.select_action(1, ActionDef.Action.CHARGE)
	ctrl.resolve()
	assert_true(b.hp[1][0] <= 0, "P1 出战被波打死")
	assert_eq(b.energy[0] - ctrl.energy[0], 4, "敌方阵亡也喂暗猪 +2.0 能（4 半能）")


# ---- h22 毕方 一鸣惊人（空过存行动 → 之后双动作释放·净零 tempo）----

func test_h22_yiming_store_then_release_double_wave() -> void:
	# 回合1 空过(存行动·不拿能量)；回合2 波+释放 → 敌吃两次波(2×2=4 半点)，消耗 1 次存储。
	var b := _battle_team(["h22", "test_p0_1", "test_p0_2"], 4, 8)
	assert_true(b.can_store(0), "在场暗鸡 → 可空过存行动")
	var e_before: int = b.energy[0]
	assert_true(b.select_action(0, ActionDef.STORE), "选空过")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.stored_action[0], 1, "存储 +1")
	assert_eq(b.energy[0], e_before, "空过不拿能量、不花能量（能量不变）")
	assert_true(b.can_double_action(0, ActionDef.Action.ATTACK), "有存储 → 波可双")
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_double(0, true)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "释放双波：敌吃 2×2=4 半点（2.0HP）")
	assert_eq(b.stored_action[0], 0, "释放消耗 1 次存储")


func test_h22_yiming_requires_chicken() -> void:
	# 队中无暗鸡 → 不能空过存行动
	var b := _battle_team(["test_p0_0", "test_p0_1", "test_p0_2"], 4, 8)
	assert_false(b.can_store(0), "无暗鸡 → 不可空过")
	assert_false(b.select_action(0, ActionDef.STORE), "选空过被拒")


func test_h22_yiming_store_caps_at_limit() -> void:
	# 存储封顶 STORED_CAP=2
	var b := _battle_team(["h22", "test_p0_1", "test_p0_2"], 4, 20)
	for _i in range(2):
		b.select_action(0, ActionDef.STORE)
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
	assert_eq(b.stored_action[0], 2, "存满 2")
	assert_false(b.can_store(0), "存储已满 → 不能再空过")


func test_h22_yiming_works_from_reserve() -> void:
	# 暗鸡在替补、出战 plain → 仍可空过 + 释放（在场含替补）
	var b := _battle_team(["test_p0_0", "h22", "test_p0_2"], 4, 8)
	assert_true(b.can_store(0), "暗鸡在替补 → 仍可空过")
	b.select_action(0, ActionDef.STORE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.stored_action[0], 1, "替补暗鸡也能存")
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_double(0, true)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "释放双波 4 半点")


func test_h22_yiming_ai_legal_actions_and_apply_choice() -> void:
	# AI 路径：legal_actions 含 STORE；apply_choice STORE → 存行动；之后 double=true 释放双波。
	var b := _battle_team(["h22", "test_p0_1", "test_p0_2"], 4, 8)
	var acts: Array = []
	for c in b.legal_actions(0):
		acts.append(int(c["action"]))
	assert_has(acts, ActionDef.STORE, "legal_actions 含空过(STORE)")
	assert_true(b.apply_choice(0, {action = ActionDef.STORE, target = -1}), "apply_choice 空过")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.stored_action[0], 1, "apply_choice STORE → 存 +1")
	assert_true(b.apply_choice(0, {action = ActionDef.Action.ATTACK, target = -1, double = true}), "apply_choice 波+释放")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "AI 释放双波 4 半点")
	assert_eq(b.stored_action[0], 0, "消耗存储")
