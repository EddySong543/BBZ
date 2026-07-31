extends GutTest

## ============================================================================
## 黑暗面英雄（h13 玄冥 / h14 蚩尤 / h15 穷奇）技能测试 —— 锁定【当前代码行为】。
##
## h13【鼠潮】= 能量：在场(含替补)时，我方每触发一次 combo 效果 → 团队 +0.5 能（无封顶·2026-07-01 去刹车）。
## h14【卸力反震】= 防御：防/大防挡下 → 反弹所挡 50% 真伤给攻击者（批③起走管线打击=喂剑气/引爆毒·on_block 触发）。
## h15【血勇】= 进攻：出战时无法用防/大防（can_afford gate·下场即解）+ 波穿防（attack_penetration）。
## h16【疾风】= 节奏：出战时，己方每局 2 次可把同一动作再做一次（波/大波/攒·技能/切换/防除外·2026-07-02 由在场收缩为出战）。
## h17【阖眸成夜】= 干扰·主动技：占动作+费1能+每局2次，下回合敌方能量冻结（usable_energy=0·只锁花不锁收·2026-07-05 重设计 B 案·沉默两连败弃）。
## h18【缠绕】= 状态：出战时，对手无法主动切换（含星日免费切换）+ 对手防不再免费(+1 能·批③ J 案)；死亡换人不受影响。HP 4→5(批③)→6(批⑧ 数值补贴)。
## h19【践踏】= 进攻：攻击命中时，这一击超过 1.0HP 的溢出部分碾到敌方随机替补（无封顶）。
## h20【罪已昭】= 状态·被动：命中敌方出战附「易伤印」(vuln)，被印英雄受伤 +0.5，直到换下场（换下清）。
## h21【调虎离山】= 干扰·主动技：占动作+费1能（批④降费·原2能）+每局2次+须出战，强制对手换人、揪其指定（未指定→随机）存活替补上场。
## h22【焚天火兆】= 节奏·主动技：占动作+免费(批③由1能降)+每局2次，蓄力（当拍无伤·+1.0 护盾）→ 下回合毕方本人的攻击穿大防（窗口恰1回合·2026-07-04 重做）。
## h23【护主】= 防御：替补席存活时，我方英雄受致命伤害 → 天狗顶替登场+1.0 护盾垫伤、承受这一击+反击攻击者 1.0 伤害(批③·普通档)、原 carry 退替补获救（每局两次·批③ 1→2·天狗可能吃死）。
## h24【饕餮】= 能量：在场(含替补)时，战场任一英雄阵亡(敌我皆可) → 你方团队 +2.0 能（4 半能）+ 并封自己回 1.0 生命（2026-07-04 双头分食·封顶 max_hp）。
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
func _resolve(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


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
	# 一回合 4 个 proc 事件（毒爆 + 易伤 + 龙破甲 + 鸡剑意）→ 无封顶 → 4 次全计入(2.0 能)
	var b := _battle_team(["h05", "h13", "h10"], 5, 8)   # 龙出战 + 暗鼠替补 + 鸡替补
	b.set_status(1, 0, "poison", 1)   # 敌出战预置毒(待引爆)
	b.set_status(1, 0, "marked", 1)   # 敌出战预置易伤
	b.select_action(0, ActionDef.Action.ATTACK)   # 龙波
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b._shuchao_procs[0], 4, "4 个 proc 事件(毒爆/易伤/龙破甲/鸡剑意) → 无封顶·全计 4 次(旧封顶 3)")


# ---- h14 蚩尤 卸力反震（防/大防挡下 → 反弹所挡 50% 真伤·批③起走管线打击喂原语）----

func test_h14_fanzhen_reflect_feeds_onhit_primitives() -> void:
	# 批③(Eddy 批 B 案)：反弹走完整 on-hit 管线——反震命中=我方攻击命中 → 替补鸡攒剑气。
	var b := _battle_team(["h14", "h10", "test_p0_2"], 6, 8)
	b.select_action(0, ActionDef.Action.DEFEND)
	b.select_action(1, ActionDef.Action.ATTACK)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 1, "反震 1 半点真伤落地(plain HP5=10半)")
	assert_eq(int(b.get_status(0, 1, "jianqi", 0)), 1, "反震喂原语：鸡(替补)攒 1 层剑气(批③)")


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
	assert_eq(b.energy[0], 14, "双攒：+2 +2 + 被动 +2 = +6 半能(8→14·被动不随双动作翻倍)")


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


