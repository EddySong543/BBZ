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


func _resolve(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h01 虚日 囤鼠（出战时己方主动来源得能 +0.5 能=+1 半能·2026-07-04 起被动收入不吃加成）----

func test_h01_dunshu_adds_half_to_every_energy_gain() -> void:
	var b := _battle("h01", 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	# 虚日：攒(2+囤鼠1) + 被动(2·白给收入不加成·2026-07-04) = +5 半能
	assert_eq(b.energy[0], 8 + 5, "虚日囤鼠：攒 +3 + 被动 +2（被动不加成）= +5 半能")
	# 对照 plain：攒2 + 被动2 = +4
	assert_eq(b.energy[1], 8 + 4, "plain 对照：攒 +2 + 被动 +2 = +4 半能")


# ---- h02 牛金 卸劲（挨打 → 血量最低的存活队友 +0.5HP 护盾·批⑤轻刀 A 单人发放·无封顶·自己不获）----

func test_h02_xiejin_shields_lowest_ally_when_damaged() -> void:
	# 牛金(出战 HP7)攒(不防)挨对手波 → 仅一名队友获盾(两替补同血=平手取前位)；牛金自己不获
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.hp[0][0], 14 - 2, "牛金挨波 2 半点(没防=诱饵盾)")
	assert_eq(b.shield[0][1], 1, "替补1 获 1 层护盾(同血平手取前位)")
	assert_eq(b.shield[0][2], 0, "替补2 不获盾(批⑤单人发放)")
	assert_eq(b.shield[0][0], 0, "牛金自己不获盾(卸给队友)")


func test_h02_xiejin_shield_targets_lowest_hp_ally() -> void:
	# 批⑤回归：替补2 血更低 → 盾发给替补2 而非前位替补1（按裸 HP 比·不含护盾）
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 8)
	b.hp[0][2] = 6   # Arrange：替补2 压到 3HP(6 半点) < 替补1 满血
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.shield[0][2], 1, "血量最低的替补2 获盾")
	assert_eq(b.shield[0][1], 0, "替补1 血更高不获盾")


func test_h02_xiejin_shield_accumulates_uncapped() -> void:
	# 连续三回合挨打 → 同一最低血队友护盾无封顶累积(3 半点=1.5HP)·2026-07-01 废除封顶
	var b := _battle_team(["h02", "test_p1_1", "test_p1_2"], 7, 12)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.shield[0][1], 3, "三次挨打→前位替补护盾无封顶累积 3 半点(1.5HP)")
	assert_eq(b.shield[0][2], 0, "另一替补始终不获盾(单人发放)")


# ---- h03 尾火 连扑（hit_count=2 → 队友 on-hit 翻倍：喂鸡剑气 ×2）----

func test_h03_lianpu_double_hit_feeds_two_jianqi() -> void:
	# P0 = 虎(出战) + 鸡(替补)；虎命中 → 全队 on-hit 触发 2 次 → 鸡 +2 剑气
	var b := _battle_team(["h03", "h10", "test_p1_2"], 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(int(b.get_status(0, 1, "jianqi", 0)), 2, "虎双段 → 鸡(替补)攒 2 层剑气")


# ---- h04 房日（重做 2026-07-04：出战时敌方每重复一次上回合动作 → 我方 +0.5 能）----
# 旧机制（登场护甲保底 + 道具锁 −1）已移除；HP 4→5。

func test_h04_repeat_energy_first_turn_no_trigger() -> void:
	var b := _battle("h04", 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	# 第 1 回合无上回合可比对 → 只有 攒2 + 被动2
	assert_eq(b.energy[0], 8 + 4, "第 1 回合不触发（无上回合）")

func test_h04_repeat_energy_gains_when_enemy_repeats() -> void:
	var b := _battle("h04", 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	var e1: int = b.energy[0]
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)   # 敌方重复「防」
	assert_eq(b.energy[0], e1 + 5, "敌方重复上回合动作 → 攒2+被动2+重复产能1 = +5 半能")

func test_h04_repeat_energy_stops_when_enemy_varies() -> void:
	var b := _battle("h04", 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	var e1: int = b.energy[0]
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)   # 敌方换动作 → 断供
	assert_eq(b.energy[0], e1 + 4, "敌方换动作 → 只有攒2+被动2、无产能")

func test_h04_repeat_energy_pays_each_consecutive_repeat() -> void:
	var b := _battle("h04", 5, 0)   # 低起手能量·避免三回合累积撞 MAX_ENERGY=20 半能上限
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	var e1: int = b.energy[0]
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)   # 重复 1 → +1
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)   # 重复 2 → +1
	assert_eq(b.energy[0], e1 + 10, "连防三回合 → 第 2/3 回合各产能 1（逐回合判定）")

