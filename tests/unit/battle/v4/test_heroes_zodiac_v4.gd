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


func _resolve(b: BattleCore, a0: int, a1: int) -> Dictionary:
	b.select_action(0, a0)
	b.select_action(1, a1)
	return b.resolve()


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


func test_h02_blocking_h10_empowered_wave_still_arms_upgrade() -> void:
	var p1: Array = [_hero("h02", 7), _hero("test_p1_1"), _hero("test_p1_2")]
	var p2: Array = [_hero("h10"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [20, 20]
	b.set_team_status(1, "jianqi", 2)
	b.select_action(0, ActionDef.Action.BIG_DEFEND)
	assert_true(b.apply_choice(1, {
		action = ActionDef.Action.ATTACK,
		target = -1,
		jianqi_attack = true,
	}), "昴日用剑气强化的是基础波")
	b.resolve()
	assert_true(b.upgrade_next_wave[0], "大防挡下强化波仍应触发玄金不动相")

	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.hp[1][0], 6, "后续升级波按大波伤害穿防")


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


func test_h02_upgraded_wave_can_trigger_h16_reserve_pursuit() -> void:
	var b := _battle_team(["h02", "h16", "test_p1_2"], 7, 20)
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)

	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 4, "升级波造成2点，替补广寒再追击1点")
	assert_eq(b.active_index[0], 1, "升级波命中后广寒应追击登场")
	assert_false(b.upgrade_next_wave[0], "升级状态应由队友这次波正常消费")


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


# ---- h03 尾火 白额雷音（每失去2点生命，攻击伤害增加1点）----

func _queue_lianhuan_actions(b: BattleCore, player: int, first_action: int,
		second_action: int) -> void:
	var item_index: int = b.give_item(player, ItemCatalog.make("t3_lianhuan_gu"))
	assert_true(b.use_item(player, item_index), "连环鼓应可进入本回合道具序列")
	assert_true(b.select_action(player, first_action), "连环鼓第一行动应可提交")
	assert_true(b.select_second_action(player, second_action), "连环鼓第二行动应可提交")


func test_h03_attack_damage_scales_once_per_two_lost_health() -> void:
	for case in [
		{"current_hp": 10, "expected_damage": 2},
		{"current_hp": 8, "expected_damage": 2},
		{"current_hp": 6, "expected_damage": 4},
		{"current_hp": 4, "expected_damage": 4},
		{"current_hp": 2, "expected_damage": 6},
	]:
		var b := _battle("h03", 5, 20)
		b.hp[0][0] = int(case["current_hp"])
		var before: int = b.hp[1][0]
		_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
		assert_eq(before - b.hp[1][0], int(case["expected_damage"]),
			"负伤增幅必须按每完整失去2点生命增加1点攻击伤害")


func test_h03_bonus_applies_to_big_wave() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[0][0] = 6
	var before: int = b.hp[1][0]
	_resolve(b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE)
	assert_eq(before - b.hp[1][0], 6,
		"失去2点生命的尾火大波应由2点伤害增加为3点")


func test_h03_reserve_does_not_increase_teammate_attack() -> void:
	var b := _battle_teams(
		["test_p0_0", "h03", "test_p0_2"],
		["test_p1_0", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[0][1] = 2
	var before: int = b.hp[1][0]
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(before - b.hp[1][0], 2,
		"替补尾火的失血不能把被动借给出战队友")


func test_h03_bonus_does_not_apply_to_item_damage() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[0][0] = 2
	var before: int = b.hp[1][0]
	var dart_index: int = b.give_item(0, ItemCatalog.make("t1_feibiao"))
	assert_true(b.use_item(0, dart_index), "尾火应可使用飞镖")
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.CHARGE)
	assert_eq(before - b.hp[1][0], 2,
		"白额雷音只强化波与大波，不强化独立道具伤害")


func test_h03_same_beat_damage_does_not_retroactively_change_formed_attack() -> void:
	var b := _battle("h03", 5, 20)
	b.hp[0][0] = 6
	var enemy_before: int = b.hp[1][0]
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.hp[0][0], 2, "尾火应正常承受同拍大波的2点伤害")
	assert_eq(enemy_before - b.hp[1][0], 4,
		"同拍攻击先共同形成；本拍新受伤不能追溯把已形成攻击再加1点")


