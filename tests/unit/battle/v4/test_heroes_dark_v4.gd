extends GutTest

## ============================================================================
## 黑暗面英雄（h13 玄冥 / h14 蚩尤 / h15 穷奇）技能测试 —— 锁定【当前代码行为】。
##
## h13【暗潮】= 进攻：玄冥出战时，可将「大波」改为连续两次「波」；防 / 大防都能挡住两次。
## h14【天不葬】= 经济·主动：按下后，本回合行动费用由出战蚩尤以等量生命支付。
## h15【七杀战鬼】= 进攻：出战时无法用防/大防（can_afford gate·下场即解）+ 波穿防（attack_penetration）。
## h16【白虹】= 调度/进攻：队友基础攻击命中时，替补广寒登场并对同一目标追击 1 点伤害。
## h17【待重命名】= 主动技：占动作+费2能，转变为敌方当前出战英雄；复制英雄本体状态，不复制团队能量。
## h18【游丝引】= 防守·主动技：费1能且占行动，平均分配我方所有存活英雄的当前生命；总生命守恒、不复活、不超过上限。
## h19【奔雷】= 进攻：攻击命中时，目标至多承受 1.0HP，超过部分转移给当前生命最高的另一名敌人。
## h20【罪已昭】= 状态·被动：命中敌方出战使其获得脆弱（vuln），受伤 +0.5，直到下场（下场清）。
## h21【调虎离山】= 干扰·主动技：占动作+费1能（批④降费·原2能）+每局2次+须出战，强制对手换人、揪其指定（未指定→随机）存活替补上场。
## h22【焚天火兆】= 控制·主动技：占动作+免费+每局2次 → 下一回合结束时双方失去全部能量。
## h23【天光长蚀】= 干扰：「波 / 大波」实际造成多少伤害，就等量降低敌方团队能量上限；最低 3 点，现有超额能量保留。
## h24【待命名】= 经济：在队时，可降低 1 点能量上限，使本回合行动少消耗 1 点能量；上限最低 3 点。
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


func _has_event(result: Dictionary, event_id: String) -> bool:
	for event: Dictionary in result["events"]:
		if String(event.get("id", "")) == event_id:
			return true
	return false


func _battle_team(p0_ids: Array, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = []
	for id in p0_ids:
		p1.append(_hero(id, hp))
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


# ---- h13 玄冥（大波可改为连续两次波）----

func test_h13_split_big_wave_deals_two_separate_wave_hits() -> void:
	var b := _battle_team(["h13", "h10", "test_p0_2"], 5, 8)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, true))
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	var damage_events := 0
	for event in result["events"]:
		if event.get("id", "") == "damage_taken" and int(event.get("player", -1)) == 1:
			damage_events += 1
	assert_eq(b.hp[1][0], 6, "两次波共造成 2 点伤害")
	assert_eq(damage_events, 2, "拆分大波必须独立结算两次命中")
	assert_eq(int(b.get_status(0, 1, "jianqi", 0)), 2, "两次命中应分别触发两次剑气")


func test_h13_split_big_wave_is_fully_blocked_by_defend() -> void:
	var b := _battle("h13", 4, 8)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, true))
	b.select_action(1, ActionDef.Action.DEFEND)
	var result: Dictionary = b.resolve()

	var block_events := 0
	for event in result["events"]:
		if event.get("id", "") == "defend_block" and int(event.get("player", -1)) == 1:
			block_events += 1
	assert_eq(b.hp[1][0], 10, "普通防应挡住两次波，而不是只挡一次")
	assert_eq(block_events, 2, "两次波应分别进入普通防结算")


func test_h13_split_big_wave_is_fully_blocked_by_big_defend() -> void:
	var b := _battle("h13", 4, 8)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, true))
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	var result: Dictionary = b.resolve()

	var block_events := 0
	for event in result["events"]:
		if event.get("id", "") == "big_defend_block" and int(event.get("player", -1)) == 1:
			block_events += 1
	assert_eq(b.hp[1][0], 10, "大防应完整挡住两次波")
	assert_eq(block_events, 2, "大防不是次数护盾，两次波都应分别被挡")


func test_h13_normal_big_wave_remains_available_and_pierces_defend() -> void:
	var b := _battle("h13", 4, 8)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK))
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 6, "不拆分时仍是穿防的 2 点大波")


func test_h13_split_big_wave_requires_h13_to_be_active() -> void:
	var reserve := _battle_team(["test_p0_0", "h13", "test_p0_2"], 5, 8)
	assert_false(reserve.can_split_big_wave_action(0, ActionDef.Action.BIG_ATTACK),
		"玄冥在替补席时不能替队友拆分大波")
	assert_false(reserve.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, true),
		"伪造拆分标记必须被动作门拒绝")


# ---- h14 蚩尤（主动开启：本回合行动费用改由生命支付）----

func test_h14_blood_payment_lets_big_wave_bypass_empty_energy_pool() -> void:
	var b := _battle("h14", 6, 0)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, true),
		"按下技能后，即使没有能量也应能用生命支付大波")
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][0], 6, "大波消耗 3 点能量，应改扣蚩尤 3 点生命")
	assert_eq(b.hp[1][0], 6, "生命支付不改变大波本身的 2 点伤害")
	assert_eq(b.energy[0], 2, "行动不扣能量，只获得正常的回合被动能量")
	var found_payment := false
	for event: Dictionary in result["events"]:
		if event.get("id", "") == "h14_blood_payment" \
				and int(event.get("player", -1)) == 0 \
				and int(event.get("amount", 0)) == 6:
			found_payment = true
	assert_true(found_payment, "结算结果应记录生命支付事件供界面反馈")


func test_h14_blood_payment_is_optional_and_requires_active_h14() -> void:
	var no_toggle := _battle("h14", 6, 0)
	assert_false(no_toggle.select_action(0, ActionDef.Action.BIG_ATTACK),
		"没有按下技能时仍按正常能量规则判断")

	var reserve := _battle_team(["test_p0_0", "h14", "test_p0_2"], 6, 0)
	assert_false(reserve.select_action(0, ActionDef.Action.ATTACK, -1, false, false, true),
		"替补席蚩尤不能为出战队友支付生命")

	var plain := _battle("test_p0_0", 6, 0)
	assert_false(plain.select_action(0, ActionDef.Action.ATTACK, -1, false, false, true),
		"无蚩尤时不能伪造生命支付标记")


func test_h14_blood_payment_uses_hp_not_shield_and_can_pay_exactly() -> void:
	var b := _battle("h14", 6, 0)
	b.hp[0][0] = 2
	b.shield[0][0] = 8
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, -1, false, false, true),
		"生命足够支付时应允许发动，即使支付后恰好归零")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[0][0], 0, "支付费用直接扣生命，可将蚩尤扣至阵亡")
	assert_eq(b.shield[0][0], 8, "生命支付不是伤害，不应消耗护盾")
	assert_eq(b.hp[1][0], 8, "即使支付后阵亡，本轮已经提交的波仍应完成结算")


func test_h14_blood_payment_survives_h07_free_switch_and_charges_original_h14() -> void:
	var b := _battle_team(["h14", "h07", "test_p0_2"], 6, 0)
	assert_true(b.set_blood_payment_active(0, true), "蚩尤出战时应能开启生命支付")
	assert_true(b.free_switch(0, 1), "顶星日上场应为免费切换")
	assert_eq(b.active_index[0], 1, "免费切换后应由星日出战")
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, true),
		"星日应能继续使用由蚩尤付款的大波")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[0][0], 6, "大波的3点费用必须扣最初发动技能的蚩尤")
	assert_eq(b.hp[0][1], 12, "当前出战的星日不应误付生命")
	assert_eq(b.energy[0], 2, "免费切换后的行动仍不消耗团队能量")


func test_h14_blood_payment_cannot_extend_h07_into_second_free_switch() -> void:
	var b := _battle_team(["h14", "h07", "h17"], 6, 0)
	assert_true(b.set_blood_payment_active(0, true))
	assert_true(b.free_switch(0, 1), "蚩尤应能免费切到星日")
	assert_false(b.free_switch(0, 2), "千里自在风同回合不能再免费切到烛阴")
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, true),
		"星日仍可继续使用由蚩尤付款的大波")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.active_index[0], 1, "本回合应停留在第一次免费切入的星日")
	assert_eq(b.hp[0][0], 6, "星日大波消耗3点能量，应改扣蚩尤3点生命")


# ---- h15 穷奇 七杀战鬼（出战不能防御 + 波穿防）----

func test_h15_qishazhangui_cannot_defend() -> void:
	var b := _battle("h15", 7, 8)   # 暗虎出战；8 半能（够大防/大波）
	assert_false(b.can_afford(0, ActionDef.Action.DEFEND), "七杀战鬼：防不合法")
	assert_false(b.can_afford(0, ActionDef.Action.BIG_DEFEND), "七杀战鬼：大防不合法")
	assert_false(b.select_action(0, ActionDef.Action.DEFEND), "七杀战鬼：选防被拒")
	var acts: Array = []
	for c in b.legal_actions(0):
		acts.append(int(c["action"]))
	assert_does_not_have(acts, ActionDef.Action.DEFEND, "legal_actions 不含防")
	assert_does_not_have(acts, ActionDef.Action.BIG_DEFEND, "legal_actions 不含大防")
	assert_true(b.can_afford(0, ActionDef.Action.ATTACK), "七杀战鬼：波仍合法")
	assert_true(b.can_afford(0, ActionDef.Action.BIG_ATTACK), "七杀战鬼：大波仍合法")


func test_h15_qishazhangui_only_disables_while_active() -> void:
	# 暗虎在替补(slot1)、出战是 plain → 出战队友能正常防（下场即恢复）
	var b := _battle_team(["test_p0_0", "h15", "test_p0_2"], 5, 8)
	assert_true(b.can_afford(0, ActionDef.Action.DEFEND), "暗虎在替补 → 出战队友能防")
	assert_true(b.can_afford(0, ActionDef.Action.BIG_DEFEND), "暗虎在替补 → 出战队友能大防")


func test_h15_qishazhangui_wave_pierces_defend() -> void:
	# 暗虎(P0)波 vs plain(P1)防 → 穿防，plain 仍吃 2 半点
	var b := _battle("h15", 7, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "七杀战鬼波穿防：plain 出防仍吃 2 半点(1.0 HP)")


func test_h15_qishazhangui_wave_blocked_by_big_defend() -> void:
	# 大防仍挡得下七杀战鬼的波（穿防只穿到大防为止）
	var b := _battle("h15", 7, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "七杀战鬼的波被大防挡下：plain 无伤")


# ---- h16 广寒 白虹（替补席响应队友基础攻击命中）----

func test_h16_reserve_pursuit_switches_in_and_hits_same_active_target() -> void:
	var b := _battle_team(["test_p0_0", "h16", "test_p0_2"], 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.active_index[0], 1, "队友攻击命中后，替补广寒应登场")
	assert_eq(b.hp[1][0], 6, "普通波1点 + 广寒追击1点，应共造成2点伤害")
	assert_true(_has_event(result, "h16_reserve_pursuit"), "结算事件应记录广寒追击")


func test_h16_blocked_team_attack_does_not_trigger_pursuit() -> void:
	var b := _battle_team(["test_p0_0", "h16", "test_p0_2"], 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.DEFEND)
	var result: Dictionary = b.resolve()

	assert_eq(b.active_index[0], 0, "队友攻击被挡时，广寒不应登场")
	assert_eq(b.hp[1][0], 10)
	assert_false(_has_event(result, "h16_reserve_pursuit"))


func test_h16_active_cannot_trigger_from_own_attack() -> void:
	var b := _battle_team(["h16", "test_p0_1", "test_p0_2"], 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.active_index[0], 0, "广寒本人出战攻击时不存在替补追击")
	assert_eq(b.hp[1][0], 8, "只结算广寒本人的普通波")


func test_h16_pursuit_follows_h04_target_to_enemy_reserve() -> void:
	var b := _battle_team(["h04", "h16", "test_p0_2"], 5, 8)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1))
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.active_index[0], 1, "命中敌方替补后广寒同样应登场")
	assert_eq(b.hp[1][1], 6, "波与追击都必须落在房日指定的同一替补目标")
	assert_eq(b.hp[1][0], 10, "敌方出战位不应被追击误伤")


func test_h16_multihit_action_triggers_only_one_pursuit() -> void:
	var b := _battle_team(["h13", "h16", "test_p0_2"], 5, 8)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, true))
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()
	var pursuits: int = 0
	for event: Dictionary in result["events"]:
		if event.get("id", "") == "h16_reserve_pursuit":
			pursuits += 1

	assert_eq(b.active_index[0], 1)
	assert_eq(b.hp[1][0], 4, "玄冥两次波共2点，广寒只追加一次1点追击")
	assert_eq(pursuits, 1, "同一个多段攻击动作只触发一次广寒追击")


func test_h16_can_repeat_after_h07_and_a_paid_switch_return_her_to_reserve() -> void:
	var b := _battle_team(["h07", "h16", "test_p0_2"], 5, 20)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "第一回合追击后广寒登场")
	assert_eq(b.hp[1][0], 6)

	assert_true(b.free_switch(0, 0), "广寒可免费切回星日")
	assert_false(b.free_switch(0, 2), "同回合不能借星日继续免费切到下一名攻击手")
	assert_true(b.select_switch(0, 2), "可把常规切换作为本回合动作，让下一名攻击手登场")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.active_index[0], 1, "广寒回到替补后可再次追击登场")
	assert_eq(b.hp[1][0], 1,
		"经过一回合常规换位后，第二次波与追击仍可成立")


func test_h16_item_and_attack_active_do_not_trigger_pursuit() -> void:
	var item_battle := _battle_team(["test_p0_0", "h16", "test_p0_2"], 5, 8)
	var dart: int = item_battle.give_item(0, ItemCatalog.make("t1_feibiao"))
	assert_true(item_battle.use_item(0, dart))
	item_battle.select_action(0, ActionDef.Action.CHARGE)
	item_battle.select_action(1, ActionDef.Action.CHARGE)
	item_battle.resolve()
	assert_eq(item_battle.active_index[0], 0, "道具命中不触发广寒追击")

	var active_battle := _battle_team(["h10", "h16", "test_p0_2"], 5, 8)
	active_battle.set_status(0, 0, "jianqi", 2)
	assert_true(active_battle.select_active(0))
	active_battle.select_action(1, ActionDef.Action.CHARGE)
	active_battle.resolve()
	assert_eq(active_battle.active_index[0], 0, "攻击型主动技命中不触发广寒追击")


