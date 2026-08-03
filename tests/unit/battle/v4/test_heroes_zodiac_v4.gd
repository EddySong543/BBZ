extends GutTest

## ============================================================================
## 12 生肖（h01-h12）技能测试 —— 锁定【当前代码行为】。
##
## 取代旧 test_heroes_batch1-8_v4（那些测的是上一代英雄 numu/tianwei/qieyun…，
## 注册表 _HERO_SKILL_SCRIPTS 现已是 dunshu/panniu/lianpu/… 新阵容）。
## 现版本只发布 12 生肖；后续新增英雄再加测试文件。
##
## 经济基线（B·2026-06-16 已实装）：能量半能制(1 能=2 半能)；大波 6 半能(3 能)；
##   被动 +1 能/回合已恢复(2026-07-03·PASSIVE_ENERGY_GAIN=2)；HP 半点制(1.0 HP=2 半点)。
## ============================================================================

const PASSIVE := 2   # 被动 +1 能/回合（2026-07-03 恢复·= ActionDef.PASSIVE_ENERGY_GAIN）


func _hero(id: String, hp: int = 5) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


## P0 slot0 = 被测生肖；其余 plain（"test_" 前缀，无技能）。e = 双方起手半能。
func _battle(hero_id: String, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = [_hero(hero_id, hp), _hero("test_p1_1"), _hero("test_p1_2")]
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


## 自定义队伍（被测英雄在指定槽，便于测 on_switch_in / 救援等）。
func _battle_team(p0_ids: Array, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = []
	for id in p0_ids:
		p1.append(_hero(id, hp))
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


func _battle_teams(p0_ids: Array, p1_ids: Array, hp: int = 5, e: int = 8) -> BattleCore:
	var p0_team: Array = []
	var p1_team: Array = []
	for id in p0_ids:
		p0_team.append(_hero(id, hp))
	for id in p1_ids:
		p1_team.append(_hero(id, hp))
	var b := BattleCore.new()
	b.setup(p0_team, p1_team, 555)
	b.energy = [e, e]
	return b


func _has_event(result: Dictionary, event_id: String, player: int = -1) -> bool:
	for event in result.get("events", []):
		if String(event.get("id", "")) == event_id and (player < 0 or int(event.get("player", -1)) == player):
			return true
	return false


func _event_count(result: Dictionary, event_id: String, player: int = -1) -> int:
	var count: int = 0
	for event in result.get("events", []):
		if String(event.get("id", "")) == event_id and (player < 0 or int(event.get("player", -1)) == player):
			count += 1
	return count


func _resolve(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h01 虚日 步虚无有乡（在场时己方主动来源得能 +0.5 能=+1 半能·回合被动能量不吃加成）----

func test_h01_dunshu_adds_half_to_every_energy_gain() -> void:
	var b := _battle("h01", 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	# 虚日：攒(2+步虚无有乡1) + 被动(2·回合被动能量不加成·2026-07-04) = +5 半能
	assert_eq(b.energy[0], 8 + 5, "虚日步虚无有乡：攒 +3 + 被动 +2（回合被动能量不加成）= +5 半能")
	# 对照 plain：攒2 + 被动2 = +4
	assert_eq(b.energy[1], 8 + 4, "plain 对照：攒 +2 + 被动 +2 = +4 半能")


# ---- h02 牛金 玄金不动相（挡下波/大波 → 己方下次波升级为大波）----

func test_h02_blocking_wave_upgrades_next_wave_to_big_wave() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	assert_eq(b.hp[0][0], 14, "防挡下波，牛金不受伤")
	assert_true(b.upgrade_next_wave[0], "成功挡下波后应留下团队升级")
	b.energy[0] = 6
	var energy_before: int = b.energy[0]

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 6, "下次波应按大波造成 4 半点伤害")
	assert_eq(b.energy[0], energy_before, "升级波仍只支付波的 2 半能；回合被动恰好补回")
	assert_eq(int(b.to_snapshot()["last_action"][0]), ActionDef.Action.ATTACK, "回合历史仍记录为波")
	assert_false(b.upgrade_next_wave[0], "升级波尝试后立即消费")


func test_h02_blocking_big_wave_arms_the_same_wave_upgrade() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.hp[0][0], 14, "大防挡下大波，牛金不受伤")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 6, "挡下大波后同样升级下一次波，而不是升级大波")


func test_h02_big_defend_blocking_wave_also_arms_upgrade() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.ATTACK)

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 6, "技能只要求挡下攻击；大防挡波也应升级下一次波")


func test_h02_failed_defend_against_big_wave_does_not_arm_upgrade() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.hp[0][0], 10, "防挡不住大波")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 10, "没有成功挡下攻击，就不产生升级")


func test_h02_upgrade_survives_switch_and_can_be_used_by_teammate() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)

	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "牛金切下、队友上场")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 6, "升级属于全队，队友的波按大波伤害并穿防")


func test_h02_upgrade_is_consumed_once_by_next_wave() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 6, "第一发升级波造成 4 半点；第二发普通波重新被防挡下")


