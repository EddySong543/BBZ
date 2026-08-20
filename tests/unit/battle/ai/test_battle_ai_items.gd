extends GutTest

## BattleAI.run_item_economy（任务 B·AI 基础道具经济）行为锁定。
## 用就绪 / 抽可抽（含自动解锁格）/ 富余补充 / reserve 不饿死动作 / 未 init 安全。
## （2026-07-03 经济重做：格自动解锁免费、无开格步骤 → 原开格相关用例移除。）

const A := ActionDef.Action
const SEED := 4242
const SS := BattleCore.SlotState


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], SEED)
	b.energy = [energy, energy]
	b.econ_init()
	return b


## P1(AI·side 1) 开局件已就绪的 battle（绕开「部署延迟」便于测机制；真实首回合开局件是锁住的）。
func _battle_ready(energy: int = 20) -> BattleCore:
	var b := _battle(energy)
	b.slots[1][0]["since"] = b.turn_number - 1
	return b


func _ready_slot(item_id: String) -> Dictionary:
	return {
		state = SS.CHARGING,
		item = ItemCatalog.make(item_id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	return r


func _advance(b: BattleCore, n: int = 1) -> void:
	for _i in range(n):
		b.select_action(0, A.CHARGE)
		b.select_action(1, A.CHARGE)
		b.resolve()


# === 用就绪道具 ===

func test_uses_ready_non_attack_item() -> void:
	# 能量紧（< 升级投资线）→ AI 把就绪的非进攻件直接用掉、不投资升级（升级择时见 test_upgrades_*）。
	# 用 _battle_ready：自带件按设计解锁前锁住，这里要测"就绪→用"，故夹具置就绪。
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_jiudun")   # 防御件（进攻件按兵不动，见 test_holds_attack_item*）
	assert_true(b.slot_ready(1, 0), "AI 自带件就绪（夹具）")
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.item_uses[1].size(), 1, "能量紧 → AI 用掉就绪非进攻件（提交盲选）")


func test_ai_targets_friendly_hero_items_without_wasting_blank_transfer() -> void:
	var armor := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	armor.hp[1] = [20, 8, 14]
	armor.slots[1][0] = _ready_slot("t2_huzhen_ding")
	BattleAI.run_item_economy(armor, 1, _rng())
	armor.select_action(0, A.CHARGE)
	armor.select_action(1, A.CHARGE)
	armor.resolve()
	assert_eq(armor.shield[1][1], 4, "护阵钉应选择生命最低的存活替补")

	var blank_transfer := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	blank_transfer.slots[1][0] = _ready_slot("t2_yijia_huan")
	BattleAI.run_item_economy(blank_transfer, 1, _rng())
	assert_true(blank_transfer.slot_ready(1, 0), "全队无护盾时不得空放移甲环")

	var transfer := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	transfer.hp[1] = [20, 8, 14]
	transfer.shield[1] = [2, 0, 4]
	transfer.slots[1][0] = _ready_slot("t2_yijia_huan")
	BattleAI.run_item_economy(transfer, 1, _rng())
	transfer.select_action(0, A.CHARGE)
	transfer.select_action(1, A.CHARGE)
	transfer.resolve()
	assert_eq(transfer.shield[1], [0, 6, 0], "移甲环应把全队护盾集中给低血存活英雄")


func test_ai_uses_houzhen_qian_to_replace_a_weaker_active_hero() -> void:
	var useful := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	useful.hp[1] = [4, 14, 18]
	useful.slots[1][0] = _ready_slot("t1_houzhen_qian")
	BattleAI.run_item_economy(useful, 1, _rng())
	assert_false(useful.slot_ready(1, 0))
	useful.select_action(0, A.CHARGE)
	useful.select_action(1, A.CHARGE)
	useful.resolve()
	assert_eq(useful.active_index[1], 2, "应预定综合生命最高的替补在回合末登场")

	var blank := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	blank.hp[1] = [20, 14, 18]
	blank.slots[1][0] = _ready_slot("t1_houzhen_qian")
	BattleAI.run_item_economy(blank, 1, _rng())
	assert_true(blank.slot_ready(1, 0), "当前出战英雄更安全时不应机械消耗候阵签")


func test_ai_holds_borrowed_mark_until_attack_and_selects_a_real_reserve_mark() -> void:
	var battle := BattleCore.new()
	battle.setup([_hero("x", 10), _hero("y", 10), _hero("z", 10)],
		[_hero("a", 10), _hero("h06", 10), _hero("h10", 10)], SEED)
	battle.energy = [BattleAI.AI_ITEM_ENERGY_RESERVE, BattleAI.AI_ITEM_ENERGY_RESERVE]
	battle.econ_init()
	battle.slots[1][0] = _ready_slot("t2_jieyin_pei")
	BattleAI.run_item_economy(battle, 1, _rng())
	assert_true(battle.slot_ready(1, 0), "借印佩在最终动作确定前应保留")
	BattleAI.commit_attack_items(battle, 1, A.CHARGE)
	assert_true(battle.slot_ready(1, 0), "非攻击回合不得消耗借印佩")
	BattleAI.commit_attack_items(battle, 1, A.ATTACK)
	assert_false(battle.slot_ready(1, 0), "攻击回合应提交借印佩")
	assert_eq(int(battle.item_uses[1][0]["target"]), 2, "优先借用尚可积累的 h10 印记")


func test_ai_delays_the_highest_tier_locked_enemy_item_and_heals_injured_reserve() -> void:
	var delay := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	delay.slots[1][0] = _ready_slot("t2_shizhi_jiasuo")
	delay.slots[0][0] = {
		state = SS.CHARGING, item = ItemCatalog.make("t1_jiudun"),
		since = delay.turn_number, used = false, draft = [], upg_draft = [],
	}
	delay.slots[0][1] = {
		state = SS.CHARGING, item = ItemCatalog.make("t3_yiqi"),
		since = delay.turn_number, used = false, draft = [], upg_draft = [],
	}
	var target_turn: int = delay.turn_number
	BattleAI.run_item_economy(delay, 1, _rng())
	delay.select_action(0, A.CHARGE)
	delay.select_action(1, A.CHARGE)
	delay.resolve()
	assert_eq(int(delay.slots[0][0]["since"]), target_turn,
		"较低稀有度目标不应被优先延迟")
	assert_eq(int(delay.slots[0][1]["since"]), target_turn + 1,
		"时滞枷锁应优先延迟最高稀有度的锁定道具")

	var heal := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	heal.hp[1] = [20, 18, 10]
	heal.slots[1][0] = _ready_slot("t2_xingjun_yaonang")
	BattleAI.run_item_economy(heal, 1, _rng())
	heal.select_action(0, A.CHARGE)
	heal.select_action(1, A.CHARGE)
	heal.resolve()
	assert_eq(heal.hp[1], [20, 18, 14], "行军药囊应治疗受伤最多的未出战英雄")


func test_ai_holds_fuying_until_attack_and_uses_zhenwen_only_against_real_hooks() -> void:
	var bind := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	bind.slots[1][0] = _ready_slot("t2_fuying_suo")
	BattleAI.run_item_economy(bind, 1, _rng())
	assert_true(bind.slot_ready(1, 0), "缚影索应等到攻击动作确定后再提交")
	BattleAI.commit_attack_items(bind, 1, A.ATTACK)
	assert_false(bind.slot_ready(1, 0))

	var no_hooks := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	no_hooks.slots[1][0] = _ready_slot("t2_zhenwen_zhen")
	BattleAI.run_item_economy(no_hooks, 1, _rng())
	assert_true(no_hooks.slot_ready(1, 0), "敌方没有命中触发英雄技能时不应空放镇纹针")

	var hooks := BattleCore.new()
	hooks.setup([_hero("h06", 10), _hero("x", 10), _hero("y", 10)],
		[_hero("a", 10), _hero("b", 10), _hero("c", 10)], SEED)
	hooks.energy = [BattleAI.AI_ITEM_ENERGY_RESERVE, BattleAI.AI_ITEM_ENERGY_RESERVE]
	hooks.econ_init()
	hooks.slots[1][0] = _ready_slot("t2_zhenwen_zhen")
	BattleAI.run_item_economy(hooks, 1, _rng())
	assert_false(hooks.slot_ready(1, 0), "敌方存在真实命中触发英雄技能时可提交镇纹针")


func test_ai_uses_huizhao_only_against_hostile_items_and_does_not_stack_suoquan() -> void:
	var counter := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	counter.slots[1][0] = _ready_slot("t2_huizhao_jing")
	counter.slots[0][0] = _ready_slot("t2_feibiao")
	BattleAI.run_item_economy(counter, 1, _rng())
	assert_false(counter.slot_ready(1, 0), "对手有公开敌向道具时应提交回照镜")

	var no_target := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	no_target.slots[1][0] = _ready_slot("t2_huizhao_jing")
	no_target.slots[0][0] = _ready_slot("t2_jiandun")
	BattleAI.run_item_economy(no_target, 1, _rng())
	assert_true(no_target.slot_ready(1, 0), "对手只有自向道具时不应空放回照镜")

	var lock := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	lock.slots[1][0] = _ready_slot("t2_suoquan_sai")
	lock.slots[1][1] = _ready_slot("t2_suoquan_sai")
	BattleAI.run_item_economy(lock, 1, _rng())
	assert_false(lock.slot_ready(1, 0), "第一件锁泉塞应正常提交")
	assert_true(lock.slot_ready(1, 1), "同拍第二件锁泉塞不会延长效果，应保留")


# === 进攻向道具按兵不动 → 攻击回合一并甩出（2026-07-03 死龟锁修复）===

func test_holds_attack_item_in_economy() -> void:
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")   # 进攻 chip
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.item_uses[1].size(), 0, "经济阶段进攻件按兵不动（不白扔喂对方免费防）")
	assert_true(b.slot_ready(1, 0), "进攻件保持就绪（留给攻击回合）")


