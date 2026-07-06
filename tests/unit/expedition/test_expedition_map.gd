extends GutTest

## 远征地图状态 行为锁定测试（规则源：design/expedition-map.md）。
## 覆盖：生成完整性与同种子复现 / 迷雾 / 时钟计量 / 危险度公式 / 撤离窗口时刻表（无死锁）/
## 遭遇结算不回溯 / 饥饿行军 / 死亡与撤离结算。战斗数值 = 占位模型，只锁结构不锁数值。

const MapState := preload("res://src/expedition/expedition_map_state.gd")

const DIRS: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _make(p_seed: int) -> MapState:
	var m: MapState = MapState.new()
	m.setup(p_seed)
	return m


func test_map_setup_generates_complete_map() -> void:
	# Arrange + Act
	for seed_v: int in [1, 777, 31337]:
		var m: MapState = _make(seed_v)
		# Assert
		assert_eq(m.ext_pos.size(), 3, "种子 %d 撤离点应 3 个" % seed_v)
		assert_gt(m.monsters.size(), 0, "种子 %d 应有怪" % seed_v)
		assert_eq(m.team.size(), 1, "开局 1 英雄")


func test_map_setup_same_seed_same_map() -> void:
	# Arrange + Act
	var a: MapState = _make(777)
	var b: MapState = _make(777)
	# Assert
	assert_eq(a.monsters.keys(), b.monsters.keys())
	assert_eq(a.ext_pos[MapState.Tile.EXT3], b.ext_pos[MapState.Tile.EXT3])


func test_map_fog_starts_revealed_around_start_and_grows() -> void:
	# Arrange
	var m: MapState = _make(777)
	assert_true(m.revealed.has(m.start_pos))
	var before: int = m.revealed.size()
	# Act：随机走（战斗/事件就地清掉保证可走）
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i: int in 60:
		if m.over:
			break
		var res: Dictionary = m.try_move(DIRS[rng.randi_range(0, 3)])
		match String(res["kind"]):
			"monster": m.fight(m.player)
			"wanderer": m.fight_wanderer()
			"chest": m.open_chest(m.player)
			"event":
				m.events.erase(m.player)
				m.grid[m.player.y][m.player.x] = MapState.Tile.FLOOR
	# Assert
	assert_gt(m.revealed.size(), before, "迷雾应随移动扩张")


func test_map_ticks_equals_steps_plus_half_beats() -> void:
	# Arrange
	var m: MapState = _make(777)
	# Act
	m.try_move(Vector2i.RIGHT)
	m.battle_beats = 10.0
	# Assert
	assert_almost_eq(m.ticks(), float(m.steps) + 5.0, 0.001)


func test_map_danger_formula_capped_at_five() -> void:
	# Arrange
	var m: MapState = _make(777)
	# Act + Assert
	assert_eq(m.danger(), 0)
	m.battle_beats = 70.0   # 刻 35 → D1
	assert_eq(m.danger(), 1)
	m.battle_beats = 400.0  # 刻 200 → 封顶 5
	assert_eq(m.danger(), 5)


func test_map_extraction_windows_follow_schedule_no_deadlock() -> void:
	# Arrange
	var m: MapState = _make(31337)
	# Act + Assert：t=0 / t=35 / t=65 / t=100 四个时刻
	assert_true(m.ext_open(MapState.Tile.EXT1))
	assert_false(m.ext_open(MapState.Tile.EXT2))
	assert_true(m.ext_open(MapState.Tile.EXT3))
	m.battle_beats = 70.0
	assert_true(m.ext_open(MapState.Tile.EXT1))
	assert_true(m.ext_open(MapState.Tile.EXT2))
	m.battle_beats = 130.0
	assert_false(m.ext_open(MapState.Tile.EXT1))
	assert_true(m.ext_open(MapState.Tile.EXT2))
	m.battle_beats = 200.0
	assert_false(m.ext_open(MapState.Tile.EXT2))
	assert_true(m.ext_open(MapState.Tile.EXT3), "撤3 永开 = 无死锁保证")


func test_map_encounter_scaling_not_retroactive() -> void:
	# Arrange
	var m: MapState = _make(777)
	var mc: Vector2i = m.monsters.keys()[0]
	# Act：D0 结算 → 拉高时钟 → 重看
	var hp_at_d0: float = float(m.resolve_encounter(mc)["hp"])
	m.battle_beats = 400.0
	var hp_at_d5: float = float(m.resolve_encounter(mc)["hp"])
	# Assert
	assert_almost_eq(hp_at_d5, hp_at_d0, 0.001, "已结算怪不回溯强化")


func test_map_new_encounter_at_d5_gets_scaled() -> void:
	# Arrange
	var m: MapState = _make(777)
	m.battle_beats = 400.0  # D5
	var mc: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in m.monsters:
		if not bool(m.monsters[c]["resolved"]):
			mc = c
			break
	var base_hp: float = float(m.monsters[mc]["hp_max"])
	# Act
	var resolved: Dictionary = m.resolve_encounter(mc)
	# Assert：吃 ×1.75 强化，或被 T1→T2 替换（同样是强化路径）
	var scaled_ok: bool = float(resolved["hp"]) >= ceilf(base_hp * 1.75) - 0.001
	assert_true(scaled_ok or int(resolved["tier"]) == 2)


func test_map_hunger_march_damages_team() -> void:
	# Arrange
	var m: MapState = _make(1)
	m.supplies = 0
	var hp_before: float = float(m.team[0]["hp"])
	# Act：走一步（找一个能走的方向）
	for d: Vector2i in DIRS:
		if bool(m.try_move(d)["moved"]):
			break
	# Assert
	assert_almost_eq(float(m.team[0]["hp"]), hp_before - 0.5, 0.001)


func test_map_starve_to_death_settles_as_death() -> void:
	# Arrange
	var m: MapState = _make(2)
	m.supplies = 0
	m.team[0]["hp"] = 0.5
	# Act：走到死
	while not m.over:
		var moved: bool = false
		for d: Vector2i in DIRS:
			if bool(m.try_move(d)["moved"]):
				moved = true
				break
		if not moved:
			break
	# Assert
	assert_true(m.over)
	assert_eq(String(m.result["outcome"]), "death")


func test_map_extract_settles_with_clock_report() -> void:
	# Arrange
	var m: MapState = _make(3)
	m.battle_beats = 140.0  # 刻 70 → 落带
	# Act
	m.extract()
	# Assert
	assert_eq(String(m.result["outcome"]), "extract")
	assert_true(bool(m.result["in_band"]))


func test_map_recruit_caps_at_three() -> void:
	# Arrange
	var m: MapState = _make(4)
	# Act + Assert
	assert_ne(m.recruit(), "")
	assert_ne(m.recruit(), "")
	assert_eq(m.recruit(), "", "满 3 人后招募返回空")
	assert_eq(m.team.size(), 3)
