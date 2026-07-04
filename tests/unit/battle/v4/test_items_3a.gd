extends GutTest

## Phase 3A 纯逻辑件（替身草人 / 打神鞭 / 周天罡气）行为锁定测试。
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


# === 周天罡气：本回合无敌·不受任何敌源伤害（2026-07-04 重做·旧「气·2/3 概率落空」已废） ===

func test_gangqi_immune_to_big_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_yiqi"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.BIG_ATTACK)   # 穿防大波也整发落空
	b.resolve()
	assert_eq(b.hp[0][0], 20, "周天罡气：大波整发落空·无伤")


func test_gangqi_immune_to_pending_burn() -> void:
	var b := _battle()
	b.pending_damage[0][0] = 2   # 妖火式延迟伤害·本回合到期
	b.use_item(0, _give(b, 0, "t3_yiqi"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 20, "周天罡气：延迟灼烧被免掉")
	assert_eq(b.pending_damage[0][0], 0, "灼烧当回合清零·不顺延")


func test_gangqi_lasts_one_turn_only() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_yiqi"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)   # 次回合无敌已过期
	b.resolve()
	assert_eq(b.hp[0][0], 20 - 2, "无敌只持续使用当回合·次回合照常挨波")
