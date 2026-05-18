extends GutTest

## ============================================================================
## 测试目的
##   锁定 BattleCore 5 个基础动作 (CHARGE/ATTACK/DEFEND/BIG_ATTACK/BIG_DEFEND)
##   在 5×5 = 25 种同时出手组合下的**当前真实行为**。
##
##   作为后续技能组件化重构 (Phase 3) 的回归基准 — 重构后这些测试必须仍全绿，
##   否则证明重构改变了基础动作语义。
##
## 覆盖范围
##   - 能量扣费 (cost) 与获取 (CHARGE 的 +1)
##   - 五个基础动作的两两组合伤害解算
##   - 防御格挡：DEFEND vs ATTACK、BIG_DEFEND vs ATTACK/BIG_ATTACK
##   - DEFEND vs BIG_ATTACK 被穿透
##   - MAX_ENERGY 上限 (20)
##
## 不覆盖（在专门文件中）
##   - 英雄技能 (h01~h13)、被动 (chenlong/xugou/haizhu/sichen/wuma)
##   - 切换 / 阵亡 / 强制切换
##   - 分身 / 护盾 / 反戈
##   - 愚者随机 / 蛇蜕复活 / 财源 / 百兽 / 舍身 / 身外化身
##   - 能量边界与 select_action 拒绝 → test_energy_cost.gd
##
## 当前锁定的行为（与 design/gdd/game-concept.md 不一致的部分）
##   - ATTACK × ATTACK : 双方**各受 1 伤**（设计文档："互相抵消"）
##   - BIG_ATTACK × BIG_ATTACK : 双方**各受 2 伤**（设计："互相抵消"）
##   - ATTACK × BIG_ATTACK : 双方都受到对方伤害（设计："仅大波方造成 1 伤"）
##   详见 tests/BEHAVIOR_NOTES.md B-001 / B-002 / B-003。
## ============================================================================


# ---- 公共参数 ----

const E_INIT := 5  # 双方初始能量；足够支付任何基础动作的成本
const HP_INIT := 10


# ============================================================================
# CHARGE × *  ——  攒不消耗能量、+1能量、不攻击不防御
# ============================================================================

func test_charge_vs_charge_both_gain_energy() -> void:
	# Arrange
	var battle := _battle()
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.CHARGE)
	# Assert
	assert_eq(battle.energy[0], E_INIT + 1, "P1 攒 +1 能量")
	assert_eq(battle.energy[1], E_INIT + 1, "P2 攒 +1 能量")
	assert_eq(battle.current_hp(0), HP_INIT, "P1 无伤")
	assert_eq(battle.current_hp(1), HP_INIT, "P2 无伤")


func test_charge_vs_attack_p2_attacks_p1() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.ATTACK)
	assert_eq(battle.energy[0], E_INIT + 1, "P1 攒 +1")
	assert_eq(battle.energy[1], E_INIT - 1, "P2 波 -1")
	assert_eq(battle.current_hp(0), HP_INIT - 1, "P1 攒时无防御，受 1 伤")
	assert_eq(battle.current_hp(1), HP_INIT, "P2 无伤")


func test_charge_vs_defend_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.DEFEND)
	assert_eq(battle.energy[0], E_INIT + 1, "P1 攒 +1")
	assert_eq(battle.energy[1], E_INIT, "P2 防 0 消耗")
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


func test_charge_vs_big_attack_p1_takes_2_damage() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_ATTACK)
	assert_eq(battle.energy[0], E_INIT + 1)
	assert_eq(battle.energy[1], E_INIT - 3, "P2 大波 -3 能量")
	assert_eq(battle.current_hp(0), HP_INIT - 2, "P1 攒时受 2 伤")
	assert_eq(battle.current_hp(1), HP_INIT)


func test_charge_vs_big_defend_no_damage() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_DEFEND)
	assert_eq(battle.energy[0], E_INIT + 1)
	assert_eq(battle.energy[1], E_INIT - 2, "P2 大防 -2 能量")
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


# ============================================================================
# ATTACK × *  ——  波伤 1，被防/大防挡
# ============================================================================

func test_attack_vs_charge_p2_takes_1_damage() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.CHARGE)
	assert_eq(battle.energy[0], E_INIT - 1)
	assert_eq(battle.energy[1], E_INIT + 1)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT - 1)