func test_h03_rechecks_current_health_on_a_later_attack() -> void:
	var b := _battle("h03", 5, 20)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.hp[0][0], 6)
	var enemy_before: int = b.hp[1][0]
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(enemy_before - b.hp[1][0], 4,
		"先前回合受到2点伤害后，后续攻击应读取当前生命并增加1点伤害")


func test_h03_no_longer_generates_sequence_waits() -> void:
	var b := _battle("h03", 5, 20)
	_queue_lianhuan_actions(b, 1, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK))
	var result: Dictionary = b.resolve()
	assert_false(_has_event(result, "sequence_shifted"),
		"H03旧序列延后机制必须完全退出")
	assert_false(_has_event(result, "sequence_wait_executed"),
		"H03不得再生成额外等待行动位")


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


func test_h04_wave_targeting_reserve_is_blocked_by_active_hero_defend() -> void:
	var b := _battle("h04", 5, 20)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1), "房日的波应可指定敌方替补")
	assert_true(b.select_action(1, ActionDef.Action.DEFEND), "敌方出战英雄应能选择防")
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][0], 10, "出战英雄选择防时自身不应代替替补承伤")
	assert_eq(b.hp[1][1], 10, "出战英雄的防应保护被房日指定的替补免受普通波")
	var found_block := false
	for event_variant: Variant in result.get("events", []):
		var event: Dictionary = event_variant
		if String(event.get("id", "")) == "defend_block" \
				and int(event.get("player", -1)) == 1 and int(event.get("slot", -1)) == 1:
			found_block = true
	assert_true(found_block, "普通防格挡事件必须携带实际受保护的替补槽")


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


func test_h03_low_health_attack_and_h04_targeted_attack_both_resolve() -> void:
	var b := _battle_teams(
		["h04", "test_p0_1", "test_p0_2"],
		["h03", "test_p1_1", "test_p1_2"], 5, 20)
	b.hp[1][0] = 2
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 1))
	assert_true(b.select_action(1, ActionDef.Action.ATTACK))
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][0], 4, "1点生命的尾火应以3点伤害命中房日")
	assert_eq(b.hp[1][1], 8, "同列已经开始的房日定向波必须照常命中替补")
	assert_false(_has_event(result, "sequence_shifted"), "H03不再改变行动序列")
	assert_false(_has_event(result, "base_attack_cancelled"), "双方同拍攻击都应完整结算")


# ---- h05 亢金 龙御极（在队时可为波额外支付 1 能，使伤害 +1）----

func test_h05_normal_wave_remains_available_without_extra_cost_or_damage() -> void:
	var b := _battle_team(["test_p0_0", "h05", "test_p0_2"], 5, 4)
	assert_true(b.has_empowered_wave(0), "亢金在替补席也应为全队开放强化波")
	assert_true(b.select_action(0, ActionDef.Action.ATTACK), "普通波始终保留")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1][0], 8, "未选择龙御极时，波仍造成 1 点伤害")
	assert_eq(b.energy[0], 4, "普通波只付 1 能，回合被动补回 1 能")


func test_h05_empowered_wave_spends_one_extra_energy_and_adds_one_damage() -> void:
	var b := _battle_team(["test_p0_0", "h05", "test_p0_2"], 5, 4)
	assert_true(b.apply_choice(0, {
		action = ActionDef.Action.ATTACK,
		target = -1,
		empowered_wave = true,
	}), "有亢金且有 2 能时可选择强化波")
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][0], 6, "强化波造成 2 点伤害")
	assert_eq(b.energy[0], 2, "强化波总计支付 2 能，回合被动补回 1 能")
	assert_true(_has_event(result, "longyuji_empowered", 0), "应记录龙御极强化事件供界面反馈")


func test_h05_empowered_wave_is_still_a_wave_and_defend_blocks_it() -> void:
	var b := _battle_team(["h05", "test_p0_1", "test_p0_2"], 5, 4)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, -1, true))
	b.select_action(1, ActionDef.Action.DEFEND)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[1][0], 10, "龙御极只加伤，不改变波的防御等级")
	assert_true(_has_event(result, "defend_block", 1), "普通防应完整挡下强化波")
	assert_eq(b.energy[0], 2, "即使被挡，额外 1 能也已支付")


