extends SceneTree

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")
const LOGICAL_SIZE := Vector2i(320, 180)
const RGB_JUMP_THRESHOLD := 0.05

var _lake_material: ShaderMaterial
var _reflection_material: ShaderMaterial
var _platform_material: ShaderMaterial
var _contact_material: ShaderMaterial
var _topology_image: Image
var _stage: BattleStage


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_stage = SCENE8.instantiate() as BattleStage
	root.add_child(_stage)
	await process_frame
	var topology := _stage.get_node("LakeTopology")
	_topology_image = topology.call("get_topology_image") as Image
	_lake_material = (
			_stage.get_node("MirrorLake") as ColorRect).material as ShaderMaterial
	_reflection_material = (
			_stage.get_node("AuroraReflection") as ColorRect).material as ShaderMaterial
	_platform_material = (
			_stage.get_node("BattlePlatform") as TextureRect).material as ShaderMaterial
	_contact_material = (
			_stage.get_node("PlatformWaterContact") as ColorRect
			).material as ShaderMaterial

	var palette_metrics := _probe_palette()
	var glacier_contact_metrics := _probe_glacier_contact()
	var shore_ice_metrics := _probe_far_shore_ice()
	var near_floe_metrics := _probe_near_floes()
	var platform_contact_metrics := _probe_platform_contact()
	var wave_metrics := _probe_wave_motion()
	var reflection_metrics := _probe_reflection_geometry()
	var diagonal_glint_metrics := _probe_diagonal_glints()
	var passed := bool(palette_metrics["passed"]) \
			and bool(glacier_contact_metrics["passed"]) \
			and bool(shore_ice_metrics["passed"]) \
			and bool(near_floe_metrics["passed"]) \
			and bool(platform_contact_metrics["passed"]) \
			and bool(wave_metrics["passed"]) \
			and bool(reflection_metrics["passed"]) \
			and bool(diagonal_glint_metrics["passed"])
	print(
			"SCENE8_LAKE_SURFACE_PROBE: ", "PASS" if passed else "FAIL",
			" palette=", palette_metrics,
			" glacier_contact=", glacier_contact_metrics,
			" shore_ice=", shore_ice_metrics,
			" near_floes=", near_floe_metrics,
			" platform_contact=", platform_contact_metrics,
			" wave=", wave_metrics,
			" reflection=", reflection_metrics,
			" diagonal_glints=", diagonal_glint_metrics)
	_stage.queue_free()
	quit(0 if passed else 1)


func _probe_glacier_contact() -> Dictionary:
	var water_cells := 0
	var contact_cells := 0
	var open_water_cells := 0
	var shadow_cells := 0
	var glint_cells := 0
	var contact_columns: Dictionary[int, int] = {}
	var shadow_strength := float(_lake_material.get_shader_parameter(
			"glacier_contact_shadow_strength"))
	var glint_strength := float(_lake_material.get_shader_parameter(
			"glacier_contact_glint_strength"))
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5:
				continue
			water_cells += 1
			if topology.a < 0.05:
				open_water_cells += 1
				continue
			contact_cells += 1
			contact_columns[x] = int(contact_columns.get(x, 0)) + 1
			var column_group := floorf(float(x) / 3.0)
			var column_break := _step(
					0.22,
					_hash21(Vector2(column_group + 79.0, 149.0)))
			var row_break := lerpf(
					0.72,
					1.0,
					_step(0.44, _hash21(Vector2(
							column_group + 101.0, float(y) + 167.0))))
			var contact_mask := topology.a \
					* lerpf(0.58, 1.0, column_break) * row_break
			shadow_cells += int(contact_mask * shadow_strength >= 0.03)
			var contact_edge := smoothstep(0.42, 0.94, topology.a)
			var glint_break := _step(
					0.48,
					_hash21(Vector2(
							floorf(float(x) / 2.0) + 269.0,
							float(y) + 283.0)))
			glint_cells += int(
					contact_edge * glint_break * glint_strength >= 0.03)
	var maximum_rows := 0
	for rows: int in contact_columns.values():
		maximum_rows = maxi(maximum_rows, rows)
	var contact_coverage := float(contact_cells) / maxf(float(water_cells), 1.0)
	var shadow_coverage := float(shadow_cells) / maxf(float(contact_cells), 1.0)
	var passed := contact_cells >= 160 and contact_cells <= 2400 \
			and contact_columns.size() >= 260 \
			and open_water_cells > contact_cells * 5 \
			and maximum_rows <= 5 \
			and shadow_coverage >= 0.68 and shadow_coverage <= 1.0 \
			and glint_cells >= 80 and glint_cells <= contact_cells * 0.65
	return {
		"passed": passed,
		"contact_cells": contact_cells,
		"contact_columns": contact_columns.size(),
		"max_rows": maximum_rows,
		"contact_coverage": snappedf(contact_coverage, 0.0001),
		"shadow_coverage": snappedf(shadow_coverage, 0.001),
		"glint_cells": glint_cells,
		"open_water_cells": open_water_cells,
	}


