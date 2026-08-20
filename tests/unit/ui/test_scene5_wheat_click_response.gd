extends GutTest

const SCENE5_PATH := "res://src/ui/scenes/scene5.tscn"
const BATTLE5_PATH := "res://src/ui/battle_screen5.tscn"
const WIND_SCRIPT_PATH := "res://src/ui/components/scene5_wind_field.gd"
const WIND_SHADER_PATH := "res://assets/shaders/scene5_wheat_wind.gdshader"
const CLICK_PARTICLE_NAMES: Array[String] = [
	"ClickLeavesMidFar",
	"ClickLeavesFar",
	"ClickLeavesCover",
]


func test_scene5_near_click_bend_is_fully_removed() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	var near_material := (
			stage.get_node("NearWheatLeft") as Control
			).material as ShaderMaterial

	assert_false(wind_field.has_method("trigger_near_click"))
	assert_false(wind_field.has_signal("near_click_triggered"))
	assert_false(near_material.shader.code.contains("click_bend"))
	assert_null(near_material.get_shader_parameter("click_bend_strength"))
	assert_eq(float(near_material.get_shader_parameter("gust_strength")), 0.0)
	assert_string_contains(near_material.shader.code, "gust_strength")


func test_scene5_far_click_uses_three_depth_matched_cpu_pixel_layers() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	assert_true(bool(wind_field.call(
			"trigger_far_leaves", Vector2(960.0, 590.0))))

	var amounts: Array[int] = []
	var factors: Array[float] = []
	var colors: Array[Color] = []
	var shared_texture: Texture2D = null
	for node_name: String in CLICK_PARTICLE_NAMES:
		var particles := stage.get_node_or_null(node_name) as CPUParticles2D
		assert_not_null(particles)
		if particles == null:
			continue
		amounts.append(particles.amount)
		factors.append(float(particles.get_meta("parallax_factor")))
		colors.append(particles.color)
		assert_true(particles.one_shot)
		assert_true(particles.emitting,
				"Every far depth must start on the click frame")
		assert_not_null(particles.texture,
				"Far disturbance needs a readable broken pixel streak")
		if particles.texture != null:
			var streak_image := particles.texture.get_image()
			assert_eq(streak_image.get_size(), Vector2i(6, 3))
			assert_between(_opaque_pixel_count(streak_image), 8, 14,
					"The streak must stay irregular instead of becoming a solid dot")
			if shared_texture == null:
				shared_texture = particles.texture
			else:
				assert_same(particles.texture, shared_texture)
		assert_between(particles.amount, 6, 10)
		assert_between(particles.lifetime, 1.3, 1.8)
		assert_eq(particles.direction.y, -1.0)
		assert_between(particles.initial_velocity_max, 22.0, 34.0)
		assert_between(particles.gravity.y, 14.0, 20.0)
		var ideal_rise := pow(particles.initial_velocity_max, 2.0) \
				/ (2.0 * particles.gravity.y)
		assert_between(ideal_rise, 15.0, 31.0,
				"The streak must rise enough to read without detaching from the field")
		assert_between(particles.scale_amount_min, 0.75, 1.2)
		assert_lte(particles.scale_amount_max, 1.6)
		assert_eq(
				particles.emission_shape,
				CPUParticles2D.EMISSION_SHAPE_RECTANGLE)
		assert_gte(particles.emission_rect_extents.x, 34.0)
		assert_eq(particles.fixed_fps, 0)
		assert_true(particles.fract_delta)
		assert_between(particles.color.a, 0.34, 0.62)

	assert_eq(amounts, [6, 8, 10])
	assert_eq(factors.size(), 3)
	if factors.size() == 3:
		assert_lt(factors[0], factors[1])
		assert_lt(factors[1], factors[2])
	assert_eq(colors.size(), 3)
	if colors.size() == 3:
		assert_lt(colors[0].a, colors[1].a)
		assert_lt(colors[1].a, colors[2].a)