func test_h05_empowered_wave_requires_h05_wave_and_two_energy() -> void:
	var plain := _battle("test_p0_0", 5, 20)
	assert_false(plain.select_action(0, ActionDef.Action.ATTACK, -1, true), "队内无亢金不能伪造强化波")

	var poor := _battle_team(["h05", "test_p0_1", "test_p0_2"], 5, 2)
	assert_true(poor.select_action(0, ActionDef.Action.ATTACK), "只有 1 能时仍可选择普通波")
	assert_false(poor.select_empowered_wave(0, true), "只有 1 能时不能追加强化费用")
	assert_false(poor.select_action(0, ActionDef.Action.BIG_ATTACK, -1, true), "龙御极不能强化大波")


func test_h05_empowered_wave_combines_with_h02_wave_upgrade() -> void:
	var b := _battle_team(["h02", "h05", "test_p0_2"], 7, 8)
	b.upgrade_next_wave[0] = true
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, -1, true))
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()

	assert_eq(b.hp[1][0], 4, "升级波按大波穿过普通防，并在 2 点基础上再增加 1 点伤害")
	assert_false(b.upgrade_next_wave[0], "玄金不动相与龙御极应在同一次波上共同兑现")


func test_h05_empowered_wave_combines_with_h04_targeting_and_h16_pursuit() -> void:
	var b := _battle_team(["h04", "h05", "h16"], 5, 12)
	assert_true(b.select_action(0, ActionDef.Action.ATTACK, 2, true))
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_eq(b.hp[1][2], 4, "房日指定替补后，强化波2点与广寒追击1点落在同一目标")
	assert_eq(b.hp[1][0], 10, "敌方出战位不应被误伤")
	assert_eq(b.active_index[0], 2, "替补广寒应在强化波命中后登场")


# ---- h06 翼火 神打（命中叠毒素；大波命中时引爆）----

func test_h06_shenda_stacks_poison_on_hit() -> void:
	var b := _battle("h06", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 1, "翼火命中 → 叠 1 层毒素")

func test_h06_shenda_only_big_attack_detonates_stacked_poison() -> void:
	var b := _battle_teams(
			["h06", "test_p0_1", "test_p0_2"],
			["test_p1_0", "test_p1_1", "test_p1_2"], 10, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	var second_wave: Dictionary = _resolve(
			b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 16, "连续两次波各造成1点伤害，不得提前引爆毒素")
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 2, "两次波命中应累积2层毒素")
	assert_false(_has_event(second_wave, "poison_detonate"), "波命中不再引爆毒素")

	var big_wave: Dictionary = _resolve(
			b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 10, "大波2点加2层毒素1点，共造成3点伤害")
	assert_true(_has_event(big_wave, "poison_detonate"), "大波命中必须引爆全部毒素")
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 1,
			"大波先清除旧毒，再由翼火本次命中重新施加1层")


# ---- h07 星日 千里快哉风（登场 0.5 冲撞）----

func test_h07_qianlikuaizaifeng_chongzhuang_on_switch_in() -> void:
	var b := _battle_team(["test_p1_0", "h07", "test_p1_2"], 5, 8)
	b.select_switch(0, 1)                       # 切到马
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()
	assert_eq(b.active_index[0], 1, "已切到马")
	assert_eq(b.hp[1][0], 10 - 1, "马登场冲撞 0.5HP = 1 半点 给对手出战(对手 HP5=10半)")
	var switch_event_index := -1
	var entry_damage_index := -1
	var entry_impact_index := -1
	var events: Array = result.get("events", [])
	for index in range(events.size()):
		var event: Dictionary = events[index]
		if String(event.get("id", "")) == "switch" and int(event.get("player", -1)) == 0:
			switch_event_index = index
		if String(event.get("id", "")) == "damage_taken" \
				and String(event.get("src", "")) == "h07_entry":
			entry_damage_index = index
		if String(event.get("id", "")) == "h07_entry_impact":
			entry_impact_index = index
	assert_gte(switch_event_index, 0, "普通切换必须先产生登场事件")
	assert_gt(entry_damage_index, switch_event_index, "h07 的 0.5 点伤害必须在登场完成后结算")
	assert_gt(entry_impact_index, entry_damage_index,
		"独立弧形受击事件必须携带已结算的实际伤害，不能让 UI 提前猜数值")
	assert_eq(int(events[entry_impact_index].get("amount", -1)), 1,
		"弧形受击事件应公开实际落血的 0.5 点")
	assert_false(bool(events[entry_impact_index].get("defeated", true)),
		"非致命登场伤害必须明确标记，防止 UI 误播普通终结命中")