func test_attack_vs_attack_both_take_1_damage() -> void:
	# CURRENT-BEHAVIOR (B-001):
	#   设计文档 game-concept.md §3.2 写"波×波 = 互相抵消，双方各-1能"。
	#   实际代码 battle_core.gd:_apply_defense 没有 ATTACK vs ATTACK 的抵消分支 —
	#   双向攻击都被解算，双方都受 1 伤。
	#   未来 Phase 3 重构若决定按设计文档改，本测试将变红，请同步更新 BEHAVIOR_NOTES B-001。
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.ATTACK)
	assert_eq(battle.energy[0], E_INIT - 1)
	assert_eq(battle.energy[1], E_INIT - 1)
	# LOCKED-FOR-REFACTOR (B-001): 若按设计文档"互相抵消"修复，下面两行需改为 HP_INIT。
	assert_eq(battle.current_hp(0), HP_INIT - 1, "P1 受 1 伤 (与设计文档'互相抵消'不一致)")
	assert_eq(battle.current_hp(1), HP_INIT - 1, "P2 受 1 伤 (与设计文档'互相抵消'不一致)")


func test_attack_vs_defend_blocked() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.DEFEND)
	assert_eq(battle.energy[0], E_INIT - 1, "P1 波 -1 (即使被挡)")
	assert_eq(battle.energy[1], E_INIT, "P2 防 0 消耗")
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT, "P2 防成功格挡波")


func test_attack_vs_big_attack_both_take_damage() -> void:
	# CURRENT-BEHAVIOR (B-003):
	#   设计文档 §3.2 写"波 vs 大波 = 大波方造成 1 伤 (波方受伤)，大波方-3能 波方-1能"。
	#   即只有大波方造成伤害；波方的波被大波压制不造成伤害。
	#   实际代码：双向都解算 — 波方受 2 伤 (BIG_ATTACK)，大波方受 1 伤 (ATTACK)。
	#   详见 BEHAVIOR_NOTES B-003。
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK)
	assert_eq(battle.energy[0], E_INIT - 1)
	assert_eq(battle.energy[1], E_INIT - 3)
	# LOCKED-FOR-REFACTOR (B-003): 若按设计"大波压制波"修复，
	#   下面 P1 hp 应改为 HP_INIT - 1，P2 hp 应改为 HP_INIT。
	assert_eq(battle.current_hp(0), HP_INIT - 2, "P1 受 2 伤 (大波)")
	assert_eq(battle.current_hp(1), HP_INIT - 1, "P2 受 1 伤 (波) — 设计文档说波被压制不应造成伤害")


func test_attack_vs_big_defend_blocked() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.BIG_DEFEND)
	assert_eq(battle.energy[0], E_INIT - 1)
	assert_eq(battle.energy[1], E_INIT - 2, "P2 大防 -2")
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT, "P2 大防格挡波")


# ============================================================================
# DEFEND × *  ——  防不消耗能量，仅格挡波（不格挡大波）
# ============================================================================

func test_defend_vs_charge_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.DEFEND, BattleCore.Action.CHARGE)
	assert_eq(battle.energy[0], E_INIT)
	assert_eq(battle.energy[1], E_INIT + 1)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


func test_defend_vs_attack_blocked() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.DEFEND, BattleCore.Action.ATTACK)
	assert_eq(battle.energy[0], E_INIT)
	assert_eq(battle.energy[1], E_INIT - 1, "P2 波 -1 (即使被挡)")
	assert_eq(battle.current_hp(0), HP_INIT, "P1 防成功格挡")
	assert_eq(battle.current_hp(1), HP_INIT)


func test_defend_vs_defend_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.DEFEND, BattleCore.Action.DEFEND)
	assert_eq(battle.energy[0], E_INIT)
	assert_eq(battle.energy[1], E_INIT)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


func test_defend_vs_big_attack_penetrated() -> void:
	# 与设计文档一致：大波穿防，防方受 2 伤。
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.DEFEND, BattleCore.Action.BIG_ATTACK)
	assert_eq(battle.energy[0], E_INIT, "P1 防 0 消耗")
	assert_eq(battle.energy[1], E_INIT - 3)
	assert_eq(battle.current_hp(0), HP_INIT - 2, "P1 防被大波穿透，受 2 伤")
	assert_eq(battle.current_hp(1), HP_INIT)


func test_defend_vs_big_defend_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.DEFEND, BattleCore.Action.BIG_DEFEND)
	assert_eq(battle.energy[0], E_INIT)
	assert_eq(battle.energy[1], E_INIT - 2)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


# ============================================================================
# BIG_ATTACK × *  ——  大波伤 2，穿防，被大防挡
# ============================================================================

func test_big_attack_vs_charge_p2_takes_2_damage() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_ATTACK, BattleCore.Action.CHARGE)
	assert_eq(battle.energy[0], E_INIT - 3)
	assert_eq(battle.energy[1], E_INIT + 1)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT - 2)


func test_big_attack_vs_attack_both_take_damage() -> void:
	# 镜像 test_attack_vs_big_attack。同一个 CURRENT-BEHAVIOR (B-003)。
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_ATTACK, BattleCore.Action.ATTACK)
	assert_eq(battle.energy[0], E_INIT - 3)
	assert_eq(battle.energy[1], E_INIT - 1)
	# LOCKED-FOR-REFACTOR (B-003): 若按设计"大波压制波"修复，
	#   下面 P1 hp 应改为 HP_INIT，P2 hp 应改为 HP_INIT - 1。
	assert_eq(battle.current_hp(0), HP_INIT - 1, "P1 受 1 伤 (波) — 设计文档说波被大波压制不应造成伤害")
	assert_eq(battle.current_hp(1), HP_INIT - 2, "P2 受 2 伤 (大波)")