func test_h16_jifeng_inactive_from_reserve() -> void:
	# 暗兔在替补、出战是 plain → 不可附加（2026-07-02 出战限定·不再躲替补给队友加倍）
	var b := _battle_team(["test_p0_0", "h16", "test_p0_2"], 4, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	assert_false(b.can_double(0), "暗兔在替补 → 出战队友不可附加（出战限定）")
	assert_false(b.has_double(0), "无出战暗兔 → 无双动作")


# ---- h17 烛阴【阖眸成夜】(主动技·下回合敌方不能重复本回合动作·2026-07-06 四改 B 案·弃冻结) ----

## 自定义双队对局（P0 队 + P1 队）。
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


func test_h17_lock_forces_repeated_action_next_turn_only() -> void:
	# 批⑤五改「锁招」：回合1 施放(敌按防) → 回合2 敌方只能「防」（其余全不可选·能量语义不受影响）→ 回合3 解锁。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 6, 8)
	assert_true(b.select_active(0), "阖眸成夜可发动(敌出战存活)")
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.energy[0], 8 - 2 + 2, "费 1 能(2 半能) + 被动 +1 能 → 净持平")
	assert_eq(b.action_lock_turn[1], 1, "锁定登记在回合 1（下一拍）")
	assert_eq(b.action_locked[1], ActionDef.Action.DEFEND, "锁定动作 = 敌方施放拍所用的「防」")
	# 回合2：P1 只能「防」·其余全不可选（能量语义不受影响）
	assert_true(b.can_afford(1, ActionDef.Action.DEFEND), "锁定的「防」可选（唯一合法）")
	assert_false(b.can_afford(1, ActionDef.Action.ATTACK), "波不可选")
	assert_false(b.can_afford(1, ActionDef.Action.CHARGE), "攒不可选（锁定动作可执行时无兜底）")
	assert_false(b.can_afford(1, ActionDef.Action.BIG_DEFEND), "大防不可选")
	assert_true(b.usable_energy(1) > 0, "能量语义不受影响（≠旧冻结）")
	var acts: Array = b.legal_actions(1)
	assert_eq(acts.size(), 1, "legal_actions 只剩锁定动作一项")
	assert_eq(int(acts[0]["action"]), int(ActionDef.Action.DEFEND), "唯一合法动作 = 被锁的「防」")
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	# 回合3：解锁
	assert_true(b.can_afford(1, ActionDef.Action.ATTACK), "次回合解锁 → 波恢复可选")


func test_h17_lock_unaffordable_action_falls_back_to_charge() -> void:
	# 批⑤回归（兜底无死锁）：锁定「大波」(3 能)但敌方下拍付不起 → 只能「攒」。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 6, 8)
	b.energy[1] = 6   # 敌方 3 能：本拍付得起大波(6 半能)·打完归零下拍付不起
	b.select_active(0)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()
	assert_eq(b.action_locked[1], ActionDef.Action.BIG_ATTACK, "锁定动作 = 大波")
	assert_false(b.can_afford(1, ActionDef.Action.BIG_ATTACK), "大波付不起(能量不足)")
	assert_true(b.can_afford(1, ActionDef.Action.CHARGE), "兜底：只能攒")
	assert_false(b.can_afford(1, ActionDef.Action.DEFEND), "兜底拍其他动作仍不可选")
	assert_true(b.legal_actions(1).size() >= 1, "合法动作集非空（无死锁）")


func test_h17_lock_uses_capped_at_two_and_chains() -> void:
	# 每局上限 2 次；两次可贴着连放（连锁两拍·合法）。锁「攒」拍敌方只能攒（最小收益面）。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 6, 20)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.action_locked[1], ActionDef.Action.CHARGE, "第一发锁「攒」")
	assert_false(b.can_afford(1, ActionDef.Action.DEFEND), "被锁攒拍：防不可选")
	assert_true(b.can_use_active(0), "还剩 1 次 → 可再放")
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 2, "已用 2 次")
	assert_false(b.can_use_active(0), "每局上限 2 → 第 3 次不可用")
	assert_eq(b.action_lock_turn[1], 2, "连放：第二发登记在回合 2")


