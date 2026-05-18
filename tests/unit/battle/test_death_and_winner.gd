extends GutTest

## ============================================================================
## 测试目的
##   锁定 BattleCore 的死亡 / 强制切换 / 胜负判定逻辑：
##   - 单英雄阵亡后的状态变化（pending_death_switch / _fallen_teammates）
##   - 一方全灭 → winner 设值
##   - 双方同回合全灭 → 平局
##   - `execute_death_switch(player, slot)` 的接受 / 拒绝条件
##   - `get_living_reserves(player)` 列表
##
## 覆盖范围
##   - HP 触底（≤0）的英雄被认为阵亡
##   - active 阵亡触发 pending_death_switch[p] = 1
##   - active 阵亡且无活替补 → 不设 pending
##   - _fallen_teammates 在阵亡时递增
##   - alive_hero_count 返回值
##   - resolve() 结尾判定胜负三种情况
##   - execute_death_switch 4 个 case
##
## 不覆盖
##   - 戌狗 (h11) 认主被动（与 _fallen_teammates 联动）→ Phase 1.3 英雄测试
##   - 蛇蜕 (h06) 复活后不计入阵亡 → Phase 1.3 英雄测试
##   - 切换时机与 UI overlay → 不在 BattleCore 单元测试范围
##
## 当前锁定的行为（疑似 bug）
##   - B-007（候选）：双方同回合全灭 → winner = 0，但代码注释为"平局"，
##     而 winner=0 在 game_over_check 之前的含义是"P1 胜利的占位/未定"。
##     语义模糊，详见 BEHAVIOR_NOTES B-007。
## ============================================================================


# ============================================================================
# 单英雄阵亡的副作用
# ============================================================================

func test_active_hero_dies_sets_pending_death_switch() -> void:
	# Arrange: P1 active HP=1，被 BIG_ATTACK 击杀
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 1, 3)
	battle.hero_hp[0][0] = 1
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_ATTACK)
	# Assert
	assert_eq(battle.hero_hp[0][0], -1, "HP=1 - 2 = -1，阵亡")
	assert_eq(battle.pending_death_switch[0], 1, "P1 待选替补")


func test_dead_hero_increments_fallen_teammates_counter() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 1, 3)
	battle.hero_hp[0][0] = 1
	# 阵亡前
	assert_eq(battle._fallen_teammates[0], 0)
	# 触发阵亡
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_ATTACK)
	# 阵亡后
	assert_eq(battle._fallen_teammates[0], 1, "P1 阵亡计数 +1")
	assert_eq(battle._fallen_teammates[1], 0, "P2 不受影响")


func test_no_pending_switch_when_no_alive_reserve() -> void:
	# Arrange: P1 仅 active 活，slot 1/2 早已死
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 1, 3)
	battle.hero_hp[0][0] = 1
	battle.hero_hp[0][1] = 0
	battle.hero_hp[0][2] = 0
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_ATTACK)
	# Assert
	assert_true(battle.game_over, "全灭，game_over=true")
	assert_eq(battle.winner, 2, "P2 获胜")
	assert_eq(battle.pending_death_switch[0], -1, "全灭时不设 pending_death_switch")


# ============================================================================
# alive_hero_count / get_living_reserves
# ============================================================================

func test_alive_hero_count_initial_is_three() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle.alive_hero_count(0), 3)
	assert_eq(battle.alive_hero_count(1), 3)


func test_alive_hero_count_excludes_dead_heroes() -> void:
	var battle := BattleFactory.plain_battle()
	battle.hero_hp[0][1] = 0
	battle.hero_hp[0][2] = 0
	assert_eq(battle.alive_hero_count(0), 1)
	assert_eq(battle.alive_hero_count(1), 3)


func test_get_living_reserves_excludes_active() -> void:
	var battle := BattleFactory.plain_battle()
	# active=0，slot 1/2 活，应返回 [1, 2]
	assert_eq(battle.get_living_reserves(0), [1, 2])