func test_h07_free_switch_is_once_per_turn_and_refreshes_next_turn() -> void:
	var b := _battle_team(["h07", "test_p0_1", "test_p0_2"], 5, 8)

	assert_true(b.free_switch(0, 1), "星日切换下场应消耗本回合唯一一次免费切换")
	assert_false(b.is_free_switch_target(0, 0), "同回合不得再免费切回星日")
	assert_false(b.free_switch(0, 0), "核心层必须拒绝同回合第二次免费切换")
	assert_true(b.select_action(0, ActionDef.Action.ATTACK), "免费切换后新出战英雄仍能正常行动")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()

	assert_true(b.is_free_switch_target(0, 0), "下一回合其他英雄切入星日也应免费")
	assert_true(b.free_switch(0, 0), "进入星日应消耗本回合唯一一次免费切换")
	assert_false(b.free_switch(0, 2), "进入星日后同回合不得再免费离场")
	assert_true(b.select_action(0, ActionDef.Action.ATTACK),
		"免费进入星日后仍能选择本回合行动")
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 0, "免费切换后星日正常登场")

	assert_true(b.free_switch(0, 1), "下一回合星日在场时恢复一次免费离场")
	assert_false(b.free_switch(0, 2), "同回合切回不能刷新已经消耗的免费切换次数")


func test_h07_free_switch_preview_can_be_cancelled_before_submission() -> void:
	var b := _battle_team(["h07", "test_p0_1", "test_p0_2"], 5, 8)
	var usage_turn_before := b.free_switch_usage_turn[0]
	var uses_before := b.free_switch_uses[0]
	assert_true(b.free_switch(0, 1))
	assert_eq(b.active_index[0], 1)
	assert_true(b.cancel_last_free_switch_preview(0),
		"顺序槽 x 必须能撤销尚未提交的免费切换")
	assert_eq(b.active_index[0], 0, "撤销后恢复预览前的出战英雄")
	assert_eq(b.free_switch_usage_turn[0], usage_turn_before)
	assert_eq(b.free_switch_uses[0], uses_before, "撤销后归还本回合免费次数")
	assert_true(b.is_free_switch_target(0, 1), "撤销后同一免费切换仍可重新选择")
	assert_false(b.cancel_last_free_switch_preview(0), "空预览栈不能重复撤销")


func test_h07_forced_entry_and_death_replacement_keep_entry_damage_but_never_grant_entry_free() -> void:
	var forced := _battle_team(["test_p0_0", "h07", "test_p0_2"], 5, 8)
	forced.request_forced_pull(0, 1)
	forced.select_action(0, ActionDef.Action.CHARGE)
	forced.select_action(1, ActionDef.Action.CHARGE)
	var forced_result: Dictionary = forced.resolve()
	assert_eq(forced.active_index[0], 1, "强制换人应先让星日完成登场")
	assert_eq(forced.hp[1][0], 9, "强制登场后的星日仍造成 0.5 点伤害")
	assert_true(_has_event(forced_result, "damage_taken", 1), "强制登场伤害应进入权威事件流")

	var death := _battle_team(["test_p0_0", "h07", "test_p0_2"], 5, 8)
	death.hp[0][0] = 0
	death.pending_death_switch[0] = true
	assert_true(death.execute_death_switch(0, 1), "死亡换人应允许选择存活的星日")
	assert_eq(death.active_index[0], 1, "死亡换人必须先更新出战位")
	assert_eq(death.hp[1][0], 9, "死亡补位完成后星日仍造成 0.5 点伤害")
	assert_false(death.is_free_switch_target(0, 0), "阵亡英雄不能成为免费离场目标")