func test_h17_lock_forces_enemy_active_skill_when_repeated() -> void:
	# 施放拍敌方用了主动技 → 下拍其只能再放主动技（ACTIVE 同轨·基础动作全不可选）。
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h21", "test_p1_1", "test_p1_2"], 6, 20)
	assert_true(b.can_use_active(1), "施放前：暗猴主动技可用")
	b.select_active(0)
	b.select_active(1)   # 敌方同拍也放主动技（调虎离山）
	b.resolve()
	assert_eq(b.action_locked[1], ActionDef.ACTIVE, "锁定动作 = ACTIVE")
	assert_true(b.can_use_active(1), "下拍：敌方只能再放主动技（cap 未满可执行）")
	assert_false(b.can_afford(1, ActionDef.Action.ATTACK), "基础动作全不可选")


# ---- 沉默 status 基建直测（原 h17 机制已弃·基建保留=远征怪/道具候选·锁 Phase 0.3 行为）----

func test_silence_status_disables_unique_and_decrements() -> void:
	# 直接写 silenced status（无施加者）：unique 全 hook 失效 + 逐回合递减到期恢复。
	var b := _battle_vs(["test_p0_0", "test_p0_1", "test_p0_2"], ["h01", "test_p1_1", "test_p1_2"], 6, 8)
	b.set_status(1, 0, "silenced", 1)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.energy[1], 8 + 4, "沉默中：攒+2 +被动+2（步虚无有乡加成失效）")
	assert_eq(int(b.get_status(1, 0, "silenced", 0)), 0, "沉默递减到期")
	var before: int = b.energy[1]
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.energy[1] - before, 5, "到期恢复：攒(2+步虚无有乡1) + 被动 2 = +5")


# ---- h18 相柳 缠绕（出战时对手无法主动切换；死亡换人不受影响）----

func test_h18_zeguo_defend_tax_and_release() -> void:
	# 批③ J 案：相柳出战 → 敌方防不再免费(+1 能=2 半能)；相柳阵亡即解税。
	var b := _battle("h18", 5, 8)
	b.energy[1] = 0
	assert_false(b.can_afford(1, ActionDef.Action.DEFEND), "泽国防御税：0 能付不起防(1 能)")
	b.energy[1] = 2
	assert_true(b.can_afford(1, ActionDef.Action.DEFEND), "有 1 能可付税防御")
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.energy[1], 2 - 2 + 2, "防被收 1 能税 + 被动 +1 能 → 净持平")
	b.hp[0][0] = 0                                     # 相柳阵亡
	b.energy[1] = 0
	assert_true(b.can_afford(1, ActionDef.Action.DEFEND), "相柳阵亡 → 防恢复免费")


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


# ---- h21 枭阳 调虎离山（主动技·强制对手换人·揪玩家指定/未指定随机的存活替补·2026-07-02 由"血最低默认"改）----

func test_h21_diaohu_pulls_specified_target() -> void:
	# 玩家指定揪敌方 slot2（非血最低）→ 被强制揪上 slot2（验证"指定"生效·非旧"血最低"默认）。
	var b := _battle_vs(["h21", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	b.hp[1][1] = 2   # slot1 残血（旧默认会揪这个）
	b.hp[1][2] = 8   # slot2 高血（玩家偏要揪这个）
	assert_true(b.select_active(0, 2), "暗猴指定揪敌方 slot2")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[1], 2, "对手被强制揪上玩家指定的 slot2（非血最低）")
	assert_eq(b.energy[0], 8 - 2 + 2, "调虎离山费 1 能（2 半能·批④降费）+ 被动回 +1 能")
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 1, "计 1 次使用")


func test_h21_diaohu_dead_target_voided() -> void:
	# 玩家指定的目标 slot2 已阵亡 → 揪人作废（不改揪存活的 slot1）；仍算发动（扣能计次）。
	var b := _battle_vs(["h21", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	b.hp[1][2] = 0   # slot2 已死（玩家仍指定它）；slot1 存活（"改揪别人"才会揪它）
	assert_true(b.select_active(0, 2), "可发动（敌尚有存活替补 slot1）")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[1], 0, "指定目标已死 → 揪人作废，对手出战仍是 slot0")
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 1, "仍计 1 次使用（主动技已发动）")


