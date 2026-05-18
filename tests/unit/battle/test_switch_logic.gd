extends GutTest

## ============================================================================
## 测试目的
##   锁定 `BattleCore.select_switch_target(player, hero_slot)` 与
##   `can_switch(player)` 的当前行为：
##   - 接受 / 拒绝条件
##   - 副作用：扣能量、切 active、设 switch_used
##   - 与狡兔三窟 (h04) 免费切换标志的交互
##   - 浅覆盖午马 (h07) 上下场护盾交接
##   - 浅覆盖申猴 (h09) 切换离场清分身
##
## 覆盖范围
##   - 4 个拒绝条件：switch_used / 同位 / 死英雄 / 能量不足
##   - 成功切换的 3 个副作用：energy -1 / active_hero_index 更新 / switch_used = true
##   - 狡兔免费切换：cost = 0、用后立即清 flag
##   - 午马上场获盾（active = h07 时）
##   - 午马下场遗赠（leaving = h07，下一个上场获盾）
##   - 申猴下场清分身
##
## 不覆盖（在其他文件中）
##   - 切换后被动技能触发链 → 英雄集成测试 (Phase 1.3)
##   - 阵亡强制切换 (pending_death_switch) → test_death_and_winner.gd
##   - 切换在 resolve() 期间的时机 → 与 selected_action(SWITCH) 联动测试，留待 Phase 1.3
##
## 当前锁定的行为
##   - 无新增 CURRENT-BEHAVIOR；切换逻辑与 design/gdd/game-concept.md §3.3 一致
## ============================================================================


# ============================================================================
# 基础成功路径
# ============================================================================

func test_switch_succeeds_when_target_alive_and_energy_sufficient() -> void:
	# Arrange
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	# Act
	var ok: bool = battle.select_switch_target(0, 1)
	# Assert
	assert_true(ok)


func test_switch_decrements_energy_by_one() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	battle.select_switch_target(0, 1)
	assert_eq(battle.energy[0], 2, "切换扣 1 能量")


func test_switch_updates_active_hero_index() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	battle.select_switch_target(0, 2)
	assert_eq(battle.active_hero_index[0], 2, "active 切到 slot 2")


func test_switch_sets_switch_used_flag() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	battle.select_switch_target(0, 1)
	assert_true(battle.switch_used[0])
	assert_false(battle.switch_used[1], "P2 的 switch_used 不受 P1 影响")


# ============================================================================
# 拒绝条件
# ============================================================================

func test_switch_rejected_when_already_switched_this_turn() -> void:
	# Arrange
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 5)
	battle.select_switch_target(0, 1)  # 第一次成功
	# Act
	var ok: bool = battle.select_switch_target(0, 2)  # 第二次应被拒
	# Assert
	assert_false(ok)
	assert_eq(battle.active_hero_index[0], 1, "active 仍在 slot 1，未被改到 2")


func test_switch_rejected_when_target_is_current_active() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	var ok: bool = battle.select_switch_target(0, 0)  # active 默认 0
	assert_false(ok)


func test_switch_rejected_when_target_hero_is_dead() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	battle.hero_hp[0][1] = 0  # slot 1 死
	var ok: bool = battle.select_switch_target(0, 1)
	assert_false(ok)


func test_switch_rejected_when_insufficient_energy() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 0)  # 0 能量
	var ok: bool = battle.select_switch_target(0, 1)
	assert_false(ok)
	assert_eq(battle.energy[0], 0, "拒绝后能量不变")


# ============================================================================
# can_switch
# ============================================================================

func test_can_switch_requires_energy_and_alive_reserve() -> void:
	var battle := BattleFactory.plain_battle()
	# 能量 0 → false
	assert_false(battle.can_switch(0))
	# 能量 1 → true
	BattleFactory.set_energy(battle, 0, 1)
	assert_true(battle.can_switch(0))


