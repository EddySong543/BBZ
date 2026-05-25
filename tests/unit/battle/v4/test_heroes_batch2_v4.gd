extends GutTest

## ============================================================================
## BattleEngineV4 英雄第二批（Step 2.2c）
##   h04 三窟   —— on_switch_out + 状态随切保留 + 受伤消层
##   h09 凶兽   —— on_resolve_end + 连段状态（被挡仍计）
##   h25 蓄势   —— on_resolve_end + "本回合造成伤害" 追踪 + 跨切保留
##   h23 周而复始 —— on_switch_in + 可复现 RNG 抽祝福
## 半点制：1.0 = 2 半点。
## ============================================================================

const ATTACK := ActionDefV4.Action.ATTACK
const BIG := ActionDefV4.Action.BIG_ATTACK
const CHARGE := ActionDefV4.Action.CHARGE
const DEFEND := ActionDefV4.Action.DEFEND


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	h.passive_id = ""
	h.extra_action_id = -1
	return h


func _battle_p0(hero_id: String, hp: int, opp_hp: int = 10, e: int = 6) -> BattleEngineV4:
	var p1: Array = [_hero(hero_id, hp), _hero("test_p1_1", 10), _hero("test_p1_2", 10)]
	var p2: Array = [_hero("test_p2_0", opp_hp), _hero("test_p2_1", 10), _hero("test_p2_2", 10)]
	var b := BattleEngineV4.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


func _aa(b: BattleEngineV4, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# ---- h04 三窟 ----

func test_h04_gains_ku_layer_on_switch_out() -> void:
	var b := _battle_p0("h04", 4)
	b.select_switch(0, 1)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(0, 0, "ku", 0)), 1, "切换下场 → 三窟 slot0 +1 窟")


func test_h04_ku_reduces_and_consumes() -> void:
	var b := _battle_p0("h04", 4)
	b.set_status(0, 0, "ku", 1)
	_aa(b, CHARGE, ATTACK)                 # 对手波 1.0，三窟减 1.0 → 0
	assert_eq(b.hp[0][0], 8, "1 窟挡掉 1.0 波 → 无伤")
	assert_eq(int(b.get_status(0, 0, "ku", 0)), 0, "消耗 1 层")


func test_h04_ku_softens_big_attack() -> void:
	var b := _battle_p0("h04", 4)
	b.set_status(0, 0, "ku", 1)
	_aa(b, CHARGE, BIG)                    # 大波 2.0，三窟 -1.0 → 1.0
	assert_eq(b.hp[0][0], 6, "大波 2.0 被三窟减到 1.0（8-2）")


func test_h04_ku_caps_at_3() -> void:
	var b := _battle_p0("h04", 4)
	b.set_status(0, 0, "ku", 3)
	b.select_switch(0, 1)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_eq(int(b.get_status(0, 0, "ku", 0)), 3, "窟层封顶 3")


# ---- h09 凶兽 ----

func test_h09_combo_escalates_1_2_3() -> void:
	var b := _battle_p0("h09", 4, 20)      # 对手 20 HP = 40 半点
	_aa(b, ATTACK, CHARGE)                 # 1.0 → -2
	_aa(b, ATTACK, CHARGE)                 # 2.0 → -4
	_aa(b, ATTACK, CHARGE)                 # 3.0 → -6
	assert_eq(b.hp[1][0], 40 - 12, "连段 1+2+3 = 6.0（12 半点）")
	assert_eq(int(b.get_status(0, 0, "combo", 0)), 3, "连段到 3")


func test_h09_combo_resets_on_charge() -> void:
	var b := _battle_p0("h09", 4, 20)
	_aa(b, ATTACK, CHARGE)                 # 1.0，combo→1
	_aa(b, CHARGE, CHARGE)                 # 非波，combo→0
	_aa(b, ATTACK, CHARGE)                 # 又是 1.0（重置后）
	assert_eq(b.hp[1][0], 40 - 4, "重置后又从 1.0 起：1.0+1.0 = 4 半点")
	assert_eq(int(b.get_status(0, 0, "combo", 0)), 1)


func test_h09_blocked_wave_still_builds_combo() -> void:
	var b := _battle_p0("h09", 4, 20)
	_aa(b, ATTACK, DEFEND)                 # 波被防挡，0 伤，但 combo 仍 +1
	assert_eq(int(b.get_status(0, 0, "combo", 0)), 1, "被挡的波仍计连段")
	_aa(b, ATTACK, CHARGE)                 # combo=1 → 2.0
	assert_eq(b.hp[1][0], 40 - 4, "第二波吃到连段 2.0")


# ---- h25 以退为进（蓄势）----