func _probe_diagonal_glints() -> Dictionary:
	var masks: Array[PackedByteArray] = []
	var first_count := 0
	var water_count := 0
	var segment_x_totals := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var segment_counts := PackedInt32Array([0, 0, 0, 0])
	for time_seconds: float in [0.0, 6.0]:
		var mask := PackedByteArray()
		mask.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
		for y: int in LOGICAL_SIZE.y:
			for x: int in LOGICAL_SIZE.x:
				var topology := _topology_image.get_pixel(x, y)
				if topology.r < 0.5:
					continue
				if is_zero_approx(time_seconds):
					water_count += 1
				var cell := Vector2(x, y)
				var wave := _shared_wave_field(cell, topology.b, time_seconds)
				var glint := _broken_diagonal_glint(
						cell, topology.b, topology.g, wave, time_seconds)
				var ice := _shore_ice_mask(
						cell, topology.g, topology.b, wave)
				var near_ice := _near_floe_mask(
						cell, topology.g, topology.b)
				glint *= 1.0 - clampf(ice + near_ice, 0.0, 1.0)
				if glint <= 0.06:
					continue
				mask[y * LOGICAL_SIZE.x + x] = 1
				if not is_zero_approx(time_seconds):
					continue
				first_count += 1
				var segment_index := _glint_segment_index(topology.b)
				if segment_index >= 0:
					segment_x_totals[segment_index] += float(x)
					segment_counts[segment_index] += 1
		masks.append(mask)

	var segment_means := PackedFloat32Array()
	var active_segments := 0
	for index: int in 4:
		if segment_counts[index] <= 0:
			segment_means.append(-1.0)
			continue
		active_segments += 1
		segment_means.append(
				segment_x_totals[index] / float(segment_counts[index]))
	var diagonal_order := active_segments == 4
	for index: int in range(1, segment_means.size()):
		diagonal_order = diagonal_order \
				and segment_means[index] > segment_means[index - 1] + 12.0
	var changed_cells := 0
	for index: int in masks[0].size():
		changed_cells += int(masks[0][index] != masks[1][index])
	var coverage := float(first_count) / maxf(float(water_count), 1.0)
	var passed := (
			coverage >= 0.0006 and coverage <= 0.008
			and active_segments == 4 and diagonal_order
			and changed_cells >= 18
			and float(_lake_material.get_shader_parameter(
					"diagonal_glint_drift_cells")) <= 1.0)
	return {
		"passed": passed,
		"coverage": snappedf(coverage, 0.0001),
		"active_cells": first_count,
		"active_segments": active_segments,
		"segment_mean_x": segment_means,
		"diagonal_order": diagonal_order,
		"changed_cells_6s": changed_cells,
	}


func _glint_segment_index(depth: float) -> int:
	var centers := _lake_material.get_shader_parameter(
			"diagonal_glint_centers") as Vector4
	var widths := _lake_material.get_shader_parameter(
			"diagonal_glint_half_widths") as Vector4
	for index: int in 4:
		if absf(depth - centers[index]) <= widths[index] + 0.012:
			return index
	return -1


func _broken_diagonal_glint(
		cell: Vector2,
		depth: float,
		shore_distance: float,
		shared_wave: Vector3,
		time_seconds: float) -> float:
	var start_x := float(_lake_material.get_shader_parameter(
			"diagonal_glint_start_x"))
	var end_x := float(_lake_material.get_shader_parameter(
			"diagonal_glint_end_x"))
	var centers := _lake_material.get_shader_parameter(
			"diagonal_glint_centers") as Vector4
	var widths := _lake_material.get_shader_parameter(
			"diagonal_glint_half_widths") as Vector4
	var cycle := float(_lake_material.get_shader_parameter(
			"diagonal_glint_cycle_sec"))
	var drift_cells := float(_lake_material.get_shader_parameter(
			"diagonal_glint_drift_cells"))
	var phase := time_seconds * TAU / maxf(cycle, 0.001)
	var diagonal_x := lerpf(
			start_x, end_x, smoothstep(0.14, 0.88, depth)) \
			* float(LOGICAL_SIZE.x) + sin(phase) * drift_cells
	var line_width := lerpf(0.62, 1.18, depth)
	var diagonal_line := 1.0 - smoothstep(
			line_width, line_width + 0.62, absf(cell.x - diagonal_x))
	var segments := 0.0
	for index: int in 4:
		segments += _soft_depth_segment(depth, centers[index], widths[index])
	segments = clampf(segments, 0.0, 1.0)
	var broken_cells := float(_hash21(Vector2(
			floor(cell.x / 3.0) + 719.0,
			floor(cell.y / 2.0) + 733.0)) >= 0.38)
	var water_response := lerpf(0.58, 1.0, shared_wave.x) \
			* lerpf(0.82, 1.0, _ordered_dither_4x4(cell))
	var pulse := 0.68 + 0.32 * sin(phase * 0.73 + depth * 8.0)
	var open_water := smoothstep(0.18, 0.42, shore_distance)
	return diagonal_line * segments * broken_cells \
			* water_response * pulse * open_water


func _soft_depth_segment(depth: float, center: float, half_width: float) -> float:
	const FEATHER := 0.012
	return smoothstep(
			center - half_width - FEATHER,
			center - half_width,
			depth) * (1.0 - smoothstep(
			center + half_width,
			center + half_width + FEATHER,
			depth))


