extends GutTest

## ============================================================================
## 测试目的
##   锁定 h05 辰龙"龙威"被动的核心行为，同时验证 HeroSkill 组件机制可用。
##   这是 HeroSkill 小步迁移的首份英雄测试。
##
## 覆盖范围（仅 3 个核心 case，按 risk-notes §3 "测试精简" 原则）
##   - 能量差 = 0 → 无加成
##   - 能量差 = 2 → 攻击 +1
##   - 能量快照取自 resolve() 开始前（动作扣费前的能量差）
##
## 不覆盖
##   - 防御交互（test_base_actions 已覆盖）
##   - BIG_ATTACK 变体（行为机理与 ATTACK 相同，避免数学覆盖表）
##   - 与其他英雄技能交互（如 chenlong vs xugou），未来真要做组合时再补
##
## 当前锁定行为
##   - 公式：energy[player] - energy[opponent] ≥ 2 时，damage += diff / 2 (向下取整)
##   - 使用 resolve() 开始前的能量快照（而非动作扣费后），与原 BattleCore 行为一致
## ============================================================================


func test_chenlong_no_bonus_when_energy_diff_zero() -> void:
	# Arrange: 双方 h05，能量都 5 → 差额 0
	var battle := _h05_battle()
	BattleFactory.set_energy(battle, 0, 5)
	BattleFactory.set_energy(battle, 1, 5)
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.CHARGE)
	# Assert: P2 仅受基础 1 伤，无龙威加成
	assert_eq(battle.current_hp(1), 10 - 1, "差额 0 → 无加成，P2 受基础 1 伤")


func test_chenlong_plus_one_when_energy_diff_exactly_two() -> void:
	# Arrange: P1 能量 4, P2 能量 2 → 差额 2 → +1 伤害
	var battle := _h05_battle()
	BattleFactory.set_energy(battle, 0, 4)
	BattleFactory.set_energy(battle, 1, 2)
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.CHARGE)
	# Assert: P2 受 1 (基础) + 1 (龙威) = 2 伤
	assert_eq(battle.current_hp(1), 10 - 2, "差额 2 → +1 加成，P2 受 2 伤")


func test_chenlong_uses_energy_snapshot_before_costs() -> void:
	# Arrange: P1 能量 4, P2 能量 0 → 起点差额 4
	# P1 出 ATTACK (cost 1)，扣费后能量 3，差额 3
	# 若用 energy_before：diff=4 → +2 伤害 → P2 受 3 伤
	# 若用扣费后：diff=3 → +1 伤害 → P2 受 2 伤
	# 当前 BattleCore 使用 energy_before 快照 — 锁定此行为
	var battle := _h05_battle()
	BattleFactory.set_energy(battle, 0, 4)
	BattleFactory.set_energy(battle, 1, 0)
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.CHARGE)
	# Assert
	assert_eq(battle.current_hp(1), 10 - 3,
		"diff=4 时基础 1 + 龙威 2 = 3 伤 (锁定 energy_before 快照行为)")


# ============================================================================
# 私有 helper
# ============================================================================

func _h05_battle() -> BattleCore:
	var pool: Array[HeroData] = HeroData.create_pool_heroes()
	var h05: HeroData
	for h in pool:
		if h.hero_id == "h05":
			h05 = h
			break
	var p1: Array[HeroData] = [h05, h05, h05]
	var p2: Array[HeroData] = [h05, h05, h05]
	var b := BattleCore.new()
	b.setup(p1, p2)
	return b