func test_h25_no_bonus_on_first_attack() -> void:
	var b := _battle_p0("h25", 5)
	_aa(b, ATTACK, CHARGE)                 # 开局无蓄势 → 1.0
	assert_eq(b.hp[1][0], 20 - 2, "首回合无蓄势，波 1.0")


func test_h25_charge_then_attack_gets_bonus() -> void:
	var b := _battle_p0("h25", 5)
	_aa(b, CHARGE, CHARGE)                 # 未造成伤害 → 蓄势
	assert_true(b.get_status(0, 0, "charge_up", false), "退手后蓄势")
	_aa(b, ATTACK, CHARGE)                 # 蓄势 → 波 +1 = 2.0
	assert_eq(b.hp[1][0], 20 - 4, "蓄势波 2.0")
	assert_false(b.get_status(0, 0, "charge_up", false), "命中后消耗蓄势")


func test_h25_landing_attack_consumes_then_normal() -> void:
	var b := _battle_p0("h25", 5)
	_aa(b, CHARGE, CHARGE)                 # 蓄势
	_aa(b, ATTACK, CHARGE)                 # 2.0（消耗）→ 16
	_aa(b, ATTACK, CHARGE)                 # 普通 1.0 → 14
	assert_eq(b.hp[1][0], 20 - 4 - 2, "消耗后回到 1.0")


func test_h25_blocked_attack_keeps_charge() -> void:
	var b := _battle_p0("h25", 5)
	_aa(b, CHARGE, CHARGE)                 # 蓄势
	_aa(b, ATTACK, DEFEND)                 # 被挡，0 伤 → 蓄势保留
	assert_true(b.get_status(0, 0, "charge_up", false), "被完全挡=未造成伤害→蓄势保留")
	_aa(b, ATTACK, CHARGE)                 # 蓄势 → 2.0
	assert_eq(b.hp[1][0], 20 - 4, "保留的蓄势生效")


# ---- h23 周而复始（RNG 祝福）----

func _battle_h23_raw(seed_value: int) -> BattleEngineV4:
	# 不覆盖 energy，保留登场 roll 的 +1能 效果
	var p1: Array = [_hero("h23", 5), _hero("test_p1_1", 10), _hero("test_p1_2", 10)]
	var p2: Array = [_hero("test_p2_0", 10), _hero("test_p2_1", 10), _hero("test_p2_2", 10)]
	var b := BattleEngineV4.new()
	b.setup(p1, p2, seed_value)
	return b


func test_h23_setup_roll_applies_exactly_one_blessing() -> void:
	var b := _battle_h23_raw(555)
	var atk := 1 if b.get_status(0, 0, "wheel_atk", false) else 0
	var df := 1 if b.get_status(0, 0, "wheel_def", false) else 0
	var sh := 1 if b.shield[0][0] > 0 else 0
	var en := 1 if b.energy[0] > ActionDefV4.INITIAL_ENERGY else 0
	assert_eq(atk + df + sh + en, 1, "登场恰好抽中 1 个祝福")


func test_h23_roll_is_reproducible_with_same_seed() -> void:
	var b1 := _battle_h23_raw(31337)
	var b2 := _battle_h23_raw(31337)
	assert_eq(b1.get_status(0, 0, "wheel_atk", false), b2.get_status(0, 0, "wheel_atk", false))
	assert_eq(b1.get_status(0, 0, "wheel_def", false), b2.get_status(0, 0, "wheel_def", false))
	assert_eq(b1.shield[0][0], b2.shield[0][0])
	assert_eq(b1.energy[0], b2.energy[0])


func test_h23_atk_blessing_adds_damage() -> void:
	var b := _battle_p0("h23", 5)
	b.set_status(0, 0, "wheel_atk", true)
	b.set_status(0, 0, "wheel_def", false)
	_aa(b, ATTACK, CHARGE)
	assert_eq(b.hp[1][0], 20 - 4, "攻+1 → 波 2.0")


func test_h23_def_blessing_reduces_damage() -> void:
	var b := _battle_p0("h23", 5)
	b.set_status(0, 0, "wheel_atk", false)
	b.set_status(0, 0, "wheel_def", true)
	b.shield[0][0] = 0                     # 清掉登场 roll 可能给的盾，隔离 def 效果
	_aa(b, CHARGE, BIG)                    # 大波 2.0，受伤-1 → 1.0
	assert_eq(b.hp[0][0], 10 - 2, "受伤-1 → 大波实受 1.0")


func test_h23_switch_out_clears_in_play_buff() -> void:
	var b := _battle_p0("h23", 5)
	b.set_status(0, 0, "wheel_atk", true)
	b.select_switch(0, 1)
	b.select_action(1, CHARGE)
	b.resolve()
	assert_false(b.get_status(0, 0, "wheel_atk", false), "下场清在场型 buff")