func _probe_palette() -> Dictionary:
	var maximum_jump_coverage := 0.0
	var unique_colors: Dictionary[int, bool] = {}
	var far_total := Vector3.ZERO
	var near_total := Vector3.ZERO
	var far_count := 0
	var near_count := 0
	for y: int in range(1, LOGICAL_SIZE.y):
		var comparable := 0
		var large_jumps := 0
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5 or topology.g < 0.38:
				continue
			var color := _topology_palette(topology.b, Vector2(x, y))
			var packed_color := (
					int(round(color.r * 255.0)) << 16
					| int(round(color.g * 255.0)) << 8
					| int(round(color.b * 255.0)))
			unique_colors[packed_color] = true
			if topology.b >= 0.10 and topology.b <= 0.22:
				far_total += Vector3(color.r, color.g, color.b)
				far_count += 1
			elif topology.b >= 0.78 and topology.b <= 0.92:
				near_total += Vector3(color.r, color.g, color.b)
				near_count += 1
			var previous_topology := _topology_image.get_pixel(x, y - 1)
			if previous_topology.r < 0.5 or previous_topology.g < 0.38:
				continue
			var previous := _topology_palette(
					previous_topology.b, Vector2(x, y - 1))
			var delta := Vector3(
					color.r - previous.r,
					color.g - previous.g,
					color.b - previous.b).length()
			comparable += 1
			large_jumps += int(delta >= RGB_JUMP_THRESHOLD)
		if comparable > 0:
			maximum_jump_coverage = maxf(
					maximum_jump_coverage,
					float(large_jumps) / float(comparable))
	var far_mean := far_total / maxf(float(far_count), 1.0)
	var near_mean := near_total / maxf(float(near_count), 1.0)
	var depth_separation := far_mean.distance_to(near_mean)
	var passed := maximum_jump_coverage < 0.60 \
			and depth_separation >= 0.08 \
			and unique_colors.size() >= 12
	return {
		"passed": passed,
		"max_jump_coverage": snappedf(maximum_jump_coverage, 0.001),
		"depth_separation": snappedf(depth_separation, 0.001),
		"unique_rgb": unique_colors.size(),
	}


func _probe_far_shore_ice() -> Dictionary:
	var mask := PackedByteArray()
	mask.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	var ice_count := 0
	var water_count := 0
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5:
				continue
			water_count += 1
			var cell := Vector2(x, y)
			var wave := _shared_wave_field(cell, topology.b, 0.0)
			if _shore_ice_mask(cell, topology.g, topology.b, wave) < 0.5:
				continue
			mask[y * LOGICAL_SIZE.x + x] = 1
			ice_count += 1

	var components: Array[Dictionary] = _ice_components(mask)
	var qualifying_components := 0
	var maximum_fill := 0.0
	var minimum_depth_variety := 999
	var all_attached := true
	var maximum_reach := 0.0
	for component: Dictionary in components:
		maximum_reach = maxf(maximum_reach, float(component["maximum_reach"]))
		all_attached = all_attached and bool(component["touches_shore"])
		if int(component["area"]) < 16 or int(component["width"]) < 8:
			continue
		qualifying_components += 1
		maximum_fill = maxf(maximum_fill, float(component["fill_ratio"]))
		minimum_depth_variety = mini(
				minimum_depth_variety, int(component["depth_variety"]))
	var ice_coverage := float(ice_count) / maxf(float(water_count), 1.0)
	var passed := ice_coverage >= 0.0025 \
			and ice_coverage <= 0.015 \
			and qualifying_components >= 3 \
			and all_attached \
			and maximum_reach <= 2.5 \
			and maximum_fill <= 0.80 \
			and minimum_depth_variety >= 2
	return {
		"passed": passed,
		"coverage": snappedf(ice_coverage, 0.0001),
		"components": components.size(),
		"qualified": qualifying_components,
		"all_attached": all_attached,
		"max_reach_cells": snappedf(maximum_reach, 0.01),
		"max_fill": snappedf(maximum_fill, 0.001),
		"min_depth_variety": minimum_depth_variety,
	}


func _probe_near_floes() -> Dictionary:
	var mask := PackedByteArray()
	mask.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	var floe_count := 0
	var water_count := 0
	var maximum_row_coverage := 0.0
	for y: int in LOGICAL_SIZE.y:
		var row_water := 0
		var row_floe := 0
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5:
				continue
			water_count += 1
			row_water += 1
			if _near_floe_mask(Vector2(x, y), topology.g, topology.b) < 0.5:
				continue
			mask[y * LOGICAL_SIZE.x + x] = 1
			floe_count += 1
			row_floe += 1
		if row_water > 0:
			maximum_row_coverage = maxf(
					maximum_row_coverage,
					float(row_floe) / float(row_water))

	var components := _near_floe_components(mask)
	var all_components_valid := true
	var minimum_area := 999
	var maximum_area := 0
	var maximum_fill := 0.0
	var minimum_row_variety := 999
	var minimum_centroid_depth := 1.0
	var maximum_centroid_depth := 0.0
	var minimum_centroid_shore := 1.0
	for component: Dictionary in components:
		var area := int(component["area"])
		var aspect := float(component["aspect"])
		var fill := float(component["fill_ratio"])
		var row_variety := int(component["row_width_variety"])
		var centroid_depth := float(component["centroid_depth"])
		var centroid_shore := float(component["centroid_shore"])
		minimum_area = mini(minimum_area, area)
		maximum_area = maxi(maximum_area, area)
		maximum_fill = maxf(maximum_fill, fill)
		minimum_row_variety = mini(minimum_row_variety, row_variety)
		minimum_centroid_depth = minf(minimum_centroid_depth, centroid_depth)
		maximum_centroid_depth = maxf(maximum_centroid_depth, centroid_depth)
		minimum_centroid_shore = minf(minimum_centroid_shore, centroid_shore)
		all_components_valid = all_components_valid \
				and area >= 6 and area <= 90 \
				and aspect >= 1.3 and aspect <= 4.0 \
				and fill <= 0.82 \
				and row_variety >= 3 \
				and centroid_depth >= 0.68 \
				and centroid_depth <= 0.92 \
				and centroid_shore >= 0.92
	var coverage := float(floe_count) / maxf(float(water_count), 1.0)
	var passed := components.size() >= 2 \
			and components.size() <= 3 \
			and coverage >= 0.001 \
			and coverage <= 0.008 \
			and maximum_row_coverage <= 0.12 \
			and all_components_valid
	return {
		"passed": passed,
		"coverage": snappedf(coverage, 0.0001),
		"components": components.size(),
		"min_area": minimum_area,
		"max_area": maximum_area,
		"max_fill": snappedf(maximum_fill, 0.001),
		"min_row_variety": minimum_row_variety,
		"centroid_depth_range": Vector2(
				snappedf(minimum_centroid_depth, 0.001),
				snappedf(maximum_centroid_depth, 0.001)),
		"min_centroid_shore": snappedf(minimum_centroid_shore, 0.001),
		"max_row_coverage": snappedf(maximum_row_coverage, 0.001),
	}


