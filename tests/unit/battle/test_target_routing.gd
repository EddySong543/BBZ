extends GutTest

## ============================================================================
## ⚠ 该文件允许直接调用 BattleCore 私有方法（`_resolve_target` / `_route_damage` /
##   `_get_valid_targets`），并直接读写私有状态（`clone_count` / `clone_hp` /
##   `clone_order` / `selected_target`），仅用于锁定遗留行为。
##   当前阶段目标是"锁定真实行为"，不是纯粹 DDD 风格。
##   Phase 3 技能组件化重构后，若 BattleCore 公开了等价 query API，应改用公开接口。
## ============================================================================
##
## 测试目的
##   锁定 BattleCore 攻击目标路由的当前行为（与申猴 h09 身外化身分身系统耦合）：
##   - 无分身时攻击直接打本体
##   - 有分身时攻击按 `selected_target` (索引到 clone_order) 路由
##   - selected_target 越界 fallback 到 0
##   - 摧毁分身后 clone_count 递减 + clone_order 重建
##
## 覆盖范围
##   - `_resolve_target(attacker, defender)` 在 0 分身 / 有分身的返回值
##   - `_route_damage(attacker, defender, dmg, ...)` 路由结果
##   - `_get_valid_targets(player)` 在 0 分身 / 有分身的列表
##   - selected_target = -1 / 0 / 越界值的处理
##   - 分身被攻击后状态变化
##
## 不覆盖（在 Phase 1.3 英雄测试中）
##   - SHEN_WAI 动作本身的创建分身流程
##   - 百兽 (h03) 多 hit 随机路由
##   - 反戈 (h02) 与分身的交互
##
## 当前锁定的行为
##   - clone_order 的 shuffle 顺序无法测（依赖 RNG）— 用 direct set 绕过
##   - selected_target 越界时 fallback 到 0，可能击中本体而非分身（设计未明示）
## ============================================================================


# ============================================================================
# _resolve_target — 决定攻击实际击中的"虚拟槽"
#   返回值含义：1 = 本体, 0 = 分身 slot 0, 2 = 分身 slot 1
# ============================================================================

func test_resolve_target_no_clones_returns_one() -> void:
	# Arrange
	var battle := BattleFactory.plain_battle()
	# Act
	var target: int = battle._resolve_target(0, 1)
	# Assert
	assert_eq(target, 1, "无分身时永远返回 1 (本体)")


func test_resolve_target_with_clones_uses_selected_target() -> void:
	# Arrange: P2 有 2 个分身，顺序固定为 [本体, 分身0, 分身1]
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 1, [1, 0, 2])  # 位置 0=本体(1), 1=分身0(0), 2=分身1(2)
	battle.selected_target[0] = 1  # P1 选攻击位置 1
	# Act
	var target: int = battle._resolve_target(0, 1)
	# Assert
	assert_eq(target, 0, "位置 1 对应 clone_order[1] = 0 (分身 slot 0)")


func test_resolve_target_falls_back_to_zero_when_negative() -> void:
	# Arrange: 未设 selected_target，默认 -1
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 1, [2, 0, 1])  # 位置 0=分身1, 1=分身0, 2=本体
	battle.selected_target[0] = -1
	# Act
	var target: int = battle._resolve_target(0, 1)
	# Assert
	assert_eq(target, 2, "selected_target=-1 fallback 到位置 0 → clone_order[0]=2")


func test_resolve_target_falls_back_to_zero_when_out_of_range() -> void:
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 1, [1, 0, 2])
	battle.selected_target[0] = 99
	var target: int = battle._resolve_target(0, 1)
	assert_eq(target, 1, "越界 fallback 到位置 0 → clone_order[0]=1 (本体)")


# ============================================================================
# _get_valid_targets — 决定百兽随机选择的有效目标池
# ============================================================================

func test_get_valid_targets_no_clones_returns_only_one() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._get_valid_targets(0), [1], "无分身时仅本体可打")


func test_get_valid_targets_with_clones_returns_clone_order() -> void:
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 0, [1, 0, 2])
	assert_eq(battle._get_valid_targets(0), [1, 0, 2], "返回 clone_order 拷贝")


