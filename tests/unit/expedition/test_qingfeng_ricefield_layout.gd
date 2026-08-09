extends GutTest

const Layout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")

const WALL: int = 1
const FLOOR: int = 0
const START: int = 2
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func test_fixed_layout_has_expected_dimensions_and_start() -> void:
	var grid: Array = Layout.build_grid(WALL, FLOOR, START)
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


func test_both_extraction_candidates_are_walkable_and_reachable() -> void:
	var grid: Array = Layout.build_grid(WALL, FLOOR, START)
	var reachable: Dictionary = _reachable_from(Layout.START, grid)
	assert_eq(Layout.EXIT_CANDIDATES.size(), 2)
	for exit_cell: Vector2i in Layout.EXIT_CANDIDATES:
		assert_ne(grid[exit_cell.y][exit_cell.x], WALL)
		assert_true(reachable.has(exit_cell), "撤离候选点必须能从南部入口抵达：%s" % str(exit_cell))


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