func _probe_platform_contact() -> Dictionary:
	var platform := _stage.get_node("BattlePlatform") as TextureRect
	var contact := _stage.get_node("PlatformWaterContact") as ColorRect
	var platform_image := platform.texture.get_image()
	var surface_bottom := float(_platform_material.get_shader_parameter(
			"surface_bottom_row"))
	var shallow_rows := float(_platform_material.get_shader_parameter(
			"shallow_wall_rows"))
	var variation_rows := float(_platform_material.get_shader_parameter(
			"edge_variation_rows"))
	var block_width := float(_platform_material.get_shader_parameter(
			"ice_block_width"))
	var total_opaque := 0
	var submerged_opaque := 0
	var occupied_columns := 0
	var contact_columns := 0
	var shadow_columns := 0
	var crest_columns := 0
	var maximum_visible_row := -1
	var minimum_boundary := 999.0
	var maximum_boundary := 0.0
	var source_row_screen_px := platform.size.y * platform.scale.y \
			/ float(platform_image.get_height())
	for x: int in platform_image.get_width():
		var block := floorf(float(x) / maxf(block_width, 1.0))
		var edge_step := variation_rows if _stable_hash(block) >= 0.72 else 0.0
		var boundary := surface_bottom + shallow_rows + edge_step
		minimum_boundary = minf(minimum_boundary, boundary)
		maximum_boundary = maxf(maximum_boundary, boundary)
		var has_alpha := false
		var support_row := clampi(
				int(floor(boundary)) - 1, 0,
				platform_image.get_height() - 1)
		for y: int in platform_image.get_height():
			if platform_image.get_pixel(x, y).a < 0.03:
				continue
			has_alpha = true
			total_opaque += 1
			if float(y) >= boundary:
				submerged_opaque += 1
			else:
				maximum_visible_row = maxi(maximum_visible_row, y)
		if has_alpha:
			occupied_columns += 1
			var has_contact := platform_image.get_pixel(x, support_row).a >= 0.03
			contact_columns += int(has_contact)
			if has_contact:
				var authored_x := platform.position.x + (
						(float(x) + 0.5) / float(platform_image.get_width())) \
						* platform.size.x * platform.scale.x
				shadow_columns += int(_contact_authored_segment(
						authored_x,
						float(_contact_material.get_shader_parameter(
								"shadow_line_coverage")), 11.0) >= 0.5)
				var authored_y := platform.position.y + boundary \
						* source_row_screen_px
				var lake_cell := Vector2i(
						clampi(int(floor(authored_x / 6.0)), 0, LOGICAL_SIZE.x - 1),
						clampi(int(floor(authored_y / 6.0)), 0, LOGICAL_SIZE.y - 1))
				var topology := _topology_image.get_pixelv(lake_cell)
				var wave := _shared_wave_field(
						Vector2(lake_cell), topology.b, 0.0)
				var moved_x := authored_x + wave.z * float(
						_contact_material.get_shader_parameter("contact_cell_px"))
				crest_columns += int(_contact_authored_segment(
						moved_x,
						float(_contact_material.get_shader_parameter(
								"crest_line_coverage")), 47.0) >= 0.5)
	var submerged_ratio := (
			float(submerged_opaque) / maxf(float(total_opaque), 1.0))
	var support_ratio := (
			float(contact_columns) / maxf(float(occupied_columns), 1.0))
	var shadow_ratio := (
			float(shadow_columns) / maxf(float(contact_columns), 1.0))
	var crest_ratio := (
			float(crest_columns) / maxf(float(contact_columns), 1.0))
	var waterline_range := Vector2(
			platform.position.y + minimum_boundary * source_row_screen_px,
			platform.position.y + maximum_boundary * source_row_screen_px)
	var contact_thickness := float(_contact_material.get_shader_parameter(
			"contact_cell_px")) * (
			float(_contact_material.get_shader_parameter("shadow_rows"))
			+ float(_contact_material.get_shader_parameter("crest_rows")))
	var topology_shared: bool = (
			_contact_material.get_shader_parameter("lake_topology")
			== _lake_material.get_shader_parameter("lake_topology"))
	var layer_order_valid := (
			_stage.get_node("FarSnowfield").get_index() < contact.get_index()
			and contact.get_index() < platform.get_index()
			and platform.get_index()
					< _stage.get_node("ForegroundLeft").get_index())
	var transform_preserved := (
			platform.position == Vector2(88.0, 166.0)
			and platform.size == Vector2(288.0, 188.0)
			and platform.scale == Vector2(6.0, 6.0)
			and contact.position == Vector2(-32.0, 802.0)
			and contact.size == Vector2(1984.0, 24.0))
	var passed: bool = submerged_ratio >= 0.28 \
			and submerged_ratio <= 0.42 \
			and maximum_visible_row <= 107 \
			and support_ratio >= 0.70 \
			and shadow_ratio >= 0.70 \
			and shadow_ratio <= 0.90 \
			and crest_ratio >= 0.25 \
			and crest_ratio <= 0.55 \
			and waterline_range.x >= 806.0 \
			and waterline_range.y <= 816.0 \
			and contact_thickness >= 6.0 \
			and contact_thickness <= 12.0 \
			and bool(_contact_material.get_shader_parameter("use_lake_topology")) \
			and topology_shared \
			and layer_order_valid \
			and transform_preserved
	return {
		"passed": passed,
		"submerged_ratio": snappedf(submerged_ratio, 0.001),
		"max_visible_source_row": maximum_visible_row,
		"contact_column_ratio": snappedf(support_ratio, 0.001),
		"shadow_column_ratio": snappedf(shadow_ratio, 0.001),
		"crest_column_ratio": snappedf(crest_ratio, 0.001),
		"waterline_y": Vector2(
				snappedf(waterline_range.x, 0.1),
				snappedf(waterline_range.y, 0.1)),
		"contact_thickness_px": contact_thickness,
		"topology_shared": topology_shared,
		"layer_order": layer_order_valid,
		"transform_preserved": transform_preserved,
	}


func _probe_wave_motion() -> Dictionary:
	var first_mask: Dictionary[Vector2i, bool] = {}
	var second_mask: Dictionary[Vector2i, bool] = {}
	var maximum_offset := 0.0
	var non_integer_offsets := 0
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5 or topology.g < 0.18:
				continue
			var cell := Vector2(x, y)
			var first_wave := _shared_wave_field(cell, topology.b, 0.0)
			var second_wave := _shared_wave_field(cell, topology.b, 7.0)
			if maxf(first_wave.x, first_wave.y * 0.72) >= 0.08:
				first_mask[Vector2i(x, y)] = true
			if maxf(second_wave.x, second_wave.y * 0.72) >= 0.08:
				second_mask[Vector2i(x, y)] = true
			for offset: float in [first_wave.z, second_wave.z]:
				maximum_offset = maxf(maximum_offset, absf(offset))
				non_integer_offsets += int(not is_equal_approx(offset, roundf(offset)))
	var moved_cells := _symmetric_difference_count(first_mask, second_mask)
	var maximum_row_coverage := 0.0
	for y: int in LOGICAL_SIZE.y:
		var water_in_row := 0
		var wave_in_row := 0
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5 or topology.g < 0.18:
				continue
			water_in_row += 1
			wave_in_row += int(first_mask.has(Vector2i(x, y)))
		if water_in_row > 0:
			maximum_row_coverage = maxf(
					maximum_row_coverage,
					float(wave_in_row) / float(water_in_row))
	var passed := first_mask.size() >= 180 \
			and second_mask.size() >= 180 \
			and moved_cells >= 160 \
			and maximum_row_coverage < 0.70 \
			and maximum_offset <= 2.0 \
			and non_integer_offsets == 0
	return {
		"passed": passed,
		"first_cells": first_mask.size(),
		"second_cells": second_mask.size(),
		"moved_cells": moved_cells,
		"max_row_coverage": snappedf(maximum_row_coverage, 0.001),
		"max_offset_cells": maximum_offset,
		"non_integer_offsets": non_integer_offsets,
	}


func _probe_reflection_geometry() -> Dictionary:
	var coverage_depth := float(_reflection_material.get_shader_parameter(
			"reflection_coverage_depth"))
	var shore_clearance := float(_reflection_material.get_shader_parameter(
			"shore_reflection_clearance"))
	var horizon_y := float(_reflection_material.get_shader_parameter("horizon_y"))
	var reflection_start := float(_reflection_material.get_shader_parameter(
			"reflection_start_depth"))
	var reflection_end := float(_reflection_material.get_shader_parameter(
			"reflection_end_depth"))
	var source_top := float(_reflection_material.get_shader_parameter(
			"reflection_source_top_y"))
	var source_bottom := float(_reflection_material.get_shader_parameter(
			"reflection_source_bottom_y"))
	var horizontal_stretch := float(_reflection_material.get_shader_parameter(
			"reflection_horizontal_stretch"))
	var lake_cells := maxf(180.0 * (1.0 - horizon_y), 1.0)
	var fade_depth := 3.0 / lake_cells
	var active_cells := 0
	var eligible_cells := 0
	var past_coverage := 0
	var minimum_source_y := 1.0
	var maximum_source_y := 0.0
	var active_depth_buckets: Dictionary[int, bool] = {}
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var topology := _topology_image.get_pixel(x, y)
			if topology.r < 0.5:
				continue
			var depth := topology.b
			if depth <= coverage_depth and topology.g >= shore_clearance:
				eligible_cells += 1
			var wave := _shared_wave_field(Vector2(x, y), depth, 0.0)
			var reflection_wave := clampf(wave.x + wave.y * 0.35, 0.0, 1.0)
			var reflection_zone := smoothstep(
					reflection_start, reflection_start + 0.045, depth) \
					* (1.0 - smoothstep(
							reflection_end - 0.07, reflection_end, depth))
			var coverage_fade := 1.0 - smoothstep(
					coverage_depth - fade_depth, coverage_depth, depth)
			var shore_fade := smoothstep(
					shore_clearance, shore_clearance + 0.12, topology.g)
			var alpha_driver := reflection_wave * reflection_zone \
					* coverage_fade * shore_fade
			if alpha_driver < 0.04:
				continue
			active_cells += 1
			var depth_t := clampf(
					(depth - reflection_start)
					/ maxf(reflection_end - reflection_start, 0.001),
					0.0, 1.0)
			active_depth_buckets[int(floorf(depth_t * 8.0))] = true
			past_coverage += int(depth > coverage_depth)
			var source_y := lerpf(
					source_bottom, source_top, depth_t)
			minimum_source_y = minf(minimum_source_y, source_y)
			maximum_source_y = maxf(maximum_source_y, source_y)
	var active_coverage := float(active_cells) / maxf(float(eligible_cells), 1.0)
	var passed := active_cells >= 600 \
			and active_coverage >= 0.04 \
			and active_coverage <= 0.42 \
			and past_coverage == 0 \
			and active_depth_buckets.size() >= 6 \
			and minimum_source_y >= source_top - 0.001 \
			and maximum_source_y <= source_bottom + 0.001 \
			and horizontal_stretch >= 1.05 \
			and horizontal_stretch <= 1.35
	return {
		"passed": passed,
		"active_cells": active_cells,
		"eligible_cells": eligible_cells,
		"active_coverage": snappedf(active_coverage, 0.001),
		"past_coverage": past_coverage,
		"source_y_range": Vector2(
				snappedf(minimum_source_y, 0.001),
				snappedf(maximum_source_y, 0.001)),
		"active_depth_buckets": active_depth_buckets.size(),
		"horizontal_stretch": horizontal_stretch,
	}