func test_h02_normal_big_wave_does_not_consume_wave_upgrade() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE)
	assert_true(b.upgrade_next_wave[0], "普通大波不消费下一次波升级")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 2, "普通大波先打 4 半点但不消费；之后升级波再打 4 半点")


func test_h02_upgraded_wave_is_blocked_by_big_defend_and_consumed() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_false(b.upgrade_next_wave[0], "升级波被大防挡住也会消费")
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 10, "升级波只到大波档：大防挡住并消费，后续普通波也被防挡住")


func test_h02_blocked_item_hit_does_not_arm_upgrade() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	var item_index: int = b.give_item(1, ItemCatalog.make("t1_feibiao"))
	b.use_item(1, item_index)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.CHARGE)

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 10, "防挡下道具 hit 不等于挡下波，不得升级后续波")


func test_h02_blocked_attack_active_does_not_arm_upgrade() -> void:
	var p1: Array = [_hero("h02", 7), _hero("test_p1_1"), _hero("test_p1_2")]
	var p2: Array = [_hero("h10"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [20, 20]
	b.set_status(1, 0, "jianqi", 1)
	b.select_action(0, ActionDef.Action.BIG_DEFEND)
	assert_true(b.select_active(1), "昴日有剑气时可用攻击型主动技")
	b.resolve()
	assert_false(b.upgrade_next_wave[0], "挡下攻击型主动技不触发玄金不动相")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 10, "未触发升级时，后续普通波仍被防挡住")


func test_h02_upgraded_wave_keeps_wave_identity_for_item_checks() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	b.energy[0] = 6
	var item_index: int = b.give_item(0, ItemCatalog.make("t2_baolie"))
	b.use_item(0, item_index)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.energy[0], 6, "爆裂卷轴只认原选招大波，不应给升级波减费")
	assert_eq(b.hp[1][0], 6, "道具不改选招身份，但升级 hit 仍按大波造成伤害")


func test_h02_wave_nullified_by_decoy_still_consumes_upgrade() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)

	var item_index: int = b.give_item(1, ItemCatalog.make("t2_caoren"))
	b.use_item(1, item_index)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_switch(1, 1)
	b.resolve()
	assert_eq(b.hp[1][1], 10, "替身草人令升级波落空")
	assert_false(b.upgrade_next_wave[0], "升级波落空仍会消费")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][1], 10, "落空已经消费升级，下一次普通波被防挡下")


func test_h02_upgrade_applies_to_both_h16_double_wave_hits() -> void:
	var b := _battle_team(["h02", "h16", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	b.select_action(0, ActionDef.Action.ATTACK)
	assert_true(b.select_double(0, true), "广寒出战时可把升级波再做一次")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 2, "疾风复制同一升级波：两段都按大波各造成 4 半点")
	assert_false(b.upgrade_next_wave[0], "疾风双段只消费同一个升级状态")


func test_h02_upgrade_and_h22_omen_can_resolve_together() -> void:
	var b := _battle_team(["h02", "h22", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.select_active(0), "毕方蓄出焚天火兆")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.upgrade_next_wave[0], "牛金留下的波升级仍在")
	assert_true(b.pierce_next_attack[0], "毕方留下的穿大防火兆同时存在")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.hp[1][0], 6, "升级提供大波伤害，火兆再让这发升级波穿过大防")
	assert_false(b.upgrade_next_wave[0], "波升级在这次波上消费")
	assert_false(b.pierce_next_attack[0], "火兆与升级波在同一次波上各自消费")


func test_h02_can_rearm_after_blocking_an_enemy_upgraded_wave() -> void:
	var p1: Array = [_hero("h02", 7), _hero("test_p1_1"), _hero("test_p1_2")]
	var p2: Array = [_hero("h02", 7), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [20, 20]
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_false(b.upgrade_next_wave[0], "进攻方升级波已被大防挡住并消费")
	assert_true(b.upgrade_next_wave[1], "防守方挡下的原选招仍是基础波，应为自己蓄出升级")

	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	assert_eq(b.hp[0][0], 10, "防守方蓄出的升级波按大波穿过普通防并造成 4 半点")


func test_h02_taking_damage_no_longer_grants_shield() -> void:
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.shield[0][0] + b.shield[0][1] + b.shield[0][2], 0,
		"旧版受伤发盾机制应完全移除")


# ---- h03 尾火 白额雷音（基础攻击对攻先制；致死则取消敌方基础攻击）----

func test_h03_baieleiyin_no_longer_doubles_on_hit() -> void:
	var b := _battle_team(["h03", "h10", "test_p1_2"], 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(0, 1, "jianqi", 0)), 1,
		"白额雷音不再拆分命中，鸡只获得 1 层剑气")


func test_h03_nonlethal_base_attack_clash_keeps_both_attacks() -> void:
	for pair in [
		[ActionDef.Action.ATTACK, ActionDef.Action.ATTACK, 2, 2],
		[ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK, 4, 2],
		[ActionDef.Action.BIG_ATTACK, ActionDef.Action.ATTACK, 2, 4],
		[ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_ATTACK, 4, 4],
	]:
		var b := _battle("h03", 5, 20)
		var hp0: int = b.hp[0][0]
		var hp1: int = b.hp[1][0]
		b.select_action(0, int(pair[0]))
		b.select_action(1, int(pair[1]))
		var result: Dictionary = b.resolve()
		assert_eq(b.hp[0][0], hp0 - int(pair[2]), "非致死时敌方攻击照常结算")
		assert_eq(b.hp[1][0], hp1 - int(pair[3]), "尾火攻击照常结算")
		assert_false(_has_event(result, "base_attack_cancelled"), "非致死不得断招")


