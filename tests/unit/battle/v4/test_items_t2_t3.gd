extends GutTest

## Tier-2 / Tier-3 道具（非中立·非趣味·Phase 1 Tier-A 批）行为锁定测试（ADR-003）。
## 无技能 test_* 英雄隔离道具效果。半点制：1HP=2 半点、1 能=2 半能。基线出战 HP=20。

const A := ActionDef.Action
const SEED := 777


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id   # "test_" 前缀 → 注册表无技能
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	var p1: Array = [_hero("test_a", 10), _hero("test_b", 10), _hero("test_c", 10)]
	var p2: Array = [_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)]
	b.setup(p1, p2, SEED)
	b.energy = [energy, energy]
	return b


func _give(b: BattleCore, player: int, id: String) -> int:
	return b.give_item(player, ItemCatalog.make(id))


func _resolve_cc(b: BattleCore) -> void:
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()


# === T2 升级线 / 数值件 ===

func test_t2_feibiao_deals_full_damage() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_feibiao"))
	_resolve_cc(b)
	assert_eq(b.hp[1][0], 16)   # 2.0 伤 = 4 半点


func test_t2_jiandun_adds_full_shield() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_jiandun"))
	_resolve_cc(b)
	assert_eq(b.shield[0][0], 4)


func test_t2_shengming_heals_full() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_shengming"))
	_resolve_cc(b)
	assert_eq(b.hp[0][0], 14)


func test_t2_nuanyu_heals_only_after_successful_defense() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_nuanyu"))
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.ATTACK)
	b.resolve()
	assert_eq(b.hp[0][0], 12)


func test_t2_nuanyu_no_heal_without_defend() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_nuanyu"))
	_resolve_cc(b)
	assert_eq(b.hp[0][0], 10)


# === T2 破防 / 穿透 / 穿甲（新 core 钩子）===

func test_t2_shitiechong_downgrades_big_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_shitiechong"))
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # 大防被降级为防 → 挡不住大波(穿防)
	b.resolve()
	assert_eq(b.hp[1][0], 16)   # 大波 2.0 = 4 半点落地


func test_t2_shitiechong_control_big_defend_blocks() -> void:
	var b := _battle()
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # 无噬铁虫 → 大防挡下大波
	b.resolve()
	assert_eq(b.hp[1][0], 20)


func test_t2_pomoshi_pierces_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_pomoshi"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 16)   # 波总伤害+1并穿防


func test_t2_qiubite_ignores_armor_layer() -> void:
	var b := _battle()
	b.shield[1][0] = 4   # 对手 2.0 甲
	b.use_item(0, _give(b, 0, "t2_qiubite"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18)      # 下一次波改为真实伤害 → 直击血量
	assert_eq(b.shield[1][0], 4)   # 护甲层原封不动


func test_t2_qiubite_control_armor_absorbs() -> void:
	var b := _battle()
	b.shield[1][0] = 4
	b.use_item(0, _give(b, 0, "t2_feibiao"))   # 普通飞镖被甲吸收
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 20)
	assert_eq(b.shield[1][0], 0)   # 2.0 飞镖被 2.0 护甲完整吸收


# === T2 状态 / 易伤 ===

func test_t2_duyao_poison_detonates_on_hit() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_duyao"))
	b.select_action(0, A.ATTACK)   # 波命中 → 引爆 3 层毒
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 15)   # 波 1点 + 3层毒素 1.5点
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 0)


func test_t2_duyao_poison_detonates_when_shield_absorbs_the_attack() -> void:
	var b := _battle()
	b.shield[1][0] = 2
	b.use_item(0, _give(b, 0, "t2_duyao"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 17, "护甲吸收波的伤害后仍算命中，毒素照常引爆")
	assert_eq(b.shield[1][0], 0)
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 0)


func test_t2_duyao_poison_does_not_detonate_when_defend_blocks_wave() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_duyao"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 20)
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 3,
		"防挡下波后不算命中，毒素保留")


func test_t2_duyao_poison_does_not_detonate_from_independent_item_damage() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_duyao"))
	b.use_item(0, _give(b, 0, "t1_feibiao"))
	_resolve_cc(b)
	assert_eq(b.hp[1][0], 18, "独立道具只造成自身1点伤害，不引爆毒素")
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 3,
		"只有波／大波命中才能引爆毒素")


func test_t2_duyao_poison_does_not_detonate_from_skill_or_retaliation_strike() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_duyao"))
	_resolve_cc(b)
	var events: Array = []
	var dealt := b.strike(1, 2, 0, ActionDef.Pen.NORMAL, events)
	assert_eq(dealt, 2, "技能或反击伤害仍正常经过伤害管线")
	assert_eq(b.hp[1][0], 18)
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 3,
		"非波／大波的管线打击不算命中，不引爆毒素")


func test_t2_lieyin_adds_three_persistent_vulnerable_layers() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_lieyin"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 15)   # 波 1点 + 3层脆弱 1.5点
	assert_eq(int(b.get_status(1, 0, "vuln", 0)), 3)


