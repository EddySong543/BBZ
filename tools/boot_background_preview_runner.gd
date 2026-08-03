extends Node

const OUTPUT_DIR := "D:/Game/BoBoZan/boot_background_runtime_frames"
const CAPTURE_COUNT := 3
const FRAME_INTERVAL_SECONDS := 2.5


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

	var background_stage := boot.get_node_or_null(
			"BackgroundStage") as BattleStage
	var pressure_motion := boot.get_node_or_null(
			"BackgroundStage/PressureMotion")
	var blue_flow_motion := boot.get_node_or_null(
			"BackgroundStage/BlueFlowMotion")
	var blue_mid := boot.get_node_or_null(
			"BackgroundStage/BlueMid") as TextureRect
	var blue_light := boot.get_node_or_null(
			"BackgroundStage/BlueLight") as TextureRect
	var gold_energy := boot.get_node_or_null(
			"BackgroundStage/GoldEnergy") as TextureRect
	if (
			background_stage == null
			or pressure_motion == null
			or blue_flow_motion == null
			or blue_mid == null
			or blue_light == null
			or gold_energy == null
	):
		push_error("Boot pressure background could not be loaded.")
		get_tree().quit(1)
		return
	if not background_stage.pointer_parallax:
		push_error("Boot pressure background pointer parallax is disabled.")
		get_tree().quit(1)
		return

	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if directory_error != OK:
		push_error(
			"Boot background frame directory could not be created.")
		get_tree().quit(1)
		return

	var first_animation_time := float(
			pressure_motion.call(&"animation_time"))
	var first_blue_animation_time := float(
			blue_flow_motion.call(&"animation_time"))
	var gold_material := gold_energy.material as ShaderMaterial
	var flow_texture := gold_material.get_shader_parameter(
			&"flow_texture") as Texture2D
	if flow_texture == null:
		push_error("Boot gold energy is missing its flow map.")
		get_tree().quit(1)
		return
	var first_gold_shader_time: float = float(
			gold_material
			.get_shader_parameter(&"motion_time"))
	for index: int in CAPTURE_COUNT:
		await RenderingServer.frame_post_draw
		var output_path := "%s/frame_%02d.png" % [OUTPUT_DIR, index]
		var error := (
			get_viewport()
			.get_texture()
			.get_image()
			.save_png(output_path))
		if error != OK:
			push_error(
				"Boot background frame could not be saved: %s"
				% output_path)
			get_tree().quit(1)
			return
		if index < CAPTURE_COUNT - 1:
			await get_tree().create_timer(
					FRAME_INTERVAL_SECONDS).timeout

	var last_animation_time := float(
			pressure_motion.call(&"animation_time"))
	var last_blue_animation_time := float(
			blue_flow_motion.call(&"animation_time"))
	var last_gold_shader_time: float = float(
			gold_material
			.get_shader_parameter(&"motion_time"))
	if last_animation_time <= first_animation_time:
		push_error("Boot pressure background animation did not advance.")
		get_tree().quit(1)
		return
	if last_blue_animation_time <= first_blue_animation_time:
		push_error("Boot blue flow animation did not advance.")
		get_tree().quit(1)
		return
	for blue_layer: TextureRect in [blue_mid, blue_light]:
		var blue_material := blue_layer.material as ShaderMaterial
		if (
				float(blue_material.get_shader_parameter(
						&"motion_time"))
				<= first_blue_animation_time
		):
			push_error(
				"Boot blue layer %s did not receive forward time."
				% blue_layer.name)
			get_tree().quit(1)
			return
	if not is_zero_approx(gold_energy.rotation):
		push_error("Boot gold energy should remain anchored.")
		get_tree().quit(1)
		return
	if last_gold_shader_time <= first_gold_shader_time:
		push_error("Boot local gold energy shader did not advance.")
		get_tree().quit(1)
		return

	print(
			"BOOT_BACKGROUND_FRAMES_OK: %d interval=%.2f animation=%.3f"
			% [
				CAPTURE_COUNT,
				FRAME_INTERVAL_SECONDS,
				last_animation_time - first_animation_time,
			])
	get_tree().quit()