func test_h03_lethal_base_attack_clash_cancels_from_p1_side_for_all_pairings() -> void:
	for pair in [
		[ActionDef.Action.ATTACK, ActionDef.Action.ATTACK],
		[ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK],
		[ActionDef.Action.BIG_ATTACK, ActionDef.Action.ATTACK],
		[ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_ATTACK],
	]:
		var b := _battle_teams(
			["test_p0_0", "test_p0_1", "test_p0_2"],
			["h03", "test_p1_1", "test_p1_2"], 5, 20)
		b.hp[0][0] = 1
		var tiger_hp: int = b.hp[1][0]
		b.select_action(0, int(pair[0]))
		b.select_action(1, int(pair[1]))
		var result: Dictionary = b.resolve()
		assert_lte(b.hp[0][0], 0, "P1 尾火应先击杀敌方攻击英雄")
		assert_eq(b.hp[1][0], tiger_hp, "致死后敌方基础攻击应被取消")
		assert_true(_has_event(result, "base_attack_cancelled", 0), "应记录 P0 基础攻击被断")


func test_h03_lethal_base_attack_clash_cancels_from_p0_side() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[1][0] = 1
	var tiger_hp: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	var result: Dictionary = b.resolve()
	assert_lte(b.hp[1][0], 0, "P0 尾火应先击杀敌方攻击英雄")
	assert_eq(b.hp[0][0], tiger_hp, "P0 尾火致死后不受敌方大波反击")
	assert_true(_has_event(result, "base_attack_cancelled", 1), "应记录 P1 基础攻击被断")


func test_h03_mirror_keeps_simultaneous_resolution() -> void:
	var b := _battle_teams(
		["h03", "test_p0_1", "test_p0_2"],
		["h03", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[0][0] = 2
	b.hp[1][0] = 2
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_lte(b.hp[0][0], 0, "同优先级镜像应保留同步结算")
	assert_lte(b.hp[1][0], 0, "同优先级镜像应允许同拍双倒")
	assert_false(_has_event(result, "base_attack_cancelled"), "同优先级不得按玩家座位断招")


func test_h03_in_reserve_does_not_grant_team_priority() -> void:
	var b := _battle_teams(
		["test_p0_0", "h03", "test_p0_2"],
		["test_p1_0", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[1][0] = 1
	var p0_hp: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], p0_hp - 2, "替补尾火不能让出战白板断掉敌方攻击")
	assert_false(_has_event(result, "base_attack_cancelled"), "替补技能不得触发")


func test_h03_shield_prevents_kill_so_enemy_attack_resolves() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[1][0] = 1
	b.shield[1][0] = 2
	var tiger_hp: int = b.hp[0][0]
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.ATTACK)
	assert_eq(b.hp[1][0], 1, "护盾吸收后敌方攻击英雄仍存活")
	assert_eq(b.hp[0][0], tiger_hp - 2, "未实际击杀时敌方攻击照常结算")


func test_h03_huanhun_prevents_kill_so_enemy_attack_resolves() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[1][0] = 1
	var item_index: int = b.give_item(1, ItemCatalog.make("t2_huanhundan"))
	assert_true(b.use_item(1, item_index), "敌方应可使用还魂丹")
	var tiger_hp: int = b.hp[0][0]
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.ATTACK)
	assert_eq(b.hp[1][0], 1, "还魂应让敌方攻击英雄保留 0.5 HP")
	assert_eq(b.hp[0][0], tiger_hp - 2, "还魂成功后敌方攻击照常结算")


func test_h03_lethal_priority_cancels_only_base_attack_not_item_hit() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[1][0] = 1
	var item_index: int = b.give_item(1, ItemCatalog.make("t1_feibiao"))
	assert_true(b.use_item(1, item_index), "敌方应可使用飞镖")
	var tiger_hp: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], tiger_hp - 1, "敌方基础攻击被断，但动作前道具伤害仍应结算")
	assert_true(_has_event(result, "base_attack_cancelled", 1), "敌方基础攻击应被断")


func test_h03_own_pre_item_kill_does_not_count_as_skill_kill() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[1][0] = 1
	var item_index: int = b.give_item(0, ItemCatalog.make("t1_feibiao"))
	assert_true(b.use_item(0, item_index), "尾火应可使用飞镖")
	var tiger_hp: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], tiger_hp - 2, "前置道具先击杀不归因于白额雷音，敌方攻击仍应结算")
	assert_false(_has_event(result, "base_attack_cancelled"), "只有尾火基础攻击实际击杀才能断招")


