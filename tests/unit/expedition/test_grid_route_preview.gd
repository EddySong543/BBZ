extends GutTest

const GridRoutePreviewScript := preload(
		"res://src/expedition/grid_route_preview.gd")


func test_footprint_count_scales_with_route_length_and_has_no_fixed_cap() -> void:
	var short_route: Array[Vector2i] = _straight_cells(4)
	var long_route: Array[Vector2i] = _straight_cells(24)
	var short_footprints: Array[Dictionary] = \
			GridRoutePreviewScript.build_stream_footprints(short_route, 120.0, 0.0)
	var long_footprints: Array[Dictionary] = \
			GridRoutePreviewScript.build_stream_footprints(long_route, 120.0, 0.0)

	assert_gt(short_footprints.size(), 0)
	assert_gt(long_footprints.size(), short_footprints.size(),
			"更长路线必须生成更多脚印，不能继续固定为七枚")
	assert_eq(short_footprints.size() % 2, 0)
	assert_eq(long_footprints.size() % 2, 0,
			"偶数数量保证循环首尾仍维持左右脚交替")


func test_footprints_cover_the_full_route_at_constant_maximum_spacing() -> void:
	var cells: Array[Vector2i] = _straight_cells(12)
	var total_length: float = 120.0 * float(cells.size() - 1)
	var maximum_spacing: float = 120.0 \
			* GridRoutePreviewScript.FOOTPRINT_SPACING_CELLS
	for anim_time: float in [0.0, 0.37, 1.91, 4.25]:
		var footprints: Array[Dictionary] = \
				GridRoutePreviewScript.build_stream_footprints(
						cells, 120.0, anim_time)
		_assert_full_route_coverage(footprints, total_length, maximum_spacing)


func test_entire_route_stream_moves_forward_at_the_reduced_speed() -> void:
	var cells: Array[Vector2i] = _straight_cells(12)
	var initial: Array[Dictionary] = GridRoutePreviewScript.build_stream_footprints(
			cells, 120.0, 0.0)
	var advanced: Array[Dictionary] = GridRoutePreviewScript.build_stream_footprints(
			cells, 120.0, 0.5)
	var expected_advance: float = 120.0 \
			* GridRoutePreviewScript.STREAM_SPEED_CELLS_PER_SECOND * 0.5

	assert_lt(GridRoutePreviewScript.STREAM_SPEED_CELLS_PER_SECOND, 0.55,
			"脚印整体速度必须比上一版更慢")
	assert_eq(initial.size(), advanced.size())
	for index: int in initial.size():
		assert_eq(int(initial[index]["stream_index"]), index)
		assert_eq(int(advanced[index]["stream_index"]), index)
		assert_almost_eq(float(advanced[index]["path_distance"])
				- float(initial[index]["path_distance"]),
				expected_advance, 0.01,
				"所有脚印必须以同一速度向目标平移")
		assert_almost_eq(float(initial[index]["base_opacity"]),
				float(advanced[index]["base_opacity"]), 0.001,
				"脚印不得重新使用逐个闪烁表达方向")


func test_restored_footprint_stream_uses_original_geometry_and_gold_palette() -> void:
	assert_almost_eq(GridRoutePreviewScript.FOOTPRINT_SPACING_CELLS,
			0.34, 0.001)
	assert_almost_eq(GridRoutePreviewScript.STREAM_SPEED_CELLS_PER_SECOND,
			0.32, 0.001)
	assert_almost_eq(GridRoutePreviewScript.SOLE_LENGTH_CELLS, 0.20, 0.001)
	assert_almost_eq(GridRoutePreviewScript.SOLE_WIDTH_CELLS, 0.092, 0.001)
	assert_almost_eq(GridRoutePreviewScript.SIDE_OFFSET_CELLS, 0.082, 0.001)
	assert_almost_eq(GridRoutePreviewScript.BASE_OPACITY, 0.72, 0.001)
	assert_eq(GridRoutePreviewScript.TRAIL_COLOR, Color("FFD34E"))


func test_short_route_loop_keeps_the_full_footprint_distribution() -> void:
	var cells: Array[Vector2i] = _straight_cells(2)
	var expected_count: int = GridRoutePreviewScript.build_stream_footprints(
			cells, 120.0, 0.0).size()
	for sample_index: int in 80:
		var anim_time: float = float(sample_index) * 0.1
		var footprints: Array[Dictionary] = \
				GridRoutePreviewScript.build_stream_footprints(
						cells, 120.0, anim_time)
		assert_eq(footprints.size(), expected_count,
				"循环过程中不得出现数量下降或整串消失")


func test_stream_alternates_left_right_at_uniform_route_spacing() -> void:
	var footprints: Array[Dictionary] = GridRoutePreviewScript.build_stream_footprints(
			_straight_cells(12), 120.0, 0.0)
	var actual_spacing: float = float(footprints[0]["actual_spacing"])

	for index: int in footprints.size():
		assert_eq(String(footprints[index]["side"]),
				"left" if index % 2 == 0 else "right")
		if index == 0:
			continue
		assert_almost_eq(float(footprints[index]["path_distance"])
				- float(footprints[index - 1]["path_distance"]),
				actual_spacing, 0.02)
		assert_ne(signf(Vector2(footprints[index - 1]["center"]).y - 60.0),
				signf(Vector2(footprints[index]["center"]).y - 60.0))


