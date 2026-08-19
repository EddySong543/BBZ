extends GutTest

const Layout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")

const WALL: int = 1
const FLOOR: int = 0
const START: int = 2
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func test_fixed_layout_has_expected_dimensions_and_start() -> void:
	var grid: Array = Layout.build_grid(WALL, FLOOR, START)
	assert_eq(Layout.WIDTH, 32)
	assert_eq(Layout.HEIGHT, 18)
	assert_eq(Layout.START, Vector2i(16, 17))
	assert_eq(grid.size(), Layout.HEIGHT)
	for row: Array in grid:
		assert_eq(row.size(), Layout.WIDTH)
	assert_eq(grid[Layout.START.y][Layout.START.x], START)
	assert_eq(Layout.GROUND_ROWS.size(), Layout.HEIGHT)
	for row_text: String in Layout.GROUND_ROWS:
		assert_eq(row_text.length(), Layout.WIDTH)
		for x: int in Layout.WIDTH:
			assert_true(row_text[x] in ["g", "r", "d"], "Ground rows may only contain g/r/d")


func test_ground_rows_cover_every_supported_surface() -> void:
	var seen: Dictionary = {}
	for y: int in Layout.HEIGHT:
		for x: int in Layout.WIDTH:
			seen[Layout.ground_terrain_at(Vector2i(x, y))] = true
	for terrain: int in [Layout.GroundTerrain.GRASS, Layout.GroundTerrain.RICE, Layout.GroundTerrain.DIRT]:
		assert_true(seen.has(terrain), "晴风稻田视觉布局必须使用正式地形：%s" % terrain)


func test_dirt_tiles_form_authored_field_roads_instead_of_scattered_patches() -> void:
	for x: int in range(4, 28):
		for y: int in [5, 13]:
			assert_eq(Layout.ground_terrain_at(Vector2i(x, y)), Layout.GroundTerrain.DIRT,
					"短横路必须连续：y=%d" % y)
	for x: int in range(2, 30):
		assert_eq(Layout.ground_terrain_at(Vector2i(x, 9)), Layout.GroundTerrain.DIRT,
				"中部横路必须连续")
	for y: int in range(1, Layout.HEIGHT):
		for x: int in [15, 16]:
			assert_eq(Layout.ground_terrain_at(Vector2i(x, y)), Layout.GroundTerrain.DIRT,
					"两格宽南北主路必须接到入口：%s" % Vector2i(x, y))


func test_current_map_is_one_fully_walkable_ground_grid() -> void:
	var grid: Array = Layout.build_grid(WALL, FLOOR, START)
	var reachable: Dictionary = _reachable_from(Layout.START, grid)
	assert_false(Layout.CURRENT_DYNAMIC_CONTENT_ENABLED)
	assert_eq(reachable.size(), Layout.WIDTH * Layout.HEIGHT)
	for row: Array in grid:
		assert_false(row.has(WALL), "当前版本不得残留墙或不可见障碍")


func _reachable_from(start: Vector2i, grid: Array) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir: Vector2i in DIRS:
			var next: Vector2i = cell + dir
			if next.x < 0 or next.y < 0 or next.x >= Layout.WIDTH or next.y >= Layout.HEIGHT:
				continue
			if grid[next.y][next.x] == WALL or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen
