extends GutTest

const GridViewZoomControllerScript := preload(
		"res://src/expedition/grid_view_zoom_controller.gd")
const VIEW_SIZE := Vector2(1920.0, 1080.0)
const CELL_SIZE: float = 120.0


func test_zoom_uses_five_complete_cell_presets_with_small_shape_drift() -> void:
	var zoom = GridViewZoomControllerScript.new()
	zoom.configure(VIEW_SIZE, CELL_SIZE)
	var contract: Dictionary = zoom.get_contract()
	assert_eq(contract["grid_presets"], [
		Vector2i(31, 17), Vector2i(27, 15), Vector2i(23, 13),
		Vector2i(19, 11), Vector2i(15, 9),
	])
	assert_eq(Vector2i(contract["current_grid"]), Vector2i(23, 13),
			"进入主界面或PVE时必须默认位于五档正中间")
	assert_eq(Vector2i(contract["default_grid"]), Vector2i(23, 13))
	assert_eq(Vector2i(contract["closest_grid"]), Vector2i(15, 9))
	assert_almost_eq(float(contract["transition_duration"]), 0.15, 0.001)
	assert_almost_eq(float(contract["primary_phase_duration"]), 0.09, 0.001)
	assert_almost_eq(float(contract["primary_phase_distance"]), 0.92, 0.001)
	assert_almost_eq(float(contract["input_burst_window"]), 0.055, 0.001)
	assert_false(bool(contract["instant_switch"]))

	var previous_cell_aspect: float = -1.0
	for grid: Vector2i in contract["grid_presets"]:
		assert_eq(grid.x % 2, 1)
		assert_eq(grid.y % 2, 1)
		var scale: Vector2 = VIEW_SIZE / (Vector2(grid) * CELL_SIZE)
		var visible_grid: Vector2 = VIEW_SIZE / (Vector2.ONE * CELL_SIZE * scale)
		assert_lte(visible_grid.distance_to(Vector2(grid)), 0.001,
				"每一档静止时四边都必须严格结束在完整格边界")
		var cell_aspect: float = scale.x / scale.y
		assert_lte(absf(cell_aspect - 1.0), 0.067,
				"每档格子横纵比例偏差不得达到明显拉伸")
		if previous_cell_aspect > 0.0:
			assert_lte(absf(cell_aspect - previous_cell_aspect), 0.038,
					"相邻档位不得突然改变横纵比例")
		previous_cell_aspect = cell_aspect


func test_zoom_animates_quickly_and_merges_only_same_direction_bursts() -> void:
	var zoom = GridViewZoomControllerScript.new()
	zoom.configure(VIEW_SIZE, CELL_SIZE)
	var middle_scale: Vector2 = zoom.current_scale
	assert_true(zoom.request_zoom(true))
	assert_false(zoom.request_zoom(true), "55ms内同向滚轮事件必须合并")
	assert_eq(Vector2i(zoom.current_grid), Vector2i(19, 11))
	assert_true(bool(zoom.get_contract()["transition_active"]))
	assert_lte(zoom.current_scale.distance_to(middle_scale), 0.0001,
			"滚轮事件本身不能瞬间跳变画面")

	assert_true(zoom.advance(0.09))
	var expected_primary_scale: Vector2 = middle_scale.lerp(zoom.target_scale, 0.92)
	assert_lte(zoom.current_scale.distance_to(expected_primary_scale), 0.0001,
			"前90ms必须完成92%的主推进，随后只做无回弹收束")
	assert_almost_eq(float(zoom.get_contract()["transition_progress"]), 0.6, 0.001)
	assert_eq(int(zoom.get_contract()["zoom_direction"]), 1)
	assert_gt(zoom.current_scale.x, middle_scale.x)
	assert_lt(zoom.current_scale.x, zoom.target_scale.x)
	assert_true(zoom.request_zoom(false), "反向滚轮必须立即打断并响应")
	assert_eq(Vector2i(zoom.current_grid), Vector2i(23, 13))
	assert_true(bool(zoom.get_contract()["transition_active"]))
	zoom.advance(0.15)
	assert_lte(zoom.current_scale.distance_to(middle_scale), 0.0001)
	assert_false(bool(zoom.get_contract()["transition_active"]))

	assert_true(zoom.request_zoom(true))
	zoom.advance(0.15)
	assert_lte(zoom.current_scale.distance_to(
			VIEW_SIZE / (Vector2(19, 11) * CELL_SIZE)), 0.0001)
	assert_false(bool(zoom.get_contract()["transition_active"]))
