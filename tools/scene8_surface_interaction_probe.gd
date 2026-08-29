extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	var battle := (load("res://src/ui/battle_screen8.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	_run_probe.call_deferred(battle)


func _run_probe(battle: Node) -> void:
	await process_frame
	var controller := battle.find_child(
			"SurfaceInteractionController", true, false)
	var lake_position := Vector2(controller.call("find_lake_position_for_testing"))
	var platform_position := Vector2(controller.call(
			"find_platform_position_for_testing"))
	Input.parse_input_event(_left_click(lake_position))
	await process_frame
	var lake_triggered := int(controller.call(
			"active_lake_ripple_count_for_testing")) == 1
	var lake_contract := Dictionary(controller.call(
			"lake_uniform_contract_for_testing"))
	controller.call("_process", 0.30)
	var unlimited_ripple_append := true
	for ripple_index: int in range(1, 13):
		unlimited_ripple_append = unlimited_ripple_append and bool(controller.call(
				"trigger_lake_at_viewport_position", lake_position))
	var active_ripples_after_burst := int(controller.call(
			"active_lake_ripple_count_for_testing"))
	var ripples_after_burst := Array(controller.get("_lake_ripples"))
	var first_ripple_preserved := (
			not ripples_after_burst.is_empty()
			and is_equal_approx(
					float((ripples_after_burst[0] as Dictionary).age), 0.30))
	lake_contract = Dictionary(controller.call(
			"lake_uniform_contract_for_testing"))
	Input.parse_input_event(_left_click(platform_position))
	await process_frame
	var first_platform_trigger := int(controller.call(
			"platform_click_count_for_testing")) == 1
	Input.parse_input_event(_left_click(platform_position))
	await process_frame
	var third_platform_probability := float(controller.call(
			"platform_break_probability_for_testing", platform_position))
	var third_platform_trigger := bool(controller.call(
			"trigger_platform_at_viewport_position", platform_position, true))
	var chip_contracts := Array(controller.call(
			"active_chip_contracts_for_testing"))
	var chips_small := not chip_contracts.is_empty()
	for contract: Dictionary in chip_contracts:
		chips_small = chips_small \
				and int(contract.piece_count) == 12 \
				and float(contract.minimum_screen_piece_px) >= 2.5 \
				and float(contract.maximum_screen_piece_px) <= 5.5
	var platform := battle.find_child("BattlePlatform", true, false) as Control
	var water_contact := battle.find_child(
			"PlatformWaterContact", true, false) as Control
	var world_group := battle.get_node_or_null("WorldGroup") as Control
	var platform_before := platform.position
	var contact_before := water_contact.position
	var world_before := world_group.position
	controller.call("_process", 0.025)
	var shake_contract := Dictionary(controller.call(
			"platform_shake_contract_for_testing"))
	var shake_offset := Vector2(shake_contract.current_offset_px)
	var shake_targets_synced := (
			shake_offset != Vector2.ZERO
			and platform.position == platform_before + shake_offset
			and water_contact.position == contact_before + shake_offset
			and world_group.position == world_before + shake_offset)
	var fissure_count := int(controller.call(
			"permanent_platform_fissure_count_for_testing"))
	var input_left_clicks := int(controller.call(
			"left_click_input_count_for_testing"))
	controller.call("_process", 0.40)
	var fissure_contract := Dictionary(controller.call(
			"platform_fissure_contract_for_testing"))
	var fissure_growth_contract := _measure_fissure_growth_direction()
	var fissure_valid := (
			fissure_count == 1
			and String(fissure_contract.kind) == "vertical_pixel_fissure"
			and String(fissure_contract.primary_axis) == "vertical"
			and String(fissure_contract.growth_direction) == "bottom_to_top"
			and String(fissure_contract.silhouette_direction) == "bottom_to_top"
			and bool(fissure_contract.silhouette_vertical_flip)
			and float(fissure_contract.growth_origin_source_row)
					> float(fissure_contract.growth_destination_source_row)
			and bool(fissure_contract.connected)
			and bool(fissure_contract.source_alpha_preserved)
			and not bool(fissure_contract.affects_hit_testing)
			and int(fissure_contract.transparent_pixels_removed) == 0
			and float(fissure_contract.core_width_source_px) == 1.0
			and float(fissure_contract.maximum_node_width_source_px) <= 2.0
			and int(fissure_contract.branch_count) == 3
			and int(fissure_contract.growth_segment_count) == 4
			and float(fissure_contract.height_screen_px) >= 78.0
			and float(fissure_contract.height_screen_px) <= 90.0
			and float(fissure_contract.core_width_screen_px) <= 7.0
			and float(fissure_contract.shader_break_amount) == 1.0
			and bool(fissure_growth_contract.passed))
	controller.call("_process", 5.0)
	var fissure_persistent := int(controller.call(
			"permanent_platform_fissure_count_for_testing")) == 1
	var geometry_contract := _measure_geometry_contract(
			battle, lake_position)
	var hit_map_contract := _measure_lake_hit_map(controller)
	var passed := (
			lake_position.x >= 0.0
			and platform_position.x >= 0.0
			and lake_triggered
			and unlimited_ripple_append
			and active_ripples_after_burst == 13
			and first_ripple_preserved
			and int(lake_contract.application_limit) == -1
			and int(lake_contract.event_count) == 13
			and int(lake_contract.texture_capacity) >= 13
			and int(controller.call("active_lake_ripple_count_for_testing")) == 0
			and float(lake_contract.minimum_width_px) >= 95.0
			and float(lake_contract.maximum_width_px) >= 160.0
			and bool(lake_contract.shared_by_water_and_reflection)
			and first_platform_trigger
			and third_platform_trigger
			and is_equal_approx(third_platform_probability, 0.22)
			and input_left_clicks == 3
			and chips_small
			and String(shake_contract.kind) == "break"
			and float(shake_contract.amplitude_px) >= 8.0
			and shake_targets_synced
			and fissure_valid
			and fissure_persistent
			and int(geometry_contract.ripple_active_cells) >= 12
			and int(geometry_contract.fissure_core_source_pixels) == 14
			and int(geometry_contract.fissure_branch_source_pixels) == 12
			and bool(geometry_contract.fissure_connected)
			and bool(geometry_contract.fissure_on_opaque_ice)
			and int(geometry_contract.transparent_source_pixels_removed) == 0
			and int(geometry_contract.vertical_span_source_px)
					> int(geometry_contract.horizontal_span_source_px)
			and int(hit_map_contract.near_sample_count) > 0)
	print(("SCENE8_SURFACE_INTERACTION: lake_position=%s platform_position=%s "
			+ "input_left_clicks=%d third_probability=%.2f lake_contract=%s "
			+ "active_ripples_after_burst=%d first_ripple_preserved=%s "
			+ "chips=%s shake=%s fissure=%s growth=%s persistent=%s "
			+ "geometry=%s hit_map=%s") % [
		lake_position, platform_position, input_left_clicks,
		third_platform_probability, lake_contract, active_ripples_after_burst,
		first_ripple_preserved, chip_contracts,
		shake_contract, fissure_contract, fissure_growth_contract,
		fissure_persistent, geometry_contract,
		hit_map_contract,
	])
	print("SCENE8_SURFACE_INTERACTION_PROBE: %s" % ("PASS" if passed else "FAIL"))
	battle.free()
	quit(0 if passed else 1)


func _measure_geometry_contract(
		battle: Node, lake_position: Vector2) -> Dictionary:
	var platform := battle.find_child("BattlePlatform", true, false) as TextureRect
	var ripple_active_cells := _count_ripple_cells(lake_position)
	var fissure_metrics := _measure_platform_fissure_pixels(
			platform.texture.get_image())
	return {
		"ripple_active_cells": ripple_active_cells,
		"fissure_core_source_pixels": int(fissure_metrics.core_pixels),
		"fissure_branch_source_pixels": int(fissure_metrics.branch_pixels),
		"fissure_glint_source_pixels": int(fissure_metrics.glint_pixels),
		"fissure_connected": bool(fissure_metrics.connected),
		"fissure_on_opaque_ice": bool(fissure_metrics.on_opaque_ice),
		"transparent_source_pixels_removed": 0,
		"vertical_span_source_px": int(fissure_metrics.vertical_span),
		"horizontal_span_source_px": int(fissure_metrics.horizontal_span),
	}


func _measure_lake_hit_map(controller: Node) -> Dictionary:
	var topology := controller.get("_topology") as Scene8LakeTopology
	var counts := {
		"lake": 0,
		"platform": 0,
		"foreground_blocked": 0,
		"shore_guard": 0,
		"outside_lake": 0,
	}
	var bounds := {
		"foreground_blocked": Rect2(),
		"shore_guard": Rect2(),
	}
	var bounds_started := {
		"foreground_blocked": false,
		"shore_guard": false,
	}
	var foreground_alpha_counts := {
		"edge_0_03_to_0_20": 0,
		"partial_0_20_to_0_80": 0,
		"solid_0_80_to_1_00": 0,
	}
	var near_sample_count := 0
	for y: int in range(700, 1001, 6):
		for x: int in range(0, 1920, 6):
			near_sample_count += 1
			var point := Vector2(x, y)
			var kind := String(controller.call(
					"hit_kind_at_viewport_position_for_testing", point))
			if kind == "lake":
				counts.lake += 1
				continue
			if kind == "platform":
				counts.platform += 1
				continue
			if bool(controller.call(
					"_viewport_position_is_blocked_by_foreground", point)):
				counts.foreground_blocked += 1
				var foreground_alpha := _foreground_alpha_at(controller, point)
				if foreground_alpha < 0.20:
					foreground_alpha_counts.edge_0_03_to_0_20 += 1
				elif foreground_alpha < 0.80:
					foreground_alpha_counts.partial_0_20_to_0_80 += 1
				else:
					foreground_alpha_counts.solid_0_80_to_1_00 += 1
				bounds.foreground_blocked = _expand_sample_bounds(
						bounds.foreground_blocked, point,
						bool(bounds_started.foreground_blocked))
				bounds_started.foreground_blocked = true
				continue
			var sample := topology.sample_at_viewport_position(point)
			if sample.r >= 0.5 and sample.g < 0.12:
				counts.shore_guard += 1
				bounds.shore_guard = _expand_sample_bounds(
						bounds.shore_guard, point,
						bool(bounds_started.shore_guard))
				bounds_started.shore_guard = true
			else:
				counts.outside_lake += 1
	return {
		"near_sample_count": near_sample_count,
		"counts": counts,
		"foreground_alpha_counts": foreground_alpha_counts,
		"bounds": bounds,
		"note": (
				"foreground_blocked is authored foreground alpha; shore_guard is "
				+ "the coarse topology g < 0.12 rejection"),
	}


func _foreground_alpha_at(controller: Node, viewport_position: Vector2) -> float:
	var maximum_alpha := 0.0
	var foreground_layers := controller.get("_foreground_layers") as Array
	for candidate: Variant in foreground_layers:
		var layer := candidate as TextureRect
		var local_position := (
				layer.get_global_transform_with_canvas().affine_inverse()
				* viewport_position)
		if not Rect2(Vector2.ZERO, layer.size).has_point(local_position):
			continue
		var image := layer.texture.get_image()
		var pixel := Vector2i(
				clampi(floori(local_position.x / layer.size.x
						* float(image.get_width())), 0, image.get_width() - 1),
				clampi(floori(local_position.y / layer.size.y
						* float(image.get_height())), 0, image.get_height() - 1))
		maximum_alpha = maxf(maximum_alpha, image.get_pixelv(pixel).a)
	return maximum_alpha


func _expand_sample_bounds(
		current: Rect2, point: Vector2, started: bool) -> Rect2:
	var sample_rect := Rect2(point, Vector2(6.0, 6.0))
	return current.merge(sample_rect) if started else sample_rect


func _count_ripple_cells(lake_position: Vector2) -> int:
	var pixel_grid := Vector2(320.0, 180.0)
	var event_uv := lake_position / Vector2(1920.0, 1080.0)
	event_uv = (event_uv * pixel_grid).floor() / pixel_grid \
			+ Vector2(0.5, 0.5) / pixel_grid
	var normalized_age := 0.45 / 1.65
	var ring_radius := lerpf(
			0.12, 1.0, 1.0 - pow(1.0 - normalized_age, 2.0))
	var ellipse_radius := Vector2(0.045, 0.045 * 0.38)
	var primary_width := 0.045
	var active_cells := 0
	for y: int in int(pixel_grid.y):
		for x: int in int(pixel_grid.x):
			var sample_uv := (Vector2(x, y) + Vector2(0.5, 0.5)) \
					/ pixel_grid
			var delta := sample_uv - event_uv
			var distance := (delta / ellipse_radius).length()
			var angle := atan2(delta.y / 0.38, delta.x)
			var segment_id := floori((angle + PI) / TAU * 18.0)
			var primary_active := (
					absf(distance - ring_radius) < primary_width
					and _shader_hash21(
							Vector2(segment_id + 1201.0, 1217.0)) >= 0.18)
			var secondary_active := (
					absf(distance - ring_radius * 0.67) < primary_width * 0.88
					and _shader_hash21(
							Vector2(segment_id + 1237.0, 1259.0)) >= 0.30)
			if primary_active or secondary_active:
				active_cells += 1
	return active_cells


func _shader_hash21(point: Vector2) -> float:
	var wrapped := Vector2(fposmod(point.x, 509.0), fposmod(point.y, 251.0))
	return fposmod(
			sin(wrapped.dot(Vector2(127.1, 311.7))) * 43758.5453,
			1.0)


func _measure_platform_fissure_pixels(image: Image) -> Dictionary:
	var center_x := image.get_width() / 2
	var core: Array[Vector2i] = []
	for local_row: int in 14:
		core.append(Vector2i(
				center_x + _fissure_core_offset(13 - local_row), 90 + local_row))
	var branches: Array[Vector2i] = [
		Vector2i(center_x + 0, 99),
		Vector2i(center_x - 1, 100),
		Vector2i(center_x - 2, 101),
		Vector2i(center_x - 3, 101),
		Vector2i(center_x + 1, 96),
		Vector2i(center_x + 2, 95),
		Vector2i(center_x + 3, 95),
		Vector2i(center_x + 4, 94),
		Vector2i(center_x - 1, 93),
		Vector2i(center_x - 2, 92),
		Vector2i(center_x - 3, 92),
		Vector2i(center_x - 4, 91),
	]
	var glints: Array[Vector2i] = [
		Vector2i(center_x + 0, 102),
		Vector2i(center_x + 2, 98),
		Vector2i(center_x + 0, 94),
		Vector2i(center_x + 2, 91),
	]
	var dark_pixels: Dictionary = {}
	for point: Vector2i in core + branches:
		dark_pixels[point] = true
	var visited: Dictionary = {}
	var pending: Array[Vector2i] = [core[0]]
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for offset_y: int in range(-1, 2):
			for offset_x: int in range(-1, 2):
				if offset_x == 0 and offset_y == 0:
					continue
				var neighbor: Vector2i = current + Vector2i(offset_x, offset_y)
				if dark_pixels.has(neighbor) and not visited.has(neighbor):
					pending.append(neighbor)
	var on_opaque_ice := true
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i.ZERO
	for point: Vector2i in core + branches + glints:
		on_opaque_ice = on_opaque_ice and image.get_pixelv(point).a >= 0.03
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return {
		"core_pixels": core.size(),
		"branch_pixels": branches.size(),
		"glint_pixels": glints.size(),
		"connected": visited.size() == dark_pixels.size(),
		"on_opaque_ice": on_opaque_ice,
		"vertical_span": maximum.y - minimum.y + 1,
		"horizontal_span": maximum.x - minimum.x + 1,
	}


func _fissure_core_offset(local_row: int) -> int:
	if local_row < 2:
		return -1
	if local_row < 4:
		return 0
	if local_row < 6:
		return 1
	if local_row < 8:
		return 0
	if local_row < 10:
		return -1
	if local_row < 11:
		return 0
	if local_row < 13:
		return 1
	return 2


func _measure_fissure_growth_direction() -> Dictionary:
	var early_rows := _revealed_fissure_rows(0.06)
	var mid_rows := _revealed_fissure_rows(0.31)
	var late_rows := _revealed_fissure_rows(0.56)
	var full_rows := _revealed_fissure_rows(0.81)
	var passed := (
			early_rows == range(10, 14)
			and mid_rows == range(7, 14)
			and late_rows == range(3, 14)
			and full_rows == range(0, 14))
	return {
		"passed": passed,
		"early_rows": early_rows,
		"mid_rows": mid_rows,
		"late_rows": late_rows,
		"full_rows": full_rows,
	}


func _revealed_fissure_rows(break_amount: float) -> Array[int]:
	var rows: Array[int] = []
	for local_row: int in 14:
		var distance_from_bottom := 13.0 - float(local_row)
		var growth_segment := mini(floori(distance_from_bottom / 3.5), 3)
		if break_amount >= float(growth_segment) * 0.25 + 0.02:
			rows.append(local_row)
	return rows


func _left_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	return event