func test_h21_diaohu_unspecified_pulls_random_reserve() -> void:
	# 未指定目标（select_active 不带 target）→ 随机揪一个存活替补（seed 固定 → 确定性）。
	var b := _battle_vs(["h21", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	assert_true(b.select_active(0), "未指定目标也可发动")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.active_index[1] in [1, 2], "未指定 → 随机揪上一个存活替补（slot1 或 slot2）")
	assert_ne(b.active_index[1], 0, "对手出战已被换走（不再是 slot0）")


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


# ---- h23 天狗 护主（替补狗顶替承伤·批③：每局两次+登场反击 1.0 真伤）----

func test_h23_huzhu_protects_carry_by_swapping_in() -> void:
	# P0 出战 carry 残血(1.0HP=2半) + 替补天狗(slot1 满血10半)。对手大波致死 →
	#   天狗立刻登场顶替、carry 退居替补获救、这一击改落天狗 + 反击咬攻击者 1.0 真伤(批③)。
	var b := _battle_team(["test_p0_0", "h23", "test_p0_2"], 5, 12)
	b.hp[0][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)   # 大波 4 半点 ≥ 2 → 致死
	b.resolve()
	assert_eq(b.hp[0][0], 2, "carry 获救·退居替补·血量不变")
	assert_eq(b.active_index[0], 1, "天狗顶替登场为出战")
	assert_eq(b.hp[0][1], 10 - 2, "登场护盾 1.0 垫掉 2 半点(2026-07-04)·天狗只落血 2 半点(10-2=8)")
	assert_eq(b.shield[0][1], 0, "护盾被这一击耗尽")
	assert_eq(b.hp[1][0], 10 - 2, "御凶反击：天狗扑咬攻击者 1.0 伤害(批③·普通档·2026-07-05)")
	assert_eq(int(b.get_status(0, 1, "huzhu_uses", 0)), 1, "护主计 1 次")


func test_h23_huzhu_twice_per_game_then_exhausted() -> void:
	# 批③：每局两次（1→2）。天狗轮换回替补可再救；第三次致死无人顶替。
	var b := _battle_team(["test_p0_0", "h23", "test_p0_2"], 5, 20)
	b.hp[0][0] = 2
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()   # 第一次：天狗登场救 slot0
	assert_eq(int(b.get_status(0, 1, "huzhu_uses", 0)), 1, "第一次御凶")
	assert_eq(b.hp[1][0], 10 - 2, "第一次反击 1.0 伤害")
	b.select_switch(0, 2)                              # 天狗退替补·slot2 上
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 2, "天狗回替补席（可再救）")
	b.hp[0][2] = 2                                     # 摆第二个致死靶
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()   # 第二次：天狗再登场救 slot2
	assert_eq(int(b.get_status(0, 1, "huzhu_uses", 0)), 2, "第二次御凶（批③上限 2）")
	assert_eq(b.active_index[0], 1, "天狗再度顶替登场")
	assert_eq(b.hp[1][0], 10 - 4, "两次反击累计 2.0 伤害")
	b.select_switch(0, 0)                              # 天狗再退替补·残血 carry 上
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()   # 第三次致死 → 御凶用尽·无人顶替 → carry 阵亡
	assert_true(b.hp[0][0] <= 0, "上限 2 用尽 → 第三次无人顶替")
	assert_eq(int(b.get_status(0, 1, "huzhu_uses", 0)), 2, "次数停在 2")


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


# ---- h24 并封 饕餮（任一英雄阵亡敌我皆可 → 团队 +2.0 能 + 并封自己回 1.0 生命·2026-07-04 双头分食）----

func test_h24_taotie_heals_self_on_death() -> void:
	# 双头分食：敌方阵亡 → 除 +2.0 能外，残血并封自己回 1.0 生命（2 半点）
	var b := _battle_vs(["h24", "test_p0_1", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	b.hp[0][0] = 6                        # 并封残血（3.0/5.0）
	b.hp[1][0] = 2                        # 敌出战残血待收割
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.hp[1][0] <= 0, "敌出战被波打死")
	assert_eq(b.hp[0][0], 6 + 2, "并封食肉：死亡 → 自己回 1.0 生命（2 半点）")

func test_h24_taotie_heal_caps_at_max_hp() -> void:
	# 满血并封：食肉封顶 max_hp 不溢出（能量那份照拿）
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
	assert_eq(b.hp[0][0], 10, "满血并封 → 食肉封顶不超 max_hp")
	assert_eq(b.energy[0] - ctrl.energy[0], 4, "能量那份不受回血封顶影响·照拿 +2.0 能")

func test_h24_taotie_heals_from_reserve() -> void:
	# 在场光环含替补：并封躺替补席、残血 → 队友阵亡也回肉
	var b := _battle_team(["test_p0_0", "h24", "test_p0_2"], 5, 8)
	b.hp[0][0] = 2                        # 出战 carry 残血待死
	b.hp[0][1] = 6                        # 替补并封残血
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	b.resolve()
	assert_true(b.hp[0][0] <= 0, "carry 被大波致死")
	assert_eq(b.hp[0][1], 6 + 2, "替补席并封也食肉 +1.0 生命（在场光环）")


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


# ---- h22 毕方 焚天火兆 v3（2026-07-06 批④ Eddy 批 A 案：蓄力免费·每局 2 次·我方下一次攻击穿大防）----
# 火兆=全队资源·不过期·兑现/落空即消（引擎态 pierce_next_attack）；v2"下回合仅毕方"窗口已废。
# 2026-07-05 批②：蓄力拍 +1.0 护盾；批③：蓄力 1 能→免费。

func test_h22_xuli_charge_turn_deals_no_damage() -> void:
	# 蓄力拍：不造成伤害·免费·获得 1.0 护盾
	var b := _battle("h22", 5, 8)
	assert_true(b.select_active(0), "蓄力可用")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "蓄力拍不造成伤害")
	assert_eq(b.energy[0], 8 + 2, "蓄力免费(2026-07-05 批③·由 1 能降) + 被动 +1 能")
	assert_eq(b.shield[0][0], 2, "蓄力拍获得 1.0 护盾(2 半点·2026-07-05 平衡批②)")

