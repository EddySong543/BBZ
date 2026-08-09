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


func test_map_setup_uses_fixed_qingfeng_dimensions_and_one_or_two_exits() -> void:
	for seed_value: int in [1, 777, 31337]:
		var map: MapState = _make(seed_value)
		assert_eq(map.grid.size(), Layout.HEIGHT)
		assert_eq((map.grid[0] as Array).size(), Layout.WIDTH)
		assert_between(map.ext_pos.size(), 1, 2)
		assert_eq(map.team.size(), 1, "开局仍为1名英雄")


func test_map_terrain_is_fixed_across_seeds() -> void:
	var first: MapState = _make(1)
	var second: MapState = _make(31337)
	assert_eq(_wall_signature(first), _wall_signature(second))


func test_map_same_seed_reproduces_dynamic_content() -> void:
	var first: MapState = _make(777)
	var second: MapState = _make(777)
	assert_eq(first.monsters.keys(), second.monsters.keys())
	assert_eq(first.chests.keys(), second.chests.keys())
	assert_eq(first.ext_pos, second.ext_pos)


func test_map_exits_use_only_fixed_candidates_and_are_always_open() -> void:
	var saw_one: bool = false
	var saw_two: bool = false
	for seed_value: int in range(40):
		var map: MapState = _make(seed_value)
		saw_one = saw_one or map.ext_pos.size() == 1
		saw_two = saw_two or map.ext_pos.size() == 2
		for tile: int in map.ext_pos:
			var exit_cell: Vector2i = map.ext_pos[tile]
			assert_has(Layout.EXIT_CANDIDATES, exit_cell)
			assert_true(map.ext_open(tile), "启用的撤离点从开局起始终开放")
	assert_true(saw_one, "种子池中应能生成单撤离点局")
	assert_true(saw_two, "种子池中应能生成双撤离点局")


func test_map_exits_start_hidden_and_are_reachable() -> void:
	for seed_value: int in [3, 9, 27]:
		var map: MapState = _make(seed_value)
		var reachable: Dictionary = _reachable_from(map.start_pos, map.grid)
		for tile: int in map.ext_pos:
			var exit_cell: Vector2i = map.ext_pos[tile]
			assert_false(map.revealed.has(exit_cell), "进图时不主动标明撤离点")
			assert_true(reachable.has(exit_cell), "启用的撤离点必须可达")


func test_map_content_uses_only_authored_anchor_pools() -> void:
	for seed_value: int in [5, 17, 29]:
		var map: MapState = _make(seed_value)
		assert_true(map.events.is_empty(), "第一版灰盒暂不生成事件")
		assert_true(map.monsters.has(Layout.REPAIR_GUARD_ANCHOR), "检修院守卫位置固定")
		assert_true(map.monsters.has(Layout.BOSS_ANCHOR), "收割场Boss位置固定")
		for cell: Vector2i in map.monsters:
			assert_has(Layout.MONSTER_ANCHORS, cell)
		for cell: Vector2i in map.chests:
			assert_has(Layout.SEARCH_ANCHORS, cell)


func test_map_fog_grows_after_movement() -> void:
	var map: MapState = _make(777)
	var before: int = map.revealed.size()
	for i: int in 8:
		var moved: bool = false
		for dir: Vector2i in DIRS:
			var result: Dictionary = map.try_move(dir)
			if bool(result["moved"]):
				moved = true
				break
		if not moved:
			break
	assert_gt(map.revealed.size(), before)


func test_map_extract_settles_run() -> void:
	var map: MapState = _make(3)
	map.extract()
	assert_eq(String(map.result["outcome"]), "extract")


func test_map_recruit_caps_at_three() -> void:
	var map: MapState = _make(4)
	assert_ne(map.recruit(), "")
	assert_ne(map.recruit(), "")
	assert_eq(map.recruit(), "")
	assert_eq(map.team.size(), 3)


func _wall_signature(map: MapState) -> String:
	var rows: Array[String] = []
	for y: int in MapState.HEIGHT:
		var row: String = ""
		for x: int in MapState.WIDTH:
			row += "#" if map.grid[y][x] == MapState.Tile.WALL else "."
		rows.append(row)
	return "\n".join(rows)


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