func test_h16_does_not_pursue_when_source_or_target_dies_in_primary_exchange() -> void:
	var source_dies := _battle_team(["test_p0_0", "h16", "test_p0_2"], 5, 8)
	source_dies.hp[0][0] = 2
	source_dies.select_action(0, ActionDef.Action.ATTACK)
	source_dies.select_action(1, ActionDef.Action.ATTACK)
	source_dies.resolve()
	assert_eq(source_dies.active_index[0], 0,
		"出手队友在主攻击交换中阵亡时，广寒不应借追击替代死亡换人")

	var target_dies := _battle_team(["test_p0_0", "h16", "test_p0_2"], 5, 8)
	target_dies.hp[1][0] = 2
	target_dies.select_action(0, ActionDef.Action.ATTACK)
	target_dies.select_action(1, ActionDef.Action.CHARGE)
	target_dies.resolve()
	assert_eq(target_dies.active_index[0], 0, "原目标已被主攻击击杀时，广寒不应追尸登场")


# ---- h17 烛阴（主动技·转变为敌方当前出战英雄）----

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


func test_h17_transforms_into_enemy_active_and_copies_runtime_state() -> void:
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h15", "test_p1_1", "test_p1_2"], 6, 8)
	b.hp[1][0] = 7
	b.shield[1][0] = 3
	b.set_status(1, 0, "vuln", 2)
	b.set_status(1, 0, "active_uses", 1)

	assert_true(b.select_active(0), "敌方出战存活时，烛阴可发动转变")
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq((b.heroes[0][0] as HeroData).hero_id, "h15", "烛阴槽位应变成敌方当前出战英雄")
	assert_eq(b.hp[0][0], 7, "复制敌方当前生命，而不是按比例换算或回满")
	assert_eq(b.max_hp[0][0], 12, "复制敌方生命上限")
	assert_eq(b.shield[0][0], 3, "护盾属于英雄本体状态，应随转变复制")
	assert_eq(int(b.get_status(0, 0, "vuln", 0)), 2, "局部状态应随英雄复制")
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 1, "技能使用进度不应被转变刷新")
	assert_eq(b.energy[0], 6, "消耗2点能量后只获得正常的回合被动能量；不复制敌方能量")
	assert_false(b.get_skill(0, 0).can_defend(), "技能组件应同步替换为目标英雄的技能")
	assert_true(_has_event(result, "h17_transform"), "结算事件应记录转变供界面反馈")


func test_h17_reads_enemy_active_after_switch() -> void:
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["test_p1_0", "h10", "test_p1_2"], 6, 8)
	b.hp[1][1] = 5
	assert_true(b.select_active(0))
	assert_true(b.select_switch(1, 1))
	b.resolve()

	assert_eq(b.active_index[1], 1, "敌方应先完成切换")
	assert_eq((b.heroes[0][0] as HeroData).hero_id, "h10", "烛阴应复制切换后出战的昴日")
	assert_eq(b.hp[0][0], 5, "生命也读取切换后的目标槽")


func test_h17_copied_skill_works_on_following_turn() -> void:
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h15", "test_p1_1", "test_p1_2"], 6, 20)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_false(b.can_afford(0, ActionDef.Action.DEFEND), "转变为穷奇后应继承无法防御")
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "转变后的穷奇之波应穿过普通防御")


func test_h17_mirror_casts_use_pre_transform_snapshots() -> void:
	var b := _battle_vs(["h17", "test_p0_1", "test_p0_2"], ["h17", "test_p1_1", "test_p1_2"], 6, 20)
	b.hp[0][0] = 5
	b.hp[1][0] = 9
	b.shield[0][0] = 1
	b.shield[1][0] = 4
	assert_true(b.select_active(0))
	assert_true(b.select_active(1))
	b.resolve()

	assert_eq(b.hp[0][0], 9, "P0 应读取 P1 转变前的生命")
	assert_eq(b.hp[1][0], 5, "P1 应读取 P0 转变前的生命，而不是读取已经改写的 P0")
	assert_eq(b.shield[0][0], 4)
	assert_eq(b.shield[1][0], 1)


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


# ---- h18 相柳（主动技·平均分配全队存活英雄当前生命）----

func test_h18_active_costs_one_energy_and_evenly_redistributes_hp() -> void:
	var b := _battle("h18", 5, 2)
	b.hp[0] = [10, 4, 1]
	assert_true(b.select_active(0), "有1点能量时，相柳应能发动主动技")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[0], [5, 5, 5], "15个半点生命应平均分为5/5/5")
	assert_eq(b.energy[0], 2, "发动消耗1点能量，回合被动再回复1点能量")


func test_h18_active_requires_one_energy() -> void:
	var b := _battle("h18", 5, 0)
	assert_false(b.can_use_active(0), "0能量时不能发动")
	assert_false(b.select_active(0), "主动技提交入口也必须拒绝")


func test_h18_redistribution_respects_max_hp_and_half_point_remainder() -> void:
	var p1: Array = [_hero("h18", 3), _hero("test_p0_1", 7), _hero("test_p0_2", 7)]
	var p2: Array = [_hero("test_p1_0"), _hero("test_p1_1"), _hero("test_p1_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [2, 2]
	b.hp[0] = [6, 14, 1]
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[0], [6, 8, 7], "低上限英雄封顶后，余下15个半点应在另外两人间尽量均分")
	assert_eq(b.hp[0][0] + b.hp[0][1] + b.hp[0][2], 21, "均分不得创造或销毁生命")


func test_h18_redistribution_excludes_dead_heroes_without_reviving_them() -> void:
	var b := _battle("h18", 5, 2)
	b.hp[0] = [10, 0, 2]
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[0], [6, 0, 6], "阵亡英雄不参与均分，也不会被复活")


