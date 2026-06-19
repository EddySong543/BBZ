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
	assert_eq(b.hp[1][0], 18)   # 1.0 伤 = 2 半点


func test_t2_jiandun_adds_full_shield() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_jiandun"))
	_resolve_cc(b)
	assert_eq(b.shield[0][0], 2)


func test_t2_shengming_heals_full() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_shengming"))
	_resolve_cc(b)
	assert_eq(b.hp[0][0], 12)


func test_t2_nuanyu_heals_only_on_defend() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_nuanyu"))
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.CHARGE)
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


func test_t2_modi_nullifies_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_modi"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)   # 防失效 → 波命中
	b.resolve()
	assert_eq(b.hp[1][0], 18)


func test_t2_modi_control_defend_blocks() -> void:
	var b := _battle()
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 20)


func test_t2_pomoshi_pierces_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_pomoshi"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 18)   # 波穿防


func test_t2_qiubite_ignores_armor_layer() -> void:
	var b := _battle()
	b.shield[1][0] = 4   # 对手 2.0 甲
	b.use_item(0, _give(b, 0, "t2_qiubite"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18)      # 穿甲 → 直击血量
	assert_eq(b.shield[1][0], 4)   # 护甲层原封不动


func test_t2_qiubite_control_armor_absorbs() -> void:
	var b := _battle()
	b.shield[1][0] = 4
	b.use_item(0, _give(b, 0, "t2_feibiao"))   # 普通飞镖被甲吸收
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 20)
	assert_eq(b.shield[1][0], 2)   # 1.0 伤被甲吸 2 半点


# === T2 状态 / 易伤 ===

func test_t2_duyao_poison_detonates_on_hit() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_duyao"))
	b.select_action(0, A.ATTACK)   # 波命中 → 引爆 2 层毒
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 16)   # 波 2 + 毒 2 = 4
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 0)


func test_t2_lieyin_vulnerable_next_hit() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_lieyin"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 17)   # 波 2 + 易伤 1 = 3
	assert_eq(int(b.get_status(1, 0, "marked", 0)), 0)


# === T2 防御件：巫毒娃娃 / 还魂丹（新 core 钩子）===

func test_t2_wudouwawa_eats_one_hit() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_wudouwawa"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)   # 波 2 全被替身吃下
	b.resolve()
	assert_eq(b.hp[0][0], 20)
	assert_eq(int(b.get_status(0, 0, "decoy_hp", 0)), 0)   # 挨一下即碎


func test_t2_wudouwawa_overflows() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_wudouwawa"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.BIG_ATTACK)   # 大波 4：替身吃 2、溢出 2 穿过
	b.resolve()
	assert_eq(b.hp[0][0], 18)


func test_t2_huanhundan_cheats_death() -> void:
	var b := _battle()
	b.hp[0][0] = 2   # 1.0 HP
	b.use_item(0, _give(b, 0, "t2_huanhundan"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.BIG_ATTACK)   # 致死大波
	b.resolve()
	assert_eq(b.hp[0][0], 1)   # 保留 0.5 HP
	assert_eq(int(b.get_status(0, 0, "huanhun_ready", 0)), 0)


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


func test_t2_daijia_taxes_big_action() -> void:
	var b := _battle(10)
	b.use_item(0, _give(b, 0, "t2_daijia"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.BIG_DEFEND)
	b.resolve()
	var got := b.energy[1]
	var b2 := _battle(10)
	b2.select_action(0, A.CHARGE)
	b2.select_action(1, A.BIG_DEFEND)
	b2.resolve()
	assert_eq(b2.energy[1] - got, 2)   # 多耗 1 能 = 2 半能


func test_t2_tengman_punishes_switch_next_turn() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_tengman"))
	b.select_action(0, A.CHARGE)
	b.select_switch(1, 1)   # 对手切换 → 被换下者(slot0)受 0.5 伤(延迟)
	b.resolve()
	assert_eq(b.pending_damage[1][0], 1)
	_resolve_cc(b)
	assert_eq(b.hp[1][0], 19)   # 延迟伤害落地


# === T2 导出 ===

func test_t2_huwan_energy_to_armor() -> void:
	var b := _battle(10)
	b.use_item(0, _give(b, 0, "t2_huwan"))
	_resolve_cc(b)
	assert_eq(b.shield[0][0], 2)   # +1.0 甲


func test_t2_xiongyao_blood_for_damage() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_xiongyao"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 19)   # 弃 0.5 HP
	assert_eq(b.hp[1][0], 16)   # 波 2 + 1.0 = 4


func test_t2_jike_heals_on_hit() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t2_jike"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 12)   # 命中回 1.0 HP


# === T2 跨回合 buff（next_armor / next_atk_bonus）===

func test_t2_suozijia_armor_next_turn() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_suozijia"))
	b.select_action(0, A.BIG_DEFEND)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(int(b.item_buffs[0].get("next_armor", 0)), 1)
	_resolve_cc(b)
	assert_eq(b.shield[0][0], 1)   # 下回合 +0.5 甲落地


func test_t2_fengbao_attack_after_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_fengbao"))
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.CHARGE)
	b.resolve()
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 17)   # 波 2 + 0.5 = 3


# === T2 惯性（_last_action）===

func test_t2_xueqiu_rewards_repeat_attack() -> void:
	var b := _battle()
	b.select_action(0, A.ATTACK)   # 第一波 → 记录 last_action
	b.select_action(1, A.CHARGE)
	b.resolve()   # opp 20 → 18
	b.use_item(0, _give(b, 0, "t2_xueqiu"))
	b.select_action(0, A.ATTACK)   # 连攻 → +0.5 伤
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 15)   # 18 - (2+1)


# === T3 ===

func test_t3_jianyi_pierces_big_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_jianyi"))
	b.select_action(0, A.BIG_ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # 穿大防 → 砸穿
	b.resolve()
	assert_eq(b.hp[1][0], 16)   # 大波 4 落地


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


func test_t3_hongyu_doubles_all_attacks() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t3_hongyu"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 6)    # 弃 2.0 HP
	assert_eq(b.hp[1][0], 16)   # 波 2 ×2 = 4


func test_t3_shengming_heals_2hp() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t3_shengming"))
	_resolve_cc(b)
	assert_eq(b.hp[0][0], 14)


func test_t3_tinglong_dumps_energy_as_piercing_damage() -> void:
	var b := _battle(10)   # 5.0 能
	b.use_item(0, _give(b, 0, "t3_tinglong"))
	b.select_action(0, A.DEFEND)       # 不耗能、不产能
	b.select_action(1, A.BIG_DEFEND)   # 穿大防 → 砸穿
	b.resolve()
	assert_eq(b.hp[1][0], 15)   # 5.0 能 → 2.5 HP = 5 半点
	assert_eq(b.energy[0], 2)   # 清零后回合末被动 +1 能


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
	assert_eq(ItemCatalog.all_tier2().size(), 28, "T2 实装件数")
	assert_eq(ItemCatalog.all_tier3().size(), 7, "T3 实装件数")
