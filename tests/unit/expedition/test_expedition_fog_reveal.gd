extends GutTest

const FogReveal := preload("res://src/expedition/expedition_fog_reveal.gd")

const BOUNDS := Rect2i(Vector2i.ZERO, Vector2i(20, 20))


func test_reveal_stamp_is_a_small_five_by_five_stepped_footprint() -> void:
	var cleared: Dictionary = FogReveal.compute_footprint(Vector2i(10, 10), BOUNDS)
	assert_eq(cleared.size(), 21)
	for delta: Vector2i in [
			Vector2i.ZERO, Vector2i(2, 0), Vector2i(-2, 0),
			Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 2), Vector2i(-1, -2),
	]:
		assert_true(cleared.has(Vector2i(10, 10) + delta), "清雾印章应包含 %s" % delta)
	for delta: Vector2i in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(2, 2), Vector2i(-2, -2)]:
		assert_false(cleared.has(Vector2i(10, 10) + delta), "清雾印章不应包含 %s" % delta)


func test_consecutive_stamps_form_a_permanent_exploration_trail() -> void:
	var cleared: Dictionary = FogReveal.compute_footprint(Vector2i(10, 10), BOUNDS)
	var first_snapshot: Dictionary = cleared.duplicate()
	FogReveal.add_footprint(cleared, Vector2i(10, 9), BOUNDS)
	assert_gt(cleared.size(), first_snapshot.size())
	for cell: Vector2i in first_snapshot:
		assert_true(cleared.has(cell), "角色离开后，走过的地图不能重新被迷雾覆盖")


func test_reveal_stamp_ignores_line_of_sight_blockers() -> void:
	var cleared: Dictionary = FogReveal.compute_footprint(Vector2i(10, 10), BOUNDS)
	assert_true(cleared.has(Vector2i(12, 10)),
			"清雾层记录探索范围，不应退化成会被中间墙格截断的随身视野")


func test_reveal_stamp_is_clamped_to_map_bounds() -> void:
	var cleared: Dictionary = FogReveal.compute_footprint(Vector2i.ZERO, BOUNDS)
	for cell: Vector2i in cleared:
		assert_true(BOUNDS.has_point(cell))
	assert_true(cleared.has(Vector2i.ZERO))
	assert_false(cleared.has(Vector2i(-1, 0)))
