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
	var intro := boot.get_node_or_null("IntroController")
	if intro != null:
		intro.call(&"finish_immediately")
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
	var pressure_contours := boot.get_node_or_null(
			"BackgroundStage/PressureContours") as ColorRect
	var gold_energy := boot.get_node_or_null(
			"BackgroundStage/GoldEnergy") as TextureRect
	var paper_base := boot.get_node_or_null(
			"BackgroundStage/PaperBase") as ColorRect
	if (
			background_stage == null
			or pressure_motion == null
			or blue_flow_motion == null
			or blue_mid == null
			or blue_light == null
			or pressure_contours == null
			or gold_energy == null
			or paper_base == null
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
	var contour_material := (
			pressure_contours.material as ShaderMaterial)
	var first_contour_shader_time := float(
			contour_material.get_shader_parameter(&"motion_time"))
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
	var captured_frames: Array[Image] = []
	for index: int in CAPTURE_COUNT:
		await RenderingServer.frame_post_draw
		var output_path := "%s/frame_%02d.png" % [OUTPUT_DIR, index]
		var captured_image := (
			get_viewport()
			.get_texture()
			.get_image())
		captured_frames.append(captured_image)
		var error := captured_image.save_png(output_path)
		if error != OK:
			push_error(
				"Boot background frame could not be saved: %s"
				% output_path)
			get_tree().quit(1)
			return
		if index < CAPTURE_COUNT - 1:
			await get_tree().create_timer(
					FRAME_INTERVAL_SECONDS).timeout

	var paper_material := paper_base.material as ShaderMaterial
	var original_paper_color: Color = paper_material.get_shader_parameter(
			&"paper_color")
	var validation_palettes: Array[Array] = [
		["beige", Color("#efe3ce")],
		["ink", Color("#1b2a41")],
		["near_black", Color("#080a0d")],
	]
	for palette: Array in validation_palettes:
		paper_material.set_shader_parameter(
				&"paper_color",
				palette[1])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var validation_path := "%s/mask_%s.png" % [
			OUTPUT_DIR,
			palette[0],
		]
		var validation_error := (
			get_viewport()
			.get_texture()
			.get_image()
			.save_png(validation_path))
		if validation_error != OK:
			push_error(
				"Boot mask validation frame could not be saved: %s"
				% validation_path)
			get_tree().quit(1)
			return
	paper_material.set_shader_parameter(
			&"paper_color",
			original_paper_color)

	var last_animation_time := float(
			pressure_motion.call(&"animation_time"))
	var last_blue_animation_time := float(
			blue_flow_motion.call(&"animation_time"))
	var last_contour_shader_time := float(
			contour_material.get_shader_parameter(&"motion_time"))
	var last_gold_shader_time: float = float(
			gold_material
			.get_shader_parameter(&"motion_time"))
	if last_animation_time <= first_animation_time:
		push_error("Boot pressure background animation did not advance.")
		get_tree().quit(1)
		return
	if last_blue_animation_time <= first_blue_animation_time:
		push_error("Boot graphite brush animation did not advance.")
		get_tree().quit(1)
		return
	if last_contour_shader_time <= first_contour_shader_time:
		push_error("Boot pressure waves did not advance outward.")
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
				"Boot graphite layer %s did not receive forward time."
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
	var gold_motion_metrics := _gold_motion_metrics(
			captured_frames[0],
			captured_frames[1])
	if (
			gold_motion_metrics.x < 4.0
			or gold_motion_metrics.y < 0.05
	):
		push_error(
			"Boot gold outer flow is not visibly advancing: %s"
			% gold_motion_metrics)
		get_tree().quit(1)
		return
	var left_depth_fraction := _left_depth_fraction(captured_frames[0])
	if left_depth_fraction < 0.035:
		push_error(
			"Boot left side still lacks visible depth structure: %.4f"
			% left_depth_fraction)
		get_tree().quit(1)
		return

	print(
			(
				"BOOT_BACKGROUND_FRAMES_OK: %d interval=%.2f "
				+ "animation=%.3f gold_delta=%.2f strong=%.3f "
				+ "left_depth=%.3f"
			)
			% [
				CAPTURE_COUNT,
				FRAME_INTERVAL_SECONDS,
				last_animation_time - first_animation_time,
				gold_motion_metrics.x,
				gold_motion_metrics.y,
				left_depth_fraction,
			])
	get_tree().quit()


func _gold_motion_metrics(
		first_frame: Image,
		second_frame: Image,
) -> Vector2:
	var delta_sum := 0.0
	var sample_count := 0
	var strong_delta_count := 0
	var x_start := int(first_frame.get_width() * 0.32)
	var x_end := int(first_frame.get_width() * 0.56)
	var y_start := int(first_frame.get_height() * 0.02)
	var y_end := int(first_frame.get_height() * 0.34)
	for y: int in range(y_start, y_end, 2):
		for x: int in range(x_start, x_end, 2):
			var first := first_frame.get_pixel(x, y)
			var second := second_frame.get_pixel(x, y)
			if not (_is_gold_pixel(first) or _is_gold_pixel(second)):
				continue
			var delta := (
					absf(first.r - second.r)
					+ absf(first.g - second.g)
					+ absf(first.b - second.b)
				) / 3.0 * 255.0
			delta_sum += delta
			sample_count += 1
			if delta > 12.0:
				strong_delta_count += 1
	if sample_count <= 0:
		return Vector2.ZERO
	return Vector2(
			delta_sum / float(sample_count),
			float(strong_delta_count) / float(sample_count))


func _is_gold_pixel(color: Color) -> bool:
	return color.r > 0.51 and color.g > 0.27 and color.b < 0.51


func _left_depth_fraction(frame: Image) -> float:
	var structured_count := 0
	var sample_count := 0
	var x_end := int(frame.get_width() * 0.38)
	var y_start := int(frame.get_height() * 0.50)
	var y_end := int(frame.get_height() * 0.92)
	for y: int in range(y_start, y_end, 4):
		for x: int in range(12, x_end, 4):
			var color := frame.get_pixel(x, y)
			var luminance := (
					color.r * 0.299
					+ color.g * 0.587
					+ color.b * 0.114)
			if luminance > 0.055 and luminance < 0.24:
				structured_count += 1
			sample_count += 1
	if sample_count <= 0:
		return 0.0
	return float(structured_count) / float(sample_count)