func _topology_palette(depth: float, cell: Vector2) -> Color:
	var far_color: Color = _lake_material.get_shader_parameter("far_color")
	var middle_color: Color = _lake_material.get_shader_parameter("middle_color")
	var near_color: Color = _lake_material.get_shader_parameter("near_color")
	var variation := float(_lake_material.get_shader_parameter(
			"palette_depth_variation"))
	var variation_cell := (cell / Vector2(9.0, 3.0)).floor()
	var low_frequency_variation := (
			_hash21(variation_cell + Vector2(17.0, 31.0)) - 0.5) * variation
	var ordered_variation := (_ordered_dither_4x4(cell) - 0.5) \
			* variation * 0.65
	var local_depth := clampf(
			depth + low_frequency_variation + ordered_variation, 0.0, 1.0)
	var far_to_middle := smoothstep(0.02, 0.60, local_depth)
	var middle_to_near := smoothstep(0.38, 0.98, local_depth)
	return far_color.lerp(middle_color, far_to_middle).lerp(
			near_color, middle_to_near)


func _shore_ice_mask(
		cell: Vector2,
		shore_distance: float,
		depth: float,
		wave: Vector3) -> float:
	var segment_width := maxf(float(_lake_material.get_shader_parameter(
			"ice_segment_cells")), 1.0)
	var presence := float(_lake_material.get_shader_parameter(
			"thin_ice_presence"))
	var segment_id := floorf(cell.x / segment_width)
	var segment_position := fposmod(cell.x / segment_width, 1.0)
	var segment_active := _step(
			1.0 - presence,
			_hash21(Vector2(segment_id + 101.0, 307.0)))
	var reach_left := _hash21(Vector2(segment_id + 127.0, 331.0))
	var reach_right := _hash21(Vector2(segment_id + 128.0, 331.0))
	var reach_blend := smoothstep(0.0, 1.0, segment_position)
	var reach_seed := lerpf(reach_left, reach_right, reach_blend)
	var rough_group := floorf(cell.x / 3.0)
	var edge_roughness := (
			_hash21(Vector2(rough_group + 173.0, segment_id + 379.0)) - 0.5) \
			* 1.25
	var reach_fraction := float(_lake_material.get_shader_parameter(
			"shore_ice_reach"))
	var shore_cells_total := float(_lake_material.get_shader_parameter(
			"shore_distance_cells"))
	var maximum_reach_cells := reach_fraction * shore_cells_total
	var reach_cells := lerpf(0.65, maximum_reach_cells, reach_seed)
	reach_cells = clampf(
			reach_cells + edge_roughness - wave.y * 0.75,
			0.35,
			maximum_reach_cells)
	var shore_cells := shore_distance * shore_cells_total
	var attached_to_shore := 1.0 - _step(
			reach_cells + 0.001, shore_cells)
	var erosion_zone := smoothstep(
			0.22, 1.0, shore_cells / maxf(reach_cells, 0.001))
	var breakup_seed := _hash21(Vector2(
			floorf(cell.x / 3.0) + 211.0,
			floorf(shore_cells) + segment_id + 419.0))
	var breakup := _step(
			breakup_seed,
			float(_lake_material.get_shader_parameter("shore_ice_breakup"))
					* erosion_zone)
	var depth_limit := float(_lake_material.get_shader_parameter("thin_ice_depth"))
	var shallow_depth_guard := 1.0 - _step(depth_limit, depth)
	return segment_active * attached_to_shore * (1.0 - breakup) \
			* shallow_depth_guard


func _ellipse_floe_lobe(
		cell: Vector2,
		center: Vector2,
		radius: Vector2,
		shear: float,
		seed: float) -> float:
	var delta := cell - center
	delta.x += delta.y * shear
	var safe_radius := Vector2(maxf(radius.x, 0.5), maxf(radius.y, 0.5))
	var normalized := delta / safe_radius
	var angle := atan2(normalized.y, normalized.x)
	var sector := floorf((angle + PI) / TAU * 12.0)
	var edge_jag := (
			_hash21(Vector2(sector + seed, seed + 509.0)) - 0.5) * 0.18
	return 1.0 - _step(1.0 + edge_jag, normalized.length())


