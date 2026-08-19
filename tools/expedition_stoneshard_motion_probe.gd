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

	screen.map.player = Vector2i(9, 7)
	screen.map._reveal_around(screen.map.player)
	screen._camera_initialized = false
	screen._refresh()
	await get_tree().create_timer(0.20).timeout
	await _shot("exped_stoneshard_idle.png")

	var move_result: Dictionary = screen.map.try_move(Vector2i.RIGHT)
	assert(bool(move_result.get("moved", false)))
	screen._refresh()
	await get_tree().create_timer(0.07).timeout
	await _shot("exped_stoneshard_step.png")

	await get_tree().create_timer(0.45).timeout
	await _shot("exped_stoneshard_land.png")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path: String = ProbeOutput.path(file_name)
	var error := get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("saved: ", output_path)
