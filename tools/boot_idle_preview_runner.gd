extends Node

const OUTPUT_DIR := "D:/Game/BoBoZan/boot_idle_frames"
const CAPTURE_COUNT := 17
const CAPTURE_DURATION := 9.0
const POINTER_SAMPLES := {
	"center": Vector2.ZERO,
	"left": Vector2(-1.0, 0.0),
	"right": Vector2(1.0, 0.0),
	"upper_right": Vector2(1.0, -1.0),
	"lower_left": Vector2(-1.0, 1.0),
}


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
	var character := boot.get_node_or_null(
			"Character") as BootCharacterIdle
	var intro := boot.get_node_or_null("IntroController")
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
			or character == null
			or intro == null
			or waist_screen_left_pivot == null
			or waist_screen_right_pivot == null):
		push_error("Boot idle animations have an invalid length.")
		get_tree().quit(1)
		return
	intro.call(&"preview_at_time", 9.0)

	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if directory_error != OK:
		push_error("Boot idle frame directory could not be created.")
		get_tree().quit(1)
		return

	animation_player.pause()
	waist_animation_player.pause()
	for index: int in CAPTURE_COUNT:
		var capture_time := (
			CAPTURE_DURATION
			* float(index)
			/ float(CAPTURE_COUNT - 1))
		character.call(&"preview_idle_at_time", capture_time)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/frame_%02d.png" % [OUTPUT_DIR, index]
		var error := get_viewport().get_texture().get_image().save_png(output_path)
		if error != OK:
			push_error("Boot idle frame could not be saved: %s" % output_path)
			get_tree().quit(1)
			return

	character.call(&"preview_idle_at_time", 4.5)
	for sample_name: String in POINTER_SAMPLES:
		character.call(
			&"preview_pointer_response",
			POINTER_SAMPLES[sample_name])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pointer_output_path := (
			"%s/pointer_%s.png" % [OUTPUT_DIR, sample_name])
		var pointer_error := (
			get_viewport().get_texture().get_image().save_png(
				pointer_output_path))
		if pointer_error != OK:
			push_error(
				"Boot pointer frame could not be saved: %s"
				% pointer_output_path)
			get_tree().quit(1)
			return

	print(
			"BOOT_IDLE_FRAMES_OK: %d duration=%.2f pointer=%d"
			% [CAPTURE_COUNT, CAPTURE_DURATION, POINTER_SAMPLES.size()])
	get_tree().quit()
