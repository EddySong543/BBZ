extends GutTest

## ============================================================================
## 测试目的
##   锁定 `BattleCore.setup(p1_heroes, p2_heroes)` 的状态初始化与重置语义：
##   - 哪些字段被 setup() 显式重置？
##   - 哪些字段被遗漏？
##   - 愚者 (h13) HP 8-14 随机化是否生效？
##   - 多次 setup 同一实例时旧状态是否被清干净？
##
## 覆盖范围
##   - 单次 setup 后的所有公开字段初值
##   - 多次 setup 重置语义（重点关注**未被重置**的字段 → B-005）
##   - 愚者 (h13) HP 随机化范围 [8, 14]
##   - hero_hp 与 hero_max_hp 按 hero.max_hp 初始化
##
## 不覆盖
##   - resolve() 后的状态变化 → 其他测试文件
##   - 英雄技能本身的初始化（在英雄集成测试中）
##
## 当前锁定的行为（疑似 bug）
##   - B-006：setup() 未重置 `_baishou_spent` / `_jiaotu_immune` / `_shetui_active`
##     三个字段。在 BattleCore 实例 new 后立即 setup 这三个为初值，
##     但若复用同一 BattleCore 多次 setup，会带上次 resolve() 末态。
##     当前 UI 每场新建 BattleCore，所以无可见影响。
##     详见 BEHAVIOR_NOTES B-006。
## ============================================================================


# ============================================================================
# 单次 setup 后的字段初值
# ============================================================================

func test_setup_initializes_hero_hp_from_max_hp() -> void:
	# Arrange
	var battle := BattleFactory.plain_battle(10, 12)
	# Assert
	assert_eq(battle.hero_hp[0], [10, 10, 10], "P1 三个英雄 HP=max_hp")
	assert_eq(battle.hero_hp[1], [12, 12, 12], "P2 三个英雄 HP=max_hp")
	assert_eq(battle.hero_max_hp[0], [10, 10, 10])
	assert_eq(battle.hero_max_hp[1], [12, 12, 12])


func test_setup_initializes_resource_fields_to_zero() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle.energy, [0, 0])
	assert_eq(battle.shield, [[0, 0, 0], [0, 0, 0]])
	assert_eq(battle.active_hero_index, [0, 0], "Active 默认指向 slot 0")


func test_setup_initializes_turn_and_game_state() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle.turn_number, 0)
	assert_false(battle.game_over)
	assert_eq(battle.winner, -1)
	assert_eq(battle.selected_action, [-1, -1])
	assert_eq(battle.switch_used, [false, false])
	assert_eq(battle.pending_death_switch, [-1, -1])


func test_setup_initializes_clone_state_empty() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle.clone_count, [0, 0])
	assert_eq(battle.clone_hp, [[], []])
	assert_eq(battle.clone_order, [[], []])
	assert_eq(battle.selected_target, [-1, -1])


func test_setup_initializes_hero_skill_flags_to_default() -> void:
	var battle := BattleFactory.plain_battle()
	assert_eq(battle._wuma_pending_shield, [false, false])
	assert_eq(battle._shenwai_used, [false, false])
	assert_eq(battle._fallen_teammates, [0, 0])
	assert_eq(battle._jiaotu_free_switch, [false, false])
	assert_eq(battle._jiaotu_used_count, [0, 0])
	assert_eq(battle._shetui_empowered, [false, false])
	assert_eq(battle._shetui_owner, [-1, -1])
	assert_eq(battle._caijin_cooldown, [false, false])
	assert_eq(battle._caijin_buff, [false, false])
	assert_eq(battle._raw_dmg_to, [0, 0])


# ============================================================================
# 多次 setup 重置语义
# ============================================================================

func test_setup_resets_explicit_fields_on_reuse() -> void:
	# Arrange: 第一次 setup → 污染部分字段 → 第二次 setup
	var battle := BattleFactory.plain_battle()
	battle.energy = [15, 15]
	battle.turn_number = 99
	battle.game_over = true
	battle.winner = 1
	battle._jiaotu_used_count = [3, 3]
	battle._caijin_cooldown = [true, true]
	battle._fallen_teammates = [2, 1]
	# Act: 第二次 setup（用同一 BattleCore 实例）
	var p1: Array[HeroData] = []
	var p2: Array[HeroData] = []
	for i in range(3):
		var h1 := HeroData.new()
		h1.hero_id = "test_p1_%d" % i
		h1.max_hp = 10
		h1.passive_id = ""
		p1.append(h1)
		var h2 := HeroData.new()
		h2.hero_id = "test_p2_%d" % i
		h2.max_hp = 10
		h2.passive_id = ""
		p2.append(h2)
	battle.setup(p1, p2)
	# Assert: 显式重置的字段已清空
	assert_eq(battle.energy, [0, 0], "energy 被重置")
	assert_eq(battle.turn_number, 0, "turn_number 被重置")
	assert_false(battle.game_over, "game_over 被重置")
	assert_eq(battle.winner, -1, "winner 被重置")
	assert_eq(battle._jiaotu_used_count, [0, 0])
	assert_eq(battle._caijin_cooldown, [false, false])
	assert_eq(battle._fallen_teammates, [0, 0])