func test_h03_cancelled_wave_still_consumes_team_attack_buffs_and_cost() -> void:
	var b := _battle_teams(
		["h03", "test_p0_1", "test_p0_2"],
		["test_p1_0", "h02", "h22"], 5, 20)
	b.hp[1][0] = 1
	b.upgrade_next_wave[1] = true
	b.pierce_next_attack[1] = true
	var enemy_energy_before: int = b.energy[1]
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_true(_has_event(result, "base_attack_cancelled", 1), "敌方强化波应被白额雷音断招")
	assert_false(b.upgrade_next_wave[1], "牛金留下的波升级在攻击尝试时消费，不因断招返还")
	assert_false(b.pierce_next_attack[1], "毕方留下的火兆在攻击尝试时消费，不因断招返还")
	assert_eq(b.energy[1], enemy_energy_before, "波照常付费；回合被动能量只抵消本次波费用")
	assert_eq(int(b.to_snapshot()["last_action"][1]), ActionDef.Action.ATTACK,
		"被断招仍记录原本提交的波，不改动作历史")


func test_h03_attacks_gain_no_extra_penetration_against_big_defend() -> void:
	for action in [ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK]:
		var b := _battle("h03", 5, 20)
		var enemy_hp: int = b.hp[1][0]
		b.select_action(0, action)
		b.select_action(1, ActionDef.Action.BIG_DEFEND)
		var result: Dictionary = b.resolve()
		assert_eq(b.hp[1][0], enemy_hp, "白额雷音只改对攻顺序，波和大波仍会被大防挡下")
		assert_false(_has_event(result, "base_attack_cancelled"), "敌方未使用基础攻击时不能触发断招")


func test_h03_lethal_priority_cancels_all_h16_double_attack_hits() -> void:
	var b := _battle_teams(
		["h03", "test_p0_1", "test_p0_2"],
		["h16", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[1][0] = 1
	var tiger_hp: int = b.hp[0][0]
	assert_true(b.select_action(0, ActionDef.Action.ATTACK))
	assert_true(b.select_action(1, ActionDef.Action.ATTACK))
	assert_true(b.select_double(1, true), "敌方广寒应可附加第二次波")
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], tiger_hp, "广寒的两条基础攻击 hit 都应被取消")
	assert_eq(int(b.get_status(1, 0, "jifeng_uses", 0)), 1, "已提交的疾风次数仍应消费")
	assert_true(_has_event(result, "base_attack_cancelled", 1), "敌方双波应作为本次基础攻击被断")


func test_h03_nonlethal_clash_keeps_both_h16_attack_hits() -> void:
	var b := _battle_teams(
		["h03", "test_p0_1", "test_p0_2"],
		["h16", "test_p1_1", "test_p1_2"], 5, 20)
	var tiger_hp: int = b.hp[0][0]
	var enemy_hp: int = b.hp[1][0]
	assert_true(b.select_action(0, ActionDef.Action.ATTACK))
	assert_true(b.select_action(1, ActionDef.Action.ATTACK))
	assert_true(b.select_double(1, true), "敌方广寒应可附加第二次波")
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], tiger_hp - 4, "非致死时广寒的两条基础攻击 hit 都应结算")
	assert_eq(b.hp[1][0], enemy_hp - 2, "尾火的先击照常造成一次波伤害")
	assert_false(_has_event(result, "base_attack_cancelled"), "未实际击杀不得取消疾风双波")


func test_h03_does_not_cancel_enemy_attack_active() -> void:
	var b := _battle_teams(
		["h03", "test_p0_1", "test_p0_2"],
		["h10", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[0][0] = 3
	b.hp[1][0] = 1
	b.set_status(1, 0, "jianqi", 1)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK))
	assert_true(b.select_active(1), "昴日有剑气时应能通过正式入口提交攻击型主动技")
	var result: Dictionary = b.resolve()
	assert_lte(b.hp[1][0], 0, "尾火基础攻击照常击杀敌方")
	assert_lte(b.hp[0][0], 0, "攻击型主动技不属于基础攻击对攻，仍按同步模型结算")
	assert_false(_has_event(result, "base_attack_cancelled"), "攻击型主动技不得被白额雷音取消")


func test_h03_lethal_guardian_rescue_keeps_enemy_attack() -> void:
	var b := _battle_teams(
		["h03", "test_p0_1", "test_p0_2"],
		["test_p1_0", "h23", "test_p1_2"], 5, 20)
	b.hp[1][0] = 1
	var tiger_hp: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[1][0], 1, "天狗护主应救下原攻击英雄")
	assert_eq(b.hp[0][0], tiger_hp - 4, "原基础攻击与天狗反击均应照常结算")
	assert_false(_has_event(result, "base_attack_cancelled"), "击中护主天狗不算击杀敌方攻击英雄")


# ---- h04 房日 十方无次第（波 / 大波可指定任一存活敌方英雄）----

func test_h04_wave_can_target_enemy_reserve() -> void:
	var b := _battle("h04", 5, 20)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1), "房日的波应可指定敌方替补")
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][0], 10, "敌方出战位不应受到定向替补的波")
	assert_eq(b.hp[1][1], 8, "指定替补应受到 1.0 HP 的波伤害")
	var found_target_event := false
	for event in result.get("events", []):
		if String(event.get("id", "")) == "damage_taken" \
				and int(event.get("player", -1)) == 1 and int(event.get("slot", -1)) == 1:
			found_target_event = true
	assert_true(found_target_event, "伤害事件必须携带实际受击替补槽")


func test_h04_big_wave_targets_reserve_and_uses_normal_defense_rules() -> void:
	var b := _battle("h04", 5, 20)
	assert_true(b.select_action(0, ActionDef.Action.BIG_ATTACK, 2), "房日的大波应可指定敌方替补")
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10, "普通防被穿时，出战位仍不应替指定目标承伤")
	assert_eq(b.hp[1][2], 6, "指定替补应承受大波 2.0 HP 伤害")

	var b2 := _battle("h04", 5, 20)
	assert_true(b2.select_action(0, ActionDef.Action.BIG_ATTACK, 2))
	b2.select_action(1, ActionDef.Action.BIG_DEFEND)
	var result: Dictionary = b2.resolve()
	assert_eq(b2.hp[1][2], 10, "大防仍应挡住指向替补的大波")
	var found_block := false
	for event in result.get("events", []):
		if String(event.get("id", "")) == "big_defend_block" and int(event.get("slot", -1)) == 2:
			found_block = true
	assert_true(found_block, "格挡事件必须携带实际受保护的替补槽")


func test_h04_target_stays_on_same_hero_when_enemy_switches() -> void:
	var b := _battle("h04", 5, 20)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1))
	assert_true(b.select_switch(1, 2), "敌方应可同拍换到另一名替补")
	b.resolve()

	assert_eq(b.active_index[1], 2, "敌方已换到槽 2")
	assert_eq(b.hp[1][1], 8, "房日锁定的是英雄槽 1，不应随敌方换位改目标")
	assert_eq(b.hp[1][2], 10, "新出战英雄不是已指定目标，不应承伤")


func test_h04_killing_reserve_does_not_request_active_death_switch() -> void:
	var b := _battle("h04", 5, 20)
	b.hp[1][1] = 1
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1))
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_lte(b.hp[1][1], 0, "指定替补应被击杀")
	assert_eq(b.active_index[1], 0, "敌方出战位保持不变")
	assert_false(b.pending_death_switch[1], "替补阵亡不应要求出战死亡换人")
	var found_death := false
	for event in result.get("events", []):
		if String(event.get("id", "")) == "hero_died" and int(event.get("slot", -1)) == 1:
			found_death = true
	assert_true(found_death, "替补阵亡仍须进入统一死亡事件流")


func test_h04_does_not_retarget_when_selected_enemy_dies_before_hit() -> void:
	var b := _battle("h04", 5, 20)
	b.hp[1][1] = 1
	b.pending_damage[1][1] = 1
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1))
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][0], 10, "指定目标在动作前阵亡后，不得自动改打出战位")
	assert_eq(b.hp[1][2], 10, "指定目标在动作前阵亡后，不得自动改打其他替补")
	assert_true(_has_event(result, "attack_target_unavailable", 1), "应记录目标已不可用的落空事件")


func test_h04_targeting_requires_active_living_unsilenced_h04() -> void:
	var plain := _battle("test_plain", 5, 20)
	assert_false(plain.select_action(0, ActionDef.Action.ATTACK, 1), "普通英雄不能显式指定替补")

	var reserve := _battle_team(["test_p1_0", "h04", "test_p1_2"], 5, 20)
	assert_false(reserve.select_action(0, ActionDef.Action.ATTACK, 1), "替补席房日不提供团队自由选敌")

	var dead_target := _battle("h04", 5, 20)
	dead_target.hp[1][1] = 0
	assert_false(dead_target.select_action(0, ActionDef.Action.ATTACK, 1), "不能指定已阵亡敌方英雄")
	assert_false(dead_target.select_action(0, ActionDef.Action.ATTACK, 9), "不能指定越界敌方槽")

	var silenced := _battle("h04", 5, 20)
	silenced.set_status(0, 0, "silenced", 1)
	assert_false(silenced.select_action(0, ActionDef.Action.ATTACK, 1), "沉默中的房日不能自由选敌")


func test_h04_attack_without_explicit_target_keeps_standard_active_targeting() -> void:
	var b := _battle("h04", 5, 20)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK), "旧调用未传目标时仍应合法")
	assert_true(b.select_switch(1, 1))
	b.resolve()

	assert_eq(b.hp[1][0], 10, "兼容调用不锁旧出战英雄")
	assert_eq(b.hp[1][1], 8, "未显式指定时仍按标准规则攻击结算时出战位")


func test_h04_old_repeat_energy_mechanism_is_removed() -> void:
	var b := _battle("h04", 5, 0)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	var result: Dictionary
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.DEFEND)
	result = b.resolve()

	assert_eq(b.energy[0], 8, "连续两回合攒只获得两次攒能与两次回合被动，不再收重复动作能量")
	assert_false(_has_event(result, "repeat_energy"), "旧重复动作产能事件应完全退役")


