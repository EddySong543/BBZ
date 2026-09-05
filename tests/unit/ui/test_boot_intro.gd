extends GutTest

const BOOT_SCREEN_PATH := "res://src/ui/boot_screen.tscn"


func test_boot_intro_uses_layered_impact_timing() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node_or_null("IntroController")

	assert_not_null(intro)
	if intro == null:
		return
	assert_eq(intro.call(&"flash_count"), 1)
	assert_almost_eq(
		float(intro.get("total_duration_seconds")),
		1.32,
		0.001)
	assert_almost_eq(
		float(intro.get("brush_duration_seconds")),
		0.72,
		0.001)
	assert_almost_eq(
		float(intro.get("gold_duration_seconds")),
		0.92,
		0.001)
	assert_almost_eq(
		float(intro.get("pressure_start_seconds")),
		0.28,
		0.001)
	assert_almost_eq(
		float(intro.get("pressure_duration_seconds")),
		0.70,
		0.001)
	assert_almost_eq(
		float(intro.get("title_duration_seconds")),
		0.76,
		0.001)
	assert_almost_eq(
		float(intro.get("prompt_duration_seconds")),
		0.94,
		0.001)
	assert_almost_eq(
		float(intro.get("brush_start_seconds")),
		float(intro.get("title_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("gold_start_seconds")),
		float(intro.get("brush_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("prompt_start_seconds")),
		float(intro.get("title_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("title_start_seconds")),
		float(intro.get("brush_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("impact_propagation_start_seconds")),
		0.18,
		0.001)
	assert_almost_eq(
		float(intro.get("impact_propagation_end_seconds")),
		0.88,
		0.001)
	assert_almost_eq(
		float(intro.get("impact_propagation_lead_seconds")),
		0.12,
		0.001)
	assert_almost_eq(
		float(intro.get("impact_support_lead_seconds")),
		0.06,
		0.001)


func test_boot_intro_continuously_propagates_then_locks_primary_layers() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var blue_mid := boot.get_node(
		"BackgroundStage/BlueMid") as TextureRect
	var gold := boot.get_node(
		"BackgroundStage/GoldEnergy") as TextureRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect

	intro.call(&"preview_at_time", 0.20)
	var early_brush := _shader_float(
		blue_mid,
		&"intro_stroke_progress")
	var early_gold := _shader_float(
		gold,
		&"intro_path_progress")
	var early_title := _shader_float(
		title,
		&"intro_reveal_progress")

	intro.call(&"preview_at_time", 0.24)
	assert_gt(
		_shader_float(blue_mid, &"intro_stroke_progress"),
		early_brush)
	assert_gt(
		_shader_float(gold, &"intro_path_progress"),
		early_gold)
	assert_gt(
		_shader_float(title, &"intro_reveal_progress"),
		early_title)

	assert_gt(float(intro.call(&"_impact_layer_seconds", 0.44)), 0.44)
	assert_almost_eq(
		float(intro.call(&"_impact_layer_seconds", 0.88)),
		0.88,
		0.001)
	var previous_layer_seconds := 0.18
	for frame_index: int in range(1, 43):
		var sample_seconds := 0.18 + float(frame_index) / 60.0
		var layer_seconds := float(intro.call(
			&"_impact_layer_seconds",
			sample_seconds))
		assert_gt(layer_seconds, previous_layer_seconds)
		previous_layer_seconds = layer_seconds


func test_boot_intro_primary_layers_use_distinct_monotonic_phases() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage")
	var blue_base := stage.get_node("BlueBase") as TextureRect
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var blue_light := stage.get_node("BlueLight") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var contours := stage.get_node("PressureContours") as ColorRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var character_base := boot.get_node(
		"Character/Rig/Base") as Sprite2D

	intro.call(&"preview_at_time", 0.48)
	var brush_progress := _shader_float(
		blue_mid,
		&"intro_stroke_progress")
	var gold_progress := _shader_float(
		gold,
		&"intro_path_progress")
	var title_progress := _shader_float(
		title,
		&"intro_reveal_progress")
	var pressure_progress := _shader_float(
		contours,
		&"intro_opacity")
	assert_gt(brush_progress, title_progress)
	assert_gt(title_progress, gold_progress)
	assert_gt(gold_progress, pressure_progress)

	intro.call(&"preview_at_time", 0.24)
	assert_gt(
		_shader_float(
			character_base,
			&"intro_impact_progress"),
		0.0)
	assert_lt(
		_shader_float(
			character_base,
			&"intro_impact_progress"),
		1.0)

	var base_material := blue_base.material as ShaderMaterial
	var mid_material := blue_mid.material as ShaderMaterial
	var light_material := blue_light.material as ShaderMaterial
	assert_gt(
		float(base_material.get_shader_parameter(
			&"intro_layer_offset")),
		float(mid_material.get_shader_parameter(
			&"intro_layer_offset")))
	assert_gt(
		float(mid_material.get_shader_parameter(
			&"intro_layer_offset")),
		float(light_material.get_shader_parameter(
			&"intro_layer_offset")))


func test_boot_gold_intro_prioritizes_character_contact_energy() -> void:
	var boot := await _instantiate_boot()
	var gold := boot.get_node(
		"BackgroundStage/GoldEnergy") as TextureRect
	var material := gold.material as ShaderMaterial

	assert_not_null(material)
	if material == null:
		return
	assert_eq(
		material.get_shader_parameter(&"intro_contact_min"),
		Vector2(0.48, 0.18))
	assert_eq(
		material.get_shader_parameter(&"intro_contact_max"),
		Vector2(0.76, 0.52))
	assert_almost_eq(
		float(material.get_shader_parameter(
			&"intro_late_path_threshold")),
		0.84,
		0.001)
	assert_almost_eq(
		float(material.get_shader_parameter(
			&"intro_contact_path_ceiling")),
		0.32,
		0.001)
	assert_true(
		material.shader.code.contains(
			"source_path_progress = mix("))
	assert_almost_eq(
		float(gold.get_meta("pointer_parallax_factor")),
		0.28,
		0.001)


func test_boot_intro_keeps_composition_anchored_without_shake() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var title := boot.get_node("TitleColumn") as Control
	var menu := boot.get_node("InterfaceLayer/BootMenu") as Control
	var character := boot.get_node("Character") as Control
	var stage_origin := stage.position
	var title_origin := title.position
	var menu_origin := menu.position
	var character_origin := character.position

	for sample_seconds: float in [0.0, 0.15, 0.34, 0.53, 1.32]:
		intro.call(&"preview_at_time", sample_seconds)
		assert_eq(stage.position, stage_origin)
		assert_eq(title.position, title_origin)
		assert_eq(menu.position, menu_origin)
		assert_eq(character.position, character_origin)


func test_boot_title_pointer_tilt_uses_one_shared_perspective_plane() -> void:
	var boot := await _instantiate_boot()
	var title := boot.get_node("TitleColumn") as BootTitleController
	title.call(&"preview_pointer_tilt", Vector2.ZERO)
	var material_nodes: Array[TextureRect] = [
		boot.get_node("TitleColumn/BoTop") as TextureRect,
		boot.get_node("TitleColumn/BoMiddle") as TextureRect,
		boot.get_node("TitleColumn/ZanBottom") as TextureRect,
		boot.get_node("TitleColumn/Chuan") as TextureRect,
		boot.get_node("TitleColumn/Shuo") as TextureRect,
		boot.get_node("TitleColumn/BoTopShadow") as TextureRect,
		boot.get_node("TitleColumn/ChuanShadow") as TextureRect,
		boot.get_node("TitleColumn/ShuoShadow") as TextureRect,
	]

	assert_almost_eq(float(title.get("pointer_yaw_degrees")), 6.0, 0.001)
	assert_almost_eq(float(title.get("pointer_pitch_degrees")), 2.5, 0.001)
	assert_almost_eq(float(title.get("pointer_smooth")), 5.0, 0.001)
	title.call(&"preview_pointer_tilt", Vector2(1.0, -1.0))
	for material_node: TextureRect in material_nodes:
		var material := material_node.material as ShaderMaterial
		assert_almost_eq(
			float(material.get_shader_parameter(&"pointer_yaw")),
			1.0,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"pointer_pitch")),
			-1.0,
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"pointer_yaw_strength")),
			tan(deg_to_rad(6.0)),
			0.001)
		assert_almost_eq(
			float(material.get_shader_parameter(&"pointer_pitch_strength")),
			tan(deg_to_rad(2.5)),
			0.001)
	assert_true(
		(material_nodes[0].material as ShaderMaterial)
			.shader.code.contains("group_pointer_x"))
	assert_null(boot.get_node_or_null("TitleColumn/ChinesePlus"))
	assert_null(boot.get_node_or_null("TitleColumn/EnglishPlus"))


func test_boot_menu_uses_text_and_imported_icons_without_plates() -> void:
	var boot := await _instantiate_boot()
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var start_button := menu.get_node("MainButtons/StartGame") as Button
	var steam_button := menu.get_node("SmallButtons/Steam") as Button

	assert_null(start_button.get_node_or_null("Plate"))
	assert_eq(start_button.text, "开始游戏")
	assert_eq(steam_button.text, "")
	assert_eq(
		steam_button.icon.resource_path,
		"res://assets/ui/boot/menu_icons/steam.png")
	assert_null(menu.get_node_or_null("SmallButtons/Settings"),
			"Boot Screen 不再显示设置齿轮入口")
	assert_null(boot.get_node_or_null("EnterPrompt"))


func test_boot_escape_opens_the_shared_pause_menu() -> void:
	var boot := await _instantiate_boot()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	boot._unhandled_input(escape)
	var pause := boot.get_node_or_null("PauseMenu") as CanvasLayer
	assert_not_null(pause)
	assert_gt(pause.layer, TransitionManager.layer,
			"Boot 暂停层必须覆盖角色、图标与全局过场画布")
	assert_true(get_tree().paused, "Boot 的 ESC 一级菜单应暂停背景动画")
	(pause as PauseMenuOverlay)._close()
	assert_false(get_tree().paused)


func test_boot_exit_energy_builds_one_way_without_intro_pulse_falloff() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var star := boot.get_node(
		"Character/Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	var glow := boot.get_node(
		"Character/Rig/RearHandEnergyAnchor/RearHandGlow") as ColorRect

	intro.call(&"_apply_exit_progress", 0.25)
	var early_star_intensity := _shader_float(star, &"intensity")
	var early_glow_intensity := _shader_float(glow, &"intensity")

	intro.call(&"_apply_exit_progress", 0.75)
	assert_gt(
		_shader_float(star, &"intensity"),
		early_star_intensity)
	assert_gt(
		_shader_float(glow, &"intensity"),
		early_glow_intensity)
	assert_almost_eq(
		_shader_float(star, &"exit_release_enabled"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(star, &"exit_release_progress"),
		0.75,
		0.001)
	assert_almost_eq(
		_shader_float(star, &"intro_pulse_enabled"),
		0.0,
		0.001)


func test_boot_exit_defaults_to_reversible_exposure_ring_variant() -> void:
	var veil := TransitionManager.get_node(
		"BootPixelVeil") as ColorRect
	assert_not_null(veil)
	var shader_material := veil.material as ShaderMaterial
	assert_not_null(shader_material)
	assert_eq(
		int(shader_material.get_shader_parameter(&"transition_mode")),
		2)
	assert_eq(
		TransitionManager.boot_exit_mode(),
		TransitionManager.BootExitMode.EXPOSURE_RING)
	var ring_fill_value: Variant = shader_material.get_shader_parameter(
		&"ring_fill_color")
	var ring_edge_value: Variant = shader_material.get_shader_parameter(
		&"ring_edge_color")
	var energy_tint_value: Variant = shader_material.get_shader_parameter(
		&"ring_energy_tint")
	var edge_half_width_value: Variant = shader_material.get_shader_parameter(
		&"ring_edge_half_width")
	assert_not_null(ring_fill_value)
	assert_not_null(ring_edge_value)
	assert_not_null(energy_tint_value)
	assert_not_null(edge_half_width_value)
	if ring_fill_value != null:
		var ring_fill: Color = ring_fill_value
		assert_true(ring_fill.is_equal_approx(Color.WHITE))
	if ring_edge_value != null:
		var ring_edge: Color = ring_edge_value
		assert_true(
			ring_edge.is_equal_approx(
				Color.from_string("#D6A33E", Color.TRANSPARENT)))
	if energy_tint_value != null:
		var energy_tint: Color = energy_tint_value
		assert_true(
			energy_tint.is_equal_approx(
				Color.from_string("#FFF7E8", Color.TRANSPARENT)))
	if edge_half_width_value != null:
		assert_almost_eq(
			float(edge_half_width_value),
			0.018,
			0.0001)
	assert_true(
		shader_material.shader.code.contains("hint_screen_texture"))
	assert_true(
		shader_material.shader.code.contains("posterized_luma"))
	assert_almost_eq(
		TransitionManager.BOOT_HOLD_TIME,
		0.03,
		0.001)


func test_boot_intro_starts_with_character_only_and_locks_entry() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var black_base := boot.get_node("IntroBlackBase") as ColorRect
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var star := boot.get_node(
		"Character/Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var contours := stage.get_node("PressureContours") as ColorRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var character_base := boot.get_node(
		"Character/Rig/Base") as Sprite2D

	intro.call(&"preview_at_time", 0.0)
	assert_false(boot.can_enter())
	assert_false(menu.visible)
	assert_false(menu.is_interaction_enabled())
	assert_true(black_base.color.is_equal_approx(Color("#c8d3d0")))
	assert_almost_eq(stage.modulate.a, 1.0, 0.001)
	assert_almost_eq(
		_shader_float(star, &"intensity"),
		float(intro.get("initial_star_intensity")),
		0.001)
	assert_almost_eq(
		_shader_float(blue_mid, &"intro_stroke_progress"),
		0.0,
		0.001)
	assert_almost_eq(
		_shader_float(gold, &"intro_path_progress"),
		0.0,
		0.001)
	assert_almost_eq(
		_shader_float(contours, &"intro_opacity"),
		0.0,
		0.001)
	assert_almost_eq(
		_shader_float(title, &"intro_reveal_progress"),
		0.0,
		0.001)
	assert_almost_eq(
		_shader_float(character_base, &"intro_light_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(character_base, &"intro_impact_progress"),
		0.0,
		0.001)


func test_boot_intro_star_brush_gold_and_title_progress_together() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var contours := stage.get_node("PressureContours") as ColorRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var star := boot.get_node(
		"Character/Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	var character_base := boot.get_node(
		"Character/Rig/Base") as Sprite2D
	var parallel_sample := (
		float(intro.get("brush_start_seconds"))
		+ float(intro.get("brush_duration_seconds")) * 0.25)
	intro.call(&"preview_at_time", parallel_sample)
	var brush_progress := _shader_float(
		blue_mid,
		&"intro_stroke_progress")
	var gold_progress := _shader_float(
		gold,
		&"intro_path_progress")
	assert_gt(brush_progress, 0.08)
	assert_lt(brush_progress, 0.30)
	assert_gt(gold_progress, 0.0)
	assert_lt(gold_progress, brush_progress)
	assert_gt(
		_shader_float(title, &"intro_reveal_progress"),
		0.0)
	assert_almost_eq(
		_shader_float(character_base, &"intro_light_progress"),
		1.0,
		0.001)
	assert_gt(
		_shader_float(character_base, &"intro_impact_progress"),
		0.0)
	assert_lt(
		_shader_float(character_base, &"intro_impact_progress"),
		1.0)
	assert_almost_eq(stage.modulate.a, 1.0, 0.001)
	assert_true(menu.visible)
	assert_gt(menu.modulate.a, 0.0)
	assert_false(menu.is_interaction_enabled())
	var star_material := star.material as ShaderMaterial
	assert_almost_eq(
		float(star_material.get_shader_parameter(
			&"intro_pulse_enabled")),
		0.0,
		0.001)

	var pressure_sample := (
		float(intro.get("pressure_start_seconds"))
		+ float(intro.get("pressure_duration_seconds")) * 0.5)
	intro.call(&"preview_at_time", pressure_sample)
	var pressure_opacity := _shader_float(
		contours,
		&"intro_opacity")
	assert_gt(pressure_opacity, 0.0)
	assert_lt(pressure_opacity, 1.0)


func test_boot_intro_finishes_parallel_layers_together() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController

	var parallel_placed_sample := maxf(
		float(intro.get("brush_start_seconds"))
			+ float(intro.get("brush_duration_seconds")),
		float(intro.get("gold_start_seconds"))
			+ float(intro.get("gold_duration_seconds")))
	intro.call(&"preview_at_time", parallel_placed_sample + 0.02)
	assert_almost_eq(
		_shader_float(blue_mid, &"intro_stroke_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(gold, &"intro_path_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(title, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_true(menu.visible)
	assert_true(boot.scale.is_equal_approx(Vector2.ONE))
	assert_true(boot.position.is_equal_approx(Vector2.ZERO))

func test_boot_title_intro_grows_from_authored_energy_cuts_without_ghosts() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var title_shadow := boot.get_node(
		"TitleColumn/BoTopShadow") as TextureRect
	var chuan := boot.get_node("TitleColumn/Chuan") as TextureRect
	var shuo := boot.get_node("TitleColumn/Shuo") as TextureRect
	var chuan_shadow := boot.get_node(
		"TitleColumn/ChuanShadow") as TextureRect
	var shuo_shadow := boot.get_node(
		"TitleColumn/ShuoShadow") as TextureRect
	var title_controller := boot.get_node("TitleColumn")
	var title_material := title.material as ShaderMaterial
	var title_shadow_material := title_shadow.material as ShaderMaterial
	var chuan_material := chuan.material as ShaderMaterial
	var shuo_material := shuo.material as ShaderMaterial
	var chuan_shadow_material := chuan_shadow.material as ShaderMaterial
	var shuo_shadow_material := shuo_shadow.material as ShaderMaterial

	assert_null(boot.get_node_or_null("TitleColumn/TitleBladeLight"))
	assert_false(title_controller.has_method(&"set_intro_state"))
	assert_not_null(title_material.get_shader_parameter(
		&"intro_activation_map"))
	assert_not_null(chuan_material.get_shader_parameter(
		&"intro_activation_map"))
	assert_not_null(shuo_material.get_shader_parameter(
		&"intro_activation_map"))
	assert_eq(
		(chuan_material.get_shader_parameter(
			&"intro_activation_map") as Texture2D).resource_path,
		"res://assets/ui/boot/title_intro_chuan.png")
	assert_eq(
		(shuo_material.get_shader_parameter(
			&"intro_activation_map") as Texture2D).resource_path,
		"res://assets/ui/boot/title_intro_shuo.png")
	assert_ne(chuan_material, shuo_material)
	assert_ne(chuan_shadow_material, shuo_shadow_material)
	assert_eq(
		title_material.get_shader_parameter(&"intro_shadow"),
		false)
	assert_eq(
		title_shadow_material.get_shader_parameter(&"intro_shadow"),
		true)
	assert_eq(
		chuan_shadow_material.get_shader_parameter(&"intro_shadow"),
		true)
	assert_eq(
		shuo_shadow_material.get_shader_parameter(&"intro_shadow"),
		true)
	assert_null(boot.get_node_or_null("TitleColumn/ChinesePlus"))
	assert_null(boot.get_node_or_null("TitleColumn/ChinesePlusShadow"))
	assert_null(boot.get_node_or_null("TitleColumn/EnglishPlus"))
	assert_null(boot.get_node_or_null("TitleColumn/EnglishPlusShadow"))
	assert_almost_eq(
		float(title_material.get_shader_parameter(&"intro_progress_delay")),
		0.0,
		0.001)
	assert_almost_eq(
		float(chuan_material.get_shader_parameter(&"intro_progress_delay")),
		0.0,
		0.001)
	assert_almost_eq(
		float(shuo_material.get_shader_parameter(&"intro_progress_delay")),
		0.0,
		0.001)
	assert_gt(
		float(title_shadow_material.get_shader_parameter(&"intro_shadow_lag")),
		0.0)
	assert_true(title_material.shader.code.contains("intro_activation_map"))
	assert_true(title_material.shader.code.contains("crack_activation"))
	assert_true(title_material.shader.code.contains("face_activation"))
	assert_false(title_material.shader.code.contains("blade_coordinate"))
	assert_false(title_material.shader.code.contains("intro_silhouette"))
	var title_midpoint := (
		float(intro.get("title_start_seconds"))
		+ float(intro.get("title_duration_seconds")) * 0.5)
	intro.call(&"preview_at_time", title_midpoint)
	var reveal_progress := _shader_float(
		title,
		&"intro_reveal_progress")
	assert_gt(reveal_progress, 0.0)
	assert_lt(reveal_progress, 1.0)
	assert_almost_eq(
		_shader_float(chuan, &"intro_reveal_progress"),
		reveal_progress,
		0.001)
	assert_almost_eq(
		_shader_float(shuo, &"intro_reveal_progress"),
		reveal_progress,
		0.001)

	var placed_sample := (
		float(intro.get("title_start_seconds"))
		+ float(intro.get("title_duration_seconds"))
		+ 0.08)
	intro.call(&"preview_at_time", placed_sample)
	assert_almost_eq(
		_shader_float(title, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(chuan, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(shuo, &"intro_reveal_progress"),
		1.0,
		0.001)


func test_boot_intro_finishes_on_the_existing_idle_contract() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var menu := boot.get_node("InterfaceLayer/BootMenu") as BootMenuController
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var chuan := boot.get_node("TitleColumn/Chuan") as TextureRect
	var shuo := boot.get_node("TitleColumn/Shuo") as TextureRect
	var character_base := boot.get_node(
		"Character/Rig/Base") as Sprite2D
	var pressure_motion := stage.get_node("PressureMotion")
	var blue_motion := stage.get_node("BlueFlowMotion")

	intro.call(&"finish_immediately")
	await get_tree().process_frame

	assert_true(boot.can_enter())
	assert_true(menu.visible)
	assert_true(menu.is_interaction_enabled())
	assert_almost_eq(
		_shader_float(blue_mid, &"intro_stroke_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(gold, &"intro_path_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(title, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(chuan, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(shuo, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(character_base, &"intro_light_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(character_base, &"intro_impact_progress"),
		1.0,
		0.001)
	assert_almost_eq(stage.modulate.a, 1.0, 0.001)
	assert_true(bool(pressure_motion.get("animation_enabled")))
	assert_true(bool(blue_motion.get("animation_enabled")))


func _shader_float(item: CanvasItem, parameter: StringName) -> float:
	var material := item.material as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return 0.0
	var value: Variant = material.get_shader_parameter(parameter)
	assert_not_null(value)
	if value == null:
		return 0.0
	return float(value)


func _instantiate_boot() -> Control:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	var boot := packed.instantiate() as Control
	add_child_autofree(boot)
	await get_tree().process_frame
	return boot
