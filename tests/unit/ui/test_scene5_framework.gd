extends GutTest

const SCENE5_PATH := "res://src/ui/scenes/scene5.tscn"
const BATTLE5_PATH := "res://src/ui/battle_screen5.tscn"
const SCENE5_CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene5_character_light.gdshader")


func test_scene5_entry_keeps_the_shared_battle_contract() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE5_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	for node_path: String in [
		"StageSlot/Stage/Sky",
		"StageSlot/Stage/BattlePlatform",
		"StageSlot/Stage/NearWheatLeft",
		"StageSlot/Stage/WindField",
		"P1Hud",
		"P2Hud",
		"Buttons",
	]:
		assert_true(screen.has_node(node_path))
	BattleSetup.reset()


func test_scene5_wind_field_receives_battle_response() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	watch_signals(wind_field)

	wind_field.call("trigger_battle_gust", 16.0, -1.0)
	assert_signal_emitted_with_parameters(wind_field, "gust_triggered", [1.0, -1.0])
	var wheat_material := (stage.get_node("FarWheat") as CanvasItem).material as ShaderMaterial
	assert_almost_eq(float(wheat_material.get_shader_parameter("gust_strength")), 1.0, 0.001)
	assert_almost_eq(float(wheat_material.get_shader_parameter("gust_direction")), -1.0, 0.001)


func test_scene5_characters_use_continuous_local_sunlight_without_color_flashing() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var materials: Array[ShaderMaterial] = []
	for display_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var display := screen.get_node("WorldGroup/%s" % display_name) \
				as CharacterDisplay
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") \
				as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		materials.append(material)
		assert_not_null(material)
		assert_eq(material.shader.resource_path, SCENE5_CHARACTER_SHADER_PATH)
		assert_lte(display.warmth_amount, 0.04,
				"Scene5 must not integrate fighters with a full-body gold wash")
		assert_lte(display.fill_amount, 0.04)
		assert_lte(display.rim_width, 1.0,
				"The sunset rim must preserve the one-pixel silhouette")
		var shadow_tint: Color = material.get_shader_parameter("shadow_tint")
		var sun_key: Color = material.get_shader_parameter("sun_key_color")
		var sky_ambient: Color = material.get_shader_parameter("sky_ambient_color")
		var field_bounce: Color = material.get_shader_parameter("field_bounce_color")
		assert_gt(shadow_tint.r, shadow_tint.b,
				"Scene5 shade must not amplify authored blue pixels")
		assert_gt(sun_key.r, sun_key.g)
		assert_gt(sun_key.g, sun_key.b)
		assert_gt(sun_key.r - sun_key.g, 0.12,
				"The wheat-field key still needs a readable warm direction")
		assert_lte(sun_key.r - sun_key.g, 0.28,
				"The local sun must not repaint the fighter orange")
		assert_lte(float(material.get_shader_parameter("sun_key_amount")), 0.2)
		assert_gt(sky_ambient.r, sky_ambient.b)
		assert_lte(absf(shadow_tint.r - shadow_tint.b), 0.14,
				"The unlit side must stay neutral enough for authored colors")
		assert_lte(display.rim_strength, 0.2,
				"Scene5 sunlight rim must not read as an ability glow")
		assert_gt(field_bounce.r, field_bounce.b)
		assert_lte(float(material.get_shader_parameter("field_bounce_amount")), 0.03)
		assert_almost_eq(float(material.get_shader_parameter(
				"idle_light_cycle_sec")), 0.75, 0.001)
		assert_between(float(material.get_shader_parameter(
				"idle_light_amount")), 0.02, 0.04)
		assert_lt(float(material.get_shader_parameter("scene_exposure")), 1.0)
		assert_gt(float(material.get_shader_parameter("highlight_compression")), 0.0)
	var shader_source := FileAccess.get_file_as_string(
			SCENE5_CHARACTER_SHADER_PATH)
	assert_string_contains(shader_source, "sun_key")
	assert_string_contains(shader_source, "sun_warm_shift")
	assert_string_contains(shader_source, "sun_highlight_guard")
	assert_string_contains(shader_source, "luma_preserving_palette")
	assert_string_contains(shader_source, "shadow_band")
	assert_string_contains(shader_source, "sun_band")
	assert_string_contains(shader_source, "idle_envelope")
	assert_string_contains(shader_source, "idle_gain")
	assert_false(shader_source.contains("stepped_shadow_band"))
	assert_false(shader_source.contains("stepped_sun_band"))
	assert_string_contains(shader_source, "rim_palette_target")
	assert_string_contains(shader_source, "sky_ambient")
	assert_string_contains(shader_source, "field_bounce")
	assert_eq(materials.size(), 2)
	if materials.size() == 2:
		assert_ne(materials[0], materials[1])
		var p1_direction: Vector2 = materials[0].get_shader_parameter("light_dir")
		var p2_direction: Vector2 = materials[1].get_shader_parameter("light_dir")
		assert_gt(p1_direction.x, 0.0)
		assert_lt(p2_direction.x, 0.0)
		assert_almost_eq(p1_direction.y, p2_direction.y, 0.001)
	BattleSetup.reset()