func test_h03_can_cancel_h04_attack_even_when_h04_targets_reserve() -> void:
	var b := _battle_teams(
		["h04", "test_p0_1", "test_p0_2"],
		["h03", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[0][0] = 1
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1))
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][1], 10, "房日的出招英雄被白额雷音击杀后，定向替补的波也应被断")
	assert_true(_has_event(result, "base_attack_cancelled", 0), "自由目标不能绕过白额雷音断招")


# ---- h05 亢金 龙御极（攻击被挡 → 目标获破绽；下次攻击穿防）----

func test_h05_blocked_wave_and_big_wave_apply_opening() -> void:
	var wave := _battle("h05", 5, 20)
	var wave_result: Dictionary
	wave.select_action(0, ActionDef.Action.ATTACK)
	wave.select_action(1, ActionDef.Action.DEFEND)
	wave_result = wave.resolve()
	assert_eq(wave.hp[1][0], 10, "波被防完整挡下")
	assert_eq(int(wave.get_status(1, 0, "opening", 0)), 1, "波被成功防御 → 目标获破绽")
	assert_true(_has_event(wave_result, "defend_block", 1), "应记录普通防御成功")
	assert_true(_has_event(wave_result, "opening_applied", 1), "应记录破绽附着供界面反馈")

	var big_wave := _battle("h05", 5, 20)
	var big_result: Dictionary
	big_wave.select_action(0, ActionDef.Action.BIG_ATTACK)
	big_wave.select_action(1, ActionDef.Action.BIG_DEFEND)
	big_result = big_wave.resolve()
	assert_eq(big_wave.hp[1][0], 10, "大波被大防完整挡下")
	assert_eq(int(big_wave.get_status(1, 0, "opening", 0)), 1, "大波被成功防御 → 目标同样获破绽")
	assert_true(_has_event(big_result, "big_defend_block", 1), "应记录大防成功")
	assert_true(_has_event(big_result, "opening_applied", 1), "大防成功后同样应记录破绽附着")


func test_h05_and_h02_attacker_and_defender_block_hooks_both_resolve() -> void:
	var b := _battle_teams(
		["h05", "test_p0_1", "test_p0_2"],
		["h02", "test_p1_1", "test_p1_2"], 5, 20)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)

	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "龙的攻击被挡后仍应留下破绽")
	assert_true(b.upgrade_next_wave[1], "牛成功防御后仍应为己方蓄出威势")


func test_h05_unblocked_attacks_do_not_apply_opening() -> void:
	var wave := _battle("h05", 5, 20)
	_resolve(wave, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(wave.hp[1][0], 8, "波直接命中")
	assert_eq(int(wave.get_status(1, 0, "opening", 0)), 0, "未被成功防御 → 不产生破绽")

	var big_wave := _battle("h05", 5, 20)
	_resolve(big_wave, ActionDef.Action.BIG_ATTACK, ActionDef.Action.DEFEND)
	assert_eq(big_wave.hp[1][0], 6, "防挡不住大波")
	assert_eq(int(big_wave.get_status(1, 0, "opening", 0)), 0, "选择防但没有挡住，也不产生破绽")


func test_h05_opening_lets_teammate_wave_pierce_defend_and_consumes() -> void:
	var b := _battle_team(["h05", "test_p1_1", "test_p1_2"], 5, 20)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "龙先逼出防御并留下破绽")

	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "换队友登场兑现窗口")

	var result: Dictionary
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.DEFEND)
	result = b.resolve()
	assert_eq(b.hp[1][0], 8, "队友的普通波借破绽穿过防")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 0, "下一次攻击后破绽消耗")
	assert_false(_has_event(result, "defend_block", 1), "穿防攻击不应被普通防挡下")
	assert_true(_has_event(result, "opening_used", 1), "应记录破绽兑现")


func test_h05_opening_is_blocked_by_big_defend_but_still_consumed() -> void:
	var b := _battle_team(["h05", "test_p1_1", "test_p1_2"], 5, 20)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	var result: Dictionary
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	result = b.resolve()
	assert_eq(b.hp[1][0], 10, "破绽只使攻击穿防，大防仍能挡住")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 0, "即使被大防挡住，下一次攻击也已消费破绽")
	assert_true(_has_event(result, "big_defend_block", 1), "穿防攻击应被大防挡下")


func test_h05_opening_consumes_on_next_attack_even_without_defense() -> void:
	var b := _battle("test_p1_0", 5, 20)
	b.set_status(1, 0, "opening", 1)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 8, "不防时攻击照常命中")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 0, "破绽属于下一次攻击，不等到目标再次防御才消费")


func test_h05_opening_persists_on_the_marked_hero_through_switches() -> void:
	var b := _battle_teams(
		["h05", "test_p0_1", "test_p0_2"],
		["test_p1_0", "test_p1_1", "test_p1_2"], 5, 20)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)

	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 1)
	b.resolve()
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "破绽随原英雄留在场下")
	assert_eq(int(b.get_status(1, 1, "opening", 0)), 0, "破绽不会转移给新出战英雄")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "攻击其他英雄不会消费原目标的破绽")

	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 0)
	b.resolve()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 8, "原英雄重新登场后，其破绽仍可被攻击兑现")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 0, "兑现后从该英雄身上移除")