func test_compact_turn_curve_contains_intermediate_tangents() -> void:
	var curve: PackedVector2Array = GridRoutePreviewScript.build_route_curve([
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2),
	], 120.0)
	var has_intermediate_tangent := false
	for index: int in curve.size() - 1:
		var tangent: Vector2 = (curve[index + 1] - curve[index]).normalized()
		if absf(tangent.x) > 0.05 and absf(tangent.y) > 0.05:
			has_intermediate_tangent = true
			break

	assert_true(has_intermediate_tangent,
			"转弯必须沿紧凑圆角逐渐旋转，不能瞬间跳转九十度")


func test_each_footprint_uses_the_original_forefoot_and_heel_parts() -> void:
	var parts: Array[PackedVector2Array] = GridRoutePreviewScript.build_sole_parts(
			Vector2(200.0, 180.0), Vector2.RIGHT, 24.0, 11.0)

	assert_eq(parts.size(), 2)
	if parts.size() != 2:
		return
	assert_eq(parts[0].size(), 6)
	assert_eq(parts[1].size(), 4)
	var forefoot_bounds: Rect2 = _polygon_bounds(parts[0])
	var heel_bounds: Rect2 = _polygon_bounds(parts[1])
	assert_gt(forefoot_bounds.size.y, heel_bounds.size.y)
	assert_gt(forefoot_bounds.position.x, heel_bounds.position.x)


func test_style_contract_is_full_route_stream_and_excludes_rejected_families() -> void:
	var contract: Dictionary = GridRoutePreviewScript.get_style_contract()
	var source := FileAccess.get_file_as_string(
			"res://src/expedition/grid_route_preview.gd")

	assert_eq(contract["implementation"],
			"full_route_alternating_footprint_stream")
	assert_true(bool(contract["uses_footprints"]))
	assert_true(bool(contract["alternates_left_right"]))
	assert_true(bool(contract["covers_full_route"]))
	assert_true(bool(contract["count_scales_with_route_length"]))
	assert_true(bool(contract["moves_continuously_forward"]))
	assert_true(bool(contract["uses_distance_sampling"]))
	assert_true(bool(contract["uses_smoothed_turn_tangents"]))
	assert_true(bool(contract["uses_endpoint_fade"]))
	assert_false(bool(contract["uses_fixed_visible_count"]))
	assert_false(bool(contract["uses_footprint_count_cap"]))
	assert_false(bool(contract["uses_loop_gap"]))
	assert_false(bool(contract["fills_every_path_cell_with_pair"]))
	assert_false(bool(contract["lights_individual_footprints"]))
	assert_true(bool(contract["uses_two_part_sole"]))
	assert_false(contract.has("uses_rigid_local_rasterization"))
	assert_false(contract.has("uses_single_piece_sole"))
	assert_false(contract.has("uses_waisted_boot_silhouette"))
	assert_false(contract.has("uses_cohesive_two_part_sole"))
	assert_false(bool(contract["uses_ground_shadow"]))
	assert_false(bool(contract["uses_inner_core"]))
	assert_false(bool(contract["uses_glow"]))
	assert_false(bool(contract["uses_inset_edge_bars"]))
	assert_false(bool(contract["uses_arrows"]))
	assert_false(bool(contract["uses_chevrons"]))
	assert_false(bool(contract["uses_continuous_ribbon"]))
	assert_false(bool(contract["uses_dashes"]))
	assert_false(bool(contract["uses_nodes"]))
	assert_false(bool(contract["uses_external_texture"]))
	assert_false(bool(contract["uses_sprite_sheet"]))
	assert_false(source.contains("MAX_VISIBLE_FOOTPRINTS"))
	assert_false(source.contains("footprint_intensity"))
	assert_false(source.contains("build_edge_bars"))
	assert_false(source.contains("draw_polyline"))


func _assert_full_route_coverage(footprints: Array[Dictionary],
		total_length: float, maximum_spacing: float) -> void:
	var distances: Array[float] = []
	for footprint: Dictionary in footprints:
		distances.append(float(footprint["path_distance"]))
	distances.sort()
	assert_gt(distances.size(), 1)
	for index: int in range(1, distances.size()):
		assert_lte(distances[index] - distances[index - 1],
				maximum_spacing + 0.02,
				"路线中段不得出现超过目标间距的脚印空段")
	var wrapped_gap: float = distances[0] + total_length \
			- distances[distances.size() - 1]
	assert_lte(wrapped_gap, maximum_spacing + 0.02,
			"起点与终点之间也必须维持整条路线覆盖")


func _straight_cells(count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index: int in count:
		cells.append(Vector2i(index, 0))
	return cells


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point: Vector2 in polygon:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)
