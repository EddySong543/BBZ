extends GutTest

## ============================================================================
## 12 生肖（h01-h12）技能测试 —— 锁定【当前代码行为】。
##
## 取代旧 test_heroes_batch1-8_v4（那些测的是上一代英雄 numu/tianwei/qieyun…，
## 注册表 _HERO_SKILL_SCRIPTS 现已是 dunshu/panniu/lianpu/… 新阵容）。
## 现版本只发布 12 生肖；后续新增英雄再加测试文件。
##
## 经济基线（B·2026-06-16 已实装）：能量半能制(1 能=2 半能)；大波 6 半能(3 能)；
##   被动能量已去除(2026-06-24·PASSIVE_ENERGY_GAIN=0)；HP 半点制(1.0 HP=2 半点)。
## ============================================================================

const PASSIVE := 0   # 被动能量已去除（2026-06-24）·原 +2 半能/回合（当前未被引用）


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


func _resolve(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h01 子鼠 囤鼠（出战时己方每次得能 +0.5 能 = +1 半能·2026-06-21 由 +1 能调为 +0.5）----

func test_h01_dunshu_adds_half_to_every_energy_gain() -> void:
	var b := _battle("h01", 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	# 子鼠：攒(2+囤鼠1) = +3 半能（被动已去除；_gain_energy(0) 不触发囤鼠加成）
	assert_eq(b.energy[0], 8 + 3, "子鼠囤鼠：攒 +2 +囤鼠 +1 = +3 半能·被动已去除")
	# 对照 plain：攒2 = +2
	assert_eq(b.energy[1], 8 + 2, "plain 对照 +2 半能·被动已去除")


# ---- h02 丑牛 卸劲（挨打 → 其他存活队友各 +0.5HP 护盾·封顶 1.0HP·自己不获）----

func test_h02_xiejin_shields_allies_when_damaged() -> void:
	# 丑牛(出战 HP7)攒(不防)挨对手波 → 两替补各 +1 半点(0.5HP)护盾；丑牛自己不获
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.hp[0][0], 14 - 2, "丑牛挨波 2 半点(没防=诱饵盾)")
	assert_eq(b.shield[0][1], 1, "替补1 获 1 层护盾(1 半点=0.5HP)")
	assert_eq(b.shield[0][2], 1, "替补2 获 1 层护盾")
	assert_eq(b.shield[0][0], 0, "丑牛自己不获盾(卸给队友)")


func test_h02_xiejin_shield_caps_per_ally() -> void:
	# 连续两回合挨打 → 替补护盾封顶 2 半点(1.0HP)、不超
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 12)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.shield[0][1], 2, "三次挨打但替补护盾封顶 2 半点(1.0HP)")


# ---- h03 寅虎 连扑（hit_count=2 → 队友 on-hit 翻倍：喂鸡剑气 ×2）----

func test_h03_lianpu_double_hit_feeds_two_jianqi() -> void:
	# P0 = 虎(出战) + 鸡(替补)；虎命中 → 全队 on-hit 触发 2 次 → 鸡 +2 剑气
	var b := _battle_team(["h03", "h10", "test_p1_2"], 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(0, 1, "jianqi", 0)), 2, "虎双段 → 鸡(替补)攒 2 层剑气")


# ---- h04 卯兔 狡兔（上场 +0.5 护甲层）----

func test_h04_jiaotu_gains_shield_on_switch_in() -> void:
	var b := _battle_team(["test_p1_0", "h04", "test_p1_2"], 5, 8)
	b.select_switch(0, 1)                       # 切到兔
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "已切到兔")
	assert_eq(b.shield[0][1], 1, "兔上场 +0.5 护甲 = 1 半点额外血量层")


# ---- h05 辰龙 裂甲（命中 → 给目标破甲）----

func test_h05_liejia_applies_broken_armor_on_hit() -> void:
	var b := _battle("h05", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)   # 对手不防 → 命中
	assert_eq(int(b.get_status(1, 0, "broken_armor", 0)), 1, "龙命中 → 目标获破甲")

func test_h05_liejia_no_broken_armor_when_blocked() -> void:
	var b := _battle("h05", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)   # 波被防挡 → 未命中
	assert_eq(int(b.get_status(1, 0, "broken_armor", 0)), 0, "被挡未命中 → 不破甲")


# ---- h06 巳蛇 淬毒（命中叠毒；被打引爆）----

func test_h06_cuidu_stacks_poison_on_hit() -> void:
	var b := _battle("h06", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 1, "蛇命中 → 叠 1 层毒")

