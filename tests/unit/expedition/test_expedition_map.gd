extends GutTest

## 晴风稻田地图状态行为测试。
## 只锁定当前已确认的固定地图、随机局势、迷雾发现和常开撤离；旧随机墙/三撤离窗/饥饿/危险度不再是契约。

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Layout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _make(p_seed: int) -> MapState:
	var map: MapState = MapState.new()
	map.setup(p_seed)
	return map


func test_map_setup_uses_fixed_qingfeng_dimensions_without_placeholder_objects() -> void:
	for seed_value: int in [1, 777, 31337]:
		var map: MapState = _make(seed_value)
		assert_eq(map.grid.size(), Layout.HEIGHT)
		assert_eq((map.grid[0] as Array).size(), Layout.WIDTH)
		assert_eq(map.ext_pos.size(), 0)
		assert_true(map.chests.is_empty())
		assert_true(map.monsters.is_empty())
		assert_true(map.events.is_empty())
		assert_eq(map.team.size(), 1, "开局仍为1名英雄")
		assert_true((map.team[0] as Dictionary).has("hero_id"), "队伍条目保留稳定英雄身份字段")


func test_map_terrain_is_fixed_across_seeds() -> void:
	var first: MapState = _make(1)
	var second: MapState = _make(31337)
	assert_eq(_wall_signature(first), _wall_signature(second))


func test_map_same_seed_reproduces_dynamic_content() -> void:
	var first: MapState = _make(777)
	var second: MapState = _make(777)
	assert_true(first.monsters.is_empty(), "晴风稻田暂不生成旧版敌人")
	assert_true(second.monsters.is_empty(), "重复生成也不得带回旧版敌人")
	assert_eq(first.chests.keys(), second.chests.keys())
	assert_eq(first.ext_pos, second.ext_pos)


func test_map_currently_spawns_ground_only_but_keeps_future_anchor_pools() -> void:
	for seed_value: int in [5, 17, 29]:
		var map: MapState = _make(seed_value)
		assert_true(map.events.is_empty(), "第一版灰盒暂不生成事件")
		assert_true(map.monsters.is_empty(), "正式敌人完成前，普通敌人、守卫与Boss均不生成")
		assert_false(_grid_contains(map.grid, MapState.Tile.MONSTER), "地图中不得残留旧版敌人格")
		assert_true(map.chests.is_empty(), "当前纯地表版本不得生成不可见搜索点")
		assert_true(map.ext_pos.is_empty(), "撤离点视觉重做前不得生成不可见撤离格")
	assert_has(Layout.MONSTER_ANCHORS, Layout.REPAIR_GUARD_ANCHOR, "检修院敌人锚点继续保留")
	assert_has(Layout.MONSTER_ANCHORS, Layout.BOSS_ANCHOR, "收割场敌人锚点继续保留")


func test_map_fog_clearance_stays_on_the_map_after_player_leaves() -> void:
	var map: MapState = _make(777)
	var start: Vector2i = map.player
	var starting_clearance: Dictionary = map.revealed.duplicate()
	assert_true(starting_clearance.has(start))
	map.player = Vector2i(16, 9)
	map._reveal_around(map.player)
	assert_true(map.revealed.has(start), "角色离开后，出生区不能重新被迷雾覆盖")
	assert_true(map.revealed.has(map.player), "玩家落脚区必须被永久清雾")
	assert_gt(map.revealed.size(), starting_clearance.size())
	for cell: Vector2i in starting_clearance:
		assert_true(map.revealed.has(cell))
		assert_true(map.visible.has(cell), "兼容可见集合也必须表达累计清雾区")


func test_map_fog_clearance_is_not_line_of_sight() -> void:
	var map: MapState = _make(777)
	map.player = Vector2i(10, 10)
	map.grid[10][11] = MapState.Tile.WALL
	map._reveal_around(map.player)
	assert_true(map.revealed.has(Vector2i(11, 10)))
	assert_true(map.revealed.has(Vector2i(12, 10)),
			"地图清雾不应被墙截断成随身视野")


func test_remote_map_reveal_is_safe_when_current_map_has_no_containers() -> void:
	var map: MapState = _make(777)
	var found: Vector2i = map.reveal_random_chest()
	assert_eq(found, Vector2i(-1, -1))


func test_map_extract_settles_run() -> void:
	var map: MapState = _make(3)
	map.extract()
	assert_eq(String(map.result["outcome"]), "extract")
	assert_false(map.result.has("ticks"), "旧危险度时钟不得进入结算")
	assert_false(map.result.has("in_band"), "旧撤离时间带不得进入结算")


func test_map_actions_never_apply_generic_hunger_damage() -> void:
	var map: MapState = _make(9)
	map.team[0] = {"hero_id": "h01", "name": "子鼠", "hp": 5.0, "hp_max": 5.0}
	for index: int in 100:
		map.advance_world_action("wait")
	assert_almost_eq(float(map.team[0]["hp"]), 5.0, 0.01)
	assert_false(map.over)
	assert_eq(map.steps, 100)


func test_map_recruit_caps_at_three() -> void:
	var map: MapState = _make(4)
	assert_ne(map.recruit({"hero_id": "h02", "name": "丑牛", "hp": 10.0, "hp_max": 10.0}), "")
	assert_ne(map.recruit({"hero_id": "h03", "name": "寅虎", "hp": 10.0, "hp_max": 10.0}), "")
	assert_eq(map.recruit({"hero_id": "h04", "name": "卯兔", "hp": 10.0, "hp_max": 10.0}), "")
	assert_eq(map.team.size(), 3)
	assert_eq(String(map.team[1]["hero_id"]), "h02")


func _wall_signature(map: MapState) -> String:
	var rows: Array[String] = []
	for y: int in MapState.HEIGHT:
		var row: String = ""
		for x: int in MapState.WIDTH:
			row += "#" if map.grid[y][x] == MapState.Tile.WALL else "."
		rows.append(row)
	return "\n".join(rows)


func _grid_contains(grid: Array, tile: int) -> bool:
	for row: Array in grid:
		if row.has(tile):
			return true
	return false


func _reachable_from(start: Vector2i, grid: Array) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir: Vector2i in DIRS:
			var next: Vector2i = cell + dir
			if next.x < 0 or next.y < 0 or next.x >= MapState.WIDTH or next.y >= MapState.HEIGHT:
				continue
			if grid[next.y][next.x] == MapState.Tile.WALL or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen
