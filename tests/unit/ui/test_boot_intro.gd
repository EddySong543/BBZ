extends GutTest

const BOOT_SCREEN_PATH := "res://src/ui/boot_screen.tscn"


func test_boot_intro_uses_character_brush_then_title_sequence() -> void:
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
		1.2,
		0.001)
	assert_almost_eq(
		float(intro.get("gold_duration_seconds")),
		1.2,
		0.001)
	assert_almost_eq(
		float(intro.get("brush_start_seconds")),
		float(intro.get("flash_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("gold_start_seconds")),
		float(intro.get("flash_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("prompt_start_seconds")),
		float(intro.get("title_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("prompt_duration_seconds")),
		float(intro.get("title_duration_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("title_start_seconds")),
		float(intro.get("brush_start_seconds")),
		0.001)
	assert_almost_eq(
		float(intro.get("title_duration_seconds")),
		float(intro.get("brush_duration_seconds")),
		0.001)


func test_boot_intro_starts_with_character_only_and_locks_entry() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var black_base := boot.get_node("IntroBlackBase") as ColorRect
	var prompt := boot.get_node("EnterPrompt") as Control
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
	assert_false(prompt.visible)
	assert_eq(black_base.color, Color.BLACK)
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


func test_boot_intro_star_brush_gold_and_title_progress_together() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var contours := stage.get_node("PressureContours") as ColorRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var prompt := boot.get_node("EnterPrompt") as Control
	var star := boot.get_node(
		"Character/Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	var character_base := boot.get_node(
		"Character/Rig/Base") as Sprite2D
	var parallel_sample := (
		float(intro.get("brush_start_seconds"))
		+ float(intro.get("brush_duration_seconds")) * 0.25)
	intro.call(&"preview_at_time", parallel_sample)
	assert_almost_eq(
		_shader_float(blue_mid, &"intro_stroke_progress"),
		0.25,
		0.001)
	assert_almost_eq(
		_shader_float(gold, &"intro_path_progress"),
		0.25,
		0.001)
	assert_gt(
		_shader_float(title, &"intro_reveal_progress"),
		0.0)
	assert_almost_eq(
		_shader_float(character_base, &"intro_light_progress"),
		1.0,
		0.001)
	assert_almost_eq(stage.modulate.a, 1.0, 0.001)
	assert_true(prompt.visible)
	assert_gt(prompt.modulate.a, 0.0)
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
	var prompt := boot.get_node("EnterPrompt") as Control

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
	assert_true(prompt.visible)
	assert_true(boot.scale.is_equal_approx(Vector2.ONE))
	assert_true(boot.position.is_equal_approx(Vector2.ZERO))

func test_boot_intro_restores_the_original_internal_title_entry() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var english := boot.get_node(
		"TitleColumn/EnglishSubtitle") as TextureRect
	var title_controller := boot.get_node("TitleColumn")

	assert_null(boot.get_node_or_null("TitleColumn/TitleBladeLight"))
	assert_false(title_controller.has_method(&"set_intro_state"))
	var title_midpoint := (
		float(intro.get("title_start_seconds"))
		+ float(intro.get("title_duration_seconds")) * 0.5)
	intro.call(&"preview_at_time", title_midpoint)
	var reveal_progress := _shader_float(
		title,
		&"intro_reveal_progress")
	assert_gt(reveal_progress, 0.0)
	assert_lt(reveal_progress, 1.0)
	assert_gt(
		_shader_float(title, &"intro_blade_strength"),
		0.0)
	assert_almost_eq(
		_shader_float(english, &"intro_reveal_progress"),
		reveal_progress,
		0.001)
	assert_gt(
		_shader_float(english, &"intro_blade_strength"),
		0.0)

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
		_shader_float(english, &"intro_reveal_progress"),
		1.0,
		0.001)


func test_boot_intro_finishes_on_the_existing_idle_contract() -> void:
	var boot := await _instantiate_boot()
	var intro := boot.get_node("IntroController")
	var stage := boot.get_node("BackgroundStage") as Control
	var prompt := boot.get_node("EnterPrompt") as Control
	var blue_mid := stage.get_node("BlueMid") as TextureRect
	var gold := stage.get_node("GoldEnergy") as TextureRect
	var title := boot.get_node("TitleColumn/BoTop") as TextureRect
	var english := boot.get_node(
		"TitleColumn/EnglishSubtitle") as TextureRect
	var character_base := boot.get_node(
		"Character/Rig/Base") as Sprite2D
	var pressure_motion := stage.get_node("PressureMotion")
	var blue_motion := stage.get_node("BlueFlowMotion")

	intro.call(&"finish_immediately")
	await get_tree().process_frame

	assert_true(boot.can_enter())
	assert_true(prompt.visible)
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
		_shader_float(english, &"intro_reveal_progress"),
		1.0,
		0.001)
	assert_almost_eq(
		_shader_float(character_base, &"intro_light_progress"),
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