func test_h06_cuidu_detonates_on_second_hit() -> void:
	# 第 1 击：叠毒(不引爆)；第 2 击：先引爆 1 层(+1 半点)再叠新毒。
	var b := _battle("h06", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)   # 10→8，毒=1
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)   # 引爆1(+1) + 波2 = -3 → 8→5
	assert_eq(b.hp[1][0], 5, "第2击引爆1层(0.5)+波(1.0)=1.5 → 10-2-3=5")
	assert_eq(int(b.get_status(1, 0, "poison", 0)), 1, "引爆后清空、再叠新 1 层")


# ---- h07 午马 当先（登场 0.5 冲撞）----

func test_h07_dangxian_chongzhuang_on_switch_in() -> void:
	var b := _battle_team(["test_p1_0", "h07", "test_p1_2"], 5, 8)
	b.select_switch(0, 1)                       # 切到马
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "已切到马")
	assert_eq(b.hp[1][0], 10 - 1, "马登场冲撞 0.5HP = 1 半点 给对手出战(对手 HP5=10半)")


# ---- h08 未羊 牧养（在场时你方替补席存活英雄每回合回 0.5HP·出战不回·2026-06-27 替罪→牧养重设计）----

func test_h08_muyang_heals_reserve_each_turn() -> void:
	# 未羊出战 + 残血替补(slot1) → 每回合替补回 0.5HP(1 半点)；出战未羊不回。
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 8)
	b.hp[0][1] = 4                       # 替补残血(2.0HP=4 半点)
	b.hp[0][0] = 8                       # 未羊出战残血(4.0HP)——验证出战不回
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][1], 5, "替补每回合回 0.5HP(1 半点)：4→5")
	assert_eq(b.hp[0][0], 8, "出战未羊不回（在前线）")


func test_h08_muyang_caps_at_max_and_requires_sheep() -> void:
	# 满血替补不溢出；无未羊则残血替补不回。
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][1], 12, "满血替补不溢出（封顶 max_hp）")
	var nb := _battle_team(["test_p0_0", "test_p0_1", "test_p0_2"], 6, 8)
	nb.hp[0][1] = 4
	nb.select_action(0, ActionDef.Action.CHARGE)
	nb.select_action(1, ActionDef.Action.CHARGE)
	nb.resolve()
	assert_eq(nb.hp[0][1], 4, "无未羊 → 替补不回血")


func test_h08_muyang_works_from_reserve() -> void:
	# 未羊在替补、出战 plain → 仍生效（在场含替补）；未羊自己在替补也回。
	var b := _battle_team(["test_p0_0", "h08", "test_p0_2"], 6, 8)
	b.hp[0][1] = 4   # 未羊(替补)残血
	b.hp[0][2] = 4   # 另一替补残血
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][1], 5, "未羊在替补也生效·自身回 0.5HP")
	assert_eq(b.hp[0][2], 5, "另一替补也回 0.5HP")


# ---- h09 申猴 裂爪（命中 → 碎对手等量能量）----

func test_h09_liezhao_shatters_energy_equal_to_damage() -> void:
	var b := _battle("h09", 5, 8)
	# 猴波命中(2 半点) → 碎对手 2 半能。对手攒(+2)，被碎(-2)，被动(+2) → 净 +2
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp[1][0], 10 - 2, "猴波命中 1.0 (对手 HP5=10半)")
	assert_eq(b.energy[1], 8, "对手攒+2 −碎能2 = 净 0·被动已去除（无碎能应 +2）")


# ---- h10 酉鸡 剑意（攒剑气 + 拔剑一闪穿防）----

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


# ---- h11 戌狗 穷追（对手切换下场 → 被换下者 1.0 真伤）----

func test_h11_zhuibu_true_damage_on_enemy_switch_out() -> void:
	var b := _battle("h11", 5, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 1)                       # 对手切换 slot0→slot1
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 2, "被换下者(slot0)受 1.0 真伤(2 半点·对手 HP5=10半)")


# ---- h12 亥猪 纳福（受伤 → 己方 +等量能量）----

func test_h12_nafu_gains_energy_when_damaged() -> void:
	var b := _battle("h12", 7, 8)               # 猪 HP7 = 14 半点
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)   # 对手波 → 猪受 2 半点
	b.resolve()
	assert_eq(b.hp[0][0], 14 - 2, "猪受 1.0 伤")
	assert_eq(b.energy[0], 8 + 4, "纳福：受伤 +2 + 攒2 = +4 半能·被动已去除")
