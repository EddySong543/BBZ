extends GutTest

## Phase 3A 纯逻辑件（替身草人 / 打神鞭 / 一气）行为锁定测试。
## 无技能 test_* 英雄隔离。半点制：1HP=2 半点。基线出战 HP=20。

const A := ActionDef.Action
const SEED := 777


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
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


# === 替身草人：切换 → 对手攻击落空 ===

func test_caoren_switch_dodges_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_caoren"))
	b.select_switch(0, 1)
	b.select_action(1, A.ATTACK)
	b.resolve()
	assert_eq(b.active_index[0], 1, "切换成功")
	assert_eq(b.hp[0][1], 20, "新出战未被波命中（替身吃下）")


func test_caoren_inert_without_switch() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t2_caoren"))
	b.select_action(0, A.CHARGE)   # 没切换 → 草人不生效
	b.select_action(1, A.ATTACK)
	b.resolve()
	assert_eq(b.hp[0][0], 18, "没切换则正常挨波")


func test_control_switch_without_caoren_takes_hit() -> void:
	var b := _battle()
	b.select_switch(0, 1)
	b.select_action(1, A.ATTACK)
	b.resolve()
	assert_eq(b.hp[0][1], 18, "对照：切换无草人 → 新出战挨波")


# === 打神鞭：强制对手切换 ===

func test_dashenbian_forces_opponent_switch() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_dashenbian"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.active_index[1], 1, "对手被强制切到首个存活替补")


func test_dashenbian_control_no_force() -> void:
	var b := _battle()
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.active_index[1], 0)


func test_dashenbian_blocked_by_immunity() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_dashenbian"))
	b.use_item(1, _give(b, 1, "t1_hushenfu"))   # 对手圣贤书免疫一次干扰
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.active_index[1], 0, "被免疫 → 未被强制切换")


# === 一气：信息博弈，2/3 概率落空（概率性·跨种子） ===

func test_yiqi_dodges_some_attacks() -> void:
	var hits := 0
	for i in range(30):
		var b := _battle()
		b.rng.seed = i * 101 + 13   # 每次不同种子 → 制造方差
		b.use_item(0, _give(b, 0, "t3_yiqi"))
		b.select_action(0, A.CHARGE)
		b.select_action(1, A.ATTACK)
		b.resolve()
		if b.hp[0][0] < 20:
			hits += 1
	# 真身 1/3 命中：应既有命中（真身被打中）也有落空（替身挡下），不全 0、不全 30。
	assert_gt(hits, 0, "一气：真身有时被命中")
	assert_lt(hits, 30, "一气：替身有时让攻击落空")


func test_yiqi_inert_when_opp_not_attacking() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_yiqi"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)   # 对手不攻击 → 一气不触发
	b.resolve()
	assert_eq(b.hp[0][0], 20)