func test_h07_free_exit_still_triggers_h11_before_switch_and_not_on_entry() -> void:
	var b := _battle_teams(
		["h07", "test_p0_1", "test_p0_2"],
		["h11", "test_p1_1", "test_p1_2"], 5, 8)
	assert_true(b.free_switch(0, 1), "星日应能免费离场")
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_eq(b.active_index[0], 1, "h11 伤害不能卡掉 h07 的免费离场")
	assert_eq(b.hp[0][0], 6, "被换下的星日应先受到 h11 的 2 点真伤")
	assert_eq(b.hp[1][0], 10, "星日离场不触发自身的登场伤害")
	var ids: Array[String] = []
	for event_variant: Variant in result.get("events", []):
		ids.append(String((event_variant as Dictionary).get("id", "")))
	assert_lt(ids.find("h11_switch_chase"), ids.find("switch"),
		"h11 伤害必须先于免费切换事件，之后再完成 h07 离场")


# ---- h08 鬼金 不坠神言（未挡到攻击的大防由队伍保留至下一回合结束）----

func test_h08_unused_big_defend_is_retained_for_team() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	b.select_action(0, ActionDef.Action.BIG_DEFEND)
	b.select_action(1, ActionDef.Action.CHARGE)
	var result: Dictionary = b.resolve()

	assert_true(b.retained_big_defend[0], "鬼金空放大防后，己方应保留一次大防")
	assert_eq(b.retained_big_defend_until_turn[0], b.turn_number,
		"空放大防应持续覆盖紧接着的下一回合")
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

	var hp_before: int = b.hp[0][1]
	b.select_switch(0, 1)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.active_index[0], 1, "下一回合切换后由队友出战")
	assert_eq(b.hp[0][1], hp_before, "保留大防属于全队，应保护下一回合刚换上的队友")
	assert_false(b.retained_big_defend[0], "保留大防实际挡下一次攻击后消耗")
	assert_true(_has_event(result, "buzhui_shenyan_consumed", 0), "应记录不坠神言兑现事件")


func test_h08_retained_big_defend_expires_at_end_of_next_turn() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)

	var expiry_result := _resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	assert_false(b.retained_big_defend[0], "下一回合没有挡到攻击时，保留大防应在回合末消失")
	assert_eq(b.retained_big_defend_until_turn[0], -1, "到期后应同时清除到期回合")
	assert_true(_has_event(expiry_result, "buzhui_shenyan_expired", 0), "应记录不坠神言到期事件")

	var hp_before: int = b.hp[0][0]
	var result := _resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.hp[0][0], hp_before - 4, "超过下一回合后，大波不再被旧神言阻挡")
	assert_false(_has_event(result, "buzhui_shenyan_consumed", 0))


func test_h08_current_defend_blocks_before_retained_big_defend() -> void:
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 20)
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.CHARGE)

	var expiry_result := _resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.ATTACK)
	assert_false(b.retained_big_defend[0],
		"当前防优先挡住波，但保留大防仍应在下一回合结束时到期")
	assert_true(_has_event(expiry_result, "buzhui_shenyan_expired", 0))

	var hp_before: int = b.hp[0][0]
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[0][0], hp_before - 2, "再下一回合未选防时，旧神言不再补位")
	assert_false(_has_event(result, "buzhui_shenyan_consumed", 0))


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
	assert_eq(b.retained_big_defend_until_turn[0], b.turn_number,
		"第二次空放应把唯一状态刷新到再下一回合结束")
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	assert_false(b.retained_big_defend[0], "刷新后的下一回合结束时仍应正常到期")


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
	var item_index: int = b.give_item(1, ItemCatalog.make("t2_qiubite"))
	assert_true(b.use_item(1, item_index), "敌方使用心脏掌握魔法令下一次攻击造成真实伤害")
	var hp_before: int = b.hp[0][0]

	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)
	var result: Dictionary = b.resolve()

	assert_eq(b.hp[0][0], hp_before - 4, "穿大防的大波应照常命中")
	assert_false(b.retained_big_defend[0], "穿大防没有消费神言，但下一回合窗口结束后仍应到期")
	assert_false(_has_event(result, "buzhui_shenyan_consumed", 0))
	assert_true(_has_event(result, "buzhui_shenyan_expired", 0))


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