func test_t2_huanhundan_cheats_death() -> void:
	var b := _battle()
	b.hp[0][0] = 2   # 1.0 HP
	b.use_item(0, _give(b, 0, "t2_huanhundan"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.BIG_ATTACK)   # 致死大波
	b.resolve()
	assert_eq(b.hp[0][0], 2)   # 整次致命伤害无效
	assert_eq(int(b.get_status(0, 0, "fatal_damage_immunity", 0)), 0)


# === T2 干扰：定身 / 课税 / 藤蔓 ===

func test_t2_dingshen_locks_switch() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_dingshen"))
	b.select_action(0, A.CHARGE)
	b.select_switch(1, 1)   # 对手想切到 slot1 → 被定身
	b.resolve()
	assert_eq(b.active_index[1], 0)   # 没切成


func test_t2_dingshen_control_switch_succeeds() -> void:
	var b := _battle()
	b.select_action(0, A.CHARGE)
	b.select_switch(1, 1)
	b.resolve()
	assert_eq(b.active_index[1], 1)


func test_t2_daijia_adds_two_damage_and_kills_the_user() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_daijia"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 14)
	assert_eq(b.hp[0][0], 0)


# === T2 导出 ===

func test_t2_jike_heals_on_hit() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_jike"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 12)   # 命中回 1.0 HP


# === T3 ===

func test_t3_jianyi_wave_hit_makes_next_turn_first_big_attack_free() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_jianyi"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18)
	b.energy[0] = 0
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 14, "命中的波令下回合第一次大波免费并正常造成伤害")


func test_t3_yujin_desperate_burst() -> void:
	var b := _battle()
	b.hp[0][0] = 2   # 濒死
	b.use_item(0, _give(b, 0, "t3_yujin"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # +3.0 穿大防
	b.resolve()
	assert_eq(b.hp[1][0], 12)   # 波 2 + 6 = 8 落地


func test_t3_yujin_inert_when_healthy() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_yujin"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 20)   # HP 不低 → 无加成 → 普通波被防挡


func test_t3_longxi_doubles_big_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_longxi"))
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 12)   # 大波 4 ×2 = 8


func test_t3_longxi_exhausts_when_blocked() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_longxi"))
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # 被大防挡下 → 力竭
	b.resolve()
	assert_eq(b.hp[1][0], 20)
	# 下回合 p0 想攻击但力竭强制 CHARGE
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 20)   # 力竭 → 攻击没打出


func test_t3_shengming_heals_3hp() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t3_shengming"))
	_resolve_cc(b)
	assert_eq(b.hp[0][0], 16)


func test_t3_tinglong_dumps_energy_as_piercing_damage() -> void:
	var b := _battle(10)   # 5.0 能
	b.use_item(0, _give(b, 0, "t3_tinglong"))
	b.select_action(0, A.DEFEND)       # 不耗能、不产能
	b.select_action(1, A.BIG_DEFEND)   # 穿大防 → 砸穿
	b.resolve()
	assert_eq(b.hp[1][0], 15)   # 5.0 能 → 2.5 HP = 5 半点
	assert_eq(b.energy[0], 2)   # 清零 → 回合末被动 +1 能（2 半能）


# === C10 补测：此前仅冒烟覆盖的 T2/T3 件 ===

func test_t2_baolie_discounts_big_attack() -> void:
	var b := _battle(10)
	b.use_item(0, _give(b, 0, "t2_baolie"))
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.DEFEND)
	b.resolve()
	var got := b.energy[0]
	var b2 := _battle(10)
	b2.select_action(0, A.BIG_ATTACK)
	b2.select_action(1, A.DEFEND)
	b2.resolve()
	assert_eq(got - b2.energy[0], 4)   # 大波少耗 2 能 = 4 半能


func test_t2_dianjinshi_upgrades_t1_slot() -> void:
	var b := _battle()
	b.slots[0] = [
		{state = BattleCore.SlotState.CHARGING, item = ItemCatalog.make("t2_dianjinshi"), since = -1, used = false, draft = [], upg_draft = []},
		{state = BattleCore.SlotState.CHARGING, item = ItemCatalog.make("t1_feibiao"), since = -1, used = false, draft = [], upg_draft = []},
	]
	var opts: Array = b.begin_pointstone_draft(0, 0, 1)
	assert_eq(opts.size(), 3)
	assert_true(b.use_slot(0, 0, -1, 1, 0))
	assert_eq(String(b.slots[0][1]["item"].item_id), String((opts[0] as ItemData).item_id))
	assert_false(b.slot_ready(0, 1), "升级出的传说道具应锁一回合")


func test_t2_fengyin_locks_one_item_use() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_fengyin"))   # p0 封 p1 一个道具槽
	_resolve_cc(b)
	assert_eq((b.item_buffs[1].get("sealed_item_turns", []) as Array).size(), 1)
	# 下回合首件合法道具照常消耗但无效；第二件成功
	var idx := _give(b, 1, "t2_feibiao")
	assert_true(b.use_item(1, idx))
	assert_eq(b.item_uses[1].size(), 0)
	assert_true(b.use_item(1, idx))
	assert_eq(b.item_uses[1].size(), 1)


