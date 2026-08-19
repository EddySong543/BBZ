extends Node

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")


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
	await _shot("exped_map32_ground_only_start.png")

	screen.map.player = Vector2i(16, 9)
	screen.map._reveal_around(screen.map.player)
	screen._camera_initialized = false
	screen._refresh()
	await get_tree().create_timer(0.20).timeout
	await _shot("exped_grid32_vision_idle.png")

	var left_result: Dictionary = screen.map.try_move(Vector2i.LEFT)
	assert(bool(left_result.get("moved", false)))
	screen._queued_move_direction = Vector2i.LEFT
	screen._refresh()
	await get_tree().create_timer(0.05).timeout
	await _shot("exped_grid32_turn_left_squeeze.png")

	# 左转尚未结束就向上：上下步只沿用当前屏幕朝向，不得被斜向插值误判成回头。
	var up_result: Dictionary = screen.map.try_move(Vector2i.UP)
	assert(bool(up_result.get("moved", false)))
	screen._queued_move_direction = Vector2i.UP
	screen._refresh()
	await get_tree().create_timer(0.11).timeout
	await _shot("exped_grid32_vertical_keeps_facing.png")
	await get_tree().create_timer(0.45).timeout

	var right_result: Dictionary = screen.map.try_move(Vector2i.RIGHT)
	assert(bool(right_result.get("moved", false)))
	screen._queued_move_direction = Vector2i.RIGHT
	screen._refresh()
	await get_tree().create_timer(0.13).timeout
	await _shot("exped_grid32_turn_right.png")
	await get_tree().create_timer(0.45).timeout
	await _shot("exped_grid32_vision_land.png")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path: String = ProbeOutput.path(file_name)
	var error: Error = get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("saved: ", output_path)