# ---- h09 紫火（造成伤害 → 移除敌方等量能量）----

func test_h09_liuzhaoyanluo_removes_energy_equal_to_damage() -> void:
	var b := _battle("h09", 5, 8)
	# 猴波命中(2 半点) → 碎对手 2 半能。对手攒(+2)，被碎(-2)，被动(+2) → 净 +2
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 10 - 2, "猴波命中 1.0 (对手 HP5=10半)")
	assert_eq(b.energy[1], 8 + 2, "对手攒+2 −碎能2 +被动2 = 净 +2（无碎能应 +4）")


# ---- h10 昴日 飞洒天星（攒剑气 + 强化基础攻击穿防）----

func test_h10_taichuwanfa_gains_jianqi_on_hit() -> void:
	var b := _battle("h10", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 1, "鸡命中 → 队伍 +1 剑气")


func test_h10_sword_qi_is_team_shared_across_switches() -> void:
	var b := _battle_team(["test_p1_0", "h10", "test_p1_2"], 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 1,
			"队友命中后由替补昴日积累的剑气属于全队")
	assert_eq(int(b.get_status(0, 0, "jianqi", 0)), 1)
	assert_eq(int(b.get_status(0, 1, "jianqi", 0)), 1,
			"兼容状态读取不得再因英雄槽位不同而看到两份剑气")
	b.active_index[0] = 2
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 1,
			"切换到任意队友后剑气不能消失")
	b.active_index[0] = 1
	b.set_team_status(0, "jianqi", 2)
	assert_true(b.apply_choice(0, {
		action = ActionDef.Action.ATTACK,
		target = -1,
		jianqi_attack = true,
	}), "昴日重新登场后可以用此前积累的队伍剑气强化波")


func test_h10_is_an_attack_modifier_not_an_independent_active_action() -> void:
	var b := _battle("h10", 5, 8)
	var skill: HeroSkill = b.get_skill(0, 0)
	assert_false(skill.has_active(), "昴日不再制造独立主动攻击结算点")
	assert_false(b.can_use_active(0), "公共主动技入口不得继续开放飞洒天星")
	b.set_team_status(0, "jianqi", 1)
	assert_false(b.can_jianqi_attack_action(0, ActionDef.Action.ATTACK),
			"1点剑气没有穿透收益，不得误触消耗")
	b.set_team_status(0, "jianqi", 2)
	assert_true(b.can_jianqi_attack_action(0, ActionDef.Action.ATTACK))
	assert_false(b.can_jianqi_attack_action(0, ActionDef.Action.BIG_ATTACK),
			"2点剑气不能强化本来就穿防的大波")


func test_h10_two_jianqi_empowers_wave_to_pierce_def_without_extra_damage() -> void:
	var b := _battle("h10", 5, 8)
	b.set_team_status(0, "jianqi", 2)
	assert_true(b.apply_choice(0, {
		action = ActionDef.Action.ATTACK,
		target = -1,
		jianqi_attack = true,
	}))
	b.select_action(1, ActionDef.Action.DEFEND)
	var result := b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "2点剑气只令波穿防，不增加波的基础伤害")
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 1,
			"出手前消耗全部旧剑气；强化波命中后按被动重新积累1点")
	assert_eq(b.energy[0], 8, "强化不另收费；波1能与回合被动1能抵消")
	assert_true(_has_event(result, "h10_jianqi_attack", 0))


func test_h10_four_jianqi_can_empower_big_wave_to_pierce_big_defend() -> void:
	var b := _battle("h10", 5, 8)
	b.set_team_status(0, "jianqi", 4)
	assert_true(b.apply_choice(0, {
		action = ActionDef.Action.BIG_ATTACK,
		target = -1,
		jianqi_attack = true,
	}))
	b.select_action(1, ActionDef.Action.BIG_DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "4点剑气令大波穿大防，仍只造成大波自身2点伤害")
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 1,
			"大波命中后重新积累1点剑气")


