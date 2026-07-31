extends Node

const OUTPUT_DIR := "D:/Game/BoBoZan/boot_idle_frames"
const CAPTURE_COUNT := 17


func _ready() -> void:
	var scene := load("res://src/ui/boot_screen.tscn") as PackedScene
	if scene == null:
		push_error("boot_screen.tscn could not be loaded.")
		get_tree().quit(1)
		return

	var boot := scene.instantiate()
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame

	var animation_player := boot.get_node_or_null(
			"Character/AnimationPlayer") as AnimationPlayer
	var waist_animation_player := boot.get_node_or_null(
			"Character/WaistAnimationPlayer") as AnimationPlayer
	if animation_player == null or not animation_player.has_animation(&"idle"):
		push_error("Boot idle animation could not be loaded.")
		get_tree().quit(1)
		return
	if (
			waist_animation_player == null
			or not waist_animation_player.has_animation(&"waist_idle")):
		push_error("Boot waist idle animation could not be loaded.")
		get_tree().quit(1)
		return
	var idle := animation_player.get_animation(&"idle")
	var waist_idle := waist_animation_player.get_animation(&"waist_idle")
	var waist_screen_left_pivot := boot.get_node_or_null(
			"Character/Rig/WaistScreenLeftPivot") as Node2D
	var waist_screen_right_pivot := boot.get_node_or_null(
			"Character/Rig/WaistScreenRightPivot") as Node2D
	if (
			idle == null
			or idle.length <= 0.0
			or waist_idle == null
			or waist_idle.length <= 0.0
			or waist_screen_left_pivot == null
			or waist_screen_right_pivot == null):
		push_error("Boot idle animations have an invalid length.")
		get_tree().quit(1)
		return

	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if directory_error != OK:
		push_error("Boot idle frame directory could not be created.")
		get_tree().quit(1)
		return

	animation_player.pause()
	waist_animation_player.pause()
	animation_player.seek(0.0, true)
	for index: int in CAPTURE_COUNT:
		var capture_time := (
			waist_idle.length
			* float(index)
			/ float(CAPTURE_COUNT - 1))
		waist_animation_player.seek(capture_time, true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/frame_%02d.png" % [OUTPUT_DIR, index]
		var error := get_viewport().get_texture().get_image().save_png(output_path)
		if error != OK:
			push_error("Boot idle frame could not be saved: %s" % output_path)
			get_tree().quit(1)
			return

	print(
			"BOOT_WAIST_FRAMES_OK: %d length=%.2f"
			% [CAPTURE_COUNT, waist_idle.length])
	get_tree().quit()
