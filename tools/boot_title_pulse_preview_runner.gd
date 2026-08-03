extends Node

const OUTPUT_DIR := "D:/Game/BoBoZan/boot_title_flow_frames"
const CAPTURE_COUNT := 42
const FRAME_INTERVAL_SECONDS := 0.10
const TITLE_CROP := Rect2i(160, 130, 300, 820)


func _ready() -> void:
	var scene := load("res://src/ui/boot_screen.tscn") as PackedScene
	if scene == null:
		push_error("boot_screen.tscn could not be loaded.")
		get_tree().quit(1)
		return

	var boot := scene.instantiate()
	add_child(boot)
	await get_tree().process_frame

	var title_column := boot.get_node_or_null("TitleColumn") as Control
	if (
		title_column == null
		or not title_column.has_method(&"current_flow_phase")
	):
		push_error("Boot title engraving-flow controller could not be loaded.")
		get_tree().quit(1)
		return

	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if directory_error != OK:
		push_error(
			"Boot title engraving-flow frame directory could not be created.")
		get_tree().quit(1)
		return

	for index: int in CAPTURE_COUNT:
		await RenderingServer.frame_post_draw
		var viewport_image := get_viewport().get_texture().get_image()
		var cropped_image := viewport_image.get_region(TITLE_CROP)
		var output_path := "%s/frame_%02d.png" % [OUTPUT_DIR, index]
		var error := cropped_image.save_png(output_path)
		if error != OK:
			push_error(
				"Boot title engraving-flow frame could not be saved: %s"
				% output_path)
			get_tree().quit(1)
			return
		if index < CAPTURE_COUNT - 1:
			await get_tree().create_timer(FRAME_INTERVAL_SECONDS).timeout

	print(
		"BOOT_TITLE_FLOW_FRAMES_OK: %d interval=%.2f phase=%.4f"
		% [
			CAPTURE_COUNT,
			FRAME_INTERVAL_SECONDS,
			float(title_column.call(&"current_flow_phase")),
		])
	get_tree().quit()
