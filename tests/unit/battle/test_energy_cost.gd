extends GutTest

## ============================================================================
## ⚠ 该文件允许直接调用 BattleCore 私有方法（如 `_get_action_cost`），
##   仅用于锁定遗留行为。当前阶段目标是"锁定真实行为"，不是纯粹 DDD 风格。
##   Phase 3 技能组件化重构后，若 BattleCore 公开了等价 API，应改用公开接口。
## ============================================================================
##
## 测试目的
##   锁定 BattleCore 能量与动作可用性的三个入口的**当前真实行为**：
##     - `_get_action_cost(player, action)` — 动作成本计算
##     - `can_afford(player, action)` — 是否可负担
##     - `select_action(player, action)` — 拒绝或接受
##
##   未来 Phase 3 重构若改动这三个函数的语义，本套件应能立即报警。
##
## 覆盖范围
##   - 5 个基础动作 (CHARGE/ATTACK/DEFEND/BIG_ATTACK/BIG_DEFEND) 的固定 cost
##   - SWITCH 常规 cost = 1
##   - 能量不足时 can_afford / select_action 的拒绝行为
##   - select_action 被拒后 selected_action 保持 -1（B-004 的"半步"）
##   - 财源广进 (h01) cooldown 期间不可用
##   - 舍身 (h08) HP > 2 才可用
##   - 身外化身 (h09) clone_count < 2 才可用
##   - 狡兔三窟 (h04) 每局 3 次上限
##   - 百兽 (h03) cost = max(energy, BAI_SHOU_MIN_COST=1)
##
## 不覆盖（在其他文件中）
##   - 5×5 矩阵的伤害结算 → test_base_actions.gd
##   - 切换的副作用（午马护盾、申猴清分身）→ 英雄集成测试 (Phase 1.3)
##   - 直接触发 B-004 的崩溃路径（避免污染 GUT 输出）
##   - resolve() 内 BAI_SHOU 实际花费的 clamp 行为 → 留到 h03 集成测试
##
## 当前锁定的行为（疑似 bug 已标 # CURRENT-BEHAVIOR / # LOCKED-FOR-REFACTOR）
##   - B-004：select_action 拒绝后 selected_action 保持 -1，下游 resolve() 会崩
##   - B-005（候选）：_get_action_cost(BAI_SHOU) 未 clamp 到 BAI_SHOU_DAMAGE_CAP=6，
##     与 resolve() 内实际花费的 clamp 不一致（详见 BEHAVIOR_NOTES B-005）
## ============================================================================


# ============================================================================
# 五个基础动作的固定 cost
# ============================================================================

func test_charge_cost_is_zero() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_action_cost(0, BattleCore.Action.CHARGE), 0)


func test_attack_cost_is_one() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_action_cost(0, BattleCore.Action.ATTACK), 1)


func test_defend_cost_is_zero() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_action_cost(0, BattleCore.Action.DEFEND), 0)


func test_big_attack_cost_is_three() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_action_cost(0, BattleCore.Action.BIG_ATTACK), 3)


func test_big_defend_cost_is_two() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_action_cost(0, BattleCore.Action.BIG_DEFEND), 2)


func test_switch_cost_is_one_by_default() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_action_cost(0, BattleCore.Action.SWITCH), 1)


# ============================================================================
# can_afford 与 select_action 的拒绝行为
# ============================================================================

func test_can_afford_attack_requires_one_energy() -> void:
	# Arrange
	var battle := BattleFactory.plain_battle()
	# Act + Assert: 0 能量
	assert_false(battle.can_afford(0, BattleCore.Action.ATTACK), "0 能量时不可 ATTACK")
	# Act + Assert: 1 能量
	BattleFactory.set_energy(battle, 0, 1)
	assert_true(battle.can_afford(0, BattleCore.Action.ATTACK), "1 能量时可 ATTACK")


