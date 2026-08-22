extends GutTest

const SCENE6_PATH := "res://src/ui/scenes/scene6.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE6_PATH := "res://src/ui/battle_screen6.tscn"


func test_scene6_has_an_independent_shared_battle_entry() -> void:
	BattleSetup.reset()
	assert_true(ResourceLoader.exists(SCENE6_PATH))
	assert_true(ResourceLoader.exists(BATTLE6_PATH))
	if not ResourceLoader.exists(BATTLE6_PATH):
		BattleSetup.reset()
		return

	var battle_source := FileAccess.get_file_as_string(BATTLE6_PATH)
	var screen := (load(BATTLE6_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(battle_source.contains(BATTLE_BASE_PATH))
	assert_true(battle_source.contains(SCENE6_PATH))
	assert_false(battle_source.contains("scene4"))
	assert_false(battle_source.contains("scene5"))
	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE6_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_not_null(screen.get_node_or_null("WorldGroup"))
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	assert_true(screen.has_node("P1Hud"))
	assert_true(screen.has_node("P2Hud"))
	assert_true(screen.has_node("Buttons"))
	assert_true(screen.has_node("DeathSwitchOverlay"))
	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	screen._refresh_switch_module()
	screen.btn_switch.pressed.emit()
	assert_true(screen._switch_tray.visible)
	screen._on_switch_candidate_pressed(1)
	assert_eq(screen._armed_switch_frame, 1)
	assert_eq(screen.selected_action, ActionDef.Action.SWITCH)
	BattleSetup.reset()


func test_scene6_uses_the_authored_chilu_valley_layers_directly() -> void:
	assert_true(ResourceLoader.exists(SCENE6_PATH))
	if not ResourceLoader.exists(SCENE6_PATH):
		return

	var scene_source := FileAccess.get_file_as_string(SCENE6_PATH)
	var stage := (load(SCENE6_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var layer_contract: Dictionary[String, float] = {
		"FarBackground": 0.15,
		"DepthHeatVeil": 0.34,
		"MidgroundLeft": 0.55,
		"MidgroundRight": 0.55,
		"MidAshBack": 0.68,
		"BattlePlatform": 1.0,
		"ForegroundLeft": 1.25,
		"ForegroundRight": 1.25,
	}
	var previous_index: int = -1
	for node_name: String in layer_contract:
		var layer := stage.get_node(node_name) as Control
		assert_not_null(layer)
		assert_eq(layer.get_parent(), stage)
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(float(layer.get_meta("parallax_factor")), layer_contract[node_name])
		assert_gt(layer.get_index(), previous_index)
		previous_index = layer.get_index()

	assert_eq((stage.get_node("FarBackground") as TextureRect).texture.resource_path,
			"res://assets/scenes/scene6/scene6_far_background.png")
	assert_eq((stage.get_node("MidgroundLeft") as TextureRect).texture.resource_path,
			"res://assets/scenes/scene6/scene6_midground_left.png")
	assert_eq((stage.get_node("MidgroundRight") as TextureRect).texture.resource_path,
			"res://assets/scenes/scene6/scene6_midground_right.png")
	assert_lt(stage.get_node("MidgroundLeft").get_index(),
			stage.get_node("BattlePlatform").get_index())
	assert_lt(stage.get_node("MidgroundRight").get_index(),
			stage.get_node("BattlePlatform").get_index())
	assert_eq((stage.get_node("BattlePlatform") as TextureRect).texture.resource_path,
			"res://assets/scenes/scene6/scene6_battle_platform.png")
	assert_eq((stage.get_node("BattlePlatform") as TextureRect).texture.get_size(),
			Vector2(516.0, 92.0),
			"Scene6 必须使用精修后的完整平台素材")
	assert_eq((stage.get_node("ForegroundLeft") as TextureRect).texture.resource_path,
			"res://assets/scenes/scene6/scene6_foreground_near_left.png")
	assert_eq((stage.get_node("ForegroundRight") as TextureRect).texture.resource_path,
			"res://assets/scenes/scene6/scene6_foreground_near_right.png")
	var platform := stage.get_node("BattlePlatform") as TextureRect
	assert_lt(platform.position.x, 480.0)
	assert_gt(platform.position.x + platform.size.x * platform.scale.x, 1440.0)
	assert_lt(platform.position.y, 748.0)
	assert_gt(platform.position.y + platform.size.y * platform.scale.y, 748.0)
	assert_eq((stage.get_node("ForegroundLeft") as TextureRect).size, Vector2(961.0, 846.0))
	assert_eq((stage.get_node("ForegroundRight") as TextureRect).size, Vector2(700.0, 535.0))

	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"))

	assert_false(stage.get_meta("framework_only", true))
	assert_eq(String(stage.get_meta("theme_name", "")), "赤炉剑谷")
	assert_false(scene_source.contains("res://assets/import/"))


func test_scene6_keeps_mature_baselines_and_fullscreen_preview() -> void:
	assert_true(ResourceLoader.exists(SCENE6_PATH))
	if not ResourceLoader.exists(SCENE6_PATH):
		return

	var stage := (load(SCENE6_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var preview := stage.get_node("PreviewBackdrop") as ColorRect
	assert_eq(preview.anchor_right, 1.0)
	assert_eq(preview.anchor_bottom, 1.0)
	assert_eq(preview.mouse_filter, Control.MOUSE_FILTER_STOP,
			"PreviewBackdrop owns Scene6 background GUI clicks below battle UI")
	assert_eq((stage.get_node("CompositionGuides/P1Baseline") as Marker2D).position,
			Vector2(480.0, 752.0))
	assert_eq((stage.get_node("CompositionGuides/P2Baseline") as Marker2D).position,
			Vector2(1440.0, 755.0))
	assert_eq((stage.get_node("CompositionGuides/PlatformBaseline") as Marker2D).position,
			Vector2(960.0, 748.0))


func test_scene6_uses_a_naturally_occluded_magma_lake() -> void:
	var stage := (load(SCENE6_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	assert_null(stage.get_node_or_null("ForgeAbyss"))
	assert_null(stage.get_node_or_null("ForgeCore"))
	assert_null(stage.get_node_or_null("PlatformForgeContact"))
	assert_null(stage.get_node_or_null("UnderbridgeForge"))
	var platform := stage.get_node_or_null("BattlePlatform") as TextureRect
	var magma := stage.get_node_or_null("MagmaLake") as ColorRect
	assert_not_null(platform)
	assert_not_null(magma)
	if platform == null or magma == null:
		return
	var material := magma.material as ShaderMaterial
	assert_not_null(material)
	assert_true(magma.visible)
	assert_eq(magma.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(magma.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_lte(magma.position.x, 0.0)
	assert_gte(magma.position.x + magma.size.x, 1920.0)
	assert_gte(magma.position.y, 830.0)
	assert_lte(magma.position.y, 890.0)
	assert_gte(magma.position.y + magma.size.y, 1080.0)
	assert_gt(magma.get_index(), stage.get_node("ThermalAtmosphere").get_index())
	assert_lt(magma.get_index(), platform.get_index())
	assert_lt(platform.get_index(), stage.get_node("ForegroundLeft").get_index())
	assert_almost_eq(float(magma.get_meta("parallax_factor")), 1.0, 0.001)
	if material == null:
		return
	assert_eq(material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene6_occluded_magma.gdshader")
	assert_gte(float(material.get_shader_parameter("pixel_size")), 4.0)
	assert_gte(float(material.get_shader_parameter("crust_coverage")), 0.55)
	assert_lte(float(material.get_shader_parameter("crust_coverage")), 0.76)
	assert_lte(float(material.get_shader_parameter("vein_coverage")), 0.18)
	assert_lte(float(material.get_shader_parameter("core_coverage")), 0.05)
	assert_almost_eq(float(material.get_shader_parameter("loop_duration_sec")), 16.0, 0.001)
	assert_almost_eq(float(material.get_shader_parameter("phase_override")), -1.0, 0.001)
	assert_lt(float(material.get_shader_parameter("far_feature_px")),
			float(material.get_shader_parameter("near_feature_px")))
	assert_gte(float(material.get_shader_parameter("molten_base_strength")), 0.50)
	var shader_source := material.shader.code
	for marker: String in [
		"occluded_magma_lake",
		"loop_phase",
		"nearward_flow_phase",
		"nearward_advection",
		"static_base_energy",
		"perspective_depth",
		"depthward_flow",
		"pixel_cell",
		"palette_band",
		"hard_crust_mask",
		"crust_edge",
		"crust_raft",
		"molten_base",
		"near_scale",
		"static_crust_topology",
		"thermal_advection",
		"contact_shadow",
		"broken_surface_mask",
	]:
		assert_true(shader_source.contains(marker),
				"Scene6 magma shader must implement %s" % marker)
	assert_false(shader_source.contains("stepped_time"),
			"Slow magma motion must use temporal feathering, not hard time steps")
	assert_false(shader_source.contains("hint_screen_texture"),
			"Magma must not distort the fighters or UI")
	assert_false(shader_source.contains("time_orbit"),
			"Magma heat must travel in one direction instead of breathing on an orbit")
	for discontinuous_marker: String in [
		"floor(TIME",
		"floor(travel",
		"plate_noise",
		"hot_pool_gate",
		"floor(px / vec2(72.0, 48.0))",
		"cellular_edge",
		"warped_ridge_field",
		"organic_crust_field",
		"micro_vein",
	]:
		assert_false(shader_source.contains(discontinuous_marker),
				"Magma must avoid rectangular or discontinuous logic: %s" % discontinuous_marker)
	for forbidden_marker: String in ["bubble", "surface_lip", "bright_line"]:
		assert_false(shader_source.contains(forbidden_marker),
				"The magma must avoid a rejected visual route: %s" % forbidden_marker)


func test_scene6_platform_is_pixel_safe_and_has_local_thermal_depth() -> void:
	var stage := (load(SCENE6_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var platform := stage.get_node_or_null("BattlePlatform") as TextureRect
	var atmosphere := stage.get_node_or_null("ThermalAtmosphere") as ColorRect
	var depth_heat_veil := stage.get_node_or_null("DepthHeatVeil") as ColorRect
	var mid_ash := stage.get_node_or_null("MidAshBack") as ColorRect
	var foreground_embers := stage.get_node_or_null("ForegroundEmbers") as ColorRect
	var magma := stage.get_node_or_null("MagmaLake") as ColorRect
	assert_not_null(platform)
	assert_not_null(atmosphere)
	assert_not_null(depth_heat_veil)
	assert_not_null(mid_ash)
	assert_not_null(foreground_embers)
	assert_not_null(magma)
	if platform == null or atmosphere == null or depth_heat_veil == null \
			or mid_ash == null \
			or foreground_embers == null or magma == null:
		return
	assert_eq(platform.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(platform.texture.get_size(), Vector2(516.0, 92.0),
			"平台节点调整不得替换精修后的完整源图")
	assert_eq(platform.scale, Vector2(4.0, 4.0))
	assert_gt(platform.size.y * platform.scale.y, 350.0,
			"完整平台放大后必须保留足够的前景厚度")
	assert_eq(platform.stretch_mode, TextureRect.STRETCH_SCALE,
			"战斗平台只能整图放大，禁止 NinePatch 或平铺中段")
	assert_lt(platform.position.y, 748.0)
	assert_gt(platform.position.y + platform.size.y * platform.scale.y, 748.0)
	assert_lte(platform.position.x, 0.0)
	assert_gte(platform.position.x + platform.size.x * platform.scale.x, 1920.0)
	var platform_grade := platform.material as ShaderMaterial
	var near_grade := (stage.get_node("ForegroundLeft") as TextureRect).material \
			as ShaderMaterial
	assert_gt(float(platform_grade.get_shader_parameter("brightness")),
			float(near_grade.get_shader_parameter("brightness")),
			"The walkable platform must read brighter than the foreground frame")
	var platform_mid := platform_grade.get_shader_parameter("palette_mid") as Color
	var near_mid := near_grade.get_shader_parameter("palette_mid") as Color
	assert_gt(_color_distance(platform_mid, near_mid), 0.1,
			"Platform forged-iron mids must stay distinct from near-rock wine reds")
	assert_gt(_color_luma(platform_mid) - _color_luma(near_mid), 0.045)
	assert_lt(atmosphere.get_index(), magma.get_index())
	assert_gt(depth_heat_veil.get_index(), stage.get_node("FarBackground").get_index())
	assert_lt(depth_heat_veil.get_index(), stage.get_node("MidgroundLeft").get_index())
	assert_null(stage.get_node_or_null("FarSmokeBanks"))
	assert_gt(mid_ash.get_index(), stage.get_node("MidgroundRight").get_index())
	assert_lt(mid_ash.get_index(), atmosphere.get_index())
	assert_lt(magma.get_index(), platform.get_index())
	assert_gt(foreground_embers.get_index(), stage.get_node("ForegroundRight").get_index())
	assert_eq(float(atmosphere.get_meta("parallax_factor")), 0.82)
	assert_gt(float(foreground_embers.get_meta("parallax_factor")), 1.25)
	assert_eq(float(magma.get_meta("parallax_factor")), 1.0)
	var atmosphere_material := atmosphere.material as ShaderMaterial
	var depth_veil_material := depth_heat_veil.material as ShaderMaterial
	var mid_ash_material := mid_ash.material as ShaderMaterial
	var foreground_material := foreground_embers.material as ShaderMaterial
	var magma_material := magma.material as ShaderMaterial
	var platform_material := platform.material as ShaderMaterial
	assert_not_null(atmosphere_material)
	assert_not_null(depth_veil_material)
	assert_not_null(mid_ash_material)
	assert_not_null(foreground_material)
	assert_not_null(magma_material)
	assert_not_null(platform_material)
	if atmosphere_material == null or depth_veil_material == null \
			or mid_ash_material == null \
			or foreground_material == null \
			or magma_material == null or platform_material == null:
		return
	assert_eq(atmosphere_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene6_thermal_atmosphere.gdshader")
	assert_lte(float(atmosphere_material.get_shader_parameter("mist_strength")), 0.08)
	assert_lte(float(atmosphere_material.get_shader_parameter("ember_density")), 0.22)
	for marker: String in [
		"ember_field",
		"irregular_ember",
		"tail_shift",
		"ember_edge_color",
		"ember_horizontal_drift",
		"current_travel",
		"next_travel",
		"motion_feather",
		"mist_band",
		"source_coherence",
		"fissure_source",
		"smoke_contour",
	]:
		assert_true(atmosphere_material.shader.code.contains(marker))
	assert_false(atmosphere_material.shader.code.contains("pixel_round_ember"))
	assert_false(atmosphere_material.shader.code.contains("hint_screen_texture"))
	assert_eq(mid_ash_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene6_mid_ash_back.gdshader")
	assert_gte(float(mid_ash_material.get_shader_parameter("ash_density")), 0.28)
	assert_gte(float(mid_ash_material.get_shader_parameter("ash_strength")), 0.64)
	assert_lt(float(mid_ash_material.get_shader_parameter("rise_speed_px")),
			float(atmosphere_material.get_shader_parameter("ember_rise_speed")))
	for marker: String in [
		"ash_field", "current_travel", "next_travel", "motion_feather", "short_flake"
	]:
		assert_true(mid_ash_material.shader.code.contains(marker))
	assert_eq(depth_veil_material.shader, atmosphere_material.shader)
	assert_eq(float(depth_veil_material.get_shader_parameter("ember_density")), 0.0)
	assert_eq(float(depth_veil_material.get_shader_parameter("ember_strength")), 0.0)
	assert_gt(float(depth_veil_material.get_shader_parameter("smoke_strength")), 0.0)
	assert_lte(float(depth_veil_material.get_shader_parameter("smoke_strength")), 0.04)
	assert_lte(float(depth_veil_material.get_shader_parameter("mist_strength")), 0.02)
	assert_gte(float(depth_veil_material.get_shader_parameter("pixel_size")), 4.0)
	assert_eq(foreground_material.shader, atmosphere_material.shader)
	assert_eq(float(foreground_material.get_shader_parameter("mist_strength")), 0.0)
	assert_lte(float(foreground_material.get_shader_parameter("ember_density")), 0.12)
	assert_lt(float(foreground_material.get_shader_parameter("ember_rise_speed")),
			float(atmosphere_material.get_shader_parameter("ember_rise_speed")))
	assert_lt(float(foreground_material.get_shader_parameter("ember_horizontal_drift")), 0.0)
	assert_gt(float(atmosphere_material.get_shader_parameter("ember_horizontal_drift")), 0.0)
	assert_gt(float(foreground_material.get_shader_parameter("pixel_size")),
			float(atmosphere_material.get_shader_parameter("pixel_size")))
	assert_lte(float(foreground_material.get_shader_parameter("pixel_size")), 3.0)
	assert_gte(float(atmosphere_material.get_shader_parameter("source_bias_strength")), 0.5)
	assert_gte(float(foreground_material.get_shader_parameter("source_bias_strength")), 0.6)
	assert_true(magma_material.shader.code.contains("occluded_magma_lake"))
	assert_lte(float(platform_material.get_shader_parameter("saturation")), 0.68)
	assert_gte(float(platform_material.get_shader_parameter("brightness")), 0.98)
	assert_lte(float(platform_material.get_shader_parameter("brightness")), 1.02)
	var platform_light := platform_material.get_shader_parameter("palette_light") as Color
	var magma_hot := magma_material.get_shader_parameter("hot_color") as Color
	assert_lt(platform_light.r, 0.50)
	assert_lte(absf(platform_light.g - platform_light.b), 0.08,
			"Platform highlights must read as forged iron, not orange paint")
	assert_gt(magma_hot.r - platform_light.r, 0.25,
			"The platform may read as warm forged iron but must not become molten")
	assert_gt(magma_hot.r, 0.80)
	assert_gte(float(platform_material.get_shader_parameter("lava_bounce_amount")), 0.015)
	assert_lte(float(platform_material.get_shader_parameter("lava_bounce_amount")), 0.03)
	assert_gte(float(platform_material.get_shader_parameter("broken_reflection_amount")), 0.015)
	assert_lte(float(platform_material.get_shader_parameter("broken_reflection_amount")), 0.035)
	assert_gte(float(platform_material.get_shader_parameter("broken_reflection_coverage")), 0.10)
	assert_lte(float(platform_material.get_shader_parameter("broken_reflection_coverage")), 0.20)
	assert_true(platform_material.shader.code.contains("broken_reflection"))
	assert_true(platform_material.shader.code.contains("reflection_gate"))
	assert_eq(platform_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene6_platform_lava.gdshader")
	assert_gte(float(platform_material.get_shader_parameter("fissure_source_restore")), 0.70)
	assert_gt(float(platform_material.get_shader_parameter("lava_pulse_strength")), 0.0)
	assert_lte(float(platform_material.get_shader_parameter("lava_pulse_strength")), 0.45)
	assert_lte(float(platform_material.get_shader_parameter("lava_moving_gain")), 0.12)
	for marker: String in [
		"source_pixel", "platform_lava_mask", "thermal_flow", "fissure_source_restore"
	]:
		assert_true(platform_material.shader.code.contains(marker))
	assert_false(platform_material.shader.code.contains("texture(TEXTURE, UV +"),
			"Platform silhouette must stay fixed; only authored fissure light may move")


func test_scene6_platform_has_no_generated_gray_edge_specks() -> void:
	var texture := load(
			"res://assets/scenes/scene6/scene6_battle_platform.png") as Texture2D
	assert_not_null(texture)
	if texture == null:
		return
	var image := texture.get_image()
	var gray_specks := 0
	var warm_fissure_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			var channel_min := minf(pixel.r, minf(pixel.g, pixel.b))
			var channel_max := maxf(pixel.r, maxf(pixel.g, pixel.b))
			if channel_min >= 40.0 / 255.0 \
					and channel_max - channel_min <= 55.0 / 255.0:
				gray_specks += 1
			var luma := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			if pixel.r >= 138.0 / 255.0 \
					and pixel.g - pixel.b >= 18.0 / 255.0 \
					and luma >= 0.25:
				warm_fissure_pixels += 1
	assert_eq(gray_specks, 0,
			"Generated neutral-gray pixels become white specks after 4x scaling")
	assert_gt(warm_fissure_pixels, 1500,
			"Speck cleanup must preserve the authored molten fissure network")


func test_scene6_layers_share_a_depth_palette_and_midground_lava_motion() -> void:
	var stage := (load(SCENE6_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	for node_name: String in [
		"FarBackground",
		"MidgroundLeft",
		"MidgroundRight",
		"BattlePlatform",
		"ForegroundLeft",
		"ForegroundRight",
	]:
		var layer := stage.get_node(node_name) as CanvasItem
		var material := layer.material as ShaderMaterial
		assert_not_null(material, "%s must own an editable Scene6 material" % node_name)
		if material == null:
			continue
		assert_gte(float(material.get_shader_parameter("palette_strength")), 0.30)
	var far_material := (stage.get_node("FarBackground") as TextureRect).material as ShaderMaterial
	assert_eq(far_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene6_far_heat.gdshader")
	assert_gte(float(far_material.get_shader_parameter("crack_pulse_strength")), 0.90)
	assert_gte(far_material.get_shader_parameter("far_moving_gain") as float, 0.24)
	assert_lte(float(far_material.get_shader_parameter("crack_coverage_limit")), 0.12)
	assert_gte(float(far_material.get_shader_parameter("outer_hotspot_suppression")), 0.08)
	assert_lte(float(far_material.get_shader_parameter("outer_hotspot_suppression")), 0.12)
	var mid_left_material := (stage.get_node("MidgroundLeft") as TextureRect).material as ShaderMaterial
	assert_lt(float(far_material.get_shader_parameter("saturation")),
			float(mid_left_material.get_shader_parameter("saturation")))
	assert_lt(float(far_material.get_shader_parameter("contrast")),
			float(mid_left_material.get_shader_parameter("contrast")))
	for marker: String in [
		"far_crack_mask",
		"far_lava_flow",
		"flow_afterglow",
		"moving_heat_gain",
		"yellow_ratio",
		"outer_field",
		"outer_hotspot_suppression",
	]:
		assert_true(far_material.shader.code.contains(marker))

	for node_name: String in ["MidgroundLeft", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		if material == null:
			continue
		assert_eq(material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene6_midground_lava.gdshader")
		assert_gt(float(material.get_shader_parameter("lava_pulse_strength")), 0.0)
		assert_gte(float(material.get_shader_parameter("lava_pulse_strength")), 0.80)
		assert_gte(float(material.get_shader_parameter("lava_moving_gain")), 0.25)
		assert_gte(float(material.get_shader_parameter("lava_cycle_sec")), 7.0)
		assert_gte(float(material.get_shader_parameter("outer_hotspot_suppression")), 0.08)
		assert_lte(float(material.get_shader_parameter("outer_hotspot_suppression")), 0.12)
		var shader_source := material.shader.code
		for marker: String in [
			"lava_color_mask",
			"thermal_flow",
			"motion_feather",
			"source_texel",
			"screen_outer_distance",
		]:
			assert_true(shader_source.contains(marker))
		assert_false(shader_source.contains("UV + scroll_speed"),
				"Midground silhouettes must stay fixed; only the lava light may move")

	var near_left_material := (stage.get_node(
			"ForegroundLeft") as TextureRect).material as ShaderMaterial
	var near_right_material := (stage.get_node(
			"ForegroundRight") as TextureRect).material as ShaderMaterial
	assert_ne(near_left_material, near_right_material)
	for near_material: ShaderMaterial in [near_left_material, near_right_material]:
		assert_lte(float(near_material.get_shader_parameter("saturation")), 0.70)
		assert_gte(float(near_material.get_shader_parameter("palette_strength")), 0.55)
		assert_gte(float(near_material.get_shader_parameter("inner_bounce_amount")), 0.04)
		assert_lte(float(near_material.get_shader_parameter("inner_bounce_amount")), 0.07)
		var near_shadow := near_material.get_shader_parameter("palette_shadow") as Color
		assert_gt(near_shadow.r, near_shadow.b)
		assert_true(near_material.shader.code.contains("inner_facing_bounce"))
	assert_gt(float(near_left_material.get_shader_parameter("inner_bounce_direction")), 0.0)
	assert_lt(float(near_right_material.get_shader_parameter("inner_bounce_direction")), 0.0)


func test_scene6_reuses_character_geometry_with_red_valley_lighting() -> void:
	assert_true(ResourceLoader.exists(BATTLE6_PATH))
	if not ResourceLoader.exists(BATTLE6_PATH):
		return

	BattleSetup.reset()
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE6_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var character_drop: Dictionary[String, float] = {
		"P1CharDisplay": 4.0,
		"P2CharDisplay": 7.0,
	}
	for node_name: String in character_drop:
		var base_node := base.get_node(node_name) as Control
		var scene6_node := screen.get_node("WorldGroup/%s" % node_name) as CharacterDisplay
		assert_eq(scene6_node.position,
				base_node.position + Vector2(0.0, character_drop[node_name]),
				"Scene6 fighters must overlap the platform surface instead of floating")
		assert_eq(scene6_node.size, base_node.size)
		assert_eq(scene6_node.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(scene6_node.rim_color, Color(0.62, 0.34, 0.12, 1.0))
		assert_lte(scene6_node.rim_strength, 0.025)
		assert_lte(scene6_node.backlight, 0.13)
		assert_eq(scene6_node.shadow_tint, Color(0.42, 0.28, 0.24, 1.0))
		assert_lte(scene6_node.warmth_amount, 0.06)
		assert_eq(scene6_node.fill_color, Color(0.46, 0.22, 0.1, 1.0))
		assert_lte(scene6_node.fill_amount, 0.02)
		assert_gt(scene6_node.light_dir.y, 0.0)
		var sprite := scene6_node.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path,
				"res://assets/shaders/canvas_env_scene6_character_light.gdshader")
		assert_lte(material.get_shader_parameter("lava_bounce_amount") as float, 0.025)
		assert_lte(float(material.get_shader_parameter("lava_bounce_start")), 0.50)
		assert_lte(float(material.get_shader_parameter("rim_strength_cap")), 0.04)
		assert_eq(float(material.get_shader_parameter("flash_peak_strength")), 0.0)
		assert_eq(float(material.get_shader_parameter("flash_dark_response")), 0.0)
		assert_ne(material.get_shader_parameter("flash_color") as Color, Color.WHITE)
		assert_gte(float(material.get_shader_parameter("source_saturation")), 1.04,
				"Scene6 characters retain authored color instead of reading gray")
		assert_gte(float(material.get_shader_parameter("source_contrast")), 1.02)
		assert_lte(float(material.get_shader_parameter("highlight_compression")), 0.18,
				"highlight compression cannot flatten the sprite into a hazy daytime grade")
		assert_gte(float(material.get_shader_parameter("lava_bounce_amount")), 0.018,
				"a constant lower amber bounce anchors the fighter in the fire cave")
		for marker: String in ["lower_forge_bounce", "source_facing_rim", "ambient_lift"]:
			assert_true(material.shader.code.contains(marker))
		assert_false(material.shader.code.contains("TIME"),
				"character environment light must remain static and never breathe or flash")
		assert_true(material.shader.code.contains("min(rim_strength, rim_strength_cap)"))
		assert_true(material.shader.code.contains("stable_flash"))
		assert_true(material.shader.code.contains("flash_response"))
		assert_false(material.shader.code.contains("idle_peak_guard"))

	var p1_material := (screen.get_node(
			"WorldGroup/P1CharDisplay/SubViewport/AnimatedSprite2D") as AnimatedSprite2D).material as ShaderMaterial
	var p2_material := (screen.get_node(
			"WorldGroup/P2CharDisplay/SubViewport/AnimatedSprite2D") as AnimatedSprite2D).material as ShaderMaterial
	assert_lt((p1_material.get_shader_parameter("light_dir") as Vector2).x, 0.0)
	assert_gt((p2_material.get_shader_parameter("light_dir") as Vector2).x, 0.0)
	assert_gt(float(p1_material.get_shader_parameter("scene_exposure")),
			float(p2_material.get_shader_parameter("scene_exposure")))
	assert_eq(float(p1_material.get_shader_parameter("highlight_compression")),
			float(p2_material.get_shader_parameter("highlight_compression")))

	var p1_shadow := screen.get_node("WorldGroup/P1Shadow") as TextureRect
	var p2_shadow := screen.get_node("WorldGroup/P2Shadow") as TextureRect
	assert_eq(p1_shadow.position,
			(base.get_node("P1Shadow") as TextureRect).position + Vector2(0.0, 4.0))
	assert_eq(p2_shadow.position,
			(base.get_node("P2Shadow") as TextureRect).position + Vector2(0.0, 7.0))
	assert_eq(p1_shadow.self_modulate, Color(0.34, 0.08, 0.12, 0.58))
	assert_eq(p2_shadow.self_modulate, Color(0.34, 0.08, 0.12, 0.58))

	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)
	var post_fx := screen.get_node("PostFX") as ColorRect
	assert_true(post_fx.visible)
	assert_lt(post_fx.get_index(), screen.get_node("P1Hud").get_index())
	assert_lt(post_fx.get_index(), screen.get_node("P2Hud").get_index())
	var post_material := post_fx.material as ShaderMaterial
	assert_not_null(post_material)
	if post_material != null:
		assert_gte(post_material.get_shader_parameter("heat_haze_strength") as float, 1.0)
		assert_lte(post_material.get_shader_parameter("heat_haze_strength") as float, 2.0)
		assert_gt(post_material.get_shader_parameter("heat_haze_speed") as float, 0.0)
		assert_lte(float(post_material.get_shader_parameter("heat_haze_top_weight")), 0.12)
		assert_gte(float(post_material.get_shader_parameter("heat_haze_lower_focus")), 0.25)
		assert_lte(float(post_material.get_shader_parameter("heat_haze_lower_focus")), 0.40)
		assert_eq(float(post_material.get_shader_parameter(
				"heat_haze_character_protection")), 1.0)
		assert_true(post_material.shader.code.contains("rising_refraction"))
		assert_true(post_material.shader.code.contains("heat_haze_offset"))
		assert_true(post_material.shader.code.contains("character_protection"))
	base.free()
	BattleSetup.reset()


func _color_distance(left: Color, right: Color) -> float:
	return Vector3(left.r, left.g, left.b).distance_to(
			Vector3(right.r, right.g, right.b))


func _color_luma(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114
