extends GutTest

## ============================================================================
## BattleCore 英雄第三批（Step 2.2c）—— 死亡链 + 穿透 + 首个半血
##   h03 渴血  —— on_kill + on_death + modify_team_outgoing（团队层 buff）
##   h06 蛇蜕  —— on_before_death（致死拦截重生）
##   h11 穷追  —— on_enemy_switch_out（穿透防御+护盾）
##   h18 教皇  —— modify_incoming + 半血 0.5（每队友 -0.5）
##   h22 隐者  —— on_ally_death（阵亡叠攻）
## ============================================================================

const ATTACK := ActionDef.Action.ATTACK
const BIG := ActionDef.Action.BIG_ATTACK
const CHARGE := ActionDef.Action.CHARGE
const DEFEND := ActionDef.Action.DEFEND


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	h.passive_id = ""
	h.extra_action_id = -1
	return h


func _team(specs: Array) -> Array:
	var t: Array = []
	for s in specs:
		t.append(_hero(s[0], s[1]))
	return t


func _battle2(p0: Array, p1: Array, e: int = 6) -> BattleCore:
	var b := BattleCore.new()
	b.setup(_team(p0), _team(p1), 555)
	b.energy = [e, e]
	return b


func _aa(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h03 渴血 ----

func test_h03_kill_grants_stack_and_buffs_next_wave() -> void:
	var b := _battle2([["h03", 5], ["t01", 10], ["t02", 10]], [["t10", 1], ["t11", 10], ["t12", 10]])
	_aa(b, ATTACK, CHARGE)                 # 寅虎波 1.0 杀掉 1HP 对手
	assert_eq(int(b.get_status(0, 0, "xuexue", 0)), 1, "击杀 → 渴血 +1 层")
	assert_true(b.pending_death_switch[1])
	b.execute_death_switch(1, 1)
	_aa(b, ATTACK, CHARGE)                 # 寅虎波 = 1.0 + 1.0 = 2.0
	assert_eq(b.hp[1][1], 16, "渴血加成 → 波 2.0 (20-4，否则应 18)")


func test_h03_buff_applies_to_teammate_wave() -> void:
	var b := _battle2([["t_atk", 10], ["h03", 5], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 1, "xuexue", 1)        # 寅虎在替补席(slot1)、1 层
	_aa(b, ATTACK, CHARGE)                 # 出战的是普通英雄
	assert_eq(b.hp[1][0], 16, "替补寅虎使队友的波也 +1.0")


func test_h03_cleared_when_tiger_dies() -> void:
	var b := _battle2([["h03", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "xuexue", 2)
	b.hp[0][0] = 2
	_aa(b, CHARGE, BIG)                    # 大波 2.0 杀寅虎
	assert_lte(b.hp[0][0], 0, "寅虎阵亡")
	assert_eq(int(b.get_status(0, 0, "xuexue", 0)), 0, "死亡清零渴血")


# ---- h06 蛇蜕 ----

func test_h06_revives_at_2hp() -> void:
	var b := _battle2([["h06", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 2
	_aa(b, CHARGE, BIG)                    # 大波致死 → 重生
	assert_eq(b.hp[0][0], 4, "首次致死重生为 2.0 HP")
	assert_true(b.get_status(0, 0, "shetui_used", false), "已标记用过")
	assert_false(b.game_over)


func test_h06_dies_on_second_lethal() -> void:
	var b := _battle2([["h06", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 2
	_aa(b, CHARGE, BIG)                    # 重生到 2.0
	_aa(b, CHARGE, BIG)                    # 再致死 → 真死
	assert_lte(b.hp[0][0], 0, "第二次致死不再重生")


# ---- h11 穷追 ----

func test_h11_chases_switching_enemy() -> void:
	var b := _battle2([["h11", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_action(0, CHARGE)
	b.select_switch(1, 1)                  # 对手 slot0 → slot1
	b.resolve()
	assert_eq(b.hp[1][0], 18, "对手下场英雄受 1.0 穿透伤 (20-2)")


func test_h11_pierces_shield() -> void:
	var b := _battle2([["h11", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.shield[1][0] = 4                     # 下场英雄有 2.0 护盾
	b.select_action(0, CHARGE)
	b.select_switch(1, 1)
	b.resolve()
	assert_eq(b.hp[1][0], 18, "穿透护盾直接扣 HP")
	assert_eq(b.shield[1][0], 4, "护盾未被消耗")


# ---- h18 教皇（半血 0.5）----

func test_h18_two_allies_reduce_one() -> void:
	var b := _battle2([["h18", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, BIG)                    # 2 队友 -1.0 → 大波 2.0 实受 1.0
	assert_eq(b.hp[0][0], 10, "12 - 2 半点")


func test_h18_one_ally_half_point() -> void:
	var b := _battle2([["h18", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0                         # 仅 1 存活队友
	_aa(b, CHARGE, BIG)                    # -0.5 → 大波实受 1.5
	assert_eq(b.hp[0][0], 9, "12 - 3 半点")
	assert_eq(b.hp_display(b.hp[0][0]), 4.5, "半血生效 = 4.5 HP")


func test_h18_no_allies_full_damage() -> void:
	var b := _battle2([["h18", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0
	b.hp[0][2] = 0
	_aa(b, CHARGE, BIG)
	assert_eq(b.hp[0][0], 8, "无队友 → 大波满 2.0 (12-4)")


func test_h18_half_point_on_wave() -> void:
	var b := _battle2([["h18", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0                         # 1 队友 → -0.5
	_aa(b, CHARGE, ATTACK)                 # 波 1.0 → 实受 0.5
	assert_eq(b.hp[0][0], 11, "12 - 1 半点")
	assert_eq(b.hp_display(b.hp[0][0]), 5.5, "0.5 伤生效 = 5.5 HP")


# ---- h22 隐者 ----

func test_h22_no_bonus_at_full_team() -> void:
	var b := _battle2([["h22", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, ATTACK, CHARGE)
	assert_eq(b.hp[1][0], 18, "满编无加成，波 1.0")


func test_h22_gains_attack_on_ally_death() -> void:
	var b := _battle2([["h22", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0
	_aa(b, CHARGE, CHARGE)                 # 触发 slot1 死亡 → 隐者 on_ally_death
	assert_eq(int(b.get_status(0, 0, "yinzhe_atk", 0)), 1, "队友阵亡 +1 攻点")
	_aa(b, ATTACK, CHARGE)
	assert_eq(b.hp[1][0], 16, "+1 攻 → 波 2.0")


func test_h22_two_points_when_solo() -> void:
	var b := _battle2([["h22", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0
	b.hp[0][2] = 0
	_aa(b, CHARGE, CHARGE)                 # 两队友同回合死 → 2 次 on_ally_death
	assert_eq(int(b.get_status(0, 0, "yinzhe_atk", 0)), 2, "独存 2 攻点")
	_aa(b, ATTACK, CHARGE)
	assert_eq(b.hp[1][0], 14, "+2 攻 → 波 3.0")


func test_h22_def_variant_reduces_damage() -> void:
	var b := _battle2([["h22", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.set_status(0, 0, "yinzhe_def", 1)    # 模拟玩家选了"防"
	_aa(b, CHARGE, BIG)                    # 大波 2.0(4半) - 0.5(1半) = 1.5
	assert_eq(b.hp[0][0], 7, "+1 防层 → 减 0.5 → 实受 1.5 (10-3)")
