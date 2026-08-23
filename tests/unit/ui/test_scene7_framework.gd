extends GutTest

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"
const SCENE7_CHARACTER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_light.gdshader"
const SCENE7_CONTACT_SHADOW_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_contact_shadow.gdshader"
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"
const UI_READABILITY_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_ui_readability.gdshader"
const FAR_CLEANUP_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_far_cleanup.gdshader"
const BIOLUME_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_biolume_plant.gdshader"
const FAR_WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_water.gdshader"
const WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_water.gdshader"
const WATER_ANIMATION_SCRIPT_PATH := \
		"res://src/ui/components/scene7_water_animation.gd"
const REAR_WATER_ANIMATED_PATH := \
		"res://assets/scenes/scene7/scene7_water_rear_animated.png"
const FRONT_WATER_ANIMATED_PATH := \
		"res://assets/scenes/scene7/scene7_water_front_animated.png"
const REAR_WATER_STATIC_PATH := \
		"res://assets/scenes/scene7/scene7_water_rear_static.png"
const FRONT_WATER_STATIC_PATH := \
		"res://assets/scenes/scene7/scene7_water_front_static.png"
const PLATFORM_ELEVATION_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_platform_elevation.gdshader"
const DEPTH_VEIL_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_depth_veil.gdshader"
const MOTES_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_motes.gdshader"
const SCENE7_ASSET_ROOT := "res://assets/scenes/scene7/"


func test_scene7_has_an_independent_shared_battle_entry() -> void:
	BattleSetup.reset()
	assert_true(ResourceLoader.exists(SCENE7_PATH))
	assert_true(ResourceLoader.exists(BATTLE7_PATH))
	if not ResourceLoader.exists(SCENE7_PATH) or not ResourceLoader.exists(BATTLE7_PATH):
		BattleSetup.reset()
		return

	var battle_source: String = FileAccess.get_file_as_string(BATTLE7_PATH)
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(battle_source.contains(BATTLE_BASE_PATH))
	assert_true(battle_source.contains(SCENE7_PATH))
	for old_scene_index: int in range(1, 7):
		assert_false(battle_source.contains("scene%d" % old_scene_index))
	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE7_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_not_null(screen.get_node_or_null("WorldGroup"))
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	for node_path: String in ["P1Hud", "P2Hud", "Buttons", "DeathSwitchOverlay"]:
		assert_not_null(screen.get_node_or_null(node_path))
	BattleSetup.reset()


