extends Node

const OUTPUT_PATH := (
	"D:/Game/BoBoZan/boot_background_runtime_frames/"
	+ "enter_feedback.png")
const PEAK_OUTPUT_PATH := (
	"D:/Game/BoBoZan/boot_background_runtime_frames/"
	+ "enter_prompt_peak.png")
const EXIT_MID_OUTPUT_PATH := (
	"D:/Game/BoBoZan/boot_background_runtime_frames/"
	+ "boot_exit_exposure_early.png")
const EXIT_PLANE_OUTPUT_PATH := (
	"D:/Game/BoBoZan/boot_background_runtime_frames/"
	+ "boot_exit_exposure_mid.png")
const EXIT_EXPOSURE_PEAK_OUTPUT_PATH := (
	"D:/Game/BoBoZan/boot_background_runtime_frames/"
	+ "boot_exit_exposure_peak.png")


func _ready() -> void:
	var packed := load("res://src/ui/boot_screen.tscn") as PackedScene
	if packed == null:
		push_error("Boot screen could not be loaded.")
		get_tree().quit(1)
		return

	var boot := packed.instantiate() as Control
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame
	var intro := boot.get_node_or_null("IntroController")
	if intro != null:
		intro.call(&"finish_immediately")
		await get_tree().process_frame

	var prompt := boot.get_node_or_null("EnterPrompt") as BootEnterPrompt
	var title := boot.get_node_or_null("TitleColumn") as BootTitleController
	if prompt == null or title == null:
		push_error("Boot title or enter prompt is missing.")
		get_tree().quit(1)
		return

	var expected_peak_phase := (
		(title.final_flow_release_seconds()
			+ prompt.title_peak_delay_seconds)
		/ title.flow_period_seconds)
	if not is_equal_approx(
		prompt.synced_peak_phase(),
		expected_peak_phase):
		push_error("Boot title and enter prompt timing are not synchronized.")
		get_tree().quit(1)
		return
	if not _verify_static_prompt_lines(prompt):
		get_tree().quit(1)
		return
	if not _verify_static_chinese_title_pulse(title):
		get_tree().quit(1)
		return

	var seconds_to_peak := (
		fposmod(
			expected_peak_phase - title.current_flow_phase(),
			1.0)
		* title.flow_period_seconds)
	await get_tree().create_timer(seconds_to_peak).timeout
	await get_tree().process_frame
	if prompt.modulate.a < 0.995:
		push_error(
			"Boot enter prompt did not peak after the title flow: %.3f"
			% prompt.modulate.a)
		get_tree().quit(1)
		return
	if not await _save_screenshot(PEAK_OUTPUT_PATH):
		get_tree().quit(1)
		return

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	click.position = Vector2(400.0, 400.0)
	click.global_position = click.position
	Input.parse_input_event(click)
	await get_tree().process_frame

	if boot.can_enter():
		push_error("Boot screen did not accept the real mouse click.")
		get_tree().quit(1)
		return
	if not TransitionManager.is_busy():
		push_error("Boot transition did not start in the click frame.")
		get_tree().quit(1)
		return
	var old_veil := TransitionManager.get_node_or_null("Veil") as ColorRect
	var boot_veil := TransitionManager.get_node_or_null(
		"BootPixelVeil") as ColorRect
	if (
		boot_veil == null
		or not boot_veil.visible
		or (old_veil != null and old_veil.visible)
	):
		push_error(
			"Boot click reused the rejected global wave veil.")
		get_tree().quit(1)
		return
	if not prompt.is_enter_feedback_active():
		push_error("Boot enter feedback did not start with the transition.")
		get_tree().quit(1)
		return
	if TransitionManager.boot_exit_mode() != (
		TransitionManager.BootExitMode.EXPOSURE_RING
	):
		push_error("Boot transition did not select exposure ring mode.")
		get_tree().quit(1)
		return
	if not is_equal_approx(prompt.modulate.a, 1.0):
		push_error("Boot enter prompt did not brighten immediately.")
		get_tree().quit(1)
		return

	await get_tree().create_timer(0.12).timeout
	print(
		"BOOT_EXIT_PROGRESS_EARLY=%.3f"
		% _boot_exit_progress())
	if not prompt.scale.is_equal_approx(Vector2.ONE):
		push_error(
			(
				"Boot enter prompt introduced a scale pop: "
				+ "actual=%s"
			)
			% prompt.scale)
		get_tree().quit(1)
		return

	if not await _save_screenshot(OUTPUT_PATH):
		get_tree().quit(1)
		return

	await get_tree().create_timer(0.16).timeout
	var mid_progress := _boot_exit_progress()
	print("BOOT_EXIT_PROGRESS_MID=%.3f" % mid_progress)
	if not TransitionManager.is_busy():
		push_error("Boot pixel transition ended before its cover midpoint.")
		get_tree().quit(1)
		return
	if mid_progress <= 0.0 or mid_progress >= 1.0:
		push_error(
			"Boot pixel transition skipped its readable cover midpoint.")
		get_tree().quit(1)
		return
	if not await _save_screenshot(EXIT_MID_OUTPUT_PATH):
		get_tree().quit(1)
		return

	await get_tree().create_timer(0.30).timeout
	var plane_progress := _boot_exit_progress()
	if plane_progress <= mid_progress or plane_progress >= 1.0:
		push_error(
			"Boot ring shockwave did not keep expanding.")
		get_tree().quit(1)
		return
	if not await _save_screenshot(EXIT_PLANE_OUTPUT_PATH):
		get_tree().quit(1)
		return

	await get_tree().create_timer(0.14).timeout
	var exposure_peak_progress := _boot_exit_progress()
	if (
		exposure_peak_progress <= plane_progress
		or exposure_peak_progress >= 1.0
	):
		push_error(
			"Boot exposure ring skipped its pre-switch peak.")
		get_tree().quit(1)
		return
	if not await _save_screenshot(EXIT_EXPOSURE_PEAK_OUTPUT_PATH):
		get_tree().quit(1)
		return

	print(
		(
			"BOOT_ENTER_FEEDBACK_OK: "
			+ "peak=%.3f alpha=%.2f scale=%.3f "
			+ "dedicated_exposure_ring=true "
			+ "ring=%.3f exposure_peak=%.3f"
		)
		% [
			prompt.synced_peak_phase(),
			prompt.modulate.a,
			prompt.scale.x,
			plane_progress,
			exposure_peak_progress,
		])
	get_tree().quit()