func test_t2_huoshou_energy_on_attack_connect() -> void:
	var b := _battle(6)
	b.use_item(0, _give(b, 0, "t2_huoshou"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	var got := b.energy[0]
	var b2 := _battle(6)
	b2.select_action(0, A.ATTACK)
	b2.select_action(1, A.CHARGE)
	b2.resolve()
	assert_eq(got - b2.energy[0], 3)   # 命中 +1.5 能


func test_t2_huoshou_no_energy_when_blocked() -> void:
	var b := _battle(6)
	b.use_item(0, _give(b, 0, "t2_huoshou"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # 大防挡下 → 未命中
	b.resolve()
	var b2 := _battle(6)
	b2.select_action(0, A.ATTACK)
	b2.select_action(1, A.BIG_DEFEND)
	b2.resolve()
	assert_eq(b.energy[0], b2.energy[0])   # 未命中 → 不回能


func test_t2_shuangsheng_does_not_repeat_item_attack_aftereffects() -> void:
	var b := _battle(6)
	b.hp[0] = [10, 10, 10]
	b.use_item(0, _give(b, 0, "t2_shuangsheng"))
	b.use_item(0, _give(b, 0, "t2_jike"))
	b.use_item(0, _give(b, 0, "t2_huoshou"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0], [12, 12, 12], "饥渴每次攻击只治疗全队一次")
	assert_eq(b.energy[0], 9, "护手每次攻击只回1.5点能量，不受双生额外触发影响")


func test_t2_mojing_borrows_energy_now_pays_next_turn() -> void:
	var b := _battle(6)
	b.use_item(0, _give(b, 0, "t2_mojing"))
	assert_eq(b.energy[0], 12, "提交时立即获得3能")
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.energy[0], 12)   # 被动+1能后，下回合选招前偿还1能


func test_t2_shuangsheng_adds_damage_without_duplicating_damage_segments() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_shuangsheng"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 16)   # 波1点 + 整次攻击1点；额外命中效果不额外造伤


func test_t3_mengdie_swaps_post_payment_energy_and_slots_but_not_hp() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.hp[1][0] = 16
	b.energy = [4, 12]
	b.energy_max = [6, 12]
	b.slots[0] = [{"item": ItemCatalog.make("t1_feibiao"), "used": false}]
	b.slots[1] = []
	b.use_item(0, _give(b, 0, "t3_mengdie"))
	_resolve_cc(b)
	assert_eq(b.hp[0][0], 10)          # 梦蝶不交换生命
	assert_eq(b.hp[1][0], 16)
	assert_eq(b.energy[0], 12)         # p1 原本已到自身上限，攒不再加能；随后交换当前能量
	assert_eq(b.energy[1], 8)
	assert_eq(b.energy_max, [6, 12])   # 梦蝶只交换当前能量，不交换双方永久能量上限
	assert_eq(b.slots[0].size(), 0)    # 道具栏对调
	assert_eq(b.slots[1].size(), 1)


func test_t3_morihuozhong_boosts_last_survivor() -> void:
	var b := _battle()
	b.hp[0][1] = 0   # 只剩出战 1 名存活
	b.hp[0][2] = 0
	b.use_item(0, _give(b, 0, "t3_morihuozhong"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 16)      # 波 2 + 火种 2 = 4 落地
	assert_eq(b.shield[0][0], 0, "火种只强化防御行动，不因攻击凭空获得护甲")
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.shield[0][0], 2, "仅剩一名英雄时，防御额外获得 1 点护甲")


func test_t3_morihuozhong_inert_with_full_team() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_morihuozhong"))   # 3 人存活 → 不触发
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18)      # 只有普通波 2
	assert_eq(b.shield[0][0], 0)


func test_t3_tianluodiwang_invalidates_same_turn_switch_without_future_lock() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_tianluodiwang"))
	b.select_action(0, A.CHARGE)
	b.select_switch(1, 1)   # p1 想切 → 本回合被禁
	b.resolve()
	assert_eq(b.active_index[1], 0)                              # 切换被锁
	assert_eq(int(b.item_buffs[1].get("item_lock", 0)), 0, "天罗不再留下跨回合的道具次数锁")


# === 基建：全件可构造 + 不崩 ===

func test_all_t2_t3_construct_and_run() -> void:
	for id in ItemCatalog.ids():
		var data: ItemData = ItemCatalog.make(id)
		assert_not_null(data, "make 失败: %s" % id)
		if data == null:
			continue
		assert_not_null(data.effect, "无 effect: %s" % id)
		if data.tier == 1:
			continue
		# 双方各持一份 → 同回合都用 → resolve 不报错
		var b := _battle()
		b.use_item(0, _give(b, 0, id))
		b.use_item(1, _give(b, 1, id))
		b.select_action(0, A.ATTACK)
		b.select_action(1, A.DEFEND)
		var r: Dictionary = b.resolve()
		assert_true(r.has("events"), "%s resolve 无结果" % id)


func test_catalog_tier_counts() -> void:
	assert_eq(ItemCatalog.all_tier2().size(), 52, "完成背包与参考游戏转译批后的T2件数")
	assert_eq(ItemCatalog.all_tier3().size(), 28, "完成参考游戏转译批后的T3件数")