func test_commits_attack_item_on_attack_turn_only() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")
	BattleAI.commit_attack_items(b, 1, ActionDef.Action.CHARGE)
	assert_eq(b.item_uses[1].size(), 0, "攒回合不甩进攻件")
	BattleAI.commit_attack_items(b, 1, ActionDef.Action.ATTACK)
	assert_eq(b.item_uses[1].size(), 1, "攻击回合甩出进攻件（与波同吃防御门）")


func test_t1_connection_items_wait_for_their_public_action_or_state() -> void:
	var switch_guard := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	switch_guard.slots[1][0]["item"] = ItemCatalog.make("t1_huanfang_kou")
	BattleAI.run_item_economy(switch_guard, 1, _rng())
	assert_true(switch_guard.slot_ready(1, 0), "换防扣在选招前保留")
	BattleAI.commit_attack_items(switch_guard, 1, A.SWITCH)
	assert_false(switch_guard.slot_ready(1, 0), "换防扣仅随切换提交")

	var wrong_switch := _battle_ready(20)
	wrong_switch.slots[1][0]["item"] = ItemCatalog.make("t1_huanfang_kou")
	BattleAI.commit_attack_items(wrong_switch, 1, A.ATTACK)
	assert_true(wrong_switch.slot_ready(1, 0), "选波时不得浪费换防扣")

	var big_guard := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	big_guard.slots[1][0]["item"] = ItemCatalog.make("t1_yazhen_zhui")
	BattleAI.run_item_economy(big_guard, 1, _rng())
	assert_true(big_guard.slot_ready(1, 0), "压阵坠在选招前保留")
	BattleAI.commit_attack_items(big_guard, 1, A.BIG_DEFEND)
	assert_false(big_guard.slot_ready(1, 0), "压阵坠仅随大防提交")

	var wave_guard := _battle_ready(20)
	wave_guard.slots[1][0]["item"] = ItemCatalog.make("t1_huifeng_qiao")
	BattleAI.commit_attack_items(wave_guard, 1, A.BIG_ATTACK)
	assert_true(wave_guard.slot_ready(1, 0), "回锋鞘不得随大波消耗")
	BattleAI.commit_attack_items(wave_guard, 1, A.ATTACK)
	assert_false(wave_guard.slot_ready(1, 0), "回锋鞘仅随波提交")