func _irregular_floe_shape(
		cell: Vector2, specification: Vector4, seed: float) -> float:
	var center := Vector2(specification.x, specification.y)
	var radius := Vector2(specification.z, specification.w)
	var shear := lerpf(
			-0.28, 0.28,
			_hash21(Vector2(seed + 17.0, seed + 41.0)))
	var primary := _ellipse_floe_lobe(cell, center, radius, shear, seed)
	var secondary_center := center + Vector2(radius.x * 0.28, -0.35)
	var secondary_radius := radius * Vector2(0.66, 0.82)
	var secondary := _ellipse_floe_lobe(
			cell, secondary_center, secondary_radius,
			-shear * 0.72, seed + 83.0)
	return maxf(primary, secondary)


func _near_floe_mask(
		cell: Vector2, shore_distance: float, depth: float) -> float:
	var minimum_depth := float(_lake_material.get_shader_parameter(
			"near_floe_min_depth"))
	var maximum_depth := float(_lake_material.get_shader_parameter(
			"near_floe_max_depth"))
	var minimum_shore := float(_lake_material.get_shader_parameter(
			"near_floe_min_shore_distance"))
	var depth_gate := _step(minimum_depth, depth) \
			* (1.0 - _step(maximum_depth, depth))
	var shore_gate := _step(minimum_shore, shore_distance)
	var specification_a: Vector4 = _lake_material.get_shader_parameter(
			"near_floe_a")
	var specification_b: Vector4 = _lake_material.get_shader_parameter(
			"near_floe_b")
	var floe_a := _irregular_floe_shape(cell, specification_a, 733.0)
	var floe_b := _irregular_floe_shape(cell, specification_b, 911.0)
	return maxf(floe_a, floe_b) * depth_gate * shore_gate


func _shared_wave_field(cell: Vector2, depth: float, time_seconds: float) -> Vector3:
	var perspective := smoothstep(0.0, 1.0, depth)
	var row_stride := lerpf(
			float(_lake_material.get_shader_parameter("far_wave_stride_cells")),
			float(_lake_material.get_shader_parameter("near_wave_stride_cells")),
			perspective)
	var row_coordinate := cell.y / maxf(row_stride, 1.0)
	var row_id := floorf(row_coordinate)
	var row_fraction := fposmod(row_coordinate, 1.0)
	var row_seed := _hash21(Vector2(row_id + 19.0, 43.0))
	var direction := lerpf(-1.0, 1.0, _step(0.5, row_seed))
	var moving_cell_x := cell.x + time_seconds * float(
			_lake_material.get_shader_parameter("wave_travel_cells_per_sec")) \
			* direction
	var bend_cells := lerpf(5.0, 11.0, perspective)
	var bend_id := floorf(moving_cell_x / bend_cells)
	var bend := (_hash21(Vector2(bend_id + 71.0, row_id + 97.0)) - 0.5) \
			* lerpf(0.54, 0.34, perspective)
	var ridge_center := lerpf(0.22, 0.78, row_seed) + bend
	var ridge_distance := absf(row_fraction - ridge_center) * row_stride
	var ridge_width := lerpf(0.32, 0.92, perspective)
	var ridge := 1.0 - smoothstep(
			ridge_width, ridge_width + 0.34, ridge_distance)
	var segment_cells := lerpf(
			float(_lake_material.get_shader_parameter("far_wave_segment_cells")),
			float(_lake_material.get_shader_parameter("near_wave_segment_cells")),
			perspective)
	var segment_id := floorf(moving_cell_x / segment_cells)
	var segment_seed := _hash21(Vector2(segment_id + 113.0, row_id + 151.0))
	var presence := float(_lake_material.get_shader_parameter("wave_presence"))
	var segment_active := _step(1.0 - presence, segment_seed)
	var segment_position := fposmod(moving_cell_x / segment_cells, 1.0)
	var segment_start := lerpf(
			0.02, 0.18,
			_hash21(Vector2(segment_id + 179.0, row_id + 193.0)))
	var segment_end := lerpf(
			0.56, 0.94,
			_hash21(Vector2(segment_id + 211.0, row_id + 227.0)))
	var segment_feather := lerpf(0.06, 0.035, perspective)
	var segment_mask := smoothstep(
			segment_start, segment_start + segment_feather, segment_position) \
			* (1.0 - smoothstep(
					segment_end - segment_feather,
					segment_end,
					segment_position))
	ridge *= segment_active * segment_mask
	var trough_center := fposmod(ridge_center + 0.48, 1.0)
	var trough_distance := absf(row_fraction - trough_center) * row_stride
	var trough_width := lerpf(0.24, 0.72, perspective)
	var trough := 1.0 - smoothstep(
			trough_width, trough_width + 0.30, trough_distance)
	var trough_seed := _hash21(Vector2(segment_id + 239.0, row_id + 263.0))
	trough *= _step(0.46, trough_seed) * segment_mask
	var cycle := float(_lake_material.get_shader_parameter("wave_cycle_sec"))
	var maximum_offset := float(_lake_material.get_shader_parameter(
			"wave_max_offset_cells"))
	var offset_phase := time_seconds * TAU / maxf(cycle, 0.001) \
			+ row_id * 0.73 + segment_seed * TAU
	var lateral_offset := roundf(clampf(
			sin(offset_phase) * maximum_offset,
			-maximum_offset, maximum_offset))
	return Vector3(ridge, trough, lateral_offset)


func _ordered_dither_4x4(cell: Vector2) -> float:
	const MATRIX: Array[int] = [
		0, 8, 2, 10,
		12, 4, 14, 6,
		3, 11, 1, 9,
		15, 7, 13, 5,
	]
	var x := int(fposmod(cell.x, 4.0))
	var y := int(fposmod(cell.y, 4.0))
	return (float(MATRIX[y * 4 + x]) + 0.5) / 16.0


