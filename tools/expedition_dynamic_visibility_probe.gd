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
	screen.set_process(false)

	screen.map.player = Vector2i(15, 9)
	screen.map._reveal_around(screen.map.player)
	screen._camera_initialized = false
	screen._refresh()
	await get_tree().process_frame
	await _shot("exped_dynamic_visibility_start.png")

	screen._queued_move_direction = Vector2i.RIGHT
	screen.map.player = Vector2i(16, 9)
	screen.map._reveal_around(screen.map.player)
	screen._refresh()
	_print_centers(screen, "after_logic_update")
	for frame: int in 5:
		screen._step_camera_follow(1.0 / 60.0)
	await get_tree().process_frame
	_print_centers(screen, "mid_step")
	await _shot("exped_dynamic_visibility_mid.png")

	for frame: int in 115:
		screen._step_camera_follow(1.0 / 60.0)
	await get_tree().process_frame
	_print_centers(screen, "settled")
	await _shot("exped_dynamic_visibility_end.png")
	get_tree().quit()


func _print_centers(screen: Control, phase: String) -> void:
	print("VISIBILITY_CENTER ", phase,
			" visual=", screen.terrain_mat.get_shader_parameter("vision_center_cell"),
			" logical=", screen.terrain_mat.get_shader_parameter("vision_logic_center_cell"),
			" camera=", screen.map_world.position)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path: String = ProbeOutput.path(file_name)
	var error: Error = get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("saved: ", output_path)