func test_h18_old_defend_tax_and_switch_lock_are_removed() -> void:
	var b := _battle("h18", 6, 2)
	b.energy[1] = 0
	assert_true(b.can_afford(1, ActionDef.Action.DEFEND), "相柳不再提高敌方防御费用")
	assert_true(b.can_afford(1, ActionDef.Action.SWITCH), "相柳不再封锁敌方主动切换")
	assert_true(b.select_switch(1, 1), "敌方切换提交入口应恢复正常")


# ---- h19 乌骓 奔雷（目标承受至多 1.0HP，其余伤害转移给最高生命的另一名敌人）----

func test_h19_jianta_overflow_tramples_reserve() -> void:
	# 大波(4半=2.0HP)命中 → 原目标承受2半，余下2半转移给生命更高的slot2。
	var b := _battle("h19", 5, 12)
	b.hp[1] = [10, 6, 8]
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1], [8, 6, 6],
		"大波总伤害守恒：原目标只承受1点，余下1点转移给最高生命的另一名敌人")


func test_h19_jianta_normal_wave_no_trample() -> void:
	# 波(2半=1.0HP)不溢出 → 替补不受踏
	var b := _battle("h19", 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "波 2 半点命中出战")
	assert_eq(b.hp[1][1], 10, "波不溢出(1.0≤1.0) → 替补不受踏")


func test_h19_jianta_tied_highest_hp_uses_lower_slot_deterministically() -> void:
	var b := _battle("h19", 5, 12)
	b.hp[1] = [10, 8, 8]
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1], [8, 6, 8], "最高生命并列时应固定转移给槽位靠前者")


func test_h19_jianta_transfers_damage_after_vulnerability_without_creating_damage() -> void:
	var b := _battle("h19", 5, 12)
	b.hp[1] = [10, 6, 8]
	b.set_status(1, 0, "vuln", 1)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1], [8, 6, 5],
		"脆弱后的2.5点总伤害应拆为原目标1点、最高生命队友1.5点")


func test_h19_jianta_primary_and_transfer_each_respect_their_own_shield() -> void:
	var b := _battle("h19", 5, 12)
	b.hp[1] = [10, 6, 8]
	b.shield[1][0] = 2
	b.shield[1][2] = 1
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1], [10, 6, 7], "两段伤害应分别经过各自目标的护盾")
	assert_eq(b.shield[1], [0, 0, 0], "原目标吸收1点，转移目标吸收0.5点")


func test_h19_jianta_discards_excess_when_no_other_enemy_is_alive() -> void:
	var b := _battle("h19", 5, 12)
	b.hp[1] = [10, 0, 0]
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1][0], 8, "没有另一名存活敌人时，原目标仍最多只承受1点")


func test_h19_jianta_blocked_no_trample() -> void:
	# 大防挡下大波(dealt=0) → on_deal_hit 不触发 → 不踏
	var b := _battle("h19", 5, 12)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "大防挡下大波·出战无伤")
	assert_eq(b.hp[1][1], 10, "被挡 → 替补不受踏")


# ---- h20 触邪 罪已昭（持续脆弱：命中敌方出战施加·受伤 +0.5·下场清）----

func test_h20_zuiyizhao_marks_and_amplifies() -> void:
	# 触邪波命中敌方出战 → 施加脆弱；此后对该目标的攻击 +0.5(1 半点)
	var b := _battle("h20", 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)   # 触邪波命中 → 附印（附印那击不放大自己）
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "首击 2 半点·未放大")
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 1, "敌方出战已获得脆弱")
	# 第二回合再波 → 这次受脆弱放大 +0.5：2 + 1 = 3 半点
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 8 - 3, "被印后受伤 +0.5 → 波打 3 半点")


func test_h20_zuiyizhao_amplifies_any_attacker() -> void:
	# 脆弱对全队生效：直接给敌方出战施加状态，普通英雄的波也 +0.5
	var b := _battle("test_p0_0", 5, 8)
	b.set_status(1, 0, "vuln", 1)                 # 手动施加脆弱
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 3, "被印目标受任意攻击 +0.5 → 波打 3 半点")


func test_h20_zuiyizhao_does_not_downgrade_hunter_mark_vulnerability() -> void:
	var b := _battle("h20", 5, 8)
	b.set_status(1, 0, "vuln", 3)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 3, "断罪不得把猎物印记的 3 层脆弱覆盖成 1 层")


func test_h20_zuiyizhao_cleared_on_switch_out() -> void:
	# 脆弱英雄下场 → 脆弱清除（换回来需重新施加）
	var b := _battle("h20", 5, 8)
	b.select_action(0, ActionDef.Action.ATTACK)   # 触邪命中 P1 出战 → 附印
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 1, "P1 出战已获得脆弱")
	b._perform_switch(1, 0, 1, [])                # 模拟 P1 把 slot0 换下
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 0, "下场 → 脆弱清除")


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