func test_t1_connection_items_avoid_blank_uses_without_spying_on_blind_action() -> void:
	var cleanse := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	cleanse.slots[1][0]["item"] = ItemCatalog.make("t1_jiedu_yaoshui")
	BattleAI.run_item_economy(cleanse, 1, _rng())
	assert_true(cleanse.slot_ready(1, 0), "无毒素/脆弱时保留解毒药水")
	cleanse.set_status(1, cleanse.active_index[1], "poison", 1)
	BattleAI.run_item_economy(cleanse, 1, _rng())
	assert_false(cleanse.slot_ready(1, 0), "出战英雄有毒素时使用解毒药水")

	var trap := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	trap.slots[1][0]["item"] = ItemCatalog.make("t1_tengman_xianjing")
	trap.hp[0][1] = 0
	trap.hp[0][2] = 0
	BattleAI.run_item_economy(trap, 1, _rng())
	assert_true(trap.slot_ready(1, 0), "敌方无替补时陷阱必定白板，应保留")
	trap.hp[0][1] = 10
	BattleAI.run_item_economy(trap, 1, _rng())
	assert_false(trap.slot_ready(1, 0), "只要敌方有可切换替补就可使用，不窥视敌方选招")

	var succession := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	succession.slots[1][0]["item"] = ItemCatalog.make("t1_xuzhen_qi")
	BattleAI.run_item_economy(succession, 1, _rng())
	assert_true(succession.slot_ready(1, 0), "健康出战不提前浪费续阵旗")
	succession.hp[1][0] = 4
	BattleAI.run_item_economy(succession, 1, _rng())
	assert_false(succession.slot_ready(1, 0), "出战低血且有替补时使用续阵旗")


func test_deneng_waits_at_energy_cap_and_xunxing_is_not_wasted_by_h04() -> void:
	var full_energy := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	full_energy.energy[1] = full_energy.energy_max[1]
	full_energy.slots[1][0]["item"] = ItemCatalog.make("t1_deneng_hufu")
	BattleAI.run_item_economy(full_energy, 1, _rng())
	assert_true(full_energy.item_uses[1].is_empty(),
		"满能时攒不会得能，AI不得把得能护符作为本回合效果空放；允许将其投资升级")

	var h04 := _battle_ready(20)
	(h04.heroes[1][0] as HeroData).hero_id = "h04"
	# 测试夹具换ID后重建一次技能组件，模拟正式房日阵容。
	var h04_battle := BattleCore.new()
	h04_battle.setup(h04.heroes[0], h04.heroes[1], SEED)
	h04_battle.energy = [20, 20]
	h04_battle.econ_init()
	h04_battle.slots[1][0] = _ready_slot("t1_xunxing_zhui")
	BattleAI.commit_attack_items(h04_battle, 1, A.ATTACK)
	assert_true(h04_battle.slot_ready(1, 0), "房日已有自由选敌权，不应为减伤的零收益寻星坠买单")
	h04_battle.set_status(1, 0, "silenced", 1)
	BattleAI.commit_attack_items(h04_battle, 1, A.ATTACK)
	assert_false(h04_battle.slot_ready(1, 0), "房日被沉默失去自身选敌权时，寻星坠仍应作为独立工具可用")

	var charge := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	charge.slots[1][0]["item"] = ItemCatalog.make("t1_deneng_hufu")
	BattleAI.run_item_economy(charge, 1, _rng())
	assert_true(charge.slot_ready(1, 0), "得能护符应等最终得能路线确定后再提交")
	BattleAI.commit_attack_items(charge, 1, A.CHARGE)
	assert_false(charge.slot_ready(1, 0), "最终选择攒时应提交得能护符")

	var free_switch := _battle_ready(20)
	(free_switch.heroes[1][0] as HeroData).hero_id = "h07"
	var h07_battle := BattleCore.new()
	h07_battle.setup(free_switch.heroes[0], free_switch.heroes[1], SEED)
	h07_battle.energy = [20, 20]
	h07_battle.econ_init()
	h07_battle.slots[1][0] = _ready_slot("t1_huanfang_kou")
	assert_true(h07_battle.free_switch(1, 1))
	BattleAI.commit_attack_items(h07_battle, 1, A.ATTACK)
	assert_false(h07_battle.slot_ready(1, 0), "H07已免费切换后即使最终攻击，也应提交换防扣")


func test_t1_healing_links_require_real_recipients_and_payable_costs() -> void:
	var first_aid := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	first_aid.slots[1][0]["item"] = ItemCatalog.make("t1_jijiu_ling")
	BattleAI.commit_attack_items(first_aid, 1, A.ATTACK)
	assert_true(first_aid.slot_ready(1, 0), "全队满血时不浪费急救铃")
	first_aid.hp[1][2] = 10
	BattleAI.commit_attack_items(first_aid, 1, A.ATTACK)
	assert_false(first_aid.slot_ready(1, 0), "有伤员且选攻击时使用急救铃")

	var ferry := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	ferry.slots[1][0]["item"] = ItemCatalog.make("t1_xuedu_jie")
	ferry.hp[1][1] = 10
	ferry.hp[1][0] = 2
	BattleAI.run_item_economy(ferry, 1, _rng())
	assert_true(ferry.slot_ready(1, 0), "仅剩1点生命且无还魂保险时不支付血渡结")
	ferry.set_status(1, 0, "fatal_damage_immunity", 1)
	BattleAI.run_item_economy(ferry, 1, _rng())
	assert_false(ferry.slot_ready(1, 0), "有受伤队友且致命付血可被还魂保护时可使用")

	var ferries := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	ferries.slots[1][0] = _ready_slot("t1_xuedu_jie")
	ferries.slots[1][1] = _ready_slot("t1_xuedu_jie")
	ferries.hp[1][0] = 4
	ferries.hp[1][1] = 12
	BattleAI.run_item_economy(ferries, 1, _rng())
	assert_false(ferries.slot_ready(1, 0), "有支付空间时可提交第一件血渡结")
	assert_true(ferries.slot_ready(1, 1), "第二件会令当前英雄死亡且无保险，应保留")

	var duplicates := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	duplicates.slots[1][0] = _ready_slot("t1_jiedu_yaoshui")
	duplicates.slots[1][1] = _ready_slot("t1_jiedu_yaoshui")
	duplicates.set_status(1, duplicates.active_index[1], "poison", 3)
	BattleAI.run_item_economy(duplicates, 1, _rng())
	assert_false(duplicates.slot_ready(1, 0), "单一状态只需一瓶解毒药水")
	assert_true(duplicates.slot_ready(1, 1), "第二瓶应保留，避免同拍重复净化同一状态")


