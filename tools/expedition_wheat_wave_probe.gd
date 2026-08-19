extends Node

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const OUT_BEFORE := "D:/Game/BoBoZan/_probe_output/exped_wheat_wave_before.png"
const OUT_EARLY := "D:/Game/BoBoZan/_probe_output/exped_wheat_wave_early.png"
const OUT_PEAK := "D:/Game/BoBoZan/_probe_output/exped_wheat_wave_peak.png"
const OUT_SPREAD := "D:/Game/BoBoZan/_probe_output/exped_wheat_wave_spread.png"
const OUT_SETTLED := "D:/Game/BoBoZan/_probe_output/exped_wheat_wave_settled.png"


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
	# Put the actor on a connected southern rice patch and remove atmosphere so
	# the probe isolates authored pixels and the response overlay.
	screen.map.player = Vector2i(4, 11)
	for y: int in screen.MapState.HEIGHT:
		for x: int in screen.MapState.WIDTH:
			screen.map.visible[Vector2i(x, y)] = true
	screen._camera_initialized = false
	screen.atmosphere_layer.visible = false
	screen._refresh()
	await get_tree().create_timer(0.12).timeout
	await _shot(OUT_BEFORE)
	screen._trigger_wheat_wave(Vector2i(5, 11), Vector2i(4, 11), Vector2i.LEFT)
	await get_tree().create_timer(0.16).timeout
	await _shot(OUT_EARLY)
	await get_tree().create_timer(0.20).timeout
	await _shot(OUT_PEAK)
	await get_tree().create_timer(0.24).timeout
	await _shot(OUT_SPREAD)
	await get_tree().create_timer(0.64).timeout
	await _shot(OUT_SETTLED)
	print("WHEAT_WAVE_PULSES_AFTER_SETTLE=", screen._wheat_wave_pulses.size())
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