func test_h05_opening_is_nonstacking_and_big_defend_rearms_one_layer() -> void:
	var b := _battle("h05", 5, 20)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "第一次被挡留下 1 个破绽")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.hp[1][0], 10, "已有破绽只到穿防，第二次仍可被大防挡住")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1,
		"旧破绽先消费、龙因再次被成功防御再留下一个；状态始终不叠加")


func test_h05_item_hit_neither_applies_nor_consumes_opening() -> void:
	var b := _battle("h05", 5, 20)
	var blocked_item: int = b.give_item(0, ItemCatalog.make("t1_feibiao"))
	b.use_item(0, blocked_item)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 0, "被挡下的独立道具伤害不触发龙御极")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "基础攻击被挡后正常留下破绽")

	var connecting_item: int = b.give_item(0, ItemCatalog.make("t1_feibiao"))
	b.use_item(0, connecting_item)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 9, "飞镖造成 0.5 点独立伤害")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "独立道具伤害不消费留给攻击的破绽")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 7, "后续基础波才借破绽穿过防")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 0, "基础攻击兑现后破绽移除")


func test_attack_active_does_not_consume_h05_opening() -> void:
	var b := _battle_teams(
		["h10", "test_p0_1", "test_p0_2"],
		["test_p1_0", "test_p1_1", "test_p1_2"], 5, 20)
	b.set_status(0, 0, "jianqi", 1)
	b.set_status(1, 0, "opening", 1)
	assert_true(b.select_active(0), "昴日有剑气时可以使用攻击型主动技")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_lt(b.hp[1][0], 10, "攻击型主动技照常造成伤害")
	assert_eq(int(b.get_status(1, 0, "opening", 0)), 1, "攻击型主动技不是基础攻击，不消费破绽")


# ---- h06 翼火 神打（命中叠毒素；再次被命中时引爆）----

func test_h06_shenda_stacks_poison_on_hit() -> void:
	var b := _battle("h06", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 1, "翼火命中 → 叠 1 层毒素")

func test_h06_shenda_detonates_on_second_hit() -> void:
	# 第 1 击：叠毒素（不引爆）；第 2 击：先引爆 1 层（+1 半点）再叠新毒素。
	var b := _battle("h06", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)   # 10→8，毒=1
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)   # 引爆1(+1) + 波2 = -3 → 8→5
	assert_eq(b.hp[1][0], 5, "第2击引爆1层(0.5)+波(1.0)=1.5 → 10-2-3=5")
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 1, "引爆后清空、再叠新 1 层")


# ---- h07 星日 千里自在风（登场 0.5 冲撞）----

func test_h07_qianlizizaifeng_chongzhuang_on_switch_in() -> void:
	var b := _battle_team(["test_p1_0", "h07", "test_p1_2"], 5, 8)
	b.select_switch(0, 1)                       # 切到马
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "已切到马")
	assert_eq(b.hp[1][0], 10 - 1, "马登场冲撞 0.5HP = 1 半点 给对手出战(对手 HP5=10半)")


# ---- h08 鬼金 不坠神言（未挡到基础攻击的大防由队伍保留，实际挡下一次攻击后消耗）----

func test_h08_unused_big_defend_is_retained_for_team() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	b.select_action(0, ActionDef.Action.BIG_DEFEND)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_true(b.retained_big_defend[0], "鬼金空放大防后，己方应保留一次大防")
	assert_true(_has_event(result, "buzhui_shenyan_retained", 0), "应记录不坠神言留存事件")


func test_h08_big_defend_that_blocks_attack_is_not_retained() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	b.select_action(0, ActionDef.Action.BIG_DEFEND)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	var result: Dictionary = b.resolve()

	assert_false(b.retained_big_defend[0], "本回合大防已挡住大波，不应再保留")
	assert_true(_has_event(result, "big_defend_block", 0), "大防应按原防御门挡住大波")
	assert_false(_has_event(result, "buzhui_shenyan_retained", 0), "已兑现的大防不应触发留存")


func test_h08_retained_big_defend_survives_switch_and_blocks_big_wave() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)

	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "鬼金下场后由队友出战")
	assert_true(b.retained_big_defend[0], "保留大防属于队伍，换人后仍存在")

	var hp_before: int = b.hp[0][1]
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][1], hp_before, "队友未选防也应被保留大防挡住大波")
	assert_false(b.retained_big_defend[0], "保留大防实际挡下一次攻击后消耗")
	assert_true(_has_event(result, "buzhui_shenyan_consumed", 0), "应记录不坠神言兑现事件")


func test_h08_current_defend_blocks_before_retained_big_defend() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)

	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	assert_true(b.retained_big_defend[0], "当前防已能挡住波时，不应浪费保留大防")

	var hp_before: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], hp_before, "未选防时由保留大防补位挡住波")
	assert_false(b.retained_big_defend[0], "补位成功后消耗保留大防")
	assert_true(_has_event(result, "buzhui_shenyan_consumed", 0))


func test_h08_retained_big_defend_ignores_non_base_strike() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)
	var hp_before: int = b.hp[0][0]
	var events: Array = []

	b.strike(0, 2, 1, ActionDef.Pen.NORMAL, events)

	assert_eq(b.hp[0][0], hp_before - 2, "反击/主动技共用的管线打击不属于基础波，不被保留大防阻挡")
	assert_true(b.retained_big_defend[0], "非基础攻击不能消费不坠神言")