func test_can_afford_big_attack_requires_three_energy() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 2)
	assert_false(battle.can_afford(0, BattleCore.Action.BIG_ATTACK), "2 能量时不可 BIG_ATTACK")
	BattleFactory.set_energy(battle, 0, 3)
	assert_true(battle.can_afford(0, BattleCore.Action.BIG_ATTACK), "3 能量时可 BIG_ATTACK")


func test_can_afford_charge_always_true() -> void:
	var battle := BattleFactory.plain_battle()
	assert_true(battle.can_afford(0, BattleCore.Action.CHARGE), "0 能量也可 CHARGE")


func test_select_action_rejects_unaffordable_action() -> void:
	# CURRENT-BEHAVIOR (B-004): select_action 拒绝时 selected_action 保持 -1。
	# 若下游 resolve() 在此状态下被调用，会崩溃 (KeyError on BASE_ACTION_DEF[-1])。
	# 本测试仅锁定 select_action 的拒绝返回值，不触发崩溃。
	# Arrange
	var battle := BattleFactory.plain_battle()
	# Act
	var ok: bool = battle.select_action(0, BattleCore.Action.BIG_ATTACK)
	# Assert
	# LOCKED-FOR-REFACTOR (B-004): 若 select_action 改为在拒绝时设默认 CHARGE，下面会变红。
	assert_false(ok, "0 能量时 BIG_ATTACK 应被拒绝")
	assert_eq(battle.selected_action[0], -1, "被拒后 selected_action 保持 -1 (B-004 隐患)")


func test_select_action_accepts_affordable_action() -> void:
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	var ok: bool = battle.select_action(0, BattleCore.Action.BIG_ATTACK)
	assert_true(ok)
	assert_eq(battle.selected_action[0], BattleCore.Action.BIG_ATTACK)


# ============================================================================
# 英雄技能的可用性门槛
# ============================================================================

func test_caijin_unavailable_during_cooldown() -> void:
	# Arrange: h01 子鼠 + 标记 cooldown
	var battle := _hero_battle(["h01", "h01", "h01"], ["h01", "h01", "h01"])
	battle._caijin_cooldown[0] = true
	# Assert
	assert_false(battle.can_afford(0, BattleCore.Action.CAI_JIN), "CAI_JIN cooldown 时不可用")
	# Act: 清除 cooldown
	battle._caijin_cooldown[0] = false
	# Assert
	assert_true(battle.can_afford(0, BattleCore.Action.CAI_JIN), "CAI_JIN 非 cooldown 时可用 (0 能也可)")


func test_sheshen_requires_hp_above_two() -> void:
	# Arrange: h08 未羊
	var battle := _hero_battle(["h08", "h08", "h08"], ["h08", "h08", "h08"])
	# Assert at HP=3 (满血 12 不便测，直接 set)
	battle.hero_hp[0][0] = 3
	assert_true(battle.can_afford(0, BattleCore.Action.SHE_SHEN), "HP=3 时舍身可用")
	battle.hero_hp[0][0] = 2
	assert_false(battle.can_afford(0, BattleCore.Action.SHE_SHEN), "HP=2 时舍身不可用 (会死)")
	battle.hero_hp[0][0] = 1
	assert_false(battle.can_afford(0, BattleCore.Action.SHE_SHEN), "HP=1 时舍身不可用")


func test_shenwai_requires_energy_and_clone_slot() -> void:
	# Arrange: h09 申猴
	var battle := _hero_battle(["h09", "h09", "h09"], ["h09", "h09", "h09"])
	# Assert: 能量门槛
	BattleFactory.set_energy(battle, 0, 2)
	assert_false(battle.can_afford(0, BattleCore.Action.SHEN_WAI), "2 能量不够 (需 3)")
	BattleFactory.set_energy(battle, 0, 3)
	assert_true(battle.can_afford(0, BattleCore.Action.SHEN_WAI), "3 能量 + 0 分身 = 可用")
	# Assert: 分身槽门槛
	battle.clone_count[0] = 2
	assert_false(battle.can_afford(0, BattleCore.Action.SHEN_WAI), "2 分身已满，不可再造")
	battle.clone_count[0] = 1
	assert_true(battle.can_afford(0, BattleCore.Action.SHEN_WAI), "1 分身 + 3 能 = 可造第 2 个")