func test_get_living_reserves_excludes_dead() -> void:
	var battle := BattleFactory.plain_battle()
	battle.hero_hp[0][1] = 0
	assert_eq(battle.get_living_reserves(0), [2], "slot 1 死，只剩 slot 2")


# ============================================================================
# 胜负判定
# ============================================================================

func test_winner_2_when_p1_all_dead() -> void:
	# Arrange: P1 三个英雄全 HP=1，P2 一个英雄 HP=1（避免双方全灭）
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 1, 3)
	for slot in range(3):
		battle.hero_hp[0][slot] = 1
	# Act: 一回合一个个打 — 测试简化，直接 set 全 0 模拟连续阵亡
	battle.hero_hp[0] = [0, 0, 0]
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.CHARGE)
	# Assert
	assert_true(battle.game_over)
	assert_eq(battle.winner, 2, "P1 全灭 → P2 (winner=2) 胜利")


func test_winner_1_when_p2_all_dead() -> void:
	var battle := BattleFactory.plain_battle()
	battle.hero_hp[1] = [0, 0, 0]
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.CHARGE)
	assert_true(battle.game_over)
	assert_eq(battle.winner, 1, "P2 全灭 → P1 (winner=1) 胜利")


func test_draw_when_both_sides_die_same_turn() -> void:
	# CURRENT-BEHAVIOR (B-007 候选):
	#   battle_core.gd:438 双方同时全灭 → game_over=true, winner=0, events 添加 "双方全灭 — 平局"。
	#   但 winner=0 在初始化时也是常见占位值（虽然 setup 用的是 -1）。
	#   语义建议：用专门常量 (DRAW=-2) 或 winner=0 表示平局并写注释。
	#   详见 BEHAVIOR_NOTES B-007。
	var battle := BattleFactory.plain_battle()
	battle.hero_hp[0] = [0, 0, 0]
	battle.hero_hp[1] = [0, 0, 0]
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.CHARGE)
	assert_true(battle.game_over)
	# LOCKED-FOR-REFACTOR (B-007): 若引入 DRAW 常量，下面应改为 BattleCore.DRAW (或类似)。
	assert_eq(battle.winner, 0, "双方同回合全灭 → winner=0 表示平局")


# ============================================================================
# execute_death_switch
# ============================================================================

func test_execute_death_switch_succeeds_with_pending() -> void:
	# Arrange: 触发 pending
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 1, 3)
	battle.hero_hp[0][0] = 1
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_ATTACK)
	assert_eq(battle.pending_death_switch[0], 1, "(precondition) pending 已设")
	# Act
	var ok: bool = battle.execute_death_switch(0, 1)
	# Assert
	assert_true(ok)
	assert_eq(battle.active_hero_index[0], 1, "active 切到 slot 1")
	assert_eq(battle.pending_death_switch[0], -1, "pending 已清")


func test_execute_death_switch_rejected_without_pending() -> void:
	var battle := BattleFactory.plain_battle()
	# pending 未设
	var ok: bool = battle.execute_death_switch(0, 1)
	assert_false(ok)


func test_execute_death_switch_rejected_to_dead_hero() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 1, 3)
	battle.hero_hp[0][0] = 1
	battle.hero_hp[0][1] = 0  # slot 1 也死
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.CHARGE, BattleCore.Action.BIG_ATTACK)
	# pending 应设 (slot 2 还活)
	var ok: bool = battle.execute_death_switch(0, 1)
	assert_false(ok, "切到死英雄拒绝")


func test_execute_death_switch_rejected_to_current_active() -> void:
	var battle := BattleFactory.plain_battle()
	# 手动设 pending = 1, active = 0
	battle.pending_death_switch[0] = 1
	var ok: bool = battle.execute_death_switch(0, 0)
	assert_false(ok, "切到当前 active 拒绝")
