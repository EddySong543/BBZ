extends Node

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")

const PREVIEW_OPTIONS: Array[Dictionary] = [
	{"id": "26x15", "columns": 26, "rows": 15},
	{"id": "28x16", "columns": 28, "rows": 16},
	{"id": "30x17", "columns": 30, "rows": 17},
	{"id": "32x18", "columns": 32, "rows": 18},
]


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.35).timeout
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().create_timer(0.35).timeout

	screen.map.player = Vector2i(16, 9)
	screen.map._reveal_around(screen.map.player)
	screen._camera_initialized = false
	screen._refresh()
	await get_tree().create_timer(0.20).timeout
	screen.camera_follow_enabled = false

	for option: Dictionary in PREVIEW_OPTIONS:
		_apply_density(screen, int(option["columns"]), int(option["rows"]))
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot("exped_density_%s.png" % String(option["id"]))
	get_tree().quit()


func _apply_density(screen: Control, columns: int, rows: int) -> void:
	var cell_screen_px: float = minf(1920.0 / float(columns), 1080.0 / float(rows))
	var world_scale: float = cell_screen_px / float(screen.MAP_CELL)
	screen.map_world.scale = Vector2.ONE * world_scale

	# 只比较格子密度；人物保持当前正式版本的72px屏幕画布。
	var desired_token_screen_scale: float = screen.TOKEN_RENDER_COMPENSATION * screen.MAP_RENDER_SCALE
	var token_local_scale: float = desired_token_screen_scale / world_scale
	var facing_sign: float = screen._player_facing_sign
	screen.player_token.scale = Vector2(token_local_scale * facing_sign, token_local_scale)

	var token_center_world: Vector2 = (
			screen._token_origin_for_cell(screen.map.player) + screen.TOKEN_SIZE * 0.5)
	var desired_offset: Vector2 = screen.MAP_VIEW_SIZE * 0.5 - token_center_world * world_scale
	var rendered_map_size: Vector2 = screen.MAP_WORLD_SIZE * world_scale
	var minimum_offset: Vector2 = screen.MAP_VIEW_SIZE - rendered_map_size
	screen.map_world.position = Vector2(
			clampf(desired_offset.x, minf(minimum_offset.x, 0.0), 0.0),
			clampf(desired_offset.y, minf(minimum_offset.y, 0.0), 0.0)
	).round()

	# 保持晴风光照为屏幕空间，不让密度预览改变云影位置。
	if screen.atmosphere_layer != null:
		screen.atmosphere_layer.position = -screen.map_world.position / world_scale
		screen.atmosphere_layer.size = screen.MAP_VIEW_SIZE / world_scale


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path: String = ProbeOutput.path(file_name)
	var error: Error = get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("saved: ", output_path)