func _hash21(point: Vector2) -> float:
	var wrapped := Vector2(
			fposmod(point.x, 509.0), fposmod(point.y, 251.0))
	return fposmod(sin(wrapped.dot(Vector2(127.1, 311.7))) * 43758.5453, 1.0)


func _stable_hash(value: float) -> float:
	return fposmod(sin(value * 12.9898) * 43758.5453, 1.0)


func _contact_authored_segment(
		authored_x: float, coverage: float, seed_offset: float) -> float:
	var width := maxf(float(_contact_material.get_shader_parameter(
			"line_cell_width_px")), 1.0)
	var line_id := floorf(authored_x / width)
	var line_position := fposmod(authored_x / width, 1.0)
	var spare := maxf(1.0 - coverage, 0.0)
	var center := 0.5 + (
			_hash21(Vector2(line_id + seed_offset + 37.0, 619.0)) - 0.5) \
			* spare * 0.72
	var half_width := coverage * 0.5
	return _step(center - half_width, line_position) \
			* (1.0 - _step(center + half_width, line_position))


func _step(edge: float, value: float) -> float:
	return 0.0 if value < edge else 1.0


func _symmetric_difference_count(
		first: Dictionary, second: Dictionary) -> int:
	var count := 0
	for position: Vector2i in first:
		count += int(not second.has(position))
	for position: Vector2i in second:
		count += int(not first.has(position))
	return count


func _ice_components(mask: PackedByteArray) -> Array[Dictionary]:
	var components: Array[Dictionary] = []
	var shore_cell_count := float(_lake_material.get_shader_parameter(
			"shore_distance_cells"))
	var visited := PackedByteArray()
	visited.resize(mask.size())
	var neighbors: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var start_index := y * LOGICAL_SIZE.x + x
			if mask[start_index] == 0 or visited[start_index] != 0:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			visited[start_index] = 1
			var area := 0
			var minimum := Vector2i(x, y)
			var maximum := Vector2i(x, y)
			var touches_shore := false
			var maximum_reach := 0.0
			var deepest_by_x: Dictionary[int, int] = {}
			while not stack.is_empty():
				var position: Vector2i = stack.pop_back()
				area += 1
				minimum = minimum.min(position)
				maximum = maximum.max(position)
				var topology := _topology_image.get_pixelv(position)
				var reach := topology.g * shore_cell_count
				maximum_reach = maxf(maximum_reach, reach)
				touches_shore = touches_shore or reach <= 1.1
				var reach_row := int(round(reach))
				deepest_by_x[position.x] = maxi(
						int(deepest_by_x.get(position.x, -1)), reach_row)
				for offset: Vector2i in neighbors:
					var neighbor := position + offset
					if neighbor.x < 0 or neighbor.y < 0 \
							or neighbor.x >= LOGICAL_SIZE.x \
							or neighbor.y >= LOGICAL_SIZE.y:
						continue
					var neighbor_index := (
							neighbor.y * LOGICAL_SIZE.x + neighbor.x)
					if mask[neighbor_index] == 0 or visited[neighbor_index] != 0:
						continue
					visited[neighbor_index] = 1
					stack.append(neighbor)
			var width := maximum.x - minimum.x + 1
			var height := maximum.y - minimum.y + 1
			var depth_values: Dictionary[int, bool] = {}
			for value: int in deepest_by_x.values():
				depth_values[value] = true
			components.append({
				"area": area,
				"width": width,
				"height": height,
				"fill_ratio": float(area) / float(width * height),
				"touches_shore": touches_shore,
				"maximum_reach": maximum_reach,
				"depth_variety": depth_values.size(),
			})
	return components


func _near_floe_components(mask: PackedByteArray) -> Array[Dictionary]:
	var components: Array[Dictionary] = []
	var visited := PackedByteArray()
	visited.resize(mask.size())
	var neighbors: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var start_index := y * LOGICAL_SIZE.x + x
			if mask[start_index] == 0 or visited[start_index] != 0:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			visited[start_index] = 1
			var area := 0
			var minimum := Vector2i(x, y)
			var maximum := Vector2i(x, y)
			var row_widths: Dictionary[int, int] = {}
			var depth_total := 0.0
			var shore_total := 0.0
			while not stack.is_empty():
				var position: Vector2i = stack.pop_back()
				area += 1
				minimum = minimum.min(position)
				maximum = maximum.max(position)
				row_widths[position.y] = int(row_widths.get(position.y, 0)) + 1
				var topology := _topology_image.get_pixelv(position)
				depth_total += topology.b
				shore_total += topology.g
				for offset: Vector2i in neighbors:
					var neighbor := position + offset
					if neighbor.x < 0 or neighbor.y < 0 \
							or neighbor.x >= LOGICAL_SIZE.x \
							or neighbor.y >= LOGICAL_SIZE.y:
						continue
					var neighbor_index := neighbor.y * LOGICAL_SIZE.x + neighbor.x
					if mask[neighbor_index] == 0 or visited[neighbor_index] != 0:
						continue
					visited[neighbor_index] = 1
					stack.append(neighbor)
			var width := maximum.x - minimum.x + 1
			var height := maximum.y - minimum.y + 1
			var distinct_widths: Dictionary[int, bool] = {}
			for row_width: int in row_widths.values():
				distinct_widths[row_width] = true
			components.append({
				"area": area,
				"width": width,
				"height": height,
				"aspect": float(width) / maxf(float(height), 1.0),
				"fill_ratio": float(area) / float(width * height),
				"row_width_variety": distinct_widths.size(),
				"centroid_depth": depth_total / maxf(float(area), 1.0),
				"centroid_shore": shore_total / maxf(float(area), 1.0),
			})
	return components