func test_big_attack_vs_defend_penetrated() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_ATTACK, BattleCore.Action.DEFEND)
	assert_eq(battle.energy[0], E_INIT - 3)
	assert_eq(battle.energy[1], E_INIT)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT - 2, "P2 防被大波穿透，受 2 伤")


func test_big_attack_vs_big_attack_both_take_2_damage() -> void:
	# CURRENT-BEHAVIOR (B-002):
	#   设计文档 §3.2 写"大波×大波 = 互相抵消，双方各-3能"。
	#   实际代码：双向都解算，双方各受 2 伤。
	#   详见 BEHAVIOR_NOTES B-002。
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_ATTACK, BattleCore.Action.BIG_ATTACK)
	assert_eq(battle.energy[0], E_INIT - 3)
	assert_eq(battle.energy[1], E_INIT - 3)
	# LOCKED-FOR-REFACTOR (B-002): 若按设计"互相抵消"修复，下面两行需改为 HP_INIT。
	assert_eq(battle.current_hp(0), HP_INIT - 2, "P1 受 2 伤 (与设计文档'互相抵消'不一致)")
	assert_eq(battle.current_hp(1), HP_INIT - 2, "P2 受 2 伤 (与设计文档'互相抵消'不一致)")


func test_big_attack_vs_big_defend_blocked() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_ATTACK, BattleCore.Action.BIG_DEFEND)
	assert_eq(battle.energy[0], E_INIT - 3)
	assert_eq(battle.energy[1], E_INIT - 2)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT, "P2 大防格挡大波")


# ============================================================================
# BIG_DEFEND × *  ——  大防消耗 2，格挡波和大波
# ============================================================================

func test_big_defend_vs_charge_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_DEFEND, BattleCore.Action.CHARGE)
	assert_eq(battle.energy[0], E_INIT - 2)
	assert_eq(battle.energy[1], E_INIT + 1)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


func test_big_defend_vs_attack_blocked() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_DEFEND, BattleCore.Action.ATTACK)
	assert_eq(battle.energy[0], E_INIT - 2)
	assert_eq(battle.energy[1], E_INIT - 1)
	assert_eq(battle.current_hp(0), HP_INIT, "P1 大防格挡波")
	assert_eq(battle.current_hp(1), HP_INIT)


func test_big_defend_vs_defend_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_DEFEND, BattleCore.Action.DEFEND)
	assert_eq(battle.energy[0], E_INIT - 2)
	assert_eq(battle.energy[1], E_INIT)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


func test_big_defend_vs_big_attack_blocked() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_DEFEND, BattleCore.Action.BIG_ATTACK)
	assert_eq(battle.energy[0], E_INIT - 2)
	assert_eq(battle.energy[1], E_INIT - 3)
	assert_eq(battle.current_hp(0), HP_INIT, "P1 大防格挡大波")
	assert_eq(battle.current_hp(1), HP_INIT)


func test_big_defend_vs_big_defend_no_interaction() -> void:
	var battle := _battle()
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.BIG_DEFEND, BattleCore.Action.BIG_DEFEND)
	assert_eq(battle.energy[0], E_INIT - 2)
	assert_eq(battle.energy[1], E_INIT - 2)
	assert_eq(battle.current_hp(0), HP_INIT)
	assert_eq(battle.current_hp(1), HP_INIT)


# ============================================================================
# 能量上限
# ============================================================================

func test_charge_at_max_energy_does_not_overflow() -> void:
	# CURRENT-BEHAVIOR (B-004 候选):
	#   攒能量获得受 MAX_ENERGY=20 截断。但消耗动作的 cost 不会被截断 (可以打到负数)。
	#   测试时 plain hero，set_energy 到上限，再攒一次确认不溢出。
	var battle := _battle()
	BattleFactory.set_energy(battle, 0, BattleCore.MAX_ENERGY)
	BattleFactory.set_energy(battle, 1, BattleCore.MAX_ENERGY)
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.CHARGE)
	assert_eq(battle.energy[0], BattleCore.MAX_ENERGY, "P1 已满，攒不再增加")
	assert_eq(battle.energy[1], BattleCore.MAX_ENERGY, "P2 已满，攒不再增加")


# ============================================================================
# 私有 helper
# ============================================================================

func _battle() -> BattleCore:
	var b := BattleFactory.plain_battle(HP_INIT, HP_INIT)
	BattleFactory.set_energy(b, 0, E_INIT)
	BattleFactory.set_energy(b, 1, E_INIT)
	return b