func test_scene5_far_click_has_no_stagger_tween_or_fixed_step() -> void:
	var source := FileAccess.get_file_as_string(WIND_SCRIPT_PATH)
	assert_false(source.contains("leaf_tween"))
	assert_false(source.contains("set_delay(delay)"))
	assert_string_contains(source, "particles.restart()")
	assert_string_contains(source, "_build_far_disturbance_texture")


func test_scene5_repeated_far_click_does_not_restart_active_streaks() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	assert_true(wind_field.has_signal("far_wheat_clicked"))
	if not wind_field.has_signal("far_wheat_clicked"):
		return
	watch_signals(wind_field)

	assert_true(bool(wind_field.call(
			"trigger_far_leaves", Vector2(900.0, 590.0))))
	var first_positions: Array[Vector2] = []
	for node_name: String in CLICK_PARTICLE_NAMES:
		first_positions.append(
				(stage.get_node(node_name) as CPUParticles2D).position)
	assert_true(bool(wind_field.call(
			"trigger_far_leaves", Vector2(1020.0, 610.0))))

	assert_signal_emit_count(wind_field, "far_wheat_clicked", 2)
	assert_signal_emit_count(wind_field, "far_leaves_triggered", 1,
			"An active one-shot must finish instead of restarting at a new origin")
	for index: int in CLICK_PARTICLE_NAMES.size():
		var particles := stage.get_node(
				CLICK_PARTICLE_NAMES[index]) as CPUParticles2D
		assert_eq(particles.position, first_positions[index])


func test_scene5_far_streak_pool_allows_different_places_without_refreshing_same_place() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	watch_signals(wind_field)

	assert_eq(int(wind_field.call("get_streak_group_count")), 3)
	assert_true(bool(wind_field.call(
			"trigger_far_leaves", Vector2(560.0, 590.0))))
	assert_true(bool(wind_field.call(
			"trigger_far_leaves", Vector2(1360.0, 590.0))))
	assert_true(bool(wind_field.call(
			"trigger_far_leaves", Vector2(590.0, 604.0))))

	assert_signal_emit_count(wind_field, "far_wheat_clicked", 3)
	assert_signal_emit_count(wind_field, "far_leaves_triggered", 2,
			"A second place uses another slot, while the first place is not refreshed")
	assert_eq(int(wind_field.call("get_active_streak_group_count")), 2)
	var origins := wind_field.call("get_active_streak_origins") as Array
	assert_eq(origins.size(), 2)
	if origins.size() == 2:
		assert_lt((origins[0] as Vector2).distance_to(Vector2(560.0, 590.0)), 1.0)
		assert_lt((origins[1] as Vector2).distance_to(Vector2(1360.0, 590.0)), 1.0)