func test_can_switch_false_when_only_one_alive() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 5)
	battle.hero_hp[0][1] = 0
	battle.hero_hp[0][2] = 0  # 仅 active 还活
	assert_false(battle.can_switch(0), "无活替补时不可切换")


func test_can_switch_false_after_switch_used() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 5)
	battle.switch_used[0] = true
	assert_false(battle.can_switch(0))


# ============================================================================
# 狡兔三窟 (h04) 免费切换
# ============================================================================

func test_jiaotu_free_switch_costs_zero_energy() -> void:
	# Arrange: 0 能量 + 设狡兔免费切换 flag
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 0)
	battle._jiaotu_free_switch[0] = true
	# Act
	var ok: bool = battle.select_switch_target(0, 1)
	# Assert
	assert_true(ok, "0 能量 + 狡兔免费 = 可切换")
	assert_eq(battle.energy[0], 0, "免费切换不扣能量")


func test_jiaotu_free_switch_flag_consumed_after_use() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 0)
	battle._jiaotu_free_switch[0] = true
	battle.select_switch_target(0, 1)
	assert_false(battle._jiaotu_free_switch[0], "免费 flag 用后立即清除")


# ============================================================================
# 午马 (h07) 上下场护盾交接 — 浅覆盖
# ============================================================================

func test_wuma_grants_shield_when_switched_in() -> void:
	# Arrange: 阵容 [non_h07, h07, non_h07]，从 slot 0 切到 slot 1 (h07)
	var battle := _battle_with_lineup(["h12", "h07", "h12"], ["h12", "h12", "h12"])
	BattleFactory.set_energy(battle, 0, 3)
	# Act
	battle.select_switch_target(0, 1)
	# Assert
	assert_eq(battle.shield[0][1], 1, "h07 上场获 1 护盾")


func test_wuma_leaves_shield_for_next_hero_when_switched_out() -> void:
	# Arrange: 阵容 [h07, non_h07, non_h07]，active = 0 (h07)，切到 slot 1
	var battle := _battle_with_lineup(["h07", "h12", "h12"], ["h12", "h12", "h12"])
	BattleFactory.set_energy(battle, 0, 3)
	# Act
	battle.select_switch_target(0, 1)
	# Assert
	assert_eq(battle.shield[0][1], 1, "h07 离场，下一个上场 (slot 1) 获 1 护盾")
	assert_false(battle._wuma_pending_shield[0], "pending 标志已清")


# ============================================================================
# 申猴 (h09) 切换离场清分身 — 浅覆盖
# ============================================================================

func test_shenwai_clones_cleared_when_switching_out() -> void:
	# Arrange: 阵容 [h09, h12, h12]，手动制造分身
	var battle := _battle_with_lineup(["h09", "h12", "h12"], ["h12", "h12", "h12"])
	BattleFactory.set_energy(battle, 0, 3)
	battle.clone_count[0] = 2
	battle.clone_hp[0] = [1, 1]
	battle.clone_order[0] = [1, 0, 2]
	# Act: 切走 h09
	battle.select_switch_target(0, 1)
	# Assert
	assert_eq(battle.clone_count[0], 0, "分身计数清零")
	assert_eq(battle.clone_hp[0], [], "分身 HP 数组清空")
	assert_eq(battle.clone_order[0], [], "分身顺序清空")


# ============================================================================
# 私有 helper
# ============================================================================

func _battle_with_lineup(p1_ids: Array, p2_ids: Array) -> BattleCore:
	var pool: Array[HeroData] = HeroData.create_pool_heroes()
	var p1: Array[HeroData] = []
	var p2: Array[HeroData] = []
	for hid in p1_ids:
		p1.append(_find_hero(pool, hid))
	for hid in p2_ids:
		p2.append(_find_hero(pool, hid))
	var b := BattleCore.new()
	b.setup(p1, p2)
	return b


func _find_hero(pool: Array[HeroData], hero_id: String) -> HeroData:
	for h in pool:
		if h.hero_id == hero_id:
			return h
	push_error("Hero ID not found: " + hero_id)
	return null