func test_setup_does_not_reset_baishou_jiaotu_shetui_transient_flags() -> void:
	# CURRENT-BEHAVIOR (B-006):
	#   setup() 未显式重置 _baishou_spent / _jiaotu_immune / _shetui_active。
	#   这三个是 resolve() 内的"单回合 transient 标志"，每次 resolve() 开头
	#   会被重置为初值，所以游戏中无可见影响。但若调用方在两次 setup
	#   之间不调 resolve()，旧值会泄漏。详见 BEHAVIOR_NOTES B-006。
	# Arrange: 第一次 setup → 污染 transient 字段 → 第二次 setup
	var battle := BattleFactory.plain_battle()
	battle._baishou_spent = [3, 5]
	battle._jiaotu_immune = [true, true]
	battle._shetui_active = [true, false]
	# Act
	var p1: Array[HeroData] = []
	var p2: Array[HeroData] = []
	for i in range(3):
		var h := HeroData.new()
		h.hero_id = "test_%d" % i
		h.max_hp = 10
		h.passive_id = ""
		p1.append(h)
		p2.append(h)
	battle.setup(p1, p2)
	# Assert: 这三个字段**未被重置**（保留污染值）
	# LOCKED-FOR-REFACTOR (B-006): 若 setup 加入这三个字段的重置，下面三行应改为初值。
	assert_eq(battle._baishou_spent, [3, 5], "_baishou_spent 未被 setup 重置")
	assert_eq(battle._jiaotu_immune, [true, true], "_jiaotu_immune 未被 setup 重置")
	assert_eq(battle._shetui_active, [true, false], "_shetui_active 未被 setup 重置")


# ============================================================================
# 愚者 (h13) HP 随机化
# ============================================================================

func test_yuzhe_hp_is_randomized_within_range() -> void:
	# Arrange + Act: 多次 setup 含 h13 的阵容，收集 HP 值
	var pool: Array[HeroData] = HeroData.create_pool_heroes()
	var yuzhe: HeroData = _find_hero(pool, "h13")
	var observed: Array[int] = []
	for _i in range(20):
		var battle := BattleCore.new()
		var p1: Array[HeroData] = [yuzhe, yuzhe, yuzhe]  # 共享同一资源，setup 内会改 hero_hp 数组
		var p2: Array[HeroData] = [_make_plain("test_p2", 10)]
		# 注意：plain_battle 默认 3 英雄；这里 P2 只有 1 英雄不影响 setup 流程
		battle.setup(p1, p2)
		observed.append(battle.hero_hp[0][0])
	# Assert: 全部观察值在 [8, 14] 范围内
	for hp in observed:
		assert_between(hp, 8, 14, "h13 HP 应在 [8, 14] 范围内，观察到: %d" % hp)


func test_yuzhe_hp_equals_max_hp_after_setup() -> void:
	# 愚者 HP 随机化后，hero_hp == hero_max_hp（满血开局）。
	var pool: Array[HeroData] = HeroData.create_pool_heroes()
	var yuzhe: HeroData = _find_hero(pool, "h13")
	for _i in range(10):
		var battle := BattleCore.new()
		battle.setup([yuzhe], [_make_plain("test_p2", 10)])
		assert_eq(battle.hero_hp[0][0], battle.hero_max_hp[0][0],
			"h13 setup 后 HP 与 max HP 相同")


func test_non_yuzhe_hp_not_randomized() -> void:
	# Plain hero HP 始终等于 max_hp，无随机。
	for _i in range(5):
		var battle := BattleFactory.plain_battle(10, 10)
		assert_eq(battle.hero_hp[0], [10, 10, 10])
		assert_eq(battle.hero_hp[1], [10, 10, 10])


# ============================================================================
# 私有 helper
# ============================================================================

func _find_hero(pool: Array[HeroData], hero_id: String) -> HeroData:
	for h in pool:
		if h.hero_id == hero_id:
			return h
	push_error("Hero ID not found: " + hero_id)
	return null


func _make_plain(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.max_hp = hp
	h.passive_id = ""
	return h


## GUT 内置 assert_between 在某些版本下名字不同；提供本地实现兜底。
func assert_between(actual: int, lo: int, hi: int, msg: String = "") -> void:
	assert_true(actual >= lo and actual <= hi,
		"%s (actual=%d, range=[%d, %d])" % [msg, actual, lo, hi])