func test_h08_retained_big_defend_is_nonstacking() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)

	assert_true(b.retained_big_defend[0], "重复空放大防仍只保留一个布尔状态")


func test_h08_retained_big_defend_protects_reserve_targeted_by_h04() -> void:
	var b := _battle_teams(
		["h08", "test_p0_1", "test_p0_2"],
		["h04", "test_p1_1", "test_p1_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)
	var reserve_hp_before: int = b.hp[0][2]

	b.select_action(0, ActionDef.Action.CHARGE)
	assert_true(b.select_action(1, ActionDef.Action.BIG_ATTACK, 2), "房日应能指定敌方替补")
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][2], reserve_hp_before, "不坠神言属于全队，应保护被房日指定的替补")
	assert_false(b.retained_big_defend[0], "挡住替补受到的基础攻击后同样消耗")
	assert_true(_has_event(result, "buzhui_shenyan_consumed", 0))


func test_h08_retained_big_defend_is_not_consumed_by_big_defend_pierce() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)
	b.pierce_next_attack[1] = true
	var hp_before: int = b.hp[0][0]

	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][0], hp_before - 2, "穿大防的波应照常命中")
	assert_true(b.retained_big_defend[0], "没有挡住攻击时，不坠神言不得被错误消耗")
	assert_false(_has_event(result, "buzhui_shenyan_consumed", 0))


func test_h08_retained_big_defend_blocks_every_hit_of_one_base_attack() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)
	var item_slot: int = b.give_item(1, ItemCatalog.make("t2_shuangsheng"))
	assert_true(b.use_item(1, item_slot), "敌方应能用双生咒符让这次攻击多命中一次")
	var hp_before: int = b.hp[0][0]

	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][0], hp_before, "一次后备大防应挡完整次多段基础攻击，而非只挡第一段")
	assert_false(b.retained_big_defend[0], "挡完整次攻击后消耗")
	assert_eq(_event_count(result, "buzhui_shenyan_consumed", 0), 1, "整次攻击只记录一次消费")


# ---- h09 紫火 裂爪（命中 → 碎对手等量能量）----

func test_h09_liezhao_shatters_energy_equal_to_damage() -> void:
	var b := _battle("h09", 5, 8)
	# 猴波命中(2 半点) → 碎对手 2 半能。对手攒(+2)，被碎(-2)，被动(+2) → 净 +2
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 10 - 2, "猴波命中 1.0 (对手 HP5=10半)")
	assert_eq(b.energy[1], 8 + 2, "对手攒+2 −碎能2 +被动2 = 净 +2（无碎能应 +4）")


# ---- h10 昴日 剑意（攒剑气 + 拔剑一闪穿防）----

func test_h10_jianyi_gains_jianqi_on_hit() -> void:
	var b := _battle("h10", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(0, 0, "jianqi", 0)), 1, "鸡命中 → +1 剑气")

func test_h10_jianyi_bajian_pierces_def_with_two_jianqi() -> void:
	var b := _battle("h10", 5, 8)
	b.set_status(0, 0, "jianqi", 2)
	assert_true(b.select_active(0), "有剑气 → 可拔剑一闪")
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "剑气2 → 穿防，防挡不住，受 波2+剑气2 = 4 半点(对手 HP5=10半)")
	assert_eq(int(b.get_status(0, 0, "jianqi", 0)), 0, "一闪消耗全部剑气")
	assert_eq(b.energy[0], 8 - 4 + 2, "一闪费 2 能(2026-07-05 由 1 能调升)·被动 +1 回填")


# ---- h11 娄金 穷追（对手切换下场 → 被换下者 2.0 真伤·2026-07-04 由 1.0 调升）----

func test_h11_zhuibu_true_damage_on_enemy_switch_out() -> void:
	var b := _battle("h11", 5, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 1)                       # 对手切换 slot0→slot1
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "被换下者(slot0)受 2.0 真伤(4 半点·2026-07-04 平衡调升)")


# ---- h12 室火 纳福（受伤 → 己方 +一半能量·1:2·2026-07-05 折半）----

func test_h12_nafu_gains_energy_when_damaged() -> void:
	var b := _battle("h12", 7, 8)               # 猪 HP7 = 14 半点
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)   # 对手波 → 猪受 2 半点
	b.resolve()
	assert_eq(b.hp[0][0], 14 - 2, "猪受 1.0 伤")
	assert_eq(b.energy[0], 8 + 5, "纳福：受伤 2 半点 +1(1:2 折半) + 攒 +2 + 被动 +2 = +5 半能")

func test_h12_nafu_big_attack_converts_half() -> void:
	var b := _battle("h12", 7, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)   # 大波 → 猪受 4 半点（穿防）
	b.resolve()
	assert_eq(b.hp[0][0], 14 - 4, "猪受 2.0 伤")
	assert_eq(b.energy[0], 8 + 6, "纳福：受伤 4 半点 +2(1:2) + 攒 +2 + 被动 +2 = +6 半能")