func test_scene5_crop_circle_requires_clustered_far_clicks_and_spans_three_depths() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	var crop_circle := stage.get_node_or_null("CropCircle")
	assert_not_null(crop_circle)
	if crop_circle == null:
		return
	assert_true(crop_circle.has_method("is_achievement_completed"))
	assert_true(crop_circle.has_method("get_achievement_progress"))
	crop_circle.set("reveal_duration_sec", 0.01)
	crop_circle.set("trigger_probability", 1.0)

	for offset: Vector2 in [
		Vector2(-36.0, -8.0),
		Vector2(24.0, 10.0),
		Vector2(-12.0, 18.0),
		Vector2(42.0, -14.0),
		Vector2.ZERO,
	]:
		assert_true(bool(wind_field.call(
				"trigger_far_leaves", Vector2(960.0, 590.0) + offset)))
	await get_tree().create_timer(0.04).timeout

	assert_true(bool(crop_circle.call("is_achievement_completed")))
	assert_eq(int(crop_circle.call("get_achievement_progress")), 5)
	var depth_scales: Array[float] = []
	var centers: Array[Vector2] = []
	for layer_name: String in [
		"MidFarWheat",
		"FarWheat",
		"FarWheatCoverBack",
	]:
		var material := (stage.get_node(layer_name) as CanvasItem).material \
				as ShaderMaterial
		assert_not_null(material)
		depth_scales.append(float(material.get_shader_parameter(
				"crop_circle_depth_scale")))
		centers.append(material.get_shader_parameter("crop_circle_center") as Vector2)
		assert_gte(float(material.get_shader_parameter(
				"crop_circle_strength")), 0.95)
		assert_gte(float(material.get_shader_parameter(
				"crop_circle_reveal")), 0.95)
	assert_eq(depth_scales.size(), 3)
	if depth_scales.size() == 3:
		assert_lt(depth_scales[0], depth_scales[1])
		assert_lt(depth_scales[1], depth_scales[2])
	assert_eq(centers.size(), 3)
	if centers.size() == 3:
		assert_eq(centers[0], centers[1])
		assert_eq(centers[1], centers[2])

	var shader_source := FileAccess.get_file_as_string(WIND_SHADER_PATH)
	assert_string_contains(shader_source, "SCREEN_UV")
	assert_string_contains(shader_source, "crop_circle_mask")
	assert_string_contains(shader_source, "crop_circle_strength")
	assert_string_contains(shader_source, "crop_circle_uv_offset")
	assert_string_contains(shader_source, "texture(TEXTURE, crop_source_uv)")
	assert_string_contains(shader_source, "outer_oval")
	assert_string_contains(shader_source, "inner_oval")
	assert_string_contains(shader_source, "pressed_lane")
	assert_string_contains(shader_source, "secondary_crop_source_uv")
	assert_false(shader_source.contains("pressed_gold"),
			"The crop formation must comb source wheat instead of painting a dark shadow")
	assert_false(shader_source.contains("crop_luminance"))
	var far_material := (stage.get_node("FarWheat") as CanvasItem).material \
			as ShaderMaterial
	var half_size := far_material.get_shader_parameter(
			"crop_circle_half_size") as Vector2
	assert_gte(half_size.x, 0.34,
			"The formation must occupy most of the background wheat width")
	assert_lte(half_size.y, 0.1)
	assert_gte(half_size.x / half_size.y, 3.5)


func test_scene5_crop_circle_resets_after_distant_click_or_timeout() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var crop_circle := stage.get_node("CropCircle")

	crop_circle.call("register_far_click", Vector2(600.0, 590.0))
	crop_circle.call("register_far_click", Vector2(1100.0, 590.0))
	assert_eq(int(crop_circle.call("get_achievement_progress")), 1,
			"A distant click starts a new cluster instead of completing the old one")

	crop_circle.set(
			"_window_started_msec",
			Time.get_ticks_msec() - 9000)
	crop_circle.call("register_far_click", Vector2(1120.0, 600.0))
	assert_eq(int(crop_circle.call("get_achievement_progress")), 1,
			"An expired cluster starts again from the latest click")
	assert_false(bool(crop_circle.call("is_achievement_completed")))


func test_scene5_crop_circle_uses_a_low_probability_roll_without_cooldown() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var crop_circle := stage.get_node("CropCircle")
	assert_almost_eq(float(crop_circle.get("trigger_probability")), 0.08, 0.001)

	crop_circle.set("trigger_probability", 0.0)
	for offset_x: float in [-32.0, -16.0, 0.0, 16.0, 32.0]:
		crop_circle.call(
				"register_far_click", Vector2(960.0 + offset_x, 590.0))
	assert_false(bool(crop_circle.call("is_achievement_completed")))
	assert_eq(int(crop_circle.call("get_achievement_progress")), 0,
			"A failed random roll must reset the gesture instead of starting a cooldown")

	crop_circle.set("trigger_probability", 1.0)
	for offset_x: float in [-32.0, -16.0, 0.0, 16.0, 32.0]:
		crop_circle.call(
				"register_far_click", Vector2(960.0 + offset_x, 590.0))
	assert_true(bool(crop_circle.call("is_achievement_completed")),
			"The next completed gesture can roll immediately after a failed one")


