extends GutTest

## ============================================================================
## BattleCore 英雄第一批（Step 2.2c）
##   h02 怒目 / h05 天威 —— modify_outgoing_damage（被动出伤 hook）
##   h01 窃运           —— 主动技框架（cost / cap / execute）
##   h21 力量           —— modify_incoming_damage（受伤减免 hook）
## 半点制：1.0 伤 = 2 半点；HP_INIT 10 → 20 半点。
## ============================================================================


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	h.passive_id = ""
	h.extra_action_id = -1
	return h


## P0 slot0 = 被测英雄；其余 plain（"test_" 前缀，无技能）。
func _battle_p0(hero_id: String, hp: int, e: int = 6) -> BattleCore:
	var p1: Array = [_hero(hero_id, hp), _hero("test_p1_1", 10), _hero("test_p1_2", 10)]
	var p2: Array = [_hero("test_p2_0", 10), _hero("test_p2_1", 10), _hero("test_p2_2", 10)]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


# ---- h02 怒目（HP<满血 → 波/大波 +1.0）----

func test_h02_numu_no_bonus_at_full_hp() -> void:
	var b := _battle_p0("h02", 6)        # HP6 满血(12 半点)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18, "满血怒目无加成，波 1.0 → 受 2 半点")


func test_h02_numu_plus_one_when_hurt() -> void:
	var b := _battle_p0("h02", 6)
	b.hp[0][0] = 10                       # < 满血(12)
	b.select_action(0, ActionDef.Action.ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 16, "残血怒目 波 +1.0 = 2.0 → 受 4 半点")


func test_h02_numu_buffs_big_attack_too() -> void:
	var b := _battle_p0("h02", 6)
	b.hp[0][0] = 10
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 14, "残血怒目 大波 2.0+1.0 = 3.0 → 受 6 半点")


# ---- h05 天威（满血 → 大波 +2.0）----

func test_h05_tianwei_big_attack_plus_two_at_full() -> void:
	var b := _battle_p0("h05", 6)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 12, "满血天威大波 2.0+2.0 = 4.0 → 受 8 半点")


func test_h05_tianwei_no_bonus_when_hurt() -> void:
	var b := _battle_p0("h05", 6)
	b.hp[0][0] = 10                       # 受过伤 → 失效
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 16, "残血天威大波正常 2.0 → 受 4 半点")


func test_h05_tianwei_normal_attack_no_bonus() -> void:
	var b := _battle_p0("h05", 6)
	b.select_action(0, ActionDef.Action.ATTACK)   # 波非大波
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18, "天威只加大波，波无加成")


# ---- h01 窃运（主动 0 能偷 1 能，cap 3）----

func test_h01_qieyun_steals_one_energy() -> void:
	var b := _battle_p0("h01", 4)
	b.energy = [5, 5]
	assert_true(b.select_active(0), "窃运可选")
	b.select_action(1, ActionDef.Action.DEFEND)   # 防：能量不变
	b.resolve()
	assert_eq(b.energy[0], 6, "己方池 +1")
	assert_eq(b.energy[1], 4, "对手池 -1")


func test_h01_qieyun_capped_at_3() -> void:
	var b := _battle_p0("h01", 4)
	b.energy = [10, 10]
	for i in range(3):
		assert_true(b.select_active(0), "第 %d 次窃运可用" % (i + 1))
		b.select_action(1, ActionDef.Action.DEFEND)
		b.resolve()
	assert_false(b.select_active(0), "第 4 次超 cap(3) 被拒")


func test_h01_qieyun_no_effect_when_opp_empty() -> void:
	var b := _battle_p0("h01", 4)
	b.energy = [5, 0]                     # 对手 0 能
	b.select_active(0)
	b.select_action(1, ActionDef.Action.DEFEND)
	b.resolve()
	assert_eq(b.energy[0], 5, "对手无能量可偷，己方不增")
	assert_eq(b.energy[1], 0)


# ---- h21 力量（≥2.0 伤 -1.0）----

func test_h21_xianglong_reduces_big_attack() -> void:
	var b := _battle_p0("h21", 7)         # HP7 = 14 半点
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.BIG_ATTACK)   # 2.0 → 力量减到 1.0
	b.resolve()
	assert_eq(b.hp[0][0], 12, "大波 2.0 被力量减 1.0 → 实受 1.0 (无技能应为 10)")


func test_h21_xianglong_does_not_reduce_wave() -> void:
	var b := _battle_p0("h21", 7)
	b.select_action(0, ActionDef.Action.CHARGE)
	b.select_action(1, ActionDef.Action.ATTACK)        # 1.0 不减
	b.resolve()
	assert_eq(b.hp[0][0], 12, "波 1.0 < 阈值，力量不减")