func test_nuanyu_waits_for_a_defense_action_and_real_team_healing_value() -> void:
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0]["item"] = ItemCatalog.make("t2_nuanyu")
	b.hp[1][1] = 10
	BattleAI.run_item_economy(b, 1, _rng())
	assert_true(b.slot_ready(1, 0), "暖玉不能在动作确定前被AI当作无条件治疗使用")
	BattleAI.commit_attack_items(b, 1, A.DEFEND)
	assert_false(b.slot_ready(1, 0), "选择防御且队伍有人受伤时才提交暖玉")

	var full := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	full.slots[1][0]["item"] = ItemCatalog.make("t2_nuanyu")
	BattleAI.commit_attack_items(full, 1, A.DEFEND)
	assert_true(full.slot_ready(1, 0), "全队满血时不应浪费暖玉")


func test_ai_does_not_submit_huanhundan_to_a_hero_who_already_used_one() -> void:
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0]["item"] = ItemCatalog.make("t2_huanhundan")
	b.set_status(1, b.active_index[1], "huanhun_used", 1)
	BattleAI.run_item_economy(b, 1, _rng())
	assert_true(b.slot_ready(1, 0), "每名英雄限用一次后，AI必须为其他英雄保留还魂丹")


# === 抽取自动解锁的格 ===

func test_draws_from_auto_opened_slot() -> void:
	var b := _battle(20)
	_advance(b, 3)                       # 显示回合 4：slot1 自动解锁（免费）
	assert_true(b.can_draw_slot(1, 1))
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 1), SS.CHARGING, "AI 抽取自动解锁格 → CHARGING")
	assert_not_null(b.slot_item(1, 1))


# === 富余能量补充 / reserve 不饿死动作 ===

func test_refills_empty_slot_with_surplus() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t3_shengming")   # 不可升 T3 → AI 直接用（隔离升级能耗）
	b.hp[1][0] = 1   # 生命药水只在有治疗收益时使用，避免把 AI 的防浪费门误判为补充失败。
	BattleAI.run_item_economy(b, 1, _rng())
	_advance(b, 1)                       # 用掉 → EMPTY
	assert_eq(b.slot_state(1, 0), SS.EMPTY)
	var e0 := b.energy[1]
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 0), SS.CHARGING, "富余能量补充空槽（3 选 1 已抽）")
	assert_eq(e0 - b.energy[1], BattleCore.ITEM_REFILL_COST, "补充扣 1 能")


func test_no_refill_when_energy_below_reserve() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t3_shengming")
	b.hp[1][0] = 1
	BattleAI.run_item_economy(b, 1, _rng())
	_advance(b, 1)                       # 用掉 → EMPTY
	b.energy[1] = BattleCore.ITEM_REFILL_COST + BattleAI.AI_ITEM_ENERGY_RESERVE - 1   # 差 1 半能
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 0), SS.EMPTY, "能量不足 reserve → 不补充（留行动预算）")


# === 升级择时（任务 C）===

func test_upgrades_ready_item_with_ample_energy() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")   # 就绪可升（T1）
	assert_true(b.can_upgrade(1, 0))
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_item(1, 0).tier, 2, "能量富余 → AI 升级就绪件（换 T2）")
	assert_false(b.slot_ready(1, 0), "升级后重新锁本回合（电报）")
	assert_eq(b.item_uses[1].size(), 0, "升级的槽不提交使用")


func test_uses_instead_of_upgrade_when_energy_tight() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_jiudun")   # 防御件（进攻件不走"直接用"路径）
	# 差 1 半能够不到「升级成本 + reserve + buffer」投资线 → 应直接用掉、不投资升级。
	b.energy[1] = BattleCore.UPGRADE_COST + BattleAI.AI_ITEM_ENERGY_RESERVE + BattleAI.AI_ITEM_UPGRADE_BUFFER - 1
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_item(1, 0).item_id, "t1_jiudun", "能量不够投资 → 不升级")
	assert_eq(b.item_uses[1].size(), 1, "改为直接用掉就绪件")


func test_upgrades_at_most_one_per_turn() -> void:
	var b := _battle_ready(30)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.slots[1][1] = {state = SS.CHARGING, item = ItemCatalog.make("t1_jiudun"),
		since = -1, used = false, draft = [], upg_draft = []}   # 第二个就绪可升槽
	assert_true(b.slot_ready(1, 0) and b.slot_ready(1, 1), "两槽都就绪可升")
	BattleAI.run_item_economy(b, 1, _rng())
	var upgraded := 0
	for s in range(BattleCore.SLOT_COUNT):
		if b.slot_item(1, s) != null and b.slot_item(1, s).tier == 2:
			upgraded += 1
	assert_eq(upgraded, 1, "每回合最多升 1 个")
	assert_eq(b.item_uses[1].size(), 1, "另一个就绪件被用掉")


# === 3 选 1 智能选牌（任务#6·2026-07-03）===

func test_smart_pick_heal_scales_with_missing_hp() -> void:
	# 治疗件随掉血增值；满血不倒扣（首版倒扣被 A/B 证伪·见 score_item_option 校准记录）。
	var full := _battle(20)
	var hurt := _battle(20)
	hurt.hp[1][0] = 4   # AI 出战重伤（满 20 半点）
	var heal := ItemCatalog.make("t1_lzhi_shengming")
	assert_gt(BattleAI.score_item_option(hurt, 1, heal), BattleAI.score_item_option(full, 1, heal),
		"掉血时治疗分 > 满血时治疗分")