func test_h22_xuli_shield_absorbs_charge_turn_attack() -> void:
	# 火光护体：蓄力拍挨的波被护盾吸收·本体不掉血
	var b := _battle("h22", 5, 8)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.ATTACK)   # 对手趁蓄力拍抢攻
	b.resolve()
	assert_eq(b.hp[0][0], 10, "波 2 半点被护盾吸收 → 毕方本体不掉血")
	assert_eq(b.shield[0][0], 0, "护盾被消耗殆尽")

func test_h22_xuli_next_turn_attack_pierces_big_defend() -> void:
	# 蓄力次回合：波升为穿大防·大防挡不住
	var b := _battle("h22", 5, 8)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.hp[1][0], 10 - 2, "蓄力次回合：波穿大防·2 半点落地")

func test_h22_xuli_big_attack_also_pierces() -> void:
	# 双档 agency：大波同样吃穿大防升级
	var b := _battle("h22", 5, 12)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	_resolve(b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.hp[1][0], 10 - 4, "蓄力次回合：大波穿大防·4 半点落地")

func test_h22_omen_persists_until_used() -> void:
	# v3 核心：火兆不过期——空过数拍后兑现照样穿大防
	var b := _battle("h22", 5, 12)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)   # 悬着不兑现
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)   # 再悬一拍
	assert_true(b.pierce_next_attack[0], "火兆仍在（不过期）")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.hp[1][0], 10 - 2, "隔多拍兑现：波穿大防·2 半点落地")


func test_h22_omen_consumed_after_first_attack() -> void:
	# 兑现即消：第一次攻击交掉火兆·后续攻击恢复普通穿透
	var b := _battle("h22", 5, 12)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_false(b.pierce_next_attack[0], "火兆已消耗")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 10 - 2, "火兆用完 → 第二发波被「防」正常挡下（伤害没再涨）")


func test_h22_omen_teammate_can_cash() -> void:
	# v3 全队共享：毕方点火 → 换队友上 → 队友的攻击兑现穿大防
	var b := _battle_team(["h22", "test_p0_1", "test_p0_2"], 5, 12)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	b.select_switch(0, 1)   # 换队友上场（火兆与毕方解绑·团队资源）
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.pierce_next_attack[0], "切换不熄灭火兆")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.hp[1][0], 10 - 2, "队友的波兑现火兆·穿大防落地")

func test_h22_xuli_no_rearm_during_window() -> void:
	# 窗口激活期间禁止再次蓄力（防误耗次数）
	var b := _battle("h22", 5, 8)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_false(b.can_use_active(0), "窗口激活中 → 不可再蓄力")

func test_h22_xuli_cap_two_per_game() -> void:
	# 每局上限 2 次（蓄→发→蓄→发 → 第 3 次蓄不可用）
	var b := _battle("h22", 5, 20)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_true(b.can_use_active(0), "窗口已过·还剩 1 次 → 可再蓄")
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_false(b.can_use_active(0), "每局上限 2 → 第 3 次不可用")

func test_h22_xuli_requires_active_bifang() -> void:
	# 主动技 = 出战英雄的技能：毕方在替补、出战 plain → 无蓄力可按
	var b := _battle_team(["test_p0_0", "h22", "test_p0_2"], 5, 8)
	assert_false(b.can_use_active(0), "毕方在替补·出战无主动技 → 不可用")
