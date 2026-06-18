extends GutTest

## ============================================================================
## BattleCore 基础动作测试（Step 2.2a）
##
## 锁定 5 个基础非切换动作（CHARGE/ATTACK/DEFEND/BIG_ATTACK/BIG_DEFEND）在
## 新数值框架 (ADR-002 §D10) + 半点制 (§D3) 下的结算行为。
##
## 与 v3 (test_base_actions.gd) 的关键差异（B·2026-06-16 经济迁移后）：
##   - 大波消耗 3 能（= 6 半能）；能量走半能制（1 能 = 2 半能）；被动 +1 能/回合（+2 半能·回合末结算）
##   - 各 energy 断言均已含回合末被动 +2 半能
##   - 伤害以半点计：波 = 2 半点 (=1.0 HP)，大波 = 4 半点 (=2.0 HP)
##   - HP 内部为半点：max_hp(整) × 2
##   - 同时独立结算模型保留（B-001/2/3）：双方攻击各受对方满伤、不抵消
## ============================================================================

const E_INIT := 6          # 双方初始能量（足付任何基础动作）
const HP_INIT := 10        # 整 HP
const HP_HALF := 20        # = HP_INIT × HP_UNIT(2)
const ATK := 2             # 波伤（半点）
const BIG := 4             # 大波伤（半点）


# ---- 工厂 ----

func _make_hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id          # "test_" 开头，避开任何英雄分支
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(e: int = E_INIT, hp: int = HP_INIT) -> BattleCore:
	var p1: Array = []
	var p2: Array = []
	for i in range(3):
		p1.append(_make_hero("test_p1_%d" % i, hp))
		p2.append(_make_hero("test_p2_%d" % i, hp))
	var b := BattleCore.new()
	b.setup(p1, p2, 12345)   # 固定 seed，确定性
	b.energy = [e, e]
	return b


func _resolve(b: BattleCore, a1: int, a2: int) -> Dictionary:
	b.select_action(0, a1)
	b.select_action(1, a2)
	return b.resolve()


# ---- setup / 数值框架 ----

func test_setup_initial_energy_is_one() -> void:
	# Arrange / Act
	var b := _battle()
	# 重新 setup 不覆盖 energy，确认初始为 1
	var p1: Array = [_make_hero("test_x", HP_INIT)]
	var p2: Array = [_make_hero("test_y", HP_INIT)]
	b.setup(p1, p2, 1)
	# Assert
	assert_eq(b.energy[0], ActionDef.INITIAL_ENERGY, "初始能量 = 1.0 能 = 2 半能 (ADR-002 D10·半能制)")
	assert_eq(b.energy[1], ActionDef.INITIAL_ENERGY)


func test_setup_hp_stored_as_half_points() -> void:
	var b := _battle()
	assert_eq(b.current_hp(0), HP_HALF, "HP 内部 = 整 HP × 2 半点")
	assert_eq(b.hp_display(b.current_hp(0)), 10.0, "20 半点显示为 10.0 HP")


# ---- CHARGE ----

func test_charge_vs_charge_both_gain_energy() -> void:
	var b := _battle()
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	assert_eq(b.energy[0], E_INIT + 4, "攒 +1 能(+2 半能) + 被动 +1 能(+2 半能)")
	assert_eq(b.energy[1], E_INIT + 4)
	assert_eq(b.current_hp(0), HP_HALF, "无伤")
	assert_eq(b.current_hp(1), HP_HALF)


func test_charge_vs_attack_p1_takes_one_hp() -> void:
	var b := _battle()
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.ATTACK)
	assert_eq(b.energy[0], E_INIT + 4, "攒 +2 半能 + 被动 +2 半能")
	assert_eq(b.energy[1], E_INIT, "波 -2 半能 + 被动 +2 半能 = 净 0")
	assert_eq(b.current_hp(0), HP_HALF - ATK, "攒无防御，受 1.0 伤 (2 半点)")
	assert_eq(b.current_hp(1), HP_HALF)


# ---- ATTACK（同时独立结算）----

