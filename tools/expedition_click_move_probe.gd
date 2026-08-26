extends SceneTree

## 无截图验收：验证远征左键选格会经过地图状态逐格移动。

const HeroDataScript := preload("res://src/battle/hero_data.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://src/expedition/expedition_screen.tscn") as PackedScene
	if packed == null:
		_fail("scene load failed")
		return
	var screen := packed.instantiate()
	root.add_child(screen)
	await process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[0])
	await process_frame

	var start: Vector2i = screen.map.player
	var target := Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if screen._is_walkable_map_cell(start + direction):
			target = start + direction
			break
	if target == Vector2i(-1, -1):
		_fail("no walkable neighbor at start")
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen._map_view_position_for_cell(target)
	if screen._cell_from_map_view_position(click.position) != target:
		_fail("view-to-cell conversion mismatch")
		return
	var hover := InputEventMouseMotion.new()
	hover.position = click.position
	screen._on_map_view_gui_input(hover)
	await process_frame
	var route_contract: Dictionary = GridRoutePreview.get_style_contract()
	if String(route_contract.get("implementation", "")) \
			!= "full_route_alternating_footprint_stream":
		_fail("route preview is not using the full-route footprint stream")
		return
	if not bool(route_contract.get("uses_footprints", false)) \
			or not bool(route_contract.get("alternates_left_right", false)) \
			or not bool(route_contract.get("covers_full_route", false)) \
			or not bool(route_contract.get("count_scales_with_route_length", false)) \
			or bool(route_contract.get("uses_fixed_visible_count", true)) \
			or bool(route_contract.get("uses_footprint_count_cap", true)) \
			or not bool(route_contract.get("moves_continuously_forward", false)) \
			or float(route_contract.get("stream_speed_cells_per_second", 1.0)) >= 0.55 \
			or not bool(route_contract.get("uses_distance_sampling", false)) \
			or bool(route_contract.get("uses_loop_gap", true)) \
			or bool(route_contract.get("fills_every_path_cell", true)) \
			or bool(route_contract.get("lights_individual_footprints", true)) \
			or bool(route_contract.get("uses_ground_shadow", true)) \
			or bool(route_contract.get("uses_inner_core", true)) \
			or bool(route_contract.get("uses_glow", true)) \
			or bool(route_contract.get("uses_inset_edge_bars", true)) \
			or bool(route_contract.get("uses_arrows", true)) \
			or bool(route_contract.get("uses_continuous_ribbon", true)) \
			or bool(route_contract.get("uses_chevrons", true)) \
			or bool(route_contract.get("uses_toe_details", true)):
		_fail("route preview still uses a rejected route family")
		return
	if screen._hovered_map_cell != target or screen._hovered_map_path.is_empty():
		_fail("continuous footprint stream did not receive the hover route")
		return
	var runtime_route_cells: Array[Vector2i] = [start]
	runtime_route_cells.append_array(screen._hovered_map_path)
	var runtime_footprints_a: Array[Dictionary] = \
			GridRoutePreview.build_stream_footprints(runtime_route_cells, 120.0, 0.0)
	var runtime_footprints_b: Array[Dictionary] = \
			GridRoutePreview.build_stream_footprints(runtime_route_cells, 120.0, 0.25)
	if runtime_footprints_a.is_empty():
		_fail("expedition full-route footprint stream is empty")
		return
	if runtime_footprints_a.size() != runtime_footprints_b.size():
		_fail("expedition footprint stream changes count during ordinary motion")
		return
	var long_route_cells: Array[Vector2i] = []
	for route_index: int in 10:
		long_route_cells.append(Vector2i(route_index, 0))
	if GridRoutePreview.build_stream_footprints(
			long_route_cells, 120.0, 0.0).size() <= runtime_footprints_a.size():
		_fail("expedition footprint count does not scale with route length")
		return
	for index: int in runtime_footprints_a.size():
		var footprint_a: Dictionary = runtime_footprints_a[index]
		var footprint_b: Dictionary = runtime_footprints_b[index]
		var parts: Array[PackedVector2Array] = footprint_a["parts"]
		if parts.size() != 2 or parts[0].size() != 6 or parts[1].size() != 4:
			_fail("expedition footprint does not use the forefoot and heel sole")
			return
		if int(footprint_a["stream_index"]) != int(footprint_b["stream_index"]) \
				or float(footprint_b["path_distance"]) \
				<= float(footprint_a["path_distance"]):
			_fail("expedition footprint train does not move continuously forward")
			return
	screen._on_map_view_gui_input(click)
	var movement_deadline: int = Time.get_ticks_msec() + 3000
	while (screen.map.player != target or screen._click_route_active) \
			and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if screen.map.player != target or screen.map.steps != 1:
		_fail("click route did not use one map step")
		return
	print("EXPEDITION_CLICK_MOVE_PROBE_OK ", JSON.stringify({
		"start": start,
		"target": target,
		"steps": screen.map.steps,
		"camera_settled": not screen._camera_is_moving(),
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error("EXPEDITION_CLICK_MOVE_PROBE: %s" % message)
	quit(1)