func test_h21_diaohu_does_not_trigger_h11_from_reserve() -> void:
	var b := _battle_vs(["h21", "h11", "test_p0_2"], ["test_p1_0", "test_p1_1", "test_p1_2"], 5, 8)
	assert_true(b.select_active(0, 1), "枭阳指定揪敌方 slot1")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.active_index[1], 1, "惊蛰仍应正常让指定替补登场")
	assert_eq(b.hp[1][0], 10, "娄金在替补席时不得因惊蛰触发影狩")


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


# ---- h23 天狗（攻击伤害等量降低敌方能量上限·最低 3 点）----

func test_h23_wave_reduces_enemy_energy_max_by_actual_damage() -> void:
	var b := _battle("h23", 6, 20)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][0], 8, "波应实际造成 1 点伤害")
	assert_eq(b.energy_max[1], 18, "1 点伤害应等量降低 1 点能量上限")
	assert_eq(b.energy[1], 20, "已存在的超额能量必须保留")
	assert_true(_has_event(result, "energy_max_reduced"), "结算流应公开能量上限降低事件")


func test_h23_big_wave_reduces_enemy_energy_max_by_two() -> void:
	var b := _battle("h23", 6, 20)
	_resolve(b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE)

	assert_eq(b.hp[1][0], 6, "大波应实际造成 2 点伤害")
	assert_eq(b.energy_max[1], 16, "2 点伤害应等量降低 2 点能量上限")


func test_h23_blocked_attack_does_not_reduce_energy_max() -> void:
	var b := _battle("h23", 6, 20)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)

	assert_eq(b.hp[1][0], 10, "防应完整挡住波")
	assert_eq(b.energy_max[1], ActionDef.MAX_ENERGY, "未造成伤害就不得降低上限")


func test_h23_uses_hp_damage_after_shield_and_vulnerability() -> void:
	var b := _battle("h23", 6, 20)
	b.shield[1][0] = 1
	b.set_status(1, 0, "vuln", 1)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)

	assert_eq(b.hp[1][0], 8, "波受脆弱增加 0.5，再由 0.5 护盾吸收，实际落血仍为 1 点")
	assert_eq(b.energy_max[1], 18, "只能按实际落血量降低上限，不能按管线中的原始伤害计算")


func test_h23_team_combo_can_raise_one_wave_to_three_damage() -> void:
	var b := _battle_team(["h23", "h02", "h05"], 6, 20)
	b.upgrade_next_wave[0] = true
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, -1, true), "队内亢金应允许强化这次波")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1][0], 4, "测试目标仅有 5 点生命，3 点攻击应实际落 3 点伤害")
	assert_eq(b.energy_max[1], 14, "玄金不动相与龙御极叠加后的 3 点伤害应降低 3 点上限")


func test_h23_energy_max_has_three_energy_floor() -> void:
	var b := _battle("h23", 6, 20)
	b.energy_max[1] = 7
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.energy_max[1], 6, "能量上限最低为 3 点（6 半能），不得继续降低")
	var cap_event: Dictionary = {}
	for event: Dictionary in result["events"]:
		if String(event.get("id", "")) == "energy_max_reduced":
			cap_event = event
			break
	assert_eq(int(cap_event.get("amount", -1)), 1, "到达下限时事件只报告实际减少的 0.5 点能量")
	assert_eq(int(cap_event.get("new_max", -1)), 6, "事件应携带结算后的真实上限")


func test_h23_overcap_energy_blocks_gains_until_spent_below_cap() -> void:
	var b := _battle("h23", 6, 20)
	b.energy_max[1] = 16
	b._gain_energy(1, 4)
	assert_eq(b.energy[1], 20, "超出上限时，获得能量不得删除现有超额能量，也不得继续增加")

	b.energy[1] = 16
	b._gain_energy(1, 2)
	assert_eq(b.energy[1], 16, "恰好位于上限时仍不能继续获得能量")

	b.energy[1] = 14
	b._gain_energy(1, 4)
	assert_eq(b.energy[1], 16, "消耗至上限以下后恢复得能，但仍须封顶于当前上限")


func test_h23_shuangsheng_bonus_counts_once_and_extra_on_hit_does_not_repeat_it() -> void:
	var b := _battle("h23", 6, 20)
	var item_slot: int = b.give_item(0, ItemCatalog.make("t2_shuangsheng"))
	assert_true(b.use_item(0, item_slot), "双生咒符应为这次攻击增加一次 on-hit")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)

	assert_eq(b.hp[1][0], 6, "双生咒符应令波的整次总伤害增加1点")
	assert_eq(b.energy_max[1], 16, "按实际2点伤害降低上限一次，额外on-hit不得重复计算同一伤害")


