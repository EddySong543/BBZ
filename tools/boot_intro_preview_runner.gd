extends Node

const OUTPUT_DIR := "D:/Game/BoBoZan/boot_intro_runtime_frames"
const BOOT_SCREEN_PATH := "res://src/ui/boot_screen.tscn"


func _ready() -> void:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	if packed == null:
		push_error("Boot screen could not be loaded.")
		get_tree().quit(1)
		return

	var boot := packed.instantiate() as Control
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame

	var intro := boot.get_node_or_null(
		"IntroController") as BootIntroController
	var prompt := boot.get_node_or_null("EnterPrompt") as BootEnterPrompt
	var star := boot.get_node_or_null(
		"Character/Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	var stage := boot.get_node_or_null("BackgroundStage") as Control
	var black_base := boot.get_node_or_null(
		"IntroBlackBase") as ColorRect
	var blue_mid := boot.get_node_or_null(
		"BackgroundStage/BlueMid") as TextureRect
	var gold := boot.get_node_or_null(
		"BackgroundStage/GoldEnergy") as TextureRect
	var contours := boot.get_node_or_null(
		"BackgroundStage/PressureContours") as ColorRect
	var title := boot.get_node_or_null(
		"TitleColumn/BoTop") as TextureRect
	var english := boot.get_node_or_null(
		"TitleColumn/EnglishSubtitle") as TextureRect
	var character_base := boot.get_node_or_null(
		"Character/Rig/Base") as Sprite2D
	var title_controller := boot.get_node_or_null(
		"TitleColumn") as BootTitleController
	if (
		intro == null
		or prompt == null
		or star == null
		or stage == null
		or black_base == null
		or blue_mid == null
		or gold == null
		or contours == null
		or title == null
		or english == null
		or character_base == null
		or title_controller == null
	):
		push_error("Boot intro runtime nodes are incomplete.")
		get_tree().quit(1)
		return

	if intro.flash_count() != 1:
		push_error("Boot intro does not contain exactly one star flash.")
		get_tree().quit(1)
		return
	if boot.get_node_or_null("TitleColumn/TitleBladeLight") != null:
		push_error("Boot title still contains the rejected blade layer.")
		get_tree().quit(1)
		return
	if not (
		is_equal_approx(
			intro.flash_start_seconds,
			0.04)
		and is_equal_approx(
			intro.brush_start_seconds,
			0.12)
		and is_equal_approx(
			intro.gold_start_seconds,
			intro.brush_start_seconds)
		and is_equal_approx(
			intro.prompt_start_seconds,
			intro.title_start_seconds)
		and is_equal_approx(
			intro.total_duration_seconds,
			1.32)
		and is_equal_approx(
			intro.brush_duration_seconds,
			0.72)
		and is_equal_approx(
			intro.gold_duration_seconds,
			0.92)
		and is_equal_approx(
			intro.pressure_start_seconds,
			0.28)
		and is_equal_approx(
			intro.pressure_duration_seconds,
			0.70)
		and is_equal_approx(
			intro.title_start_seconds,
			intro.brush_start_seconds)
		and is_equal_approx(
			intro.title_duration_seconds,
			0.76)
		and is_equal_approx(
			intro.prompt_duration_seconds,
			0.94)
		and is_equal_approx(
			intro.impact_propagation_start_seconds,
			0.18)
		and is_equal_approx(
			intro.impact_propagation_end_seconds,
			0.88)
		and is_equal_approx(
			intro.impact_propagation_lead_seconds,
			0.12)
		and is_equal_approx(
			intro.impact_support_lead_seconds,
			0.06)
	):
		push_error("Boot intro timing contract drifted.")
		get_tree().quit(1)
		return

	var directory_error := DirAccess.make_dir_recursive_absolute(
		OUTPUT_DIR)
	if directory_error != OK:
		push_error("Boot intro frame directory could not be created.")
		get_tree().quit(1)
		return

	var capture_points: Array[Array] = [
		["00_character_ready", 0.0],
		["01_energy_trigger", 0.18],
		["02_impact_propagation", 0.30],
		["03_impact_body", 0.48],
		["03b_gold_contact_check", 0.68],
		["04_clean_lock", 0.88],
		[
			"05_brush_mid",
			intro.brush_start_seconds
				+ intro.brush_duration_seconds * 0.50,
		],
		[
			"06_parallel_placed",
			maxf(
				intro.brush_start_seconds
					+ intro.brush_duration_seconds,
				intro.gold_start_seconds
					+ intro.gold_duration_seconds)
				+ 0.02,
		],
		[
			"07_parallel_entry",
			intro.title_start_seconds
				+ intro.title_duration_seconds * 0.45,
		],
		["08_idle", intro.total_duration_seconds],
	]

	var captured_frames: Dictionary = {}
	for capture_point: Array in capture_points:
		intro.preview_at_time(float(capture_point[1]))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/%s.png" % [
			OUTPUT_DIR,
			String(capture_point[0]),
		]
		var captured_image := (
			get_viewport()
			.get_texture()
			.get_image())
		captured_frames[String(capture_point[0])] = captured_image
		var save_error := captured_image.save_png(output_path)
		if save_error != OK:
			push_error(
				"Boot intro frame could not be saved: %s"
				% output_path)
			get_tree().quit(1)
			return

	intro.finish_immediately()
	title_controller.set_process(false)
	for pointer_capture: Array in [
		["09_title_pointer_left", Vector2(-1.0, 0.0)],
		["10_title_pointer_right", Vector2(1.0, 0.0)],
		["11_title_pointer_upper", Vector2(0.0, -1.0)],
	]:
		title_controller.preview_pointer_tilt(pointer_capture[1])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pointer_image := get_viewport().get_texture().get_image()
		var pointer_path := "%s/%s.png" % [
			OUTPUT_DIR,
			String(pointer_capture[0]),
		]
		if pointer_image.save_png(pointer_path) != OK:
			push_error("Boot pointer-title frame could not be saved.")
			get_tree().quit(1)
			return
	title_controller.preview_pointer_tilt(Vector2.ZERO)

	if black_base.color != Color.BLACK:
		push_error("Boot intro black base is not pure black.")
		get_tree().quit(1)
		return
	if _lit_fraction(
			captured_frames["00_character_ready"] as Image) < 0.02:
		push_error("Boot intro initial character is not visible.")
		get_tree().quit(1)
		return

	intro.preview_at_time(0.0)
	if (
		not is_equal_approx(
			_shader_float(
				character_base,
				&"intro_light_progress"),
			1.0)
		or not is_equal_approx(stage.modulate.a, 1.0)
		or _shader_float(blue_mid, &"intro_stroke_progress") > 0.001
		or _shader_float(gold, &"intro_path_progress") > 0.001
		or _shader_float(title, &"intro_reveal_progress") > 0.001
		or prompt.visible
	):
		push_error("Boot initial character-only frame drifted.")
		get_tree().quit(1)
		return

	intro.preview_at_time(
		intro.brush_start_seconds
			+ intro.brush_duration_seconds * 0.25)
	for item_and_parameter: Array in [
		[blue_mid, &"intro_stroke_progress"],
		[gold, &"intro_path_progress"],
	]:
		if _shader_float(
			item_and_parameter[0],
			item_and_parameter[1]) <= 0.0:
			push_error("A Boot brush-impact reveal did not start.")
			get_tree().quit(1)
			return
	if (
		_shader_float(title, &"intro_reveal_progress") <= 0.0
		or _shader_float(english, &"intro_reveal_progress") <= 0.0
		or not prompt.visible
	):
		push_error("Boot title did not start with the brush impact.")
		get_tree().quit(1)
		return
	var quarter_brush_progress := _shader_float(
		blue_mid,
		&"intro_stroke_progress")
	var quarter_gold_progress := _shader_float(
		gold,
		&"intro_path_progress")
	if (
		quarter_brush_progress <= 0.08
		or quarter_brush_progress >= 0.30
		or quarter_gold_progress <= 0.0
		or quarter_gold_progress >= quarter_brush_progress
		or _shader_float(star, &"intro_pulse_enabled") > 0.001
		or not boot.scale.is_equal_approx(Vector2.ONE)
		or not boot.position.is_equal_approx(Vector2.ZERO)
	):
		push_error(
			"Boot layered reveal lost its visible phase separation.")
		get_tree().quit(1)
		return

	intro.preview_at_time(
		intro.pressure_start_seconds
			+ intro.pressure_duration_seconds * 0.5)
	var pressure_opacity := _shader_float(
		contours,
		&"intro_opacity")
	if pressure_opacity <= 0.0 or pressure_opacity >= 1.0:
		push_error("Boot pressure contours are not fading in place.")
		get_tree().quit(1)
		return

	intro.preview_at_time(
		maxf(
			intro.brush_start_seconds
				+ intro.brush_duration_seconds,
			intro.gold_start_seconds
				+ intro.gold_duration_seconds)
			+ 0.02)
	if (
		_shader_float(blue_mid, &"intro_stroke_progress") < 0.999
		or _shader_float(gold, &"intro_path_progress") < 0.999
		or _shader_float(title, &"intro_reveal_progress") < 0.999
		or not prompt.visible
	):
		push_error("Boot parallel layers did not settle together.")
		get_tree().quit(1)
		return

	intro.preview_at_time(
		intro.title_start_seconds
			+ intro.title_duration_seconds * 0.45)
	var title_entry_progress := _shader_float(
		title,
		&"intro_reveal_progress")
	var title_material := title.material as ShaderMaterial
	var english_material := english.material as ShaderMaterial
	if (
		title_entry_progress <= 0.0
		or title_entry_progress >= 1.0
		or title_material.get_shader_parameter(
			&"intro_activation_map") == null
		or not is_equal_approx(
			_shader_float(english, &"intro_reveal_progress"),
			title_entry_progress)
		or english_material.get_shader_parameter(
			&"intro_activation_map") == null
		or not is_equal_approx(
			_shader_float(english, &"intro_progress_delay"),
			0.052632)
		or title_material.shader.code.contains("blade_coordinate")
		or not prompt.visible
		or prompt.modulate.a <= 0.0
	):
		push_error("Boot title, subtitle, and prompt are not synchronized.")
		get_tree().quit(1)
		return

	intro.finish_immediately()
	await get_tree().process_frame
	if not boot.can_enter() or not prompt.visible:
		push_error("Boot intro did not restore the idle input contract.")
		get_tree().quit(1)
		return

	boot.queue_free()
	await get_tree().process_frame
	var runtime_boot := packed.instantiate() as Control
	add_child(runtime_boot)
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime_intro := runtime_boot.get_node_or_null(
		"IntroController") as BootIntroController
	var runtime_prompt := runtime_boot.get_node_or_null(
		"EnterPrompt") as BootEnterPrompt
	if runtime_intro == null or runtime_prompt == null:
		push_error("Boot continuous intro nodes are incomplete.")
		get_tree().quit(1)
		return

	var playback_started_msec := Time.get_ticks_msec()
	await get_tree().create_timer(0.90).timeout
	var locked_click := InputEventMouseButton.new()
	locked_click.button_index = MOUSE_BUTTON_LEFT
	locked_click.button_mask = MOUSE_BUTTON_MASK_LEFT
	locked_click.pressed = true
	locked_click.position = Vector2(400.0, 400.0)
	locked_click.global_position = locked_click.position
	Input.parse_input_event(locked_click)
	await get_tree().process_frame
	if (
		runtime_boot.can_enter()
		or TransitionManager.is_busy()
		or not runtime_prompt.visible
	):
		push_error(
			"Boot intro input lock or synchronized prompt contract failed.")
		get_tree().quit(1)
		return

	await runtime_intro.intro_finished
	await get_tree().process_frame
	var playback_seconds := (
		float(Time.get_ticks_msec() - playback_started_msec)
		/ 1000.0)
	if (
		playback_seconds < 1.15
		or playback_seconds > 1.60
		or not runtime_boot.can_enter()
		or not runtime_prompt.visible
	):
		push_error(
			"Boot continuous playback contract failed: %.3f"
			% playback_seconds)
		get_tree().quit(1)
		return

	print(
		"BOOT_INTRO_V8_FRAMES_OK: character_ready=true "
		+ "layered_impact_entry=true pulse=false "
		+ "flash_start=%.2f "
		% runtime_intro.flash_start_seconds
		+ "duration=%.2f playback=%.3f frames=%d"
		% [
			runtime_intro.total_duration_seconds,
			playback_seconds,
			capture_points.size(),
		])
	get_tree().quit()


func _shader_float(
	item: CanvasItem,
	parameter: StringName,
) -> float:
	var material := item.material as ShaderMaterial
	if material == null:
		return 0.0
	var value: Variant = material.get_shader_parameter(parameter)
	if value == null:
		return 0.0
	return float(value)


func _lit_fraction(frame: Image) -> float:
	var lit_count := 0
	var sample_count := 0
	for y: int in range(0, frame.get_height(), 4):
		for x: int in range(0, frame.get_width(), 4):
			if _luminance(frame.get_pixel(x, y)) > 0.01:
				lit_count += 1
			sample_count += 1
	if sample_count <= 0:
		return 0.0
	return float(lit_count) / float(sample_count)


func _luminance(color: Color) -> float:
	return (
		color.r * 0.299
		+ color.g * 0.587
		+ color.b * 0.114)