func test_h10_jianqi_is_spent_when_formed_attack_is_nullified() -> void:
	var b := _battle("h10", 5, 8)
	b.set_team_status(0, "jianqi", 2)
	var decoy_index: int = b.give_item(1, ItemCatalog.make("t2_caoren"))
	assert_true(b.use_item(1, decoy_index))
	assert_true(b.apply_choice(0, {
		action = ActionDef.Action.ATTACK,
		target = -1,
		jianqi_attack = true,
	}))
	assert_true(b.select_switch(1, 1))
	b.resolve()
	assert_eq(b.hp[1][1], 10, "攻击被替身等效果无效化后不造成伤害")
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 0,
			"攻击已经形成，旧剑气仍会消耗；未命中也不会重新积累")


func test_h10_modifier_works_in_item_v2_sequence_resolution() -> void:
	var b := _battle("h10", 5, 8)
	b.enable_item_v2([], [])
	b.set_team_status(0, "jianqi", 2)
	assert_true(b.submit_item_v2_command_sequence(0, [{
		kind = "action", action = ActionDef.Action.ATTACK, target = -1,
		jianqi_attack = true,
	}]))
	assert_true(b.submit_item_v2_command_sequence(1, [{
		kind = "action", action = ActionDef.Action.DEFEND, target = -1,
	}]))
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "新版道具序列也必须让强化波穿防")
	assert_eq(int(b.get_team_status(0, "jianqi", 0)), 1)


# ---- h11 娄金 穷追（对手切换下场 → 被换下者 2.0 真伤·2026-07-04 由 1.0 调升）----

func test_h11_yingshou_true_damage_on_enemy_switch_out() -> void:
	var b := _battle("h11", 5, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 1)                       # 对手切换 slot0→slot1
	var result: Dictionary = b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "被换下者(slot0)受 2.0 真伤(4 半点·2026-07-04 平衡调升)")
	var chase_event: Dictionary = {}
	for event_variant: Variant in result.get("events", []):
		var event: Dictionary = event_variant
		if String(event.get("id", "")) == "h11_switch_chase":
			chase_event = event
			break
	assert_false(chase_event.is_empty(), "影狩伤害必须进入事件流，不能只静默改写血量")
	assert_eq(int(chase_event.get("player", -1)), 1, "事件目标是正在换下英雄的一方")
	assert_eq(int(chase_event.get("slot", -1)), 0, "事件锁定换下前的英雄槽")
	assert_eq(int(chase_event.get("amount", 0)), 4, "事件记录实际扣除的2点真伤")
	assert_eq(int(chase_event.get("source_player", -1)), 0, "事件保留影狩发动方")
	var event_ids: Array[String] = []
	for event_variant: Variant in result.get("events", []):
		event_ids.append(String((event_variant as Dictionary).get("id", "")))
	assert_lt(event_ids.find("h11_switch_chase"), event_ids.find("switch"),
			"核心事件顺序同样必须先记录影狩伤害，再记录换人")


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


func test_h12_reserve_damage_does_not_receive_h01_energy_bonus() -> void:
	var b := _battle_teams(
		["h01", "h12", "test_p0_2"],
		["h04", "test_p1_1", "test_p1_2"], 5, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	assert_true(b.select_action(1, ActionDef.Action.ATTACK, 1), "房日应能指定替补席室火")
	b.resolve()

	assert_eq(b.hp[0][1], 8, "替补室火应受到 1 点伤害")
	assert_eq(b.energy[0], 14,
		"步虚只加成出战虚日自己的攒；替补室火的受伤产能不得再吃一次步虚加成")


func test_h12_self_damaged_passive_triggers_while_h04_hits_it_on_reserve() -> void:
	var b := _battle_teams(
		["test_p0_0", "h12", "test_p0_2"],
		["h04", "test_p1_1", "test_p1_2"], 5, 8)
	assert_true(b.select_action(0, ActionDef.Action.CHARGE))
	assert_true(b.select_action(1, ActionDef.Action.ATTACK, 1), "房日应能指定替补席室火")
	b.resolve()

	assert_eq(b.hp[0][1], 8, "替补室火应实际承受 1 点伤害")
	assert_eq(b.energy[0], 13,
		"写明本英雄受到伤害的纳福在替补位也应触发：攒2、回合被动2、纳福1")