func test_h23_item_bonus_attached_to_wave_counts_toward_cap_reduction() -> void:
	var b := _battle("h23", 6, 20)
	var item_slot: int = b.give_item(0, ItemCatalog.make("t1_xianshou"))
	assert_true(b.use_item(0, item_slot), "先手应可为本次攻击附加 1 点伤害")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)

	assert_eq(b.hp[1][0], 6, "波本体与先手加成应合并造成 2 点伤害")
	assert_eq(b.energy_max[1], 16, "合并进波的道具伤害应计入天光长蚀的上限削减")


func test_h23_item_damage_is_not_a_basic_attack() -> void:
	var b := _battle("h23", 6, 20)
	var item_slot: int = b.give_item(0, ItemCatalog.make("t1_feibiao"))
	assert_true(b.use_item(0, item_slot), "生锈的暗器应可与波在同一回合使用")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)

	assert_eq(b.hp[1][0], 6, "独立道具伤害 1 点与波伤害 1 点都应正常结算")
	assert_eq(b.energy_max[1], 18, "同回合独立道具伤害不计入，只有波的 1 点伤害触发天光长蚀")


# ---- h24 并封（降低能量上限，换取本回合行动减费）----

func test_h24_reserve_can_discount_a_paid_action() -> void:
	var b := _battle_team(["test_p0_0", "h24", "test_p0_2"], 5, 4)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"并封在替补席也应让 2 能量支付原价 3 能量的大波")
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.energy_max[0], 18, "发动后永久降低 1 点能量上限")
	assert_eq(b.energy[0], 2, "大波减为 2 能，回合末再获得 1 点被动能量")
	assert_true(_has_event(result, "h24_energy_cap_discount"), "结算流应记录并封减费")


func test_h24_discount_preserves_energy_above_the_new_cap() -> void:
	var b := _battle("h24", 6, 20)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, -1, false, false, false, true))
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.energy_max[0], 18)
	assert_eq(b.energy[0], 20, "当前能量高于新上限时仍保留超额能量；本次波被减为 0 费")


func test_h24_cannot_discount_without_the_hero_or_at_the_floor() -> void:
	var plain := _battle("test_p0_0", 5, 4)
	assert_false(plain.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"队内无并封时不得伪造减费")

	var floor_battle := _battle("h24", 6, 4)
	floor_battle.energy_max[0] = 6
	assert_false(floor_battle.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"能量上限已到 3 点时不得继续发动")
	assert_false(floor_battle.select_action(0, ActionDef.Action.CHARGE, -1, false, false, false, true),
		"0 费行动不得白白降低上限")

	var half_step := _battle("h24", 6, 4)
	half_step.energy_max[0] = 7
	assert_false(half_step.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"上限只剩 3.5 点时无法完整降低 1 点，不得换取完整减费")

	var dead_reserve := _battle_team(["test_p0_0", "h24", "test_p0_2"], 5, 4)
	dead_reserve.hp[0][1] = 0
	assert_false(dead_reserve.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"已阵亡的并封不再属于存活队伍，不能继续提供能力")


func test_h24_reselecting_a_normal_action_cancels_the_discount() -> void:
	var b := _battle("h24", 6, 8)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true))
	assert_true(b.select_action(0, ActionDef.Action.ATTACK), "重新提交普通波应取消先前减费选择")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.energy_max[0], 20, "只有最终提交的行动会支付能量上限")


func test_h24_discount_includes_longyuji_extra_cost() -> void:
	var b := _battle_team(["test_p0_0", "h05", "h24"], 5, 2)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, -1, true, false, false, true),
		"龙御极总计 2 能，应可由并封减到 1 能支付")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1][0], 6, "龙御极仍造成 2 点伤害")
	assert_eq(b.energy_max[0], 18)
	assert_eq(b.energy[0], 2, "支付减费后的 1 能，再获得回合被动 1 能")


func test_h24_discount_applies_before_h14_blood_payment() -> void:
	var b := _battle_team(["h14", "h24", "test_p0_2"], 6, 0)
	assert_true(b.set_blood_payment_active(0, true))
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, true, true),
		"并封应先把大波降至 2 能，再由蚩尤改为支付 2 点生命")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[0][0], 8, "蚩尤应支付减费后的 2 点生命")
	assert_eq(b.energy_max[0], 18)


func test_h24_discount_can_pay_for_an_active_skill() -> void:
	var b := _battle_team(["h17", "h24", "test_p0_2"], 7, 2)
	assert_true(b.select_active(0, -1, false, true), "2 能主动技应可由并封减到 1 能")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.energy_max[0], 18)
	assert_eq(b.energy[0], 2, "支付 1 能后由回合被动补回 1 能")


func test_h24_discount_uses_the_final_action_cost_after_item_modifiers() -> void:
	var b := _battle_team(["h24", "test_p0_1", "test_p0_2"], 6, 4)
	var scroll_slot: int = b.give_item(0, ItemCatalog.make("t2_baolie"))
	assert_true(b.use_item(0, scroll_slot), "爆裂卷轴应可与并封同时提交")
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true))
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.energy_max[0], 18)
	assert_eq(b.energy[0], 6,
		"大波3能先受卷轴减2，再由并封减1至0费，回合末获得1点被动能量")