func test_jiaotu_three_uses_per_game() -> void:
	# Arrange: h04 卯兔
	var battle := _hero_battle(["h04", "h04", "h04"], ["h04", "h04", "h04"])
	BattleFactory.set_energy(battle, 0, 99)  # 能量永远够
	# Assert
	battle._jiaotu_used_count[0] = 0
	assert_true(battle.can_afford(0, BattleCore.Action.JIAO_TU), "第 1 次可用")
	battle._jiaotu_used_count[0] = 2
	assert_true(battle.can_afford(0, BattleCore.Action.JIAO_TU), "第 3 次可用")
	battle._jiaotu_used_count[0] = 3
	assert_false(battle.can_afford(0, BattleCore.Action.JIAO_TU), "第 4 次不可用 (上限 3)")


# ============================================================================
# 百兽 (h03) cost 动态计算
# ============================================================================

func test_baishou_cost_uses_max_of_energy_and_one() -> void:
	# CURRENT-BEHAVIOR (B-005 候选):
	#   _get_action_cost(BAI_SHOU) = maxi(energy, BAI_SHOU_MIN_COST=1)，不 clamp 到 6。
	#   但 resolve() 内实际花费 spent = clampi(energy, 1, 6)，即 cap 在 6。
	#   两者不一致 → 调用方若读 _get_action_cost 推断花费，会与实际 resolve() 行为偏离。
	#   当前 UI 不直接读 _get_action_cost(BAI_SHOU)，所以无可见影响。
	#   详见 BEHAVIOR_NOTES B-005。
	# Arrange
	var battle := _hero_battle(["h03", "h03", "h03"], ["h03", "h03", "h03"])
	# Act + Assert: 能量 0
	BattleFactory.set_energy(battle, 0, 0)
	assert_eq(battle._get_action_cost(0, BattleCore.Action.BAI_SHOU), 1, "0 能 → cost = max(0, 1) = 1")
	# Act + Assert: 能量 4
	BattleFactory.set_energy(battle, 0, 4)
	assert_eq(battle._get_action_cost(0, BattleCore.Action.BAI_SHOU), 4)
	# Act + Assert: 能量 10 — cost 未 clamp 到 6
	BattleFactory.set_energy(battle, 0, 10)
	# LOCKED-FOR-REFACTOR (B-005): 若 _get_action_cost 改为 clamp 到 6，下面应改为 6。
	assert_eq(battle._get_action_cost(0, BattleCore.Action.BAI_SHOU), 10,
		"_get_action_cost 不 clamp 到 BAI_SHOU_DAMAGE_CAP — 与 resolve() 内 clamp 不一致")


func test_baishou_can_afford_only_needs_one_energy() -> void:
	# can_afford(BAI_SHOU) 走特判，仅检查 energy >= BAI_SHOU_MIN_COST=1，
	# 不依赖 _get_action_cost 返回值，所以 B-005 不影响 can_afford。
	var battle := _hero_battle(["h03", "h03", "h03"], ["h03", "h03", "h03"])
	BattleFactory.set_energy(battle, 0, 0)
	assert_false(battle.can_afford(0, BattleCore.Action.BAI_SHOU))
	BattleFactory.set_energy(battle, 0, 1)
	assert_true(battle.can_afford(0, BattleCore.Action.BAI_SHOU))


# ============================================================================
# 私有 helper
# ============================================================================

## 用具体英雄 ID 列表构造 BattleCore (绕过 plain_battle，让英雄技能生效)。
## 调用方 own 这些英雄 — 不要在多个测试间共享。
func _hero_battle(p1_ids: Array, p2_ids: Array) -> BattleCore:
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
	push_error("Hero ID not found in pool: " + hero_id)
	return null
