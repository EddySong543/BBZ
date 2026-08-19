extends Node

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const QingfengLayout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.4).timeout
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().create_timer(0.4).timeout
	screen.map.player = QingfengLayout.START
	screen.map._reveal_around(QingfengLayout.START)
	screen._camera_initialized = false
	screen._refresh()
	await get_tree().create_timer(0.25).timeout
	await _shot("exped_teleport_occupied_a.png")
	await get_tree().create_timer(0.48).timeout
	await _shot("exped_teleport_occupied_b.png")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path: String = ProbeOutput.path(file_name)
	get_viewport().get_texture().get_image().save_png(output_path)
	print("saved: ", output_path)