func test_h04_repeat_energy_inactive_from_reserve() -> void:
	# 房日在替补席 → 光环不生效（出战限定）
	var b := _battle_team(["test_p1_0", "h04", "test_p1_2"], 5, 8)
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)
	var e1: int = b.energy[0]
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND)   # 敌方重复但房日未出战
	assert_eq(b.energy[0], e1 + 4, "房日在替补席 → 敌方重复不产能")

func test_h04_repeat_energy_counts_switch_as_action() -> void:
	# 「动作」含切换：敌方连续两回合切换 = 重复
	var b := _battle("h04", 5, 8)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 1)
	b.resolve()
	var e1: int = b.energy[0]
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_switch(1, 0)
	b.resolve()
	assert_eq(b.energy[0], e1 + 5, "敌方连续切换（同为切换动作）→ 视为重复、产能 1")


# ---- h05 亢金 裂甲（命中 → 给目标破甲）----

func test_h05_liejia_applies_broken_armor_on_hit() -> void:
	var b := _battle("h05", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)   # 对手不防 → 命中
	assert_eq(int(b.get_status(1, 0, "broken_armor", 0)), 1, "龙命中 → 目标获破甲")

func test_h05_liejia_no_broken_armor_when_blocked() -> void:
	var b := _battle("h05", 5, 8)
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)   # 波被防挡 → 未命中
	assert_eq(int(b.get_status(1, 0, "broken_armor", 0)), 0, "被挡未命中 → 不破甲")


# ---- h06 翼火 淬毒（命中叠毒；被打引爆）----

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


# ---- h07 星日 当先（登场 0.5 冲撞）----

func test_h07_dangxian_chongzhuang_on_switch_in() -> void:
	var b := _battle_team(["test_p1_0", "h07", "test_p1_2"], 5, 8)
	b.select_switch(0, 1)                       # 切到马
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.active_index[0], 1, "已切到马")
	assert_eq(b.hp[1][0], 10 - 1, "马登场冲撞 0.5HP = 1 半点 给对手出战(对手 HP5=10半)")


# ---- h08 鬼金 牧养（出战时你方替补席存活英雄每回合回 0.5HP·出战不回·2026-07-02 由在场收缩为出战）----

func test_h08_muyang_heals_reserve_each_turn() -> void:
	# 鬼金出战 + 残血替补(slot1) → 每回合替补回 0.5HP(1 半点)；出战鬼金不回。
	var b := _battle_team(["h08", "test_p0_1", "test_p0_2"], 6, 8)
	b.hp[0][1] = 4                       # 替补残血(2.0HP=4 半点)
	b.hp[0][0] = 8                       # 鬼金出战残血(4.0HP)——验证出战不回
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][1], 5, "替补每回合回 0.5HP(1 半点)：4→5")
	assert_eq(b.hp[0][0], 8, "出战鬼金不回（在前线）")


func test_h08_muyang_caps_at_max_and_requires_sheep() -> void:
	# 满血替补不溢出；无鬼金则残血替补不回。
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
	assert_eq(nb.hp[0][1], 4, "无鬼金 → 替补不回血")


func test_h08_muyang_inactive_from_reserve() -> void:
	# 鬼金在替补、出战 plain → 不牧养（2026-07-02 出战限定·鬼金须站前线牧养）
	var b := _battle_team(["test_p0_0", "h08", "test_p0_2"], 6, 8)
	b.hp[0][1] = 4   # 鬼金(替补)残血
	b.hp[0][2] = 4   # 另一替补残血
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][1], 4, "鬼金在替补 → 不牧养、自身不回")
	assert_eq(b.hp[0][2], 4, "另一替补也不回")


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