func test_attack_vs_attack_both_take_one_hp() -> void:
	# B-001 等价（新数值）：双方各受 1.0 伤，不抵消
	var b := _battle()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.ATTACK)
	assert_eq(b.energy[0], E_INIT, "波 -2 半能 + 被动 +2 = 净 0")
	assert_eq(b.energy[1], E_INIT)
	assert_eq(b.current_hp(0), HP_HALF - ATK, "P1 受 1.0")
	assert_eq(b.current_hp(1), HP_HALF - ATK, "P2 受 1.0")


func test_attack_vs_defend_blocked() -> void:
	var b := _battle()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND)
	assert_eq(b.energy[0], E_INIT, "波 -2 半能 + 被动 +2 = 净 0（即使被挡仍扣）")
	assert_eq(b.energy[1], E_INIT + 2, "防 0 消耗 + 被动 +2 半能")
	assert_eq(b.current_hp(1), HP_HALF, "防格挡波")


func test_attack_vs_big_attack_both_take_damage() -> void:
	# B-003 等价：双向都解算，无压制
	var b := _battle()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.energy[0], E_INIT, "波净 0")
	assert_eq(b.energy[1], E_INIT - 4, "大波 -3 能(-6 半能) + 被动 +2 = 净 -4 半能")
	assert_eq(b.current_hp(0), HP_HALF - BIG, "P1 受 2.0 (大波)")
	assert_eq(b.current_hp(1), HP_HALF - ATK, "P2 受 1.0 (波)")


func test_attack_vs_big_defend_blocked() -> void:
	var b := _battle()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.BIG_DEFEND)
	assert_eq(b.energy[1], E_INIT - 2, "大防 -2 能")
	assert_eq(b.current_hp(1), HP_HALF, "大防格挡波")


# ---- BIG_ATTACK ----

func test_big_attack_vs_charge_p2_takes_two_hp() -> void:
	var b := _battle()
	_resolve(b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.energy[0], E_INIT - 4, "大波 -3 能(-6 半能) + 被动 +2 = 净 -4 半能")
	assert_eq(b.current_hp(1), HP_HALF - BIG, "受 2.0 伤")


func test_big_attack_vs_big_attack_both_take_two_hp() -> void:
	# B-002 等价：双方各受 2.0，不抵消
	var b := _battle()
	_resolve(b, ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.energy[0], E_INIT - 4, "大波净 -4 半能")
	assert_eq(b.energy[1], E_INIT - 4)
	assert_eq(b.current_hp(0), HP_HALF - BIG, "P1 受 2.0")
	assert_eq(b.current_hp(1), HP_HALF - BIG, "P2 受 2.0")


func test_defend_vs_big_attack_penetrated() -> void:
	# 大波穿防
	var b := _battle()
	_resolve(b, ActionDef.Action.DEFEND, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.current_hp(0), HP_HALF - BIG, "防被大波穿透，受 2.0")


func test_big_defend_vs_big_attack_blocked() -> void:
	var b := _battle()
	_resolve(b, ActionDef.Action.BIG_DEFEND, ActionDef.Action.BIG_ATTACK)
	assert_eq(b.energy[0], E_INIT - 2, "大防 -2")
	assert_eq(b.current_hp(0), HP_HALF, "大防格挡大波")


# ---- 能量边界 ----

func test_charge_at_max_energy_does_not_overflow() -> void:
	var b := _battle()
	b.energy = [ActionDef.MAX_ENERGY, ActionDef.MAX_ENERGY]
	_resolve(b, ActionDef.Action.CHARGE, ActionDef.Action.CHARGE)
	assert_eq(b.energy[0], ActionDef.MAX_ENERGY, "已满攒不溢出")
	assert_eq(b.energy[1], ActionDef.MAX_ENERGY)


func test_select_action_rejects_unaffordable() -> void:
	var b := _battle(1, HP_INIT)   # 仅 1 能
	# 大波需 2 能 → 应被拒
	var ok := b.select_action(0, ActionDef.Action.BIG_ATTACK)
	assert_false(ok, "能量不足，大波被拒")


# ---- 半点最小伤害 sanity ----

func test_half_point_min_damage_unit() -> void:
	# 波 = 2 半点 = 1.0 HP；半点显示正确
	var b := _battle()
	_resolve(b, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
	assert_eq(b.hp_display(b.current_hp(1)), 9.0, "10.0 - 1.0 = 9.0")
