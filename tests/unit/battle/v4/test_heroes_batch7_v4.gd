extends GutTest

## ============================================================================
## BattleCore 英雄第七批（Step 2.2c）—— 管线类
##   h27 节制 —— 延迟伤害（>1.0 截到 1.0，溢出下回合 Phase 0 结算）
##   h30 星星 —— 替补参战，伤害对半转移到后排星星
##   h29 塔   —— 直接击杀溢出分摊给对手剩余队友（splash 不再触发 on_kill）
##   h34 世界 —— 全场 AOE（除己，含双方替补，穿透）
##   h33 审判 —— 处决 HP≤2.0（切换之后判定）
## ============================================================================

const ATTACK := ActionDef.Action.ATTACK
const BIG := ActionDef.Action.BIG_ATTACK
const CHARGE := ActionDef.Action.CHARGE


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


# ---- h27 节制（延迟）----

func test_h27_caps_to_one_and_defers_overflow() -> void:
	var b := _battle2([["h27", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, BIG)   # 大波 2.0 > 1.0 → 本回合只受 1.0，溢出 1.0 入 pending
	assert_eq(b.hp[0][0], 6, "本回合只受 1.0（8-2）")
	assert_eq(b.pending_damage[0][0], 2, "溢出 1.0 延迟")
	_aa(b, CHARGE, CHARGE)   # 下回合 Phase 0 结算延迟
	assert_eq(b.hp[0][0], 4, "延迟 1.0 全额落（6-2）")
	assert_eq(b.pending_damage[0][0], 0, "pending 清空")


func test_h27_small_hit_not_deferred() -> void:
	var b := _battle2([["h27", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, ATTACK)   # 波 1.0 不 > 1.0 → 不延迟
	assert_eq(b.hp[0][0], 6, "1.0 全额受（8-2）")
	assert_eq(b.pending_damage[0][0], 0, "无延迟")


# ---- h30 星星（替补参战转移）----

func test_h30_splits_damage_to_bench_star() -> void:
	var b := _battle2([["t_act", 10], ["h30", 6], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, BIG)   # 大波 2.0 打 P0 出战(slot0)；星星(slot1)分担一半
	assert_eq(b.hp[0][0], 18, "出战受一半 1.0（20-2）")
	assert_eq(b.hp[0][1], 10, "星星替补承一半 1.0（12-2）")


func test_h30_inactive_when_star_is_active() -> void:
	var b := _battle2([["h30", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, BIG)   # 星星自己出战 → 不分担
	assert_eq(b.hp[0][0], 8, "星星出战时承全伤 2.0（12-4）")


func test_h30_inactive_when_star_dead() -> void:
	var b := _battle2([["t_act", 10], ["h30", 6], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0   # 星星阵亡
	_aa(b, CHARGE, BIG)
	assert_eq(b.hp[0][0], 16, "星星亡 → 出战承全伤 2.0（20-4）")


# ---- h29 塔（溢出分摊）----

func test_h29_overkill_splashes_to_reserves() -> void:
	var b := _battle2([["h29", 5], ["t01", 10], ["t02", 10]], [["t10", 1], ["t11", 10], ["t12", 10]])
	_aa(b, BIG, CHARGE)   # 大波 2.0 杀掉 1.0 出战 → 溢出 1.0 分摊给 2 替补
	assert_lte(b.hp[1][0], 0, "对手出战阵亡")
	assert_eq(b.hp[1][1], 19, "替补1 各受 0.5（20-1）")
	assert_eq(b.hp[1][2], 19, "替补2 各受 0.5（20-1）")


func test_h29_no_overkill_no_splash() -> void:
	var b := _battle2([["h29", 5], ["t01", 10], ["t02", 10]], [["t10", 2], ["t11", 10], ["t12", 10]])
	_aa(b, BIG, CHARGE)   # 大波 2.0 刚好杀 2.0，无溢出
	assert_lte(b.hp[1][0], 0, "出战阵亡")
	assert_eq(b.hp[1][1], 20, "无溢出 → 替补无伤")


# ---- h34 世界（全场 AOE）----

func test_h34_aoe_hits_everyone_except_self() -> void:
	var b := _battle2([["h34", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 8, "世界本人免疫（HP4=8 不变）")
	assert_eq(b.hp[0][1], 18, "己方队友 -1.0")
	assert_eq(b.hp[0][2], 18, "己方替补 -1.0")
	assert_eq(b.hp[1][0], 18, "对手出战 -1.0")
	assert_eq(b.hp[1][2], 18, "对手替补 -1.0")
	assert_eq(b.energy[0], 4, "耗 2 能")


# ---- h33 审判（处决）----

func test_h33_executes_low_hp_target() -> void:
	var b := _battle2([["h33", 5], ["t01", 10], ["t02", 10]], [["t10", 2], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 0, "HP=2.0(≤阈值) 被处决归零")
	assert_true(b.pending_death_switch[1])


func test_h33_no_effect_on_high_hp() -> void:
	var b := _battle2([["h33", 5], ["t01", 10], ["t02", 10]], [["t10", 3], ["t11", 10], ["t12", 10]])
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 6, "HP=3.0>阈值 → 无效")
	assert_eq(b.energy[0], 4, "无效仍消耗 2 能")


func test_h33_judges_after_opponent_switch() -> void:
	var b := _battle2([["h33", 5], ["t01", 10], ["t02", 10]], [["t10", 1], ["t11", 10], ["t12", 10]])
	b.select_active(0)        # 审判
	b.select_switch(1, 1)     # 对手把残血(slot0)切走，换上健康 slot1
	b.resolve()
	assert_eq(b.active_index[1], 1, "对手已切到 slot1")
	assert_eq(b.hp[1][1], 20, "审判判的是切换后的健康出战位 → 无效")
	assert_eq(b.hp[1][0], 2, "残血英雄切走躲过处决")