func test_smart_pick_prefers_heal_when_damaged() -> void:
	var b := _battle(20)
	b.hp[1][0] = 4   # AI 出战重伤（满 20 半点）
	var dart := ItemCatalog.make("t1_feibiao")
	var heal := ItemCatalog.make("t1_lzhi_shengming")
	assert_gt(BattleAI.score_item_option(b, 1, heal), BattleAI.score_item_option(b, 1, dart),
		"重伤：治疗 > 飞镖")


func test_smart_pick_prefers_attack_at_kill_range() -> void:
	var b := _battle(20)
	b.hp[0][0] = 2   # 敌方出战进斩杀圈（≤2HP=4 半点）
	var dart := ItemCatalog.make("t1_feibiao")
	var shield := ItemCatalog.make("t1_jiudun")
	assert_gt(BattleAI.score_item_option(b, 1, dart), BattleAI.score_item_option(b, 1, shield),
		"敌进斩杀圈：进攻件 > 护盾件（收割票）")


func test_smart_pick_values_energy_when_starved() -> void:
	var b := _battle(20)
	b.energy[1] = 2   # 缺能（1.0 能）
	var mana := ItemCatalog.make("t1_lzhi_fali")
	var b2 := _battle(20)
	b2.energy[1] = 12  # 能量富余
	assert_gt(BattleAI.score_item_option(b, 1, mana), BattleAI.score_item_option(b2, 1, mana),
		"缺能时能量件比富余时更值钱")


# === T2 提基：点金石目标、即时资源与新 EV / role ===

func test_pointstone_chooses_t3_candidate_and_locks_target_for_one_turn() -> void:
	var b := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0] = _ready_slot("t2_dianjinshi")
	b.slots[1][0]["upg_draft"] = [
		ItemCatalog.make("t3_fali"),
		ItemCatalog.make("t3_yujin"),
		ItemCatalog.make("t3_shengming"),
	]
	b.slots[1][1] = _ready_slot("t1_feibiao")
	b.slots[1][2] = _ready_slot("t2_jiandun")

	BattleAI.run_item_economy(b, 1, _rng())

	assert_eq(b.slot_item(1, 1).item_id, "t3_fali",
			"17件T3同一基础EV后，低能局面应选择能立即打开行动空间的法力药水")
	assert_true(bool(b.slots[1][0]["used"]), "点金石成功消耗")
	assert_false(bool(b.slots[1][1]["used"]), "升级目标不是本回合已使用道具")
	assert_false(b.slot_ready(1, 1), "新传说道具必须锁定一回合")


func test_pointstone_stays_ready_without_a_legal_t1_target() -> void:
	var b := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0] = _ready_slot("t2_dianjinshi")
	b.slots[1][1] = _ready_slot("t2_jiandun")
	b.slots[1][2] = _ready_slot("t2_feibiao")

	BattleAI.run_item_economy(b, 1, _rng())

	assert_true(b.slot_ready(1, 0), "没有另一件可升级 T1 时不得空放点金石")
	assert_eq(b.slot_item(1, 0).item_id, "t2_dianjinshi")


func test_t2_ev_and_attack_roles_use_catalog_truth() -> void:
	var b := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	var t1_shield := ItemCatalog.make("t1_jiudun")
	var t2_shield := ItemCatalog.make("t2_jiandun")
	assert_eq(t2_shield.ev_half, 4, "T2 稳定件以 2 点价值为目录基准")
	assert_gt(BattleAI.score_item_option(b, 1, t2_shield),
			BattleAI.score_item_option(b, 1, t1_shield),
			"AI 从 ev_half 读取新层级，不沿用旧 1 点硬编码")

	b.slots[1][0] = _ready_slot("t2_huoshou")   # role=攻→能，dimension=导出
	BattleAI.run_item_economy(b, 1, _rng())
	assert_true(b.slot_ready(1, 0), "含攻击连接的 T2 role 留到攻击回合")
	BattleAI.commit_attack_items(b, 1, A.ATTACK)
	assert_false(b.slot_ready(1, 0), "攻击确定后再提交命中骑乘 T2")


func test_magic_crystal_and_burst_scroll_open_previously_unaffordable_actions() -> void:
	var crystal := _battle(2)
	crystal.slots[1][0] = _ready_slot("t2_mojing")
	BattleAI.run_item_economy(crystal, 1, _rng())
	assert_true(crystal.can_afford(1, A.BIG_ATTACK),
			"AI 在选动作前结算魔晶即时产能")

	var scroll := _battle(2)
	scroll.slots[1][0] = _ready_slot("t2_baolie")
	BattleAI.run_item_economy(scroll, 1, _rng())
	assert_true(scroll.can_afford(1, A.BIG_ATTACK),
			"AI 在选动作前读取爆裂卷轴即时大波减费")


# === T3 条件与唯一遗物 ===

func test_t3_attack_items_wait_for_their_actual_public_action_condition() -> void:
	var wave := _battle(20)
	wave.slots[1][0] = _ready_slot("t3_jianyi")
	wave.slots[1][1] = _ready_slot("t3_longxi")
	wave.slots[1][2] = _ready_slot("t3_yujin")
	BattleAI.commit_attack_items(wave, 1, A.ATTACK)
	assert_false(wave.slot_ready(1, 0), "至臻剑意只应随「波」提交")
	assert_true(wave.slot_ready(1, 1), "龙息不能被「波」白白烧掉")
	assert_true(wave.slot_ready(1, 2), "生命高于1点时不应浪费不死鸟羽毛")

	var big_wave := _battle(20)
	big_wave.slots[1][0] = _ready_slot("t3_jianyi")
	big_wave.slots[1][1] = _ready_slot("t3_longxi")
	BattleAI.commit_attack_items(big_wave, 1, A.BIG_ATTACK)
	assert_true(big_wave.slot_ready(1, 0), "至臻剑意不能被「大波」反向消耗")
	assert_false(big_wave.slot_ready(1, 1), "龙息应随「大波」提交")

	var last_stand := _battle(20)
	last_stand.hp[1][0] = 2
	last_stand.slots[1][0] = _ready_slot("t3_yujin")
	BattleAI.commit_attack_items(last_stand, 1, A.ATTACK)
	assert_false(last_stand.slot_ready(1, 0), "达到公开濒死条件后应提交不死鸟羽毛")