func test_h24_does_not_spend_cap_when_items_already_reduce_the_action_to_zero() -> void:
	var b := _battle_team(["h24", "test_p0_1", "test_p0_2"], 6, 4)
	for _i in range(3):
		var slot: int = b.give_item(0, ItemCatalog.make("t2_baolie"))
		assert_true(b.use_item(0, slot), "三张爆裂卷轴应可把本次大波最终费用压到 0")
	assert_false(b.select_action(0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"爆裂卷轴已把大波降至0费时，不得再支付上限启用并封")
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK))
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.energy_max[0], 20,
		"道具已把最终行动费用降到 0 时，并封不应白白扣除能量上限")
	assert_eq(b.energy[0], 6, "0 费大波后只获得本回合 1 点被动能量")


func test_h24_zero_cost_active_silenced_provider_and_forced_fallback_do_not_spend_cap() -> void:
	var zero_active := _battle_team(["h22", "h24", "test_p0_2"], 5, 4)
	assert_false(zero_active.select_active(0, -1, false, true),
		"0 费主动技不得白白支付能量上限")

	var silenced := _battle_team(["test_p0_0", "h24", "test_p0_2"], 5, 4)
	silenced.set_status(0, 1, "silenced", 1)
	assert_false(silenced.select_action(
		0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true),
		"被沉默的未出战并封不能继续提供能力")

	var exhausted := _battle("h24", 6, 6)
	assert_true(exhausted.select_action(
		0, ActionDef.Action.BIG_ATTACK, -1, false, false, false, true))
	exhausted.item_buffs[0]["exhausted_next"] = true
	exhausted.select_action(1, ActionDef.Action.CHARGE)
	exhausted.resolve()
	assert_eq(exhausted.energy_max[0], 20,
		"动作被强制回退为攒时必须清除并封选择，不得扣除上限")


# ---- h22 毕方 焚天火兆（2026-08-08 重设计：下一回合结束时双方能量归零）----
# 免费·占动作·每局 2 次；火兆是全局公开期限，换人/阵亡不取消，且同一时间只存在一个。

func test_h22_cast_schedules_next_round_without_immediate_burn_or_shield() -> void:
	var b := _battle("h22", 5, 8)
	assert_true(b.select_active(0), "焚天火兆可用")
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.energy[0], 10, "施放回合只结算被动能量，不立即清空")
	assert_eq(b.energy[1], 8, "敌方波的费用被回合被动抵消，不立即清空")
	assert_eq(b.hp[0][0], 8, "新版不再附带护盾，毕方正常承受波的 1 点伤害")
	assert_eq(b.shield[0][0], 0, "新版不再获得护盾")
	assert_eq(b.energy_burn_turn, b.turn_number, "火兆瞄准当前选择阶段对应的回合末")
	assert_false(_has_event(result, "h22_energy_burn"), "施放回合不触发能量归零")


func test_h22_burns_both_teams_after_all_next_round_energy_gains() -> void:
	var b := _battle("h22", 5, 8)
	b.energy_max = [16, 12]
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.energy, [0, 0], "下一回合的攒与被动能量结算完成后，双方能量全部归零")
	assert_eq(b.energy_max, [16, 12], "焚天火兆只清当前能量，不恢复双方动态上限")
	assert_eq(b.energy_burn_turn, -1, "归零后清除火兆期限")
	assert_true(_has_event(result, "h22_energy_burn"), "结算流应公开记录焚天火兆触发")


func test_h22_burn_survives_switching_out() -> void:
	var b := _battle_team(["h22", "test_p0_1", "test_p0_2"], 5, 12)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_true(b.select_switch(0, 1), "毕方可以在倒计时回合换下")
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.active_index[0], 1, "毕方已经下场")
	assert_eq(b.energy, [0, 0], "火兆与毕方本人解绑，换下后仍清空双方能量")
	assert_true(_has_event(result, "h22_energy_burn"))


func test_h22_pending_global_omen_blocks_recast_from_either_team() -> void:
	var b := _battle_vs(
		["h22", "test_p0_1", "test_p0_2"],
		["h22", "test_p1_1", "test_p1_2"], 5, 12)
	b.select_active(0)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_false(b.can_use_active(0), "本方不能在同一火兆期间重复发动")
	assert_false(b.can_use_active(1), "火兆是全局期限，敌方毕方也不能叠加或刷新")


func test_h22_cap_two_per_game_after_each_burn_resolves() -> void:
	var b := _battle("h22", 5, 20)
	for cast_index in range(2):
		assert_true(b.select_active(0), "第 %d 次焚天火兆可用" % (cast_index + 1))
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
		_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)

	assert_false(b.can_use_active(0), "每局上限 2 次，第 3 次不可用")
	assert_eq(int(b.get_status(0, 0, "active_uses", 0)), 2)


func test_h22_requires_active_bifang() -> void:
	var b := _battle_team(["test_p0_0", "h22", "test_p0_2"], 5, 8)
	assert_false(b.can_use_active(0), "毕方在替补时不能发动主动技")