func test_get_valid_targets_returns_duplicate_not_reference() -> void:
	# 修改返回值不应影响 BattleCore 内部 clone_order。
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 0, [1, 0, 2])
	var copy: Array = battle._get_valid_targets(0)
	copy.clear()
	assert_eq(battle.clone_order[0], [1, 0, 2], "原 clone_order 未被外部 clear 影响")


# ============================================================================
# _route_damage — 把已计算的伤害路由到本体或分身
# ============================================================================

func test_route_damage_no_clones_returns_full_dmg() -> void:
	# Arrange
	var battle := BattleFactory.plain_battle()
	var events: Array = []
	# Act
	var result: int = battle._route_damage(0, 1, 2, events, "测试")
	# Assert
	assert_eq(result, 2, "无分身 → 全伤害命中本体 (return dmg)")


func test_route_damage_hits_clone_returns_zero_and_destroys_clone() -> void:
	# Arrange: P2 有分身, P1 选位置 1（命中分身 slot 0）
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 1, [1, 0, 2])  # 位置 1 → clone_order[1]=0 (分身 0)
	battle.selected_target[0] = 1
	var events: Array = []
	# Act
	var result: int = battle._route_damage(0, 1, 2, events, "测试")
	# Assert
	assert_eq(result, 0, "击中分身时返回 0 (本体不受伤)")
	assert_eq(battle.clone_hp[1][0], 0, "分身 0 HP 归零")
	assert_eq(battle.clone_count[1], 1, "分身计数 -1")


func test_route_damage_hits_hero_returns_full_dmg_when_clones_exist() -> void:
	# Arrange: P2 有分身, P1 选位置 0（命中本体）
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 1, [1, 0, 2])  # 位置 0 → clone_order[0]=1 (本体)
	battle.selected_target[0] = 0
	var events: Array = []
	# Act
	var result: int = battle._route_damage(0, 1, 2, events, "测试")
	# Assert
	assert_eq(result, 2, "命中本体时返回完整伤害")
	assert_eq(battle.clone_count[1], 2, "分身计数不变")


func test_route_damage_zero_dmg_short_circuits() -> void:
	# Arrange: 0 伤害不应做任何状态修改
	var battle := BattleFactory.plain_battle()
	_inject_clones(battle, 1, [1, 0, 2])
	battle.selected_target[0] = 1
	var clones_before: int = battle.clone_count[1]
	var events: Array = []
	# Act
	var result: int = battle._route_damage(0, 1, 0, events, "测试")
	# Assert
	assert_eq(result, 0)
	assert_eq(battle.clone_count[1], clones_before, "0 伤害不消耗分身")


# ============================================================================
# 端到端：通过 resolve() 验证 routing 在真实战斗中生效
# ============================================================================

func test_attack_via_resolve_destroys_targeted_clone() -> void:
	# Arrange: P2 有分身，P1 充能攻击位置 1
	var battle := BattleFactory.plain_battle()
	BattleFactory.set_energy(battle, 0, 3)
	_inject_clones(battle, 1, [1, 0, 2])  # 位置 1 → 分身 slot 0
	battle.selected_target[0] = 1
	# Act
	BattleFactory.choose_and_resolve(battle, BattleCore.Action.ATTACK, BattleCore.Action.CHARGE)
	# Assert
	assert_eq(battle.clone_count[1], 1, "分身被攻击摧毁")
	assert_eq(battle.current_hp(1), 10, "本体未受伤")


# ============================================================================
# 私有 helper
# ============================================================================

## 直接注入分身状态，绕过 SHEN_WAI 动作流程。
## clone_order 用显式顺序避免依赖 RNG shuffle。
func _inject_clones(battle: BattleCore, player: int, order: Array) -> void:
	# 计算分身数量 = order 中 1 (本体) 之外的元素个数
	var num_clones: int = 0
	for o in order:
		if o == 0 or o == 2:
			num_clones += 1
	battle.clone_count[player] = num_clones
	# clone_hp 数组大小固定为 2（slot 0, slot 1），未存在的分身 hp=0
	battle.clone_hp[player] = [0, 0]
	for o in order:
		if o == 0:
			battle.clone_hp[player][0] = 1
		elif o == 2:
			battle.clone_hp[player][1] = 1
	battle.clone_order[player] = order.duplicate()
