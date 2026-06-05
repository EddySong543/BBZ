extends GutTest

## ============================================================================
## BattleCore 英雄第四批（Step 2.2c）
##   h08 替罪 —— 主动耗 HP 换团队能量（active + 自定前置）
##   h10 啼晓 —— 回合触发被动（modify_outgoing + turn_number）
##   h16 皇后 —— 团队治疗含替补（active 写替补 HP）
##   h19 恋人 —— on_setup 绑定挚爱 + on_ally_death 殉情（穿透）+ 连锁死亡
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


# ---- h08 替罪 ----

func test_h08_sacrifice_hp_for_team_energy() -> void:
	var b := _battle2([["h08", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 3)
	assert_true(b.select_active(0))
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 8, "自身 -1.0 HP (10-2)")
	assert_eq(b.energy[0], 5, "团队池 +2 (3+2)")


func test_h08_blocked_at_low_hp() -> void:
	var b := _battle2([["h08", 5], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][0] = 2   # 1.0 HP
	assert_false(b.can_use_active(0), "HP=1.0 不可用（需 >1.0）")


# ---- h10 啼晓 ----

func test_h10_wave_upgrades_every_third_turn() -> void:
	var b := _battle2([["h10", 5], ["t01", 10], ["t02", 10]], [["t10", 15], ["t11", 10], ["t12", 10]])
	_aa(b, ATTACK, CHARGE)   # 回合1：1.0
	_aa(b, ATTACK, CHARGE)   # 回合2：1.0
	_aa(b, ATTACK, CHARGE)   # 回合3：升级 2.0
	assert_eq(b.hp[1][0], 30 - 8, "1+1+2 = 4.0（8 半点），第3回合波升级")


func test_h10_third_wave_pierces_defend() -> void:
	var b := _battle2([["h10", 5], ["t01", 10], ["t02", 10]], [["t10", 15], ["t11", 10], ["t12", 10]])
	_aa(b, ATTACK, CHARGE)   # 回合1：波 1.0 (30→28)
	_aa(b, ATTACK, CHARGE)   # 回合2：波 1.0 (28→26)
	_aa(b, ATTACK, DEFEND)   # 回合3：波按大波判定 → 穿"防"，受 2.0 (26→22)
	assert_eq(b.hp[1][0], 22, "第3波穿防：30 -2 -2 -4 半点")


# ---- h16 皇后 ----

func test_h16_heals_whole_team_including_reserves() -> void:
	var b := _battle2([["h16", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 3)
	b.hp[0][0] = 4
	b.hp[0][1] = 4
	b.hp[0][2] = 4
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 6, "出战 +1.0")
	assert_eq(b.hp[0][1], 6, "替补1 +1.0")
	assert_eq(b.hp[0][2], 6, "替补2 +1.0")
	assert_eq(b.energy[0], 1, "耗 2 能 (3-2)")


func test_h16_no_overheal_and_no_revive() -> void:
	var b := _battle2([["h16", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]], 3)
	b.hp[0][2] = 0   # 已阵亡的替补
	b.select_active(0)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 12, "满血不溢出")
	assert_eq(b.hp[0][2], 0, "不复活死者")


# ---- h19 恋人 ----

func test_h19_default_beloved_assigned() -> void:
	var b := _battle2([["h19", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	assert_eq(int(b.get_status(0, 0, "beloved", -1)), 1, "默认挚爱 = 槽位最小队友 slot1")


func test_h19_damage_reduced_while_beloved_alive() -> void:
	var b := _battle2([["h19", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	_aa(b, CHARGE, BIG)   # 大波 2.0，挚爱在世 → -1.0 → 1.0
	assert_eq(b.hp[0][0], 10, "12 - 2 半点")


func test_h19_sunk_cost_on_beloved_death() -> void:
	var b := _battle2([["h19", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0   # 挚爱阵亡
	_aa(b, CHARGE, CHARGE)   # 触发 slot1 死亡 → 恋人殉情
	assert_eq(b.hp[0][0], 6, "恋人殉情受 3.0（12-6）")


func test_h19_no_reduction_after_beloved_dead() -> void:
	var b := _battle2([["h19", 6], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.hp[0][1] = 0
	_aa(b, CHARGE, CHARGE)   # 殉情 → 恋人 12→6
	_aa(b, CHARGE, BIG)      # 挚爱已亡 → 不再减伤 → 大波满 2.0
	assert_eq(b.hp[0][0], 2, "6 - 4 半点（不再 -1）")