func _boot_exit_progress() -> float:
	var veil := TransitionManager.get_node_or_null(
		"BootPixelVeil") as ColorRect
	if veil == null:
		return -1.0
	var shader_material := veil.material as ShaderMaterial
	if shader_material == null:
		return -1.0
	var value: Variant = shader_material.get_shader_parameter(&"progress")
	if value == null:
		return -1.0
	return float(value)


func _verify_static_prompt_lines(prompt: BootEnterPrompt) -> bool:
	var left_line := prompt.get_node("LineLeft") as ColorRect
	var right_line := prompt.get_node("LineRight") as ColorRect
	if (
		left_line.material != null
		or right_line.material != null
		or prompt.has_method(&"set_line_pulse_phase")
	):
		push_error("Boot prompt decoration lines still have pulse behavior.")
		return false
	return true


func _verify_static_chinese_title_pulse(
		title: BootTitleController,
) -> bool:
	for node_name: String in ["BoTop", "BoMiddle", "ZanBottom"]:
		var glyph := title.get_node(NodePath(node_name)) as TextureRect
		var glyph_material := glyph.material as ShaderMaterial
		if bool(glyph_material.get_shader_parameter(&"flow_enabled")):
			push_error(
				"Boot Chinese title still has internal pulse: %s"
				% node_name)
			return false
	var english := title.get_node("EnglishSubtitle") as TextureRect
	var english_material := english.material as ShaderMaterial
	if not bool(english_material.get_shader_parameter(&"flow_enabled")):
		push_error("Boot English subtitle flow changed unexpectedly.")
		return false
	return true


func _save_screenshot(output_path: String) -> bool:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(
		output_path.get_base_dir())
	var save_error := (
		get_viewport()
		.get_texture()
		.get_image()
		.save_png(output_path))
	if save_error != OK:
		push_error(
			"Boot enter feedback screenshot could not be saved: %s"
			% output_path)
		return false
	return true
