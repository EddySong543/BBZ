extends GutTest

const GridRoutePreviewScript := preload(
		"res://src/expedition/grid_route_preview.gd")


func test_straight_grid_route_stays_regular_without_hand_drawn_wobble() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
	]
	var curve: PackedVector2Array = GridRoutePreviewScript.build_curve(cells, 120.0)
	assert_eq(curve.size(), cells.size())
	assert_eq(curve[0], Vector2(300.0, 420.0))
	assert_eq(curve[curve.size() - 1], Vector2(660.0, 420.0))
	for point: Vector2 in curve:
		assert_almost_eq(point.y, 420.0, 0.001,
				"直线路段不得再加入交替手绘摆动")


func test_turn_uses_only_a_compact_twelve_pixel_corner() -> void:
	var curve: PackedVector2Array = GridRoutePreviewScript.build_curve([
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2),
	], 120.0, 12.0, 4)
	var corner := Vector2(300.0, 180.0)
	for point: Vector2 in curve:
		if point.x >= 288.0 and point.y <= 192.0:
			assert_lte(absf(point.x - corner.x), 12.001)
			assert_lte(absf(point.y - corner.y), 12.001)
	assert_true(curve.has(Vector2(288.0, 180.0)))
	assert_true(curve.has(Vector2(300.0, 192.0)))


func test_regular_markers_advance_toward_target_with_phase() -> void:
	var curve: PackedVector2Array = GridRoutePreviewScript.build_curve([
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	], 120.0)
	var initial: Array[PackedVector2Array] = GridRoutePreviewScript.build_markers(
			curve, 24.0, 0.0, 10.0)
	var advanced: Array[PackedVector2Array] = GridRoutePreviewScript.build_markers(
			curve, 24.0, 8.0, 10.0)
	assert_gt(initial.size(), 4)
	assert_eq(initial.size(), advanced.size())
	var initial_center: Vector2 = (initial[0][0] + initial[0][1]) * 0.5
	var advanced_center: Vector2 = (advanced[0][0] + advanced[0][1]) * 0.5
	assert_almost_eq(advanced_center.x - initial_center.x, 8.0, 0.001,
			"相位增加必须让整列标记沿路径朝目标推进")