func test_ai_keeps_unique_t3_relic_duplicate_until_existing_one_ends() -> void:
	var b := _battle(20)
	b.relics[1].append({data = ItemCatalog.make("t3_shixinding"), state = {}})
	b.slots[1][0] = _ready_slot("t3_shixinding")
	BattleAI.commit_attack_items(b, 1, A.ATTACK)
	assert_true(b.slot_ready(1, 0), "唯一噬心钉存续时重复件没有叠乘价值，不应被AI浪费")


func test_ai_does_not_spend_obviously_blank_t3_before_action_selection() -> void:
	var b := _battle(20)
	b.energy[1] = b.energy_max[1]
	b.slots[1][0] = _ready_slot("t3_shengming")
	b.slots[1][1] = _ready_slot("t3_fali")
	b.slots[1][2] = _ready_slot("t3_yiqi")
	b.energy[0] = 0
	b.hp[0][1] = 0
	b.hp[0][2] = 0

	BattleAI.run_item_economy(b, 1, _rng())

	assert_true(b.slot_ready(1, 0), "满血时不应空放上等生命药水")
	assert_true(b.slot_ready(1, 1), "满能时不应空放上等法力药水")
	assert_true(b.slot_ready(1, 2), "对手当前无任何合法攻击时不应空放周天罡气")


func test_ai_uses_mengdie_only_when_public_energy_and_item_bar_swap_is_favorable() -> void:
	var favorable := _battle(20)
	favorable.energy = [16, 0]
	favorable.slots[1][0] = _ready_slot("t3_mengdie")
	favorable.slots[0][0] = _ready_slot("t3_morihuozhong")
	BattleAI.run_item_economy(favorable, 1, _rng())
	assert_false(favorable.slot_ready(1, 0), "对方公开资源显著更高时应提交梦蝶")

	var unfavorable := _battle(20)
	unfavorable.energy = [0, 16]
	unfavorable.slots[1][0] = _ready_slot("t3_mengdie")
	BattleAI.run_item_economy(unfavorable, 1, _rng())
	assert_true(unfavorable.slot_ready(1, 0), "交换会明显亏损时应保留梦蝶")


func test_t3_item_option_values_morihuozhong_last_survivor_condition() -> void:
	var full_team := _battle(20)
	var last_survivor := _battle(20)
	last_survivor.hp[1][1] = 0
	last_survivor.hp[1][2] = 0
	var fire := ItemCatalog.make("t3_morihuozhong")
	assert_gt(BattleAI.score_item_option(last_survivor, 1, fire),
		BattleAI.score_item_option(full_team, 1, fire),
		"末日火种在唯一存活英雄局面应显著升值")


func test_tianluodiwang_option_values_opponent_public_items_as_interference_targets() -> void:
	var pressure := _battle(20)
	pressure.slots[0][0] = _ready_slot("t3_fali")
	pressure.slots[0][1] = _ready_slot("t3_yiqi")
	var blank := _battle(20)
	for slot: int in range(BattleCore.SLOT_COUNT):
		blank.slots[0][slot]["item"] = null
	blank.hp[0][1] = 0
	blank.hp[0][2] = 0
	var net := ItemCatalog.make("t3_tianluodiwang")
	assert_gt(BattleAI.score_item_option(pressure, 1, net),
		BattleAI.score_item_option(blank, 1, net),
		"对手有公开就绪道具时，天罗拥有首件干扰价值")
	var one_item := _battle(20)
	one_item.slots[0][0] = _ready_slot("t3_fali")
	assert_almost_eq(BattleAI.score_item_option(pressure, 1, net),
		BattleAI.score_item_option(one_item, 1, net), 0.001,
		"天罗只封首件道具，不得按对手整栏数量线性增值")


func test_t3_option_scoring_reads_poison_switch_and_attack_conditions() -> void:
	var neutral := _battle(20)
	var poison_ready := _battle(20)
	poison_ready.set_status(0, 0, "poison", 3)
	var heding := ItemCatalog.make("t3_hedinghong")
	assert_gt(BattleAI.score_item_option(poison_ready, 1, heding),
		BattleAI.score_item_option(neutral, 1, heding),
		"敌方当前毒层越高，下一次逐层增伤的鹤顶红越值钱")

	var no_reserve := _battle(20)
	no_reserve.hp[1][1] = 0
	no_reserve.hp[1][2] = 0
	var pearl := ItemCatalog.make("t3_yemingzhu")
	assert_gt(BattleAI.score_item_option(neutral, 1, pearl),
		BattleAI.score_item_option(no_reserve, 1, pearl),
		"没有可切换替补时夜明珠应折价")

	var no_attack := _battle(20)
	no_attack.energy[0] = 0
	var qi := ItemCatalog.make("t3_yiqi")
	assert_gt(BattleAI.score_item_option(neutral, 1, qi),
		BattleAI.score_item_option(no_attack, 1, qi),
		"对手当前存在合法攻击时周天罡气才有明确即时防护价值")

	var free_big := _battle(20)
	free_big.energy[1] = 0
	free_big.item_buffs[1]["free_big_attack_until_turn"] = free_big.turn_number
	var shixin := ItemCatalog.make("t3_shixinding")
	assert_gt(BattleAI.score_item_option(free_big, 1, shixin),
		BattleAI.score_item_option(no_attack, 0, shixin),
		"至臻剑意的免费大波窗口应成为噬心钉可续攻的真实组合")


# === 背包首批 + 参考游戏转译批 AI 收口 ===