func test_scene5_crop_circle_holds_briefly_then_restores_all_three_wheat_layers() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var crop_circle := stage.get_node("CropCircle")
	crop_circle.set("trigger_probability", 1.0)
	crop_circle.set("reveal_duration_sec", 0.02)
	crop_circle.set("hold_duration_sec", 0.03)
	crop_circle.set("recover_duration_sec", 0.02)
	for offset_x: float in [-32.0, -16.0, 0.0, 16.0, 32.0]:
		crop_circle.call(
				"register_far_click", Vector2(960.0 + offset_x, 590.0))
	assert_true(bool(crop_circle.call("is_visual_active")))
	crop_circle.call("_process", 0.02)
	for layer_name: String in [
		"MidFarWheat",
		"FarWheat",
		"FarWheatCoverBack",
	]:
		var material := (stage.get_node(layer_name) as CanvasItem).material \
				as ShaderMaterial
		assert_gte(float(material.get_shader_parameter(
				"crop_circle_strength")), 0.95)

	crop_circle.call("_process", 0.03)
	crop_circle.call("_process", 0.02)
	assert_true(bool(crop_circle.call("is_achievement_completed")))
	assert_false(bool(crop_circle.call("is_visual_active")),
			"The achievement remains earned but its field mark must recover")
	for layer_name: String in [
		"MidFarWheat",
		"FarWheat",
		"FarWheatCoverBack",
	]:
		var material := (stage.get_node(layer_name) as CanvasItem).material \
				as ShaderMaterial
		assert_lte(float(material.get_shader_parameter(
				"crop_circle_strength")), 0.01)
		assert_lte(float(material.get_shader_parameter(
				"crop_circle_reveal")), 0.01)


func test_scene5_click_input_does_not_consume_battle_or_ui_events() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var wind_field := stage.get_node("WindField")
	var sky := stage.get_node("Sky") as Control
	var platform := stage.get_node("BattlePlatform") as Control
	assert_eq(wind_field.get("click_input_target_path"), NodePath("../Sky"))
	assert_eq(sky.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(platform.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var source := FileAccess.get_file_as_string(WIND_SCRIPT_PATH)
	assert_string_contains(source, "func _on_click_input_gui_input")
	assert_string_contains(source, "MOUSE_BUTTON_LEFT")
	assert_false(source.contains("func _unhandled_input"))
	assert_false(source.contains("accept_event"))
	assert_false(source.contains("set_input_as_handled"))


func test_scene5_sky_gui_near_click_stays_quiet() -> void:
	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	add_child_autofree(host)
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	host.add_child(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	var sky := stage.get_node("Sky") as Control
	watch_signals(wind_field)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var canvas_position := Vector2(960.0, 768.0)
	click.position = sky.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	sky.gui_input.emit(click)
	assert_signal_not_emitted(wind_field, "far_leaves_triggered",
			"Foreground wheat clicks must not leak through to far wheat")
	for node_name: String in CLICK_PARTICLE_NAMES:
		var particles := stage.get_node(node_name) as CPUParticles2D
		assert_false(particles.emitting)


func test_scene5_battle_gust_still_reaches_near_and_character_occluder() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	await get_tree().process_frame
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var wind_field := stage.get_node("WindField")
	var near_material := (
			stage.get_node("NearWheatLeft") as Control
			).material as ShaderMaterial
	var occluder_material := (
			screen.get_node("WorldGroup/WorldForegroundOccluder") as Control
			).material as ShaderMaterial

	wind_field.call("trigger_battle_gust", 16.0, 1.0)
	assert_gte(float(near_material.get_shader_parameter("gust_strength")), 0.95)
	assert_gte(float(occluder_material.get_shader_parameter("gust_strength")), 0.95)
	assert_false(near_material.shader.code.contains("click_bend"))
	assert_false(occluder_material.shader.code.contains("click_bend"))
	BattleSetup.reset()


func _opaque_pixel_count(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count