func test_scene7_composes_daylight_oasis_layers_with_authored_geometry() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var scene_source: String = FileAccess.get_file_as_string(SCENE7_PATH)
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var layer_contract: Dictionary[String, float] = {
		"Sky": 0.0,
		"FarBackground": 0.18,
		"OasisDepthVeil": 0.32,
		"MidgroundLeft": 0.55,
		"MidgroundCenter": 0.55,
		"MidgroundRight": 0.55,
		"FrontWater": 1.0,
		"BattlePlatform": 1.0,
		"ForegroundLeft": 1.25,
		"ForegroundRight": 1.25,
	}
	for node_name: String in layer_contract:
		var layer := stage.get_node_or_null(node_name) as Control
		assert_not_null(layer, "%s must be a direct editable layer" % node_name)
		if layer == null:
			continue
		assert_eq(layer.get_parent(), stage)
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(float(layer.get_meta("parallax_factor")), layer_contract[node_name])
	var rear_water_shape := stage.get_node_or_null("RearWater") as Polygon2D
	assert_not_null(rear_water_shape, "rear water must use an authored polygon boundary")
	if rear_water_shape != null:
		assert_eq(rear_water_shape.get_parent(), stage)
		assert_eq(rear_water_shape.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(float(rear_water_shape.get_meta("parallax_factor")), 0.55)

	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"))
	assert_false(bool(stage.get_meta("framework_only", true)))
	assert_eq(String(stage.get_meta("theme_name", "")), "白昼碧月泉")
	assert_null(stage.get_node_or_null("DaylightBackdrop"))
	var sky := stage.get_node("Sky") as TextureRect
	assert_null(sky.material)
	assert_false(scene_source.contains("canvas_env_scene7_sky_rebuild.gdshader"))
	assert_false(scene_source.contains("canvas_env_scene7_daylight_atmosphere.gdshader"))

	var texture_contract: Dictionary[String, String] = {
		"Sky": SCENE7_ASSET_ROOT + "scene7_sky.png",
		"FarBackground": SCENE7_ASSET_ROOT + "scene7_far_background.png",
		"MidgroundLeft": SCENE7_ASSET_ROOT + "scene7_midground_left.png",
		"MidgroundCenter": SCENE7_ASSET_ROOT + "scene7_midground_center.png",
		"MidgroundRight": SCENE7_ASSET_ROOT + "scene7_midground_right.png",
		"BattlePlatform": SCENE7_ASSET_ROOT + "scene7_battle_platform.png",
		"ForegroundLeft": SCENE7_ASSET_ROOT + "scene7_foreground_left.png",
		"ForegroundRight": SCENE7_ASSET_ROOT + "scene7_foreground_right.png",
	}
	for node_name: String in texture_contract:
		var layer := stage.get_node(node_name) as TextureRect
		assert_not_null(layer.texture)
		assert_eq(layer.texture.resource_path, texture_contract[node_name])

	for node_name: String in ["FarBackground"]:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, FAR_CLEANUP_SHADER_PATH)
	for node_name: String in [
		"MidgroundLeft", "MidgroundCenter", "MidgroundRight",
		"ForegroundLeft", "ForegroundRight",
	]:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, BIOLUME_SHADER_PATH)

	var rear_pool := stage.get_node_or_null("RearWater") as Polygon2D
	var front_water := stage.get_node_or_null("FrontWater") as ColorRect
	assert_not_null(rear_pool)
	assert_not_null(front_water)
	assert_null(stage.get_node_or_null("PlatformWaterContact"))
	if rear_pool == null or front_water == null:
		return
	var rear_water_material := rear_pool.material as ShaderMaterial
	var front_water_material := front_water.material as ShaderMaterial
	assert_not_null(rear_water_material)
	assert_not_null(front_water_material)
	assert_eq(rear_water_material.shader.resource_path, FAR_WATER_SHADER_PATH)
	assert_eq(front_water_material.shader.resource_path, WATER_SHADER_PATH)
	assert_null(rear_pool.texture)
	var depth_veil := stage.get_node("OasisDepthVeil") as ColorRect
	var depth_veil_material := depth_veil.material as ShaderMaterial
	assert_not_null(depth_veil_material)
	assert_eq(depth_veil_material.shader.resource_path, DEPTH_VEIL_SHADER_PATH)
	assert_gte(float(depth_veil_material.get_shader_parameter("opacity")), 0.06)
	assert_lte(float(depth_veil_material.get_shader_parameter("opacity")), 0.12)
	assert_lt(stage.get_node("FarBackground").get_index(), depth_veil.get_index())
	assert_lt(depth_veil.get_index(), rear_pool.get_index())
	assert_lte(depth_veil.position.x, -24.0)
	assert_gte(depth_veil.position.x + depth_veil.size.x, 1944.0)
	assert_lte(depth_veil.position.y, 340.0)
	assert_gte(depth_veil.position.y + depth_veil.size.y, 680.0)
	assert_lt(rear_pool.get_index(), stage.get_node("OasisMotesFar").get_index())
	assert_lt(stage.get_node("MidgroundCenter").get_index(),
			stage.get_node("MidgroundLeft").get_index())
	assert_lt(stage.get_node("MidgroundLeft").get_index(),
			stage.get_node("MidgroundRight").get_index())
	assert_lt(stage.get_node("MidgroundRight").get_index(),
			front_water.get_index())
	assert_lt(front_water.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_eq(rear_pool.polygon.size(), 24)
	assert_eq(rear_pool.polygon[0], Vector2(-32.0, 680.0))
	assert_eq(rear_pool.polygon[15], Vector2(1440.0, 683.0))
	assert_eq(rear_pool.polygon[16], Vector2(1536.0, 684.0))
	assert_eq(rear_pool.polygon[21], Vector2(1952.0, 680.0))
	assert_eq(rear_pool.polygon[22], Vector2(1952.0, 760.0))
	assert_eq(rear_pool.polygon[23], Vector2(-32.0, 760.0))
	assert_eq(rear_pool.uv.size(), 24)
	assert_eq(rear_pool.uv[0], Vector2(0.0, 0.0))
	assert_eq(rear_pool.uv[21], Vector2(480.0, 0.0))
	assert_eq(rear_pool.uv[22], Vector2(480.0, 29.0))
	assert_eq(rear_pool.uv[23], Vector2(0.0, 29.0))
	assert_lte(front_water.position.x, -24.0)
	assert_gte(front_water.position.x + front_water.size.x, 1944.0)
	assert_gte(front_water.position.y, 854.0)
	assert_lte(front_water.position.y, 858.0)
	assert_gte(front_water.position.y + front_water.size.y, 1080.0)

	assert_eq(sky.size, Vector2(1672.0, 941.0))
	assert_true(is_equal_approx(sky.scale.x, sky.scale.y))
	assert_lt(absf(sky.scale.x * sky.size.x - 1920.0), 1.0)

	var platform := stage.get_node("BattlePlatform") as TextureRect
	assert_true(platform.position.is_equal_approx(Vector2(-133.165, 234.0)))
	assert_true(platform.size.is_equal_approx(Vector2(364.83334, 188.0)))
	assert_eq(platform.scale, Vector2(6.0, 6.0))
	assert_eq(platform.stretch_mode, TextureRect.STRETCH_SCALE)
	assert_true(is_equal_approx(platform.scale.x, platform.scale.y))
	assert_eq(platform.texture.get_size(), Vector2(332.0, 188.0))
	assert_eq(platform.texture.get_image().get_used_rect(), Rect2i(7, 83, 318, 23))
	var platform_visible_rect := _displayed_used_rect(platform)
	assert_lt(platform_visible_rect.position.x, 0.0)
	assert_gt(platform_visible_rect.end.x, 1920.0)
	assert_almost_eq(platform_visible_rect.size.y, 126.0, 0.05)
	assert_lte(platform_visible_rect.position.y, 748.0)
	assert_gt(platform_visible_rect.end.y, 748.0)
	assert_false(scene_source.contains("res://assets/import/"))
	assert_true(scene_source.contains(SCENE7_ASSET_ROOT))
	assert_true(scene_source.contains("canvas_env_scene7"))
	assert_false(scene_source.contains("OasisWaterFront"))
	assert_true(scene_source.contains("Scene7FrontWaterMat"))
	assert_true(scene_source.contains(FAR_WATER_SHADER_PATH))
	assert_true(scene_source.contains(WATER_SHADER_PATH))
	assert_false(scene_source.contains(WATER_ANIMATION_SCRIPT_PATH))
	assert_false(scene_source.contains(FRONT_WATER_STATIC_PATH))


func test_scene7_far_background_rebuilds_large_desert_masses_without_pixel_noise() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var background := stage.get_node("FarBackground") as TextureRect
	assert_eq(background.size, Vector2(289.0, 171.0))
	assert_eq(background.scale, Vector2(6.7, 6.7))
	assert_eq(background.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)

	var material := background.material as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_eq(material.shader.resource_path, FAR_CLEANUP_SHADER_PATH)
	assert_gte(float(material.get_shader_parameter("cleanup_strength")), 0.65)
	assert_lte(float(material.get_shader_parameter("cleanup_strength")), 0.82)
	assert_gte(float(material.get_shader_parameter("outlier_threshold")), 0.14)
	assert_lte(float(material.get_shader_parameter("outlier_threshold")), 0.26)
	assert_gte(float(material.get_shader_parameter("neighbor_coherence")), 0.06)
	assert_lte(float(material.get_shader_parameter("neighbor_coherence")), 0.16)
	assert_gte(float(material.get_shader_parameter("edge_protection")), 0.12)
	assert_lte(float(material.get_shader_parameter("edge_protection")), 0.28)
	assert_gte(float(material.get_shader_parameter("macro_block_px")), 1.5)
	assert_lte(float(material.get_shader_parameter("macro_block_px")), 2.5)
	assert_gte(float(material.get_shader_parameter("detail_reduction")), 0.20)
	assert_lte(float(material.get_shader_parameter("detail_reduction")), 0.36)
	assert_gte(float(material.get_shader_parameter("palette_strength")), 0.12)
	assert_lte(float(material.get_shader_parameter("palette_strength")), 0.24)
	assert_gte(float(material.get_shader_parameter("atmosphere_strength")), 0.08)
	assert_lte(float(material.get_shader_parameter("atmosphere_strength")), 0.16)
	var shader_source := FileAccess.get_file_as_string(FAR_CLEANUP_SHADER_PATH)
	assert_true(shader_source.contains("TEXTURE_PIXEL_SIZE"))
	assert_true(shader_source.contains("neighbor_mean"))
	assert_true(shader_source.contains("outlier_gate"))
	assert_true(shader_source.contains("edge_gate"))
	assert_true(shader_source.contains("macro_block_px"))
	assert_true(shader_source.contains("detail_reduction"))
	assert_true(shader_source.contains("source_preserved"))
	assert_true(shader_source.contains("atmosphere_color"))
	assert_false(shader_source.contains("filter_linear"))


func test_scene7_midgrounds_author_distinct_root_and_water_contacts() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var geometry_contract := {
		"MidgroundCenter": [Vector2(253.0, 168.0), Vector2(522.2, 240.8), Vector2(2.5, 2.5), "rear_center_island", 683.0],
		"MidgroundLeft": [Vector2(-294.0, 82.0), Vector2(359.83334, 271.08334), Vector2(2.4, 2.4), "rear_left_bank", 679.0],
		"MidgroundRight": [Vector2(1330.0, 117.0), Vector2(352.4167, 251.0), Vector2(2.4, 2.4), "rear_right_bank", 679.0],
		"ForegroundLeft": [Vector2(-174.0, 280.0), Vector2(224.0, 280.0), Vector2(3.25, 3.25), "front_left_bank_frame", 864.0],
		"ForegroundRight": [Vector2(1282.0, 527.0), Vector2(304.0, 204.0), Vector2(3.0, 3.0), "front_right_bank_frame", 864.0],
	}
	for node_name: String in geometry_contract:
		var geometry: Array = geometry_contract[node_name]
		var geometry_layer := stage.get_node(node_name) as TextureRect
		assert_eq(geometry_layer.position, geometry[0])
		assert_true(geometry_layer.size.is_equal_approx(geometry[1]))
		assert_eq(geometry_layer.scale, geometry[2])
		if node_name.begins_with("Foreground"):
			assert_eq(geometry_layer.size, geometry_layer.texture.get_size())
		assert_eq(String(geometry_layer.get_meta("composition_role")), geometry[3])
		assert_almost_eq(
				float(geometry_layer.get_meta("shoreline_anchor_y")), geometry[4], 0.01)
	var contact_strengths: Array[float] = []
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		assert_eq(material.shader.resource_path, BIOLUME_SHADER_PATH)
		var palette_strength := float(material.get_shader_parameter("palette_strength"))
		var contact_strength := float(material.get_shader_parameter("contact_strength"))
		var sediment_strength := float(material.get_shader_parameter("sediment_strength"))
		var reflection_strength := float(material.get_shader_parameter("reflection_strength"))
		assert_gte(palette_strength, 0.20, "%s needs restrained oasis depth grading" % node_name)
		assert_gte(contact_strength, 0.34, "%s needs an authored root contact" % node_name)
		assert_lte(contact_strength, 0.58, "%s contact must stay local" % node_name)
		assert_gte(sediment_strength, 0.14, "%s needs wet sand staining" % node_name)
		assert_gte(reflection_strength, 0.10, "%s needs a short water reflection" % node_name)
		assert_lte(reflection_strength, 0.24, "%s reflection must stay restrained" % node_name)
		contact_strengths.append(contact_strength)
	assert_ne(contact_strengths[0], contact_strengths[1])
	assert_ne(contact_strengths[1], contact_strengths[2])

	for node_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		assert_almost_eq(float(material.get_shader_parameter("contact_strength")), 0.0, 0.001)
		assert_almost_eq(float(material.get_shader_parameter("reflection_strength")), 0.0, 0.001)


func test_scene7_plant_layers_use_pixel_safe_depth_integration() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var shader_source := FileAccess.get_file_as_string(BIOLUME_SHADER_PATH)
	assert_true(shader_source.contains("TEXTURE_PIXEL_SIZE"))
	assert_true(shader_source.contains("inside_edge"))
	assert_true(shader_source.contains("grade_embedded_cyan"))
	assert_true(shader_source.contains("source_cyan_compression"))
	assert_true(shader_source.contains("source_cyan_value_ceiling"))
	assert_true(shader_source.contains("actual_highlight"))
	assert_true(shader_source.contains("source_cyan_midtone_lift"))
	assert_true(shader_source.contains("apply_cool_highlight_shoulder"))
	assert_true(shader_source.contains("emission_soft_knee"))
	assert_true(shader_source.contains("use_sparse_source_logic"),
			"source-cyan grading must be isolated from protected foreground materials")
	assert_true(shader_source.contains("atmosphere_strength"))
	assert_true(shader_source.contains("edge_integration_strength"))
	assert_true(shader_source.contains("root_merge_strength"))

	var mid_air_total := 0.0
	var foreground_air_total := 0.0
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var air_value: Variant = material.get_shader_parameter("atmosphere_strength")
		var edge_value: Variant = material.get_shader_parameter("edge_integration_strength")
		var root_value: Variant = material.get_shader_parameter("root_merge_strength")
		var cyan_compression: Variant = material.get_shader_parameter("source_cyan_compression")
		var cyan_ceiling: Variant = material.get_shader_parameter("source_cyan_value_ceiling")
		assert_not_null(air_value, "%s needs depth air" % node_name)
		assert_not_null(edge_value, "%s needs one-pixel edge integration" % node_name)
		assert_not_null(root_value, "%s needs water-root merging" % node_name)
		assert_not_null(cyan_compression, "%s needs embedded cyan compression" % node_name)
		assert_not_null(cyan_ceiling, "%s needs a source cyan value ceiling" % node_name)
		if (air_value == null or edge_value == null or root_value == null
				or cyan_compression == null or cyan_ceiling == null):
			continue
		assert_gte(float(air_value), 0.06)
		assert_lte(float(air_value), 0.08)
		assert_gte(float(edge_value), 0.08)
		assert_lte(float(edge_value), 0.15)
		assert_gte(float(root_value), 0.72)
		assert_lte(float(root_value), 0.92)
		assert_gte(float(cyan_compression), 0.20)
		assert_lte(float(cyan_compression), 0.28)
		assert_gte(float(cyan_ceiling), 0.56)
		assert_lte(float(cyan_ceiling), 0.60)
		assert_gte(float(material.get_shader_parameter("emission_threshold")), 0.56)
		assert_gte(float(material.get_shader_parameter("emission_core_end")), 0.92)
		assert_gte(float(material.get_shader_parameter("emission_soft_knee")), 0.14)
		assert_gte(float(material.get_shader_parameter("source_cyan_midtone_lift")), 0.09)
		assert_lte(float(material.get_shader_parameter("source_cyan_midtone_lift")), 0.15)
		assert_gte(float(material.get_shader_parameter("highlight_shoulder_strength")), 6.0)
		assert_between(float(material.get_shader_parameter("cool_output_gain")), 0.94, 0.98)
		mid_air_total += float(air_value)

	for node_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var air_value: Variant = material.get_shader_parameter("atmosphere_strength")
		var edge_value: Variant = material.get_shader_parameter("edge_integration_strength")
		var cyan_compression: Variant = material.get_shader_parameter("source_cyan_compression")
		assert_not_null(air_value, "%s needs restrained depth air" % node_name)
		assert_not_null(edge_value, "%s needs restrained edge integration" % node_name)
		assert_not_null(cyan_compression, "%s keeps source colors by default" % node_name)
		if air_value == null or edge_value == null or cyan_compression == null:
			continue
		assert_gte(float(air_value), 0.02)
		assert_lte(float(air_value), 0.045)
		assert_gte(float(edge_value), 0.04)
		assert_almost_eq(float(cyan_compression), 0.0, 0.001)
		assert_lte(float(edge_value), 0.075)
		foreground_air_total += float(air_value)

	assert_gt(mid_air_total / 3.0, foreground_air_total / 2.0 + 0.025)


func test_scene7_environment_motion_is_local_layered_and_out_of_phase() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var plant_shader_source := FileAccess.get_file_as_string(BIOLUME_SHADER_PATH)
	var veil_shader_source := FileAccess.get_file_as_string(DEPTH_VEIL_SHADER_PATH)
	assert_true(plant_shader_source.contains("void vertex()"))
	assert_true(plant_shader_source.contains("TIME"))
	assert_true(plant_shader_source.contains("sway_strength_px"))
	assert_true(plant_shader_source.contains("spatial_phase"))
	assert_true(plant_shader_source.contains("tip_flutter"))
	assert_true(plant_shader_source.contains("vertical_sway_ratio"))
	assert_true(plant_shader_source.contains("edge_motion_strength"))
	assert_true(plant_shader_source.contains("glow_pulse_strength"))
	assert_true(veil_shader_source.contains("TIME"))
	assert_true(veil_shader_source.contains("smooth_block_noise"))
	assert_true(FileAccess.file_exists(FAR_WATER_SHADER_PATH))
	assert_true(FileAccess.file_exists(WATER_SHADER_PATH))

	var sway_speeds: Array[float] = []
	var pulse_phases: Array[float] = []
	for node_name: String in [
		"MidgroundLeft", "MidgroundCenter", "MidgroundRight",
		"ForegroundLeft", "ForegroundRight",
	]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var sway_strength_value: Variant = material.get_shader_parameter("sway_strength_px")
		var sway_speed_value: Variant = material.get_shader_parameter("sway_speed")
		var pulse_strength_value: Variant = material.get_shader_parameter("glow_pulse_strength")
		var edge_motion_value: Variant = material.get_shader_parameter("edge_motion_strength")
		var pulse_speed_value: Variant = material.get_shader_parameter("glow_pulse_speed")
		var pulse_phase_value: Variant = material.get_shader_parameter("glow_pulse_phase")
		assert_not_null(sway_strength_value, "%s needs local sway" % node_name)
		assert_not_null(pulse_strength_value, "%s needs local emission breathing" % node_name)
		if sway_strength_value == null or sway_speed_value == null \
				or edge_motion_value == null \
				or pulse_strength_value == null or pulse_speed_value == null \
				or pulse_phase_value == null:
			continue
		var minimum_sway := 0.68 if node_name.begins_with("Foreground") else 0.46
		var minimum_pulse := 0.16 if node_name.begins_with("Foreground") else 0.13
		assert_gte(float(sway_strength_value), minimum_sway)
		assert_lte(float(sway_strength_value), 0.82)
		assert_gte(float(sway_speed_value), 0.28)
		assert_lte(float(sway_speed_value), 0.72)
		assert_gte(float(edge_motion_value), 0.05)
		assert_lte(float(edge_motion_value), 0.1)
		assert_gte(float(pulse_strength_value), minimum_pulse)
		assert_lte(float(pulse_strength_value), 0.20)
		assert_gte(float(pulse_speed_value), 0.32)
		assert_lte(float(pulse_speed_value), 0.86)
		sway_speeds.append(float(sway_speed_value))
		pulse_phases.append(float(pulse_phase_value))
	assert_eq(sway_speeds.size(), 5)
	assert_eq(pulse_phases.size(), 5)
	for index: int in range(1, sway_speeds.size()):
		assert_ne(sway_speeds[index], sway_speeds[index - 1])
		assert_ne(pulse_phases[index], pulse_phases[index - 1])

	for mote_name: String in ["OasisMotesFar", "OasisMotesNear"]:
		var motes := stage.get_node_or_null(mote_name) as ColorRect
		assert_not_null(motes, "%s must be a direct procedural layer" % mote_name)
		if motes == null:
			continue
		var material := motes.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, MOTES_SHADER_PATH)
		assert_gte(float(material.get_shader_parameter("rise_px_per_sec")), 2.0)
		assert_lte(float(material.get_shader_parameter("rise_px_per_sec")), 5.0)
		assert_gte(float(material.get_shader_parameter("density")), 0.34)
		assert_gte(float(material.get_shader_parameter("alpha")), 0.28)
		assert_lte(float(material.get_shader_parameter("alpha")), 0.42)
		assert_eq(motes.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(motes.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_gte((stage.get_node("OasisMotesFar") as ColorRect).position.y, 500.0)
	assert_gte((stage.get_node("OasisMotesNear") as ColorRect).position.y, 600.0)
	if stage.get_node_or_null("OasisMotesFar") == null \
			or stage.get_node_or_null("OasisMotesNear") == null:
		return
	assert_lt(stage.get_node("OasisMotesFar").get_index(),
			stage.get_node("MidgroundLeft").get_index())
	assert_lt(stage.get_node("MidgroundCenter").get_index(),
			stage.get_node("FrontWater").get_index())
	assert_lt(stage.get_node("FrontWater").get_index(),
			stage.get_node("BattlePlatform").get_index())
	assert_lt(stage.get_node("BattlePlatform").get_index(),
			stage.get_node("OasisMotesNear").get_index())
	assert_lt(stage.get_node("OasisMotesNear").get_index(),
			stage.get_node("ForegroundLeft").get_index())


func test_scene7_front_water_underlaps_the_authored_road() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var platform_visible_rect := _displayed_used_rect(platform)
	var front_water := stage.get_node("FrontWater") as ColorRect
	var platform_underlap := platform_visible_rect.end.y - front_water.position.y
	assert_gte(platform_underlap, 6.0)
	assert_lte(platform_underlap, 10.0)
	assert_lt(front_water.get_index(), platform.get_index())
	assert_null(stage.get_node_or_null("PlatformWaterContact"))


func test_scene7_water_is_scene2_style_code_animation_without_sprite_sheets() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_true(FileAccess.file_exists(FAR_WATER_SHADER_PATH))
	assert_true(FileAccess.file_exists(WATER_SHADER_PATH))
	assert_false(FileAccess.file_exists(WATER_ANIMATION_SCRIPT_PATH))
	assert_false(FileAccess.file_exists(REAR_WATER_STATIC_PATH))
	assert_false(FileAccess.file_exists(FRONT_WATER_STATIC_PATH))
	assert_false(FileAccess.file_exists(REAR_WATER_ANIMATED_PATH))
	assert_false(FileAccess.file_exists(FRONT_WATER_ANIMATED_PATH))
	assert_null(stage.get_node_or_null("RearWaterShape"))
	assert_null(stage.get_node_or_null("FrontShallowWater"))
	assert_null(stage.get_node_or_null("RearWaterAnimated"))
	assert_null(stage.get_node_or_null("FrontWaterAnimated"))
	assert_null(stage.get_node_or_null("RearWaterFrameArt"))
	assert_null(stage.get_node_or_null("FrontWaterFrameArt"))
	assert_null(stage.get_node_or_null("WaterFrameController"))
	assert_null(stage.get_node_or_null("WaterAnimationController"))
	assert_null(stage.get_node_or_null("RearWaterDiagnosticRoot"))
	assert_null(stage.get_node_or_null("FrontWaterDiagnosticRoot"))
	assert_null(stage.get_node_or_null("WaterDiagnosticController"))
	assert_null(stage.get_node_or_null("RearWaterAnimation"))
	assert_null(stage.get_node_or_null("FrontWaterAnimation"))
	assert_null(stage.get_node_or_null("PlatformWaterContact"))
	var rear_water := stage.get_node("RearWater") as Polygon2D
	var front_water := stage.get_node("FrontWater") as ColorRect
	var rear_material := rear_water.material as ShaderMaterial
	var front_material := front_water.material as ShaderMaterial
	assert_not_null(rear_material)
	assert_not_null(front_material)
	assert_eq(rear_material.shader.resource_path, FAR_WATER_SHADER_PATH)
	assert_eq(front_material.shader.resource_path, WATER_SHADER_PATH)
	assert_eq(float(rear_water.get_meta("parallax_factor")), 0.55)
	assert_eq(float(front_water.get_meta("parallax_factor")), 1.0)
	assert_eq(rear_water.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(front_water.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_null(rear_water.texture)
	assert_lt(rear_water.get_index(), front_water.get_index())
	assert_lt(stage.get_node("MidgroundLeft").get_index(), front_water.get_index())
	assert_lt(stage.get_node("MidgroundCenter").get_index(), front_water.get_index())
	assert_lt(stage.get_node("MidgroundRight").get_index(), front_water.get_index())
	var reflection_grab := stage.get_node_or_null("OasisReflectionGrab") as BackBufferCopy
	assert_not_null(reflection_grab)
	assert_eq(reflection_grab.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_lt(stage.get_node("MidgroundCenter").get_index(), reflection_grab.get_index())
	assert_lt(reflection_grab.get_index(), front_water.get_index())
	assert_lt(front_water.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_gte(float(rear_material.get_shader_parameter("main_ring_strength")), 0.38)
	assert_gte(float(front_material.get_shader_parameter("main_ring_strength")), 0.35)
	assert_gte(float(rear_material.get_shader_parameter("caustic_strength")), 0.10)
	assert_gte(float(front_material.get_shader_parameter("caustic_strength")), 0.10)
	assert_gte(float(front_material.get_shader_parameter("reflection_height_px")), 500.0)
	assert_gte(float(front_material.get_shader_parameter("reflection_strength")), 0.5)
	assert_gte(float(front_material.get_shader_parameter("reflection_colorize")), 0.6)
	var front_surface: Color = front_material.get_shader_parameter("surface_color")
	var front_deep: Color = front_material.get_shader_parameter("deep_color")
	assert_gte(front_surface.s, 0.80)
	assert_gte(front_deep.s, 0.90)
	assert_between(front_surface.h * 360.0, 180.0, 205.0)
	assert_between(front_deep.h * 360.0, 180.0, 215.0)
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	assert_true(bool(screen.get("character_reflections_enabled")))
	assert_eq(screen.get("character_reflection_receiver_path"), NodePath("FrontWater"))
	var rear_source := FileAccess.get_file_as_string(FAR_WATER_SHADER_PATH)
	var front_source := FileAccess.get_file_as_string(WATER_SHADER_PATH)
	assert_true(rear_source.contains("TIME * anim_fps"))
	assert_true(rear_source.contains("local_position = VERTEX"))
	assert_true(rear_source.contains("spring_distance"))
	assert_true(rear_source.contains("ring_mask"))
	assert_false(rear_source.contains("flow_speed_px"))
	assert_false(rear_source.contains("flow_direction"))
	assert_false(rear_source.contains("sampler2D TEXTURE"))
	assert_true(front_source.contains("TIME * anim_fps"))
	assert_true(front_source.contains("hint_screen_texture"))
	assert_true(front_source.contains("SCREEN_UV"))
	assert_true(front_source.contains("p1_reflection_tex"))
	assert_true(front_source.contains("character_waterline_y"))
	assert_true(front_source.contains("reflection_height_px"))
	assert_true(front_source.contains("signed_radial_wave"))
	assert_true(front_source.contains("spring_distance"))
	assert_true(front_source.contains("ring_mask"))
	assert_false(front_source.contains("ripple_speed_px"))
	assert_false(front_source.contains("flow_direction"))
	assert_false(front_source.contains("slice_speed"))
	assert_false(front_source.contains("AtlasTexture"))


func test_scene7_platform_material_exposes_a_raised_shore_contact_band() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var material := platform.material as ShaderMaterial
	assert_eq(material.shader.resource_path, PLATFORM_ELEVATION_SHADER_PATH)
	if material.shader.resource_path != PLATFORM_ELEVATION_SHADER_PATH:
		return
	var contact_band_px := float(material.get_shader_parameter("contact_band_px"))
	assert_gte(contact_band_px, 4.0)
	assert_lte(contact_band_px, 6.0)
	assert_gte(float(material.get_shader_parameter("dry_edge_strength")), 0.34)
	assert_gte(float(material.get_shader_parameter("wet_edge_strength")), 0.22)
	assert_lte(float(material.get_shader_parameter("wet_edge_strength")), 0.24)
	assert_gte(float(material.get_shader_parameter("contact_shadow_strength")), 0.28)
	assert_lte(float(material.get_shader_parameter("contact_shadow_strength")), 0.3)
	assert_gte(float(material.get_shader_parameter("waterline_strength")), 0.12)
	assert_lte(float(material.get_shader_parameter("waterline_strength")), 0.14)
	var wet_edge_color: Color = material.get_shader_parameter("wet_edge_color")
	var waterline_color: Color = material.get_shader_parameter("waterline_color")
	assert_between(wet_edge_color.h * 360.0, 190.0, 205.0)
	assert_between(waterline_color.h * 360.0, 182.0, 200.0)
	var platform_shader_source := FileAccess.get_file_as_string(
			PLATFORM_ELEVATION_SHADER_PATH)
	assert_false(platform_shader_source.contains("TIME"))


func test_scene7_guides_keep_the_mature_character_baseline() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_eq(
			(stage.get_node("CompositionGuides/P1Baseline") as Marker2D).position,
			Vector2(480.0, 748.0))
	assert_eq(
			(stage.get_node("CompositionGuides/P2Baseline") as Marker2D).position,
			Vector2(1440.0, 748.0))
	assert_eq(
			(stage.get_node("CompositionGuides/PlatformBaseline") as Marker2D).position,
			Vector2(960.0, 748.0))
	assert_eq(float(stage.get_node("BattlePlatform").get_meta("parallax_factor")), 1.0)


func test_scene7_restores_neutral_daylight_and_shades_only_behind_ui() -> void:
	if not ResourceLoader.exists(BATTLE7_PATH):
		return

	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var post_fx := screen.get_node("PostFX") as ColorRect
	var veil := screen.get_node_or_null("UiReadabilityVeil") as ColorRect
	assert_not_null(veil)
	if veil == null:
		return
	assert_lt(post_fx.get_index(), veil.get_index())
	for ui_name: String in ["P1Hud", "P2Hud", "TimerLabel", "Buttons"]:
		assert_lt(veil.get_index(), screen.get_node(ui_name).get_index())
	assert_eq(veil.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	var veil_material := veil.material as ShaderMaterial
	assert_not_null(veil_material)
	if veil_material != null:
		assert_eq(veil_material.shader.resource_path, UI_READABILITY_SHADER_PATH)
		assert_gte(float(veil_material.get_shader_parameter("hud_support_strength")), 0.14)
		assert_lte(float(veil_material.get_shader_parameter("hud_support_strength")), 0.22)
		assert_gte(float(veil_material.get_shader_parameter("timer_support_strength")), 0.18)
		assert_lte(float(veil_material.get_shader_parameter("timer_support_strength")), 0.26)
		assert_gte(float(veil_material.get_shader_parameter("bottom_strength")), 0.35)
		assert_lte(float(veil_material.get_shader_parameter("bottom_strength")), 0.50)
		assert_between(float(veil_material.get_shader_parameter("horizontal_feather")), 0.012, 0.022)
		assert_between(float(veil_material.get_shader_parameter("top_fade_start")), 0.04, 0.07)
		assert_between(float(veil_material.get_shader_parameter("top_fade_end")), 0.20, 0.25)
		var support_tint: Color = veil_material.get_shader_parameter("support_tint")
		assert_gt(support_tint.g, support_tint.r * 1.8)
		assert_gt(support_tint.b, support_tint.r * 2.0)
	var veil_source := FileAccess.get_file_as_string(UI_READABILITY_SHADER_PATH)
	assert_true(veil_source.contains("local_horizontal_mask"))
	assert_true(veil_source.contains("top_falloff"))
	assert_true(veil_source.contains("p1_support"))
	assert_true(veil_source.contains("p2_support"))
	assert_true(veil_source.contains("timer_support"))
	assert_true(veil_source.contains("support_gate"))
	assert_true(veil_source.contains("hint_screen_texture"))
	assert_false(veil_source.contains("p1_hud_mask"))
	assert_false(veil_source.contains("shade_color"))

	var post_material := post_fx.material as ShaderMaterial
	assert_gte(float(post_material.get_shader_parameter("brightness")), 1.0)
	assert_lte(float(post_material.get_shader_parameter("brightness")), 1.02)
	assert_gte(float(post_material.get_shader_parameter("saturation")), 0.9)
	assert_lte(float(post_material.get_shader_parameter("saturation")), 0.95)
	assert_eq(float(post_material.get_shader_parameter("split_strength")), 0.0)
	assert_eq(float(post_material.get_shader_parameter("vignette_strength")), 0.0)
	assert_eq(float(post_material.get_shader_parameter("tint_strength")), 0.0)


func test_scene7_final_palette_separates_daylight_sand_oasis_shade_and_biolume() -> void:
	if not ResourceLoader.exists(SCENE7_PATH) or not ResourceLoader.exists(BATTLE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	add_child_autofree(screen)
	await get_tree().process_frame

	for node_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var shadow_palette: Color = material.get_shader_parameter("shadow_palette")
		var sunlit_palette: Color = material.get_shader_parameter("sunlit_palette")
		var palette_strength := float(material.get_shader_parameter("palette_strength"))
		assert_gte(palette_strength, 0.2, "%s needs the oasis palette" % node_name)
		assert_lte(palette_strength, 0.25, "%s must retain source detail" % node_name)
		assert_gt(shadow_palette.g, shadow_palette.r * 3.0)
		assert_gt(shadow_palette.b, shadow_palette.r * 2.8)
		assert_gt(sunlit_palette.r, sunlit_palette.b * 1.35)
		assert_gt(sunlit_palette.g, sunlit_palette.b * 1.6)

	var background_material := \
			(stage.get_node("FarBackground") as TextureRect).material as ShaderMaterial
	var far_shadow: Color = background_material.get_shader_parameter("shadow_color")
	var far_sand: Color = background_material.get_shader_parameter("sand_color")
	var far_atmosphere: Color = background_material.get_shader_parameter("atmosphere_color")
	assert_gt(far_shadow.g, far_shadow.r * 1.7)
	assert_gt(far_shadow.b, far_shadow.r * 1.7)
	assert_gt(far_sand.r, far_sand.b * 1.7)
	assert_gt(far_sand.g, far_sand.b * 1.35)
	assert_gt(far_atmosphere.g, far_atmosphere.r * 1.35)
	assert_gt(far_atmosphere.b, far_atmosphere.r * 1.35)
	assert_gte(float(background_material.get_shader_parameter("palette_strength")), 0.12)
	assert_lte(float(background_material.get_shader_parameter("palette_strength")), 0.24)
	assert_gte(float(background_material.get_shader_parameter("atmosphere_strength")), 0.08)
	assert_lte(float(background_material.get_shader_parameter("atmosphere_strength")), 0.16)

	var post_material := (screen.get_node("PostFX") as ColorRect).material as ShaderMaterial
	var shadow_tint: Color = post_material.get_shader_parameter("shadow_tint")
	var highlight_tint: Color = post_material.get_shader_parameter("highlight_tint")
	assert_gte(float(post_material.get_shader_parameter("brightness")), 1.0)
	assert_gte(float(post_material.get_shader_parameter("saturation")), 0.9)
	assert_lte(float(post_material.get_shader_parameter("saturation")), 0.95)
	assert_eq(float(post_material.get_shader_parameter("split_strength")), 0.0)
	assert_eq(float(post_material.get_shader_parameter("vignette_strength")), 0.0)
	assert_gt(shadow_tint.g, shadow_tint.r)
	assert_gt(shadow_tint.b, shadow_tint.r)
	assert_gt(highlight_tint.r, highlight_tint.b * 1.04)
	assert_eq(float(post_material.get_shader_parameter("edge_blur_amount")), 0.0)
	assert_eq(float(post_material.get_shader_parameter("grain_amount")), 0.0)
	assert_eq(float(post_material.get_shader_parameter("heat_haze_strength")), 0.0)


func test_scene7_reuses_character_geometry_with_daylight_visual_parameters() -> void:
	if not ResourceLoader.exists(BATTLE7_PATH):
		return

	BattleSetup.reset()
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var base_node := base.get_node(node_name) as CharacterDisplay
		var scene7_node := screen.get_node("WorldGroup/%s" % node_name) as CharacterDisplay
		assert_eq(scene7_node.position, base_node.position)
		assert_eq(scene7_node.size, base_node.size)
		assert_eq(scene7_node.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(scene7_node.rim_color, Color(1.0, 0.91, 0.74, 1.0))
		assert_almost_eq(scene7_node.rim_strength, 0.0, 0.001)
		assert_almost_eq(scene7_node.backlight, 0.012, 0.001)
		assert_eq(scene7_node.shadow_tint, Color(0.86, 0.9, 0.88, 1.0))
		assert_eq(scene7_node.light_dir, Vector2(0.35, -1.0))
		assert_eq(scene7_node.skin_warmth, Color(1.02, 1.01, 0.99, 1.0))
		assert_almost_eq(scene7_node.warmth_amount, 0.0, 0.001)
		assert_eq(scene7_node.fill_color, Color(0.36, 0.6, 0.56, 1.0))
		assert_almost_eq(scene7_node.fill_amount, 0.0, 0.001)
		assert_not_null(scene7_node.get_render_texture())
		var sprite := scene7_node.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
		assert_not_null(sprite.sprite_frames)
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material != null:
			assert_eq(material.shader.resource_path, SCENE7_CHARACTER_SHADER_PATH)
			assert_almost_eq(
					float(material.get_shader_parameter("source_saturation")),
					1.0,
					0.001)
			assert_almost_eq(
					float(material.get_shader_parameter("source_contrast")),
					1.0,
					0.001)
			assert_almost_eq(
					float(material.get_shader_parameter("daylight_key_amount")),
					0.004,
					0.001)
			assert_almost_eq(
					float(material.get_shader_parameter("water_bounce_amount")),
					0.006,
					0.001)
			assert_almost_eq(
					float(material.get_shader_parameter("ambient_tint_amount")),
					0.08,
					0.001)
			assert_almost_eq(
					float(material.get_shader_parameter("highlight_shoulder_strength")),
					0.8,
					0.001)

	var shadow_positions: Dictionary[String, Vector2] = {
		"P1Shadow": Vector2(414.0, 732.0),
		"P2Shadow": Vector2(1374.0, 732.0),
	}
	for shadow_name: String in shadow_positions:
		var shadow := screen.get_node("WorldGroup/%s" % shadow_name) as TextureRect
		assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(shadow.rotation, 0.0)
		assert_eq(shadow.position, shadow_positions[shadow_name])
		assert_eq(shadow.size, Vector2(132.0, 32.0))
		assert_eq(shadow.self_modulate, Color.WHITE)
		var shadow_material := shadow.material as ShaderMaterial
		assert_not_null(shadow_material)
		if shadow_material != null:
			assert_eq(
					shadow_material.shader.resource_path,
					SCENE7_CONTACT_SHADOW_SHADER_PATH)
			assert_almost_eq(
				float(shadow_material.get_shader_parameter("shadow_strength")),
				0.60,
				0.001)
			assert_almost_eq(
				float(shadow_material.get_shader_parameter("wet_edge_strength")),
				0.14,
				0.001)
			assert_almost_eq(
				float(shadow_material.get_shader_parameter("foot_height")),
				0.20,
				0.001)

	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)

	var post_fx := screen.get_node("PostFX") as ColorRect
	var post_material := post_fx.material as ShaderMaterial
	assert_not_null(post_material)
	if post_material != null:
		assert_eq(post_material.shader.resource_path, POSTFX_SHADER_PATH)
		assert_eq(float(post_material.get_shader_parameter("barrel_amount")), 0.0)
		assert_almost_eq(float(post_material.get_shader_parameter("brightness")), 1.01, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("contrast")), 1.0, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("saturation")), 0.95, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("tint_strength")), 0.0, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("split_strength")), 0.0, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("vignette_strength")), 0.0, 0.001)
		assert_eq(float(post_material.get_shader_parameter("grain_amount")), 0.0)
		assert_eq(float(post_material.get_shader_parameter("heat_haze_strength")), 0.0)
	base.free()
	BattleSetup.reset()


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var source_size: Vector2 = layer.texture.get_size()
	var stretch_ratio := Vector2(
		layer.size.x / source_size.x,
		layer.size.y / source_size.y)
	return Rect2(
		layer.position + Vector2(used_rect.position) * stretch_ratio * layer.scale,
		Vector2(used_rect.size) * stretch_ratio * layer.scale)


func _alpha_used_rect(image: Image, threshold: float) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _is_water_frame_palette_color(sample: Color) -> bool:
	var opaque_sample := Color(sample.r, sample.g, sample.b, 1.0)
	for candidate: Color in [
		Color("071c2d"), Color("0a3040"), Color("0b4144"), Color("10574f"),
		Color("176b77"), Color("248797"), Color("45adb1"), Color("76d8bf"),
	]:
		if opaque_sample.is_equal_approx(candidate):
			return true
	return false


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