func test_ai_uses_backpack_tools_with_real_targets_and_private_choices() -> void:
	var deposit := _battle(0)
	deposit.configure_battle_backpacks([], ["t1_lzhi_shengming"])
	deposit.econ_init()
	deposit.slots[1][0] = _ready_slot("t1_jicun_pai")
	deposit.slots[1][1] = _ready_slot("t1_jiudun")
	BattleAI.run_item_economy(deposit, 1, _rng())
	assert_false(deposit.slot_ready(1, 0), "寄存牌应在缺能时选择另一件就绪道具")
	assert_true(bool(deposit.slots[1][1]["used"]), "被寄存的目标槽应当腾空")
	assert_eq(deposit.energy[1], BattleCore.HP_UNIT, "寄存牌应立即获得1点能量")

	var repurchase := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	repurchase.configure_battle_backpacks([], [])
	repurchase.econ_init()
	repurchase.slots[1][0] = _ready_slot("t2_huigou_quan")
	repurchase.used_item_history[1].append({item_id = "t1_xianshou", tier = 1})
	BattleAI.run_item_economy(repurchase, 1, _rng())
	assert_false(repurchase.slot_ready(1, 0), "回购券有合法历史目标时应选择候选")
	assert_eq(String((repurchase.battle_backpacks[1][0] as Dictionary)["item_id"]),
		"t1_xianshou")
	assert_true(bool((repurchase.battle_backpacks[1][0] as Dictionary)["temporary"]),
		"回购产物必须保持临时物件身份")

	var exchange := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	exchange.configure_battle_backpacks([], ["t1_lzhi_shengming", "t2_jiandun"])
	exchange.econ_init()
	exchange.slots[1][0] = _ready_slot("t2_huanqian_tong")
	exchange.slots[1][1] = _ready_slot("t1_xianshou")
	BattleAI.run_item_economy(exchange, 1, _rng())
	assert_false(exchange.slot_ready(1, 0), "换签筒应选择另一件道具与背包候选")
	assert_ne(exchange.slot_item(1, 1).item_id, "t1_xianshou")
	assert_false(exchange.slot_ready(1, 1), "换入道具必须锁定一回合")


func test_ai_uses_remaining_backpack_tools_only_with_real_value() -> void:
	var insurance := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	insurance.configure_battle_backpacks([], [])
	insurance.econ_init()
	insurance.slots[1][0] = _ready_slot("t2_baojia_feng")
	insurance.slots[1][1] = _ready_slot("t3_yiqi")
	insurance.slots[0][0] = _ready_slot("t1_yaohuo")
	BattleAI.run_item_economy(insurance, 1, _rng())
	assert_false(insurance.slot_ready(1, 0), "存在敌方负面道具时应为高价值道具投保")
	assert_eq(int((insurance.item_uses[1][0] as Dictionary)["item_slot_target"]), 1)

	var emergency := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	emergency.configure_battle_backpacks([], ["t1_xianshou", "t2_jiandun"])
	emergency.econ_init()
	emergency.slots[1][0] = _ready_slot("t2_yingji_xiang")
	BattleAI.run_item_economy(emergency, 1, _rng())
	assert_eq((emergency.slot_item(1, 0) as ItemData).item_id, "t1_xianshou",
		"应急箱应从背包取出普通道具并立即替换来源槽")
	assert_true(emergency.slot_ready(1, 0), "应急箱替换结果必须可以在本回合继续使用")

	var listen := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	listen.configure_battle_backpacks(
		["t1_xianshou", "t1_jiudun", "t2_jiandun"], [])
	listen.econ_init()
	listen.slots[1][0] = _ready_slot("t1_tingxia_tong")
	BattleAI.run_item_economy(listen, 1, _rng())
	assert_false(listen.slot_ready(1, 0), "敌方背包仍有未知道具时应使用听匣筒")


func test_ai_arms_conversion_items_only_when_their_route_exists() -> void:
	var dew := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	dew.configure_battle_backpacks([], [])
	dew.econ_init()
	dew.energy[1] = 0
	dew.slots[1][0] = _ready_slot("t2_chenglu_zhan")
	dew.slots[1][1] = _ready_slot("t3_shengming")
	BattleAI.run_item_economy(dew, 1, _rng())
	assert_false(dew.slot_ready(1, 0), "本回合存在治疗来源且能量未满时应登记承露盏")

	var gourd := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	gourd.configure_battle_backpacks([], [])
	gourd.econ_init()
	gourd.energy[1] = gourd.energy_max[1]
	gourd.hp[1][0] = 4
	gourd.slots[1][0] = _ready_slot("t2_naying_hulu")
	BattleAI.run_item_economy(gourd, 1, _rng())
	assert_false(gourd.slot_ready(1, 0), "有受伤目标且攒会溢出时应登记纳盈葫芦")

	var blank := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	blank.configure_battle_backpacks([], [])
	blank.econ_init()
	blank.slots[1][0] = _ready_slot("t2_chenglu_zhan")
	BattleAI.run_item_economy(blank, 1, _rng())
	assert_true(blank.slot_ready(1, 0), "没有治疗来源时不得空放承露盏")


func test_ai_targets_enemy_ready_items_for_wager_and_use_pressure() -> void:
	for source_id in ["t2_yawu_piao", "t2_cuiyong_pai"]:
		var b := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
		b.configure_battle_backpacks([], [])
		b.econ_init()
		b.slots[1][0] = _ready_slot(source_id)
		b.slots[0][0] = _ready_slot("t1_xianshou")
		b.slots[0][1] = _ready_slot("t3_yiqi")
		BattleAI.run_item_economy(b, 1, _rng())
		assert_false(b.slot_ready(1, 0), "%s 应对公开就绪道具选择目标" % source_id)
		assert_eq(int((b.item_uses[1][0] as Dictionary)["item_slot_target"]), 1,
			"应优先施压价值更高的传说道具")


func test_ai_holds_blank_new_items_and_uses_live_windows() -> void:
	var pill_blank := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	pill_blank.slots[1][0] = _ready_slot("t2_dingming_wan")
	BattleAI.run_item_economy(pill_blank, 1, _rng())
	assert_true(pill_blank.slot_ready(1, 0), "生命不少于3点时不得浪费定命丸")

	var pill_live := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	pill_live.hp[1][0] = 2
	pill_live.slots[1][0] = _ready_slot("t2_dingming_wan")
	BattleAI.run_item_economy(pill_live, 1, _rng())
	assert_false(pill_live.slot_ready(1, 0), "低于3点时应使用定命丸")

	var broom_blank := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	broom_blank.slots[1][0] = _ready_slot("t2_jingwen_zhou")
	BattleAI.run_item_economy(broom_blank, 1, _rng())
	assert_true(broom_blank.slot_ready(1, 0), "没有待清命中成果时不得空放净纹帚")

	var broom_live := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	broom_live.set_status(0, 0, "poison", 3)
	broom_live.slots[1][0] = _ready_slot("t2_jingwen_zhou")
	BattleAI.run_item_economy(broom_live, 1, _rng())
	assert_false(broom_live.slot_ready(1, 0), "敌方待结算命中成果更多时应使用净纹帚")

	var armor_blank := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	armor_blank.energy[0] = 3 * ActionDef.ENERGY_UNIT
	armor_blank.slots[1][0] = _ready_slot("t2_pianfeng_jia")
	BattleAI.run_item_economy(armor_blank, 1, _rng())
	assert_true(armor_blank.slot_ready(1, 0), "敌方可用大波时不得主动给其增伤")

	var armor_live := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	armor_live.energy[0] = ActionDef.ENERGY_UNIT
	armor_live.slots[1][0] = _ready_slot("t2_pianfeng_jia")
	BattleAI.run_item_economy(armor_live, 1, _rng())
	assert_false(armor_live.slot_ready(1, 0), "敌方只能用波时应使用偏锋甲")

	var limiter := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	limiter.slots[1][0] = _ready_slot("t2_duyong_feng")
	limiter.slots[0][0] = _ready_slot("t1_xianshou")
	limiter.slots[0][1] = _ready_slot("t1_jiudun")
	BattleAI.run_item_economy(limiter, 1, _rng())
	assert_false(limiter.slot_ready(1, 0), "我方仅一件、敌方至少两件时应使用独用封")

	var silence := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	silence.heroes[0][0] = _hero("h01", 10)
	silence.heroes[0][1] = _hero("h06", 10)
	silence.slots[1][0] = _ready_slot("t3_xiling_ling")
	BattleAI.run_item_economy(silence, 1, _rng())
	assert_false(silence.slot_ready(1, 0), "敌方英雄技能压力更高时应使用息灵铃")


func test_ai_uses_last_wish_only_for_a_real_sacrifice_handoff() -> void:
	var blank := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	blank.slots[1][0] = _ready_slot("t3_yiyuan_deng")
	BattleAI.run_item_economy(blank, 1, _rng())
	assert_true(blank.slot_ready(1, 0), "满血出战且替补无治疗收益时不得使用遗愿灯")

	var live := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	live.hp[1] = [2, 4, 12]
	live.max_hp[1] = [20, 20, 20]
	live.slots[1][0] = _ready_slot("t3_yiyuan_deng")
	BattleAI.run_item_economy(live, 1, _rng())
	assert_false(live.slot_ready(1, 0), "残血出战应把遗愿灯交给治疗收益最大的替补")
	assert_eq(int((live.item_uses[1][0] as Dictionary)["target"]), 1)


func test_ai_commits_exact_spend_refund_and_lone_attack_boost() -> void:
	var refund := _battle(ActionDef.ENERGY_UNIT)
	refund.slots[1][0] = _ready_slot("t2_huiliu_zhu")
	BattleAI.commit_attack_items(refund, 1, A.ATTACK)
	assert_false(refund.slot_ready(1, 0), "能量正好支付波时应提交回流珠")

	var no_refund := _battle(2 * ActionDef.ENERGY_UNIT)
	no_refund.slots[1][0] = _ready_slot("t2_huiliu_zhu")
	BattleAI.commit_attack_items(no_refund, 1, A.ATTACK)
	assert_true(no_refund.slot_ready(1, 0), "行动不会耗尽能量时应保留回流珠")

	var lone := _battle(BattleAI.AI_ITEM_ENERGY_RESERVE)
	lone.slots[1][0] = _ready_slot("t1_gufeng_zhui")
	BattleAI.commit_attack_items(lone, 1, A.ATTACK)
	assert_false(lone.slot_ready(1, 0), "孤锋锥为唯一可用道具时应随攻击提交")


func test_lianhuan_gu_expands_ai_choices_into_two_different_public_actions() -> void:
	var b := _battle(20)
	b.slots[1][0] = _ready_slot("t3_lianhuan_gu")
	assert_true(b.use_slot(1, 0))
	var choices: Array = BattleAI._legal_actions_for_decision(b, 1)
	assert_gt(choices.size(), 0)
	for choice_variant in choices:
		var choice: Dictionary = choice_variant
		assert_true(choice.has("second_action"), "连环鼓搜索节点必须携带第二行动")
		assert_ne(int(choice["action"]), int(choice["second_action"]), "两个公共行动必须不同")
		assert_true(int(choice["second_action"]) in [A.CHARGE, A.ATTACK, A.DEFEND, A.BIG_ATTACK, A.BIG_DEFEND])


func test_new_t3_friendly_targets_choose_a_useful_dead_or_healthier_reserve() -> void:
	var summon := _battle(20)
	summon.hp[1][1] = 0
	summon.hp[1][2] = 0
	summon.max_hp[1][1] = 8
	summon.max_hp[1][2] = 14
	assert_eq(BattleAI._best_friendly_item_target(
		summon, 1, ItemCatalog.make("t3_zhaohun_fan")), 2,
		"招魂幡应优先复活生命上限更高的已死亡替补")

	var swap := _battle(20)
	swap.hp[1][0] = 2
	swap.hp[1][1] = 10
	swap.shield[1][1] = 4
	swap.hp[1][2] = 6
	assert_eq(BattleAI._best_friendly_item_target(
		swap, 1, ItemCatalog.make("t3_huanming_qi")), 1,
		"换命契应选择能明显改善出战生存线的替补")


# === 安全：未 init 经济 ===

func test_safe_when_econ_not_init() -> void:
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], SEED)
	BattleAI.run_item_economy(b, 1, _rng())   # slots=[[],[]] → 守卫早退、不崩
	assert_eq(b.item_uses[1].size(), 0, "未启用经济：AI 无道具操作")
