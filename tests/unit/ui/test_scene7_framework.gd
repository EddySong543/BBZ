extends GutTest

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"
const SCENE7_CHARACTER_SHADER_PATH := \
		"res://assets/shaders/character_light.gdshader"
const SCENE7_CONTACT_SHADOW_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_contact_shadow.gdshader"
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"
const UI_READABILITY_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_ui_readability.gdshader"
const FAR_CLEANUP_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_far_cleanup.gdshader"
const SKY_GRADE_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_sky_grade.gdshader"
const BIOLUME_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_biolume_plant.gdshader"
const BIOLUME_GLOW_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_biolume_glow_fx.gdshader"
const BIOLUME_RELIGHT_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_biolume_cluster_relight.gdshader"
const BIOLUME_GLOW_SCRIPT_PATH := \
		"res://src/ui/components/scene7_biolume_glow_overlay.gd"
const MIDGROUND_MOTION_SCRIPT_PATH := \
		"res://src/ui/components/scene7_midground_motion_mesh.gd"
const SCENE7_BRANCH_MASK_ROOT := \
		"res://assets/scenes/scene7/scene7_branch_mask_"
const SCENE7_BRANCH_UNDERPAINT_ROOT := \
		"res://assets/scenes/scene7/scene7_branch_underpaint_"
const MIDGROUND_PALETTE_PRESETS_PATH := \
		"res://tools/scene7_midground_palette_presets.gd"
const FAR_WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_water.gdshader"
const FAR_REFLECTION_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_reflection.gdshader"
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
const PLATFORM_SPRING_CONTACT_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_platform_spring_contact.gdshader"
const FOREGROUND_CENTER_STONE_PATH := \
		"res://assets/scenes/scene7/scene7_foreground_center_stone.png"
const DEPTH_VEIL_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_depth_veil.gdshader"
const MOTES_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_motes.gdshader"
const FOREGROUND_STONE_GRADE_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_foreground_stone_grade.gdshader"
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
		"ForegroundCenterStone": 1.25,
		"ForegroundCenterStone2": 1.25,
		"ForegroundCenterStone3": 1.25,
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
	assert_eq(String(stage.get_meta("theme_name", "")), "珊瑚霞金碧月泉")
	assert_null(stage.get_node_or_null("DaylightBackdrop"))
	var sky := stage.get_node("Sky") as TextureRect
	var sky_material := sky.material as ShaderMaterial
	assert_not_null(sky_material)
	if sky_material != null:
		assert_true(sky_material.resource_local_to_scene)
		assert_eq(sky_material.shader.resource_path, SKY_GRADE_SHADER_PATH)
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
		"ForegroundCenterStone": FOREGROUND_CENTER_STONE_PATH,
		"ForegroundCenterStone2": FOREGROUND_CENTER_STONE_PATH,
		"ForegroundCenterStone3": FOREGROUND_CENTER_STONE_PATH,
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
	assert_gte(float(depth_veil_material.get_shader_parameter("opacity")), 0.015)
	assert_lte(float(depth_veil_material.get_shader_parameter("opacity")), 0.025)
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
	assert_eq(rear_pool.vertex_colors.size(), 24)
	for vertex_index: int in range(22):
		assert_almost_eq(rear_pool.vertex_colors[vertex_index].r, 0.0, 0.001)
	for vertex_index: int in range(22, 24):
		assert_almost_eq(rear_pool.vertex_colors[vertex_index].r, 1.0, 0.001)
	assert_lte(front_water.position.x, -24.0)
	assert_gte(front_water.position.x + front_water.size.x, 1944.0)
	assert_gte(front_water.position.y, 822.0)
	assert_lte(front_water.position.y, 826.0)
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
	var platform_source_rect := _displayed_used_rect(platform)
	var platform_visible_rect := _scene7_platform_visible_rect(platform)
	assert_lt(platform_source_rect.position.x, 0.0)
	assert_gt(platform_source_rect.end.x, 1920.0)
	assert_almost_eq(platform_source_rect.size.y, 126.0, 0.05)
	assert_almost_eq(platform_visible_rect.size.y, 96.0, 0.05)
	assert_lte(platform_visible_rect.position.y, 748.0)
	assert_almost_eq(platform_visible_rect.end.y, 834.0, 0.01)
	assert_false(scene_source.contains("res://assets/import/"))
	assert_true(scene_source.contains(SCENE7_ASSET_ROOT))
	assert_true(scene_source.contains("canvas_env_scene7"))
	assert_false(scene_source.contains("OasisWaterFront"))
	assert_true(scene_source.contains("Scene7FrontWaterMat"))
	assert_true(scene_source.contains(FAR_WATER_SHADER_PATH))
	assert_true(scene_source.contains(WATER_SHADER_PATH))
	assert_false(scene_source.contains(WATER_ANIMATION_SCRIPT_PATH))
	assert_false(scene_source.contains(FRONT_WATER_STATIC_PATH))


func test_scene7_far_background_uses_continuous_atmospheric_perspective() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var background := stage.get_node("FarBackground") as TextureRect
	assert_eq(background.size, Vector2(332.0, 188.0))
	assert_eq(background.scale, Vector2(6.0, 6.0))
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
	assert_eq(float(material.get_shader_parameter("local_radius_px")), 2.0)
	assert_gte(float(material.get_shader_parameter("far_detail_retention")), 0.66)
	assert_lte(float(material.get_shader_parameter("far_detail_retention")), 0.78)
	assert_gte(float(material.get_shader_parameter("near_detail_retention")), 0.90)
	assert_lte(float(material.get_shader_parameter("near_detail_retention")), 0.98)
	assert_gte(float(material.get_shader_parameter("far_saturation_retention")), 0.92)
	assert_lte(float(material.get_shader_parameter("far_saturation_retention")), 0.98)
	assert_gte(float(material.get_shader_parameter("near_saturation_retention")), 0.98)
	assert_lte(float(material.get_shader_parameter("near_saturation_retention")), 1.0)
	assert_gte(float(material.get_shader_parameter("air_strength")), 0.04)
	assert_lte(float(material.get_shader_parameter("air_strength")), 0.08)
	assert_gte(float(material.get_shader_parameter("edge_air_strength")), 0.08)
	assert_lte(float(material.get_shader_parameter("edge_air_strength")), 0.12)
	assert_gte(float(material.get_shader_parameter("horizon_warmth")), 0.08)
	assert_lte(float(material.get_shader_parameter("horizon_warmth")), 0.12)
	assert_between(float(material.get_shader_parameter(
			"sand_palette_strength")), 0.96, 1.0)
	assert_between(float(material.get_shader_parameter(
			"sand_saturation")), 1.12, 1.20)
	assert_between(float(material.get_shader_parameter(
			"source_value_detail")), 0.28, 0.35)
	var sand_shadow: Color = material.get_shader_parameter("sand_shadow_color")
	var sand_mid: Color = material.get_shader_parameter("sand_mid_color")
	var sand_highlight: Color = material.get_shader_parameter("sand_highlight_color")
	assert_between(sand_shadow.h * 360.0, 285.0, 315.0)
	assert_between(sand_shadow.s, 0.22, 0.30)
	assert_between(sand_mid.h * 360.0, 6.0, 18.0)
	assert_between(sand_mid.s, 0.36, 0.48)
	assert_between(sand_highlight.h * 360.0, 20.0, 34.0)
	assert_between(sand_highlight.s, 0.38, 0.46)
	assert_lt(_luma(sand_shadow), _luma(sand_mid))
	assert_lt(_luma(sand_mid), _luma(sand_highlight))
	var shader_source := FileAccess.get_file_as_string(FAR_CLEANUP_SHADER_PATH)
	assert_true(shader_source.contains("TEXTURE_PIXEL_SIZE"))
	assert_true(shader_source.contains("neighbor_mean"))
	assert_true(shader_source.contains("outlier_gate"))
	assert_true(shader_source.contains("edge_gate"))
	assert_true(shader_source.contains("alpha_weighted_local_mean"))
	assert_true(shader_source.contains("interior_gate"))
	assert_true(shader_source.contains("distance_weight"))
	assert_true(shader_source.contains("detail_retention"))
	assert_true(shader_source.contains("structural_edge"))
	assert_true(shader_source.contains("silhouette_air"))
	assert_true(shader_source.contains("horizon_warmth"))
	assert_true(shader_source.contains("warm_chroma_mask"))
	assert_true(shader_source.contains("luma_scaled_palette"))
	assert_true(shader_source.contains("sand_palette_ramp"))
	assert_true(shader_source.contains("saturation_scaled_palette"))
	assert_true(shader_source.contains("sand_shadow_color"))
	assert_true(shader_source.contains("sand_mid_color"))
	assert_true(shader_source.contains("sand_highlight_color"))
	assert_false(shader_source.contains("macro_block_px"))
	assert_false(shader_source.contains("quantized_zone"))
	assert_false(shader_source.contains("top_ridge"))
	assert_false(shader_source.contains("filter_linear"))
	assert_false(shader_source.contains("TIME"))


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
	assert_true(shader_source.contains("biolume_core_mask"))
	assert_true(shader_source.contains("preserve_biolume_core"))
	assert_true(shader_source.contains("body_compression_mask"))
	assert_true(shader_source.contains("source_cyan_midtone_lift"))
	assert_true(shader_source.contains("apply_cool_highlight_shoulder"))
	assert_true(shader_source.contains("emission_soft_knee"))
	assert_true(shader_source.contains("use_sparse_source_logic"),
			"source-cyan grading must be isolated from protected foreground materials")
	assert_true(shader_source.contains("atmosphere_strength"))
	assert_true(shader_source.contains("edge_integration_strength"))
	assert_true(shader_source.contains("root_merge_strength"))
	assert_true(shader_source.contains("root_contact_zone"))
	assert_true(shader_source.contains("solid_root_face"))
	assert_true(shader_source.contains("submerged_fringe"))

	var mid_air_total := 0.0
	var foreground_air_total := 0.0
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var air_value: Variant = material.get_shader_parameter("atmosphere_strength")
		var edge_value: Variant = material.get_shader_parameter("edge_integration_strength")
		var root_value: Variant = material.get_shader_parameter("root_merge_strength")
		var cyan_compression: Variant = material.get_shader_parameter("source_cyan_compression")
		var cyan_ceiling: Variant = material.get_shader_parameter("source_cyan_value_ceiling")
		var core_preservation: Variant = material.get_shader_parameter("core_preservation")
		assert_not_null(air_value, "%s needs depth air" % node_name)
		assert_not_null(edge_value, "%s needs one-pixel edge integration" % node_name)
		assert_not_null(root_value, "%s needs water-root merging" % node_name)
		assert_not_null(cyan_compression, "%s needs body-only cyan compression" % node_name)
		assert_not_null(cyan_ceiling, "%s needs a restrained cyan body ceiling" % node_name)
		assert_not_null(core_preservation, "%s must preserve authored luminous cores" % node_name)
		if (air_value == null or edge_value == null or root_value == null
				or cyan_compression == null or cyan_ceiling == null
				or core_preservation == null):
			continue
		assert_gte(float(air_value), 0.055)
		assert_lte(float(air_value), 0.07)
		assert_gte(float(edge_value), 0.08)
		assert_lte(float(edge_value), 0.15)
		assert_gte(float(root_value), 0.72)
		assert_lte(float(root_value), 0.92)
		assert_between(float(material.get_shader_parameter("contact_start")), 0.68, 0.78)
		var sediment_color: Color = material.get_shader_parameter("sediment_color")
		assert_between(sediment_color.h * 360.0, 285.0, 315.0)
		assert_lte(_luma(sediment_color), 0.34)
		assert_between(float(core_preservation), 0.76, 0.86)
		assert_between(float(cyan_compression), 0.17, 0.19)
		assert_between(float(cyan_ceiling), 0.67, 0.70)
		assert_between(float(material.get_shader_parameter("core_start")), 0.58, 0.68)
		assert_between(float(material.get_shader_parameter("core_full")), 0.78, 0.92)
		assert_between(float(material.get_shader_parameter("core_value_floor")), 0.63, 0.68)
		assert_between(float(material.get_shader_parameter("core_value_ceiling")), 0.76, 0.80)
		assert_between(float(material.get_shader_parameter("core_tint_mix")), 0.24, 0.32)
		assert_between(float(material.get_shader_parameter("emission_threshold")), 0.58, 0.68)
		assert_between(float(material.get_shader_parameter("emission_core_end")), 0.78, 0.92)
		assert_between(float(material.get_shader_parameter("emission_soft_knee")), 0.08, 0.11)
		assert_between(float(material.get_shader_parameter("source_cyan_midtone_lift")), 0.07, 0.085)
		assert_between(float(material.get_shader_parameter("highlight_shoulder_strength")), 1.2, 1.5)
		assert_between(float(material.get_shader_parameter("cool_output_gain")), 0.95, 0.97)
		assert_between(float(material.get_shader_parameter("base_brightness")), 0.88, 0.93)
		var ambient_tint: Color = material.get_shader_parameter("ambient_tint")
		var shadow_palette: Color = material.get_shader_parameter("shadow_palette")
		var sunlit_palette: Color = material.get_shader_parameter("sunlit_palette")
		assert_between(_luma(ambient_tint), 0.63, 0.70)
		assert_between(_luma(shadow_palette), 0.10, 0.15)
		assert_between(_luma(sunlit_palette), 0.32, 0.38)
		assert_between(float(material.get_shader_parameter("palette_strength")), 0.35, 0.39)
		assert_almost_eq(float(material.get_shader_parameter("halo_radius")), 1.0, 0.001)
		assert_lte(float(material.get_shader_parameter("halo_alpha")), 0.12)
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

	assert_gte(mid_air_total / 3.0, foreground_air_total / 2.0 - 0.005)


func test_scene7_environment_motion_is_local_layered_and_out_of_phase() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var plant_shader_source := FileAccess.get_file_as_string(BIOLUME_SHADER_PATH)
	var glow_shader_source := FileAccess.get_file_as_string(BIOLUME_GLOW_SHADER_PATH)
	var relight_shader_source := FileAccess.get_file_as_string(
			BIOLUME_RELIGHT_SHADER_PATH)
	var veil_shader_source := FileAccess.get_file_as_string(DEPTH_VEIL_SHADER_PATH)
	assert_true(plant_shader_source.contains("void vertex()"))
	assert_true(plant_shader_source.contains("TIME"))
	assert_false(plant_shader_source.contains("sway_strength_px"))
	assert_true(plant_shader_source.contains("branch_mask"))
	assert_true(plant_shader_source.contains("branch_underpaint_texture"))
	assert_true(plant_shader_source.contains("branch_underpaint_enabled"))
	assert_true(plant_shader_source.contains("branch_motion_enabled"))
	assert_true(plant_shader_source.contains("inverse_rotate_pixel_uv"))
	assert_true(plant_shader_source.contains("branch_motion_fps"))
	assert_true(plant_shader_source.contains("branch_pivot_a"))
	assert_true(plant_shader_source.contains("branch_cycle_sec"))
	assert_true(plant_shader_source.contains("branch_angle_deg"))
	assert_false(plant_shader_source.contains("mesh_motion_enabled"))
	assert_false(plant_shader_source.contains("leaf_weight = COLOR.r"))
	assert_true(plant_shader_source.contains("point_twinkle_strength"))
	assert_true(plant_shader_source.contains("cluster_breathe_strength"))
	assert_true(plant_shader_source.contains("edge_motion_strength"))
	assert_true(plant_shader_source.contains("glow_pulse_strength"))
	assert_true(glow_shader_source.contains("render_mode unshaded, blend_add"))
	assert_true(glow_shader_source.contains("point_flash"))
	assert_true(glow_shader_source.contains("point_mask"))
	assert_true(glow_shader_source.contains("cluster_mask"))
	assert_true(glow_shader_source.contains("diagnostic_time_sec"))
	assert_true(relight_shader_source.contains("render_mode unshaded, blend_mix"))
	assert_true(relight_shader_source.contains("trough_brightness"))
	assert_true(relight_shader_source.contains("texture(TEXTURE, UV)"))
	assert_true(veil_shader_source.contains("TIME"))
	assert_true(veil_shader_source.contains("smooth_block_noise"))
	assert_true(FileAccess.file_exists(FAR_WATER_SHADER_PATH))
	assert_true(FileAccess.file_exists(FAR_REFLECTION_SHADER_PATH))
	assert_true(FileAccess.file_exists(WATER_SHADER_PATH))
	assert_false(FileAccess.file_exists(MIDGROUND_MOTION_SCRIPT_PATH))
	assert_true(FileAccess.file_exists(MIDGROUND_PALETTE_PRESETS_PATH))
	assert_true(FileAccess.file_exists(BIOLUME_GLOW_SCRIPT_PATH))
	var branch_contract := {
		"MidgroundCenter": ["midground_center", 3, 5.0],
		"MidgroundLeft": ["midground_left", 1, 4.0],
		"MidgroundRight": ["midground_right", 1, 4.0],
		"ForegroundLeft": ["foreground_left", 2, 5.0],
	}
	for source_name: String in branch_contract:
		var contract: Array = branch_contract[source_name]
		var source := stage.get_node(source_name) as TextureRect
		assert_true(source.visible)
		var source_material := source.material as ShaderMaterial
		assert_not_null(source_material)
		if source_material == null:
			continue
		var branch_enabled: Variant = source_material.get_shader_parameter(
				"branch_motion_enabled")
		assert_not_null(branch_enabled)
		if branch_enabled == null:
			continue
		assert_eq(float(branch_enabled), 1.0)
		assert_eq(int(source_material.get_shader_parameter(
				"branch_group_count")), int(contract[1]))
		assert_eq(float(source_material.get_shader_parameter(
				"branch_motion_fps")), float(contract[2]))
		var mask := source_material.get_shader_parameter("branch_mask") as Texture2D
		assert_not_null(mask)
		if mask == null:
			continue
		assert_eq(mask.resource_path,
				SCENE7_BRANCH_MASK_ROOT + String(contract[0]) + ".png")
		assert_eq(mask.get_size(), source.texture.get_size())
		assert_eq(float(source_material.get_shader_parameter(
				"branch_underpaint_enabled")), 1.0)
		var underpaint := source_material.get_shader_parameter(
				"branch_underpaint_texture") as Texture2D
		assert_not_null(underpaint)
		if underpaint != null:
			assert_eq(underpaint.resource_path,
					SCENE7_BRANCH_UNDERPAINT_ROOT + String(contract[0]) + ".png")
			assert_eq(underpaint.get_size(), source.texture.get_size())
		var mask_image := mask.get_image()
		var moving_pixel_count := 0
		for channel: int in range(int(contract[1])):
			var channel_count := _channel_pixel_count(mask_image, channel)
			moving_pixel_count += channel_count
			assert_gte(channel_count, 24)
		if underpaint != null:
			assert_gte(
					_opaque_pixel_count(underpaint.get_image()),
					moving_pixel_count)

	for old_motion_name: String in [
		"MidgroundCenterLeafMotion",
		"MidgroundLeftLeafMotion",
		"MidgroundRightLeafMotion",
	]:
		assert_null(stage.get_node_or_null(old_motion_name))
	var foreground_right_material := (stage.get_node(
			"ForegroundRight") as TextureRect).material as ShaderMaterial
	var foreground_right_branch: Variant = foreground_right_material.get_shader_parameter(
			"branch_motion_enabled")
	assert_true(foreground_right_branch == null \
			or is_zero_approx(float(foreground_right_branch)))

	for source_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var source_material := (stage.get_node(source_name) as TextureRect).material \
				as ShaderMaterial
		assert_eq(float(source_material.get_shader_parameter(
				"point_twinkle_strength")), 0.0)
		assert_eq(float(source_material.get_shader_parameter(
				"cluster_breathe_strength")), 0.0)
		assert_eq(float(source_material.get_shader_parameter(
				"glow_pulse_strength")), 0.0)
		assert_eq(float(source_material.get_shader_parameter(
				"edge_motion_strength")), 0.0)

	var glow_contract := {
		"MidgroundLeftGlowFX": ["MidgroundLeft", true, false, 0.55, false],
		"MidgroundCenterGlowFX": ["MidgroundCenter", true, false, 0.55, false],
		"MidgroundCenterGrassGlowFX": ["MidgroundCenter", false, true, 0.55, true],
		"MidgroundRightGlowFX": ["MidgroundRight", true, false, 0.55, false],
		"MidgroundRightGrassGlowFX": ["MidgroundRight", false, true, 0.55, true],
		"ForegroundLeftGlowFX": ["ForegroundLeft", true, false, 1.25, false],
	}
	for glow_name: String in glow_contract:
		var contract: Array = glow_contract[glow_name]
		var source := stage.get_node(contract[0]) as TextureRect
		var expects_points: bool = contract[1]
		var expects_cluster: bool = contract[2]
		var expects_relight: bool = contract[4]
		var overlay := stage.get_node_or_null(glow_name) as MeshInstance2D
		assert_not_null(overlay)
		if overlay == null:
			continue
		assert_eq(overlay.texture, source.texture)
		assert_true(overlay.position.is_equal_approx(source.position))
		assert_true(overlay.scale.is_equal_approx(source.scale))
		assert_eq(float(overlay.get_meta("parallax_factor")), float(contract[3]))
		if expects_points:
			assert_gte(int(overlay.get_meta("point_component_count", 0)), 3)
			assert_gte(int(overlay.get_meta("point_core_pixel_count", 0)), 3)
			assert_gt(
					int(overlay.get_meta("point_halo_pixel_count", 0)),
					int(overlay.get_meta("point_core_pixel_count", 0)))
		else:
			assert_eq(int(overlay.get_meta("point_component_count", 0)), 0)
		var glow_material := overlay.material as ShaderMaterial
		assert_not_null(glow_material)
		if glow_material == null:
			continue
		assert_true(glow_material.resource_local_to_scene)
		assert_eq(
				glow_material.shader.resource_path,
				BIOLUME_RELIGHT_SHADER_PATH if expects_relight
				else BIOLUME_GLOW_SHADER_PATH)
		if expects_points:
			assert_gte(float(glow_material.get_shader_parameter("point_core_peak")), 0.22)
			assert_gte(float(glow_material.get_shader_parameter("point_halo_peak")), 0.10)
			assert_between(float(glow_material.get_shader_parameter(
					"point_cycle_sec")), 7.0, 8.0)
		if expects_cluster:
			assert_gte(int(overlay.get_meta("cluster_core_pixel_count", 0)), 40)
			assert_gte(int(overlay.get_meta("cluster_halo_pixel_count", 0)), 20)
			assert_between(float(glow_material.get_shader_parameter(
					"cluster_cycle_sec")), 9.0, 10.0)
			if expects_relight:
				assert_lte(float(glow_material.get_shader_parameter(
						"trough_brightness")), 0.75)
				assert_gte(float(glow_material.get_shader_parameter(
						"peak_brightness")), 1.14)
		else:
			assert_eq(int(overlay.get_meta("cluster_core_pixel_count", 0)), 0)
	var center_point_overlay := stage.get_node("MidgroundCenterGlowFX") \
			as MeshInstance2D
	var center_cluster_overlay := stage.get_node("MidgroundCenterGrassGlowFX") \
			as MeshInstance2D
	var right_point_overlay := stage.get_node("MidgroundRightGlowFX") \
			as MeshInstance2D
	var right_cluster_overlay := stage.get_node("MidgroundRightGrassGlowFX") \
			as MeshInstance2D
	var center_exclusions: Array = center_point_overlay.get("point_exclusion_zones")
	var center_clusters: Array = center_cluster_overlay.get("cluster_zones")
	var center_component_seeds: Array = center_cluster_overlay.get(
			"cluster_component_seeds")
	var right_exclusions: Array = right_point_overlay.get("point_exclusion_zones")
	var right_clusters: Array = right_cluster_overlay.get("cluster_zones")
	assert_eq(right_exclusions, right_clusters)
	assert_eq(center_exclusions.size(), 1)
	assert_true(center_clusters.is_empty())
	assert_eq(center_component_seeds, [Vector2(0.8, 0.68)])
	assert_eq(right_exclusions.size(), 1)
	var center_exclusion: Vector4 = center_exclusions[0]
	var center_bounds: Rect2i = center_cluster_overlay.get_meta(
			"cluster_core_source_bounds", Rect2i())
	assert_lte(center_bounds.position.x, 281)
	assert_lte(center_bounds.position.y, 74)
	assert_gte(center_bounds.end.x, 360)
	assert_gte(center_bounds.end.y, 139)
	assert_gte(int(center_cluster_overlay.get_meta(
			"cluster_core_pixel_count", 0)), 2100)
	var source_size := Vector2(
			(stage.get_node("MidgroundCenter") as TextureRect).texture.get_size())
	var exclusion_min := Vector2(
			center_exclusion.x - center_exclusion.z,
			center_exclusion.y - center_exclusion.w) * source_size
	var exclusion_max := Vector2(
			center_exclusion.x + center_exclusion.z,
			center_exclusion.y + center_exclusion.w) * source_size
	assert_lte(exclusion_min.x, float(center_bounds.position.x))
	assert_lte(exclusion_min.y, float(center_bounds.position.y))
	assert_gte(exclusion_max.x, float(center_bounds.end.x))
	assert_gte(exclusion_max.y, float(center_bounds.end.y))

	var pulse_phases: Array[float] = []
	for node_name: String in [
		"MidgroundLeft", "MidgroundCenter", "MidgroundRight",
		"ForegroundLeft", "ForegroundRight",
	]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var pulse_strength_value: Variant = material.get_shader_parameter("glow_pulse_strength")
		var edge_motion_value: Variant = material.get_shader_parameter("edge_motion_strength")
		var pulse_speed_value: Variant = material.get_shader_parameter("glow_pulse_speed")
		var pulse_phase_value: Variant = material.get_shader_parameter("glow_pulse_phase")
		assert_not_null(pulse_strength_value, "%s needs local emission breathing" % node_name)
		if edge_motion_value == null \
				or pulse_strength_value == null or pulse_speed_value == null \
				or pulse_phase_value == null:
			continue
		var foreground_layer := node_name.begins_with("Foreground")
		if foreground_layer:
			assert_between(float(edge_motion_value), 0.05, 0.1)
			assert_between(float(pulse_strength_value), 0.16, 0.20)
		else:
			assert_eq(float(edge_motion_value), 0.0)
			assert_eq(float(pulse_strength_value), 0.0)
		assert_gte(float(pulse_speed_value), 0.32)
		assert_lte(float(pulse_speed_value), 0.86)
		pulse_phases.append(float(pulse_phase_value))
	assert_eq(pulse_phases.size(), 5)
	for index: int in range(1, pulse_phases.size()):
		assert_ne(pulse_phases[index], pulse_phases[index - 1])

	var mote_contract := {
		"OasisMotesFar": [0.64, 1.4, 1.8, 0.20, 0.26, 0.0, 1.2],
		"OasisMotesMid": [0.82, 2.2, 2.6, 0.27, 0.31, 1.5, 2.5],
		"OasisMotesNear": [1.12, 3.0, 3.4, 0.32, 0.36, 2.5, 3.5],
	}
	var layer_alphas: Array[float] = []
	var layer_rise_speeds: Array[float] = []
	var layer_cell_widths: Array[float] = []
	for mote_name: String in ["OasisMotesFar", "OasisMotesMid", "OasisMotesNear"]:
		var contract: Array = mote_contract[mote_name]
		var motes := stage.get_node_or_null(mote_name) as ColorRect
		assert_not_null(motes, "%s must be a direct procedural layer" % mote_name)
		if motes == null:
			continue
		var material := motes.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		assert_eq(material.shader.resource_path, MOTES_SHADER_PATH)
		assert_true(material.resource_local_to_scene)
		assert_eq(float(motes.get_meta("parallax_factor")), float(contract[0]))
		var rise_speed := float(material.get_shader_parameter("rise_px_per_sec"))
		var layer_alpha := float(material.get_shader_parameter("alpha"))
		assert_between(rise_speed, float(contract[1]), float(contract[2]))
		assert_between(layer_alpha, float(contract[3]), float(contract[4]))
		assert_between(float(material.get_shader_parameter("horizontal_sway_px")),
				float(contract[5]), float(contract[6]))
		assert_gte(float(material.get_shader_parameter("density")), 0.44)
		assert_gte(float(material.get_shader_parameter("secondary_density")), 0.12)
		assert_between(float(material.get_shader_parameter("cycle_sec")), 9.0, 15.0)
		assert_between(float(material.get_shader_parameter("motion_fps")), 8.0, 10.0)
		assert_not_null(material.get_shader_parameter("diagnostic_time_sec"))
		assert_null(material.get_shader_parameter("horizontal_px_per_sec"))
		assert_eq(motes.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(motes.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		var pixel_grid: Vector2 = material.get_shader_parameter("pixel_grid")
		layer_cell_widths.append(motes.size.x / pixel_grid.x)
		layer_alphas.append(layer_alpha)
		layer_rise_speeds.append(rise_speed)
	assert_eq(layer_alphas.size(), 3)
	assert_lt(layer_alphas[0], layer_alphas[1])
	assert_lt(layer_alphas[1], layer_alphas[2])
	assert_lt(layer_rise_speeds[0], layer_rise_speeds[1])
	assert_lt(layer_rise_speeds[1], layer_rise_speeds[2])
	assert_lte(layer_cell_widths[0], layer_cell_widths[1] + 0.01)
	assert_lt(layer_cell_widths[1], layer_cell_widths[2])
	var mote_source := FileAccess.get_file_as_string(MOTES_SHADER_PATH)
	for required_token: String in [
		"mote_sample", "local_cycle", "seed_speed", "horizontal_sway_px",
		"wrapped_axis_distance", "secondary_density", "diagnostic_time_sec",
		"floor(motion_time() * motion_fps)",
	]:
		assert_true(mote_source.contains(required_token),
				"independent mote motion needs %s" % required_token)
	assert_false(mote_source.contains("moving_cell = cell + drift"))
	assert_false(mote_source.contains("horizontal_px_per_sec"))
	assert_gte((stage.get_node("OasisMotesFar") as ColorRect).position.y, 500.0)
	assert_gte((stage.get_node("OasisMotesMid") as ColorRect).position.y, 420.0)
	assert_gte((stage.get_node("OasisMotesNear") as ColorRect).position.y, 600.0)
	if stage.get_node_or_null("OasisMotesFar") == null \
			or stage.get_node_or_null("OasisMotesMid") == null \
			or stage.get_node_or_null("OasisMotesNear") == null:
		return
	assert_lt(stage.get_node("OasisMotesFar").get_index(),
			stage.get_node("MidgroundLeft").get_index())
	assert_lt(stage.get_node("RearWaterReflection").get_index(),
			stage.get_node("OasisMotesMid").get_index())
	assert_lt(stage.get_node("OasisMotesMid").get_index(),
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
	var platform_visible_rect := _scene7_platform_visible_rect(platform)
	var front_water := stage.get_node("FrontWater") as ColorRect
	var platform_underlap := platform_visible_rect.end.y - front_water.position.y
	assert_gte(platform_underlap, 4.0)
	assert_almost_eq(platform_underlap, 10.0, 0.01)
	assert_lt(front_water.get_index(), platform.get_index())
	assert_null(stage.get_node_or_null("PlatformWaterContact"))


func test_scene7_adds_a_complete_center_stone_and_only_a_thin_spring_contact() -> void:
	assert_true(ResourceLoader.exists(FOREGROUND_CENTER_STONE_PATH))
	assert_true(FileAccess.file_exists(PLATFORM_SPRING_CONTACT_SHADER_PATH))
	assert_true(FileAccess.file_exists(FOREGROUND_STONE_GRADE_SHADER_PATH))
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var front_water := stage.get_node("FrontWater") as ColorRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var contact := stage.get_node_or_null("PlatformSpringContact") as ColorRect
	var center_stone := stage.get_node_or_null("ForegroundCenterStone") as TextureRect
	assert_not_null(contact)
	assert_not_null(center_stone)
	if contact == null or center_stone == null:
		return

	var manual_stone_contract := {
		"ForegroundCenterStone": {
			"position": Vector2(74.0, 655.89087),
			"size": Vector2(390.94336, 312.8302),
			"rotation": 0.0,
		},
		"ForegroundCenterStone2": {
			"position": Vector2(319.0, 662.89087),
			"size": Vector2(390.94336, 312.83014),
			"rotation": 0.0,
		},
		"ForegroundCenterStone3": {
			"position": Vector2(349.99994, 891.8908),
			"size": Vector2(390.94336, 312.8302),
			"rotation": -0.3630285,
		},
	}
	for node_name: String in manual_stone_contract:
		var stone := stage.get_node_or_null(node_name) as TextureRect
		assert_not_null(stone)
		if stone == null:
			continue
		assert_eq(stone.texture.resource_path, FOREGROUND_CENTER_STONE_PATH)
		assert_eq(stone.texture.get_size(), Vector2(288.0, 216.0))
		assert_eq(stone.texture.get_image().get_used_rect(), Rect2i(8, 100, 274, 69))
		assert_true(is_equal_approx(stone.scale.x, stone.scale.y))
		assert_eq(stone.scale, Vector2(2.65, 2.65))
		assert_eq(stone.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(stone.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(float(stone.get_meta("parallax_factor")), 1.25)
		assert_eq(String(stone.get_meta("composition_role")),
				"front_center_stone_frame")
		var expected: Dictionary = manual_stone_contract[node_name]
		assert_true(stone.position.is_equal_approx(expected["position"]))
		assert_true(stone.size.is_equal_approx(expected["size"]))
		assert_almost_eq(stone.rotation, float(expected["rotation"]), 0.00001)
		assert_eq(stone.material, center_stone.material)
	var center_stone_material := center_stone.material as ShaderMaterial
	assert_not_null(center_stone_material)
	if center_stone_material != null:
		assert_eq(center_stone_material.shader.resource_path,
				FOREGROUND_STONE_GRADE_SHADER_PATH)
		assert_eq(center_stone_material.get_shader_parameter("ambient_tint"),
				Color(0.52, 0.58, 0.72, 1.0))
		assert_gte(float(center_stone_material.get_shader_parameter(
				"palette_strength")), 0.42)
		assert_lte(float(center_stone_material.get_shader_parameter(
				"palette_strength")), 0.48)
		assert_lte(float(center_stone_material.get_shader_parameter(
				"base_brightness")), 0.86)
	assert_lt(stage.get_node("OasisMotesNear").get_index(),
			center_stone.get_index())

	assert_eq(contact.position, Vector2(-32.0, 824.0))
	assert_eq(contact.size, Vector2(1984.0, 18.0))
	assert_eq(contact.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(contact.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(float(contact.get_meta("parallax_factor")), 1.0)
	assert_lt(front_water.get_index(), contact.get_index())
	assert_lt(contact.get_index(), platform.get_index())
	var contact_material := contact.material as ShaderMaterial
	assert_not_null(contact_material)
	if contact_material == null:
		return
	assert_eq(contact_material.shader.resource_path,
			PLATFORM_SPRING_CONTACT_SHADER_PATH)
	assert_eq(float(contact_material.get_shader_parameter(
			"contact_thickness_px")), 5.0)
	assert_eq(float(contact_material.get_shader_parameter("line_cell_width_px")), 78.0)
	assert_eq(float(contact_material.get_shader_parameter("line_presence")), 0.86)
	assert_eq(float(contact_material.get_shader_parameter("line_margin_px")), 8.0)
	assert_eq(float(contact_material.get_shader_parameter(
			"minimum_thickness_px")), 3.0)
	assert_eq(float(contact_material.get_shader_parameter("anim_fps")), 8.0)
	assert_eq(float(contact_material.get_shader_parameter(
			"spring_period_sec")), 7.6)
	assert_eq(float(contact_material.get_shader_parameter(
			"active_line_ratio")), 0.64)
	assert_eq(float(contact_material.get_shader_parameter("contact_alpha")), 0.66)
	assert_eq(contact_material.get_shader_parameter("surface_color"),
			Color(0.133, 0.667, 0.6, 1.0))
	assert_eq(contact_material.get_shader_parameter("ripple_color"),
			Color(0.333, 0.8, 0.667, 1.0))
	assert_eq(contact_material.get_shader_parameter("spring_glow_color"),
			Color(0.44, 0.88, 0.72, 1.0))
	assert_eq(float(contact_material.get_shader_parameter(
			"ripple_palette_mix")), 0.58)
	assert_eq(float(contact_material.get_shader_parameter(
			"glow_palette_mix")), 0.42)
	var contact_platform_size: Vector2 = contact_material.get_shader_parameter(
			"platform_rect_size_px")
	assert_true(contact_platform_size.is_equal_approx(platform.size))
	assert_eq(contact_material.get_shader_parameter("platform_node_scale"),
			platform.scale)
	assert_null(contact_material.get_shader_parameter("motion_px"))
	var contact_source := FileAccess.get_file_as_string(
			PLATFORM_SPRING_CONTACT_SHADER_PATH)
	assert_true(contact_source.contains("platform_texture"))
	assert_true(contact_source.contains("platform_rect_size_px"))
	assert_true(contact_source.contains("platform_node_scale"))
	assert_true(contact_source.contains("platform_uv_x"))
	assert_true(contact_source.contains("stable_hash"))
	assert_true(contact_source.contains("contact_thickness_px"))
	assert_true(contact_source.contains("TIME"))
	assert_true(contact_source.contains("accepted_static_alpha"))
	assert_true(contact_source.contains("authored_line_width"))
	assert_true(contact_source.contains("authored_line_start"))
	assert_true(contact_source.contains("contact_event_state"))
	assert_true(contact_source.contains("active_line_ratio"))
	assert_true(contact_source.contains("spring_period_sec"))
	assert_true(contact_source.contains("floor(TIME * anim_fps) / anim_fps"))
	assert_true(contact_source.contains("single_line_mask"))
	assert_true(contact_source.contains("maximum_edge_cut"))
	assert_true(contact_source.contains("active_thickness_px"))
	assert_true(contact_source.contains("minimum_thickness_px"))
	assert_true(contact_source.contains("hold_frames = 6.0"))
	assert_true(contact_source.contains("contact_ripple_color"))
	assert_true(contact_source.contains("contact_glow_color"))
	assert_true(contact_source.contains("ripple_palette_mix"))
	assert_true(contact_source.contains("glow_palette_mix"))
	assert_false(contact_source.contains("segment_width_px"))
	assert_false(contact_source.contains("segment_density"))
	assert_false(contact_source.contains("cluster_layout"))
	assert_false(contact_source.contains("segment_length_ratio"))
	assert_false(contact_source.contains("straight_edge_coverage"))
	assert_false(contact_source.contains("cos(6.2831853 * group_phase)"))
	assert_false(contact_source.contains("smoothstep"))
	assert_false(contact_source.contains("spring_surge_event"))
	assert_false(contact_source.contains("surge_extension_alpha"))
	assert_false(contact_source.contains("base_highlight"))
	assert_false(contact_source.contains("local_spring_retraction"))
	assert_false(contact_source.contains("bottom_row_visibility"))
	assert_false(contact_source.contains("inner_row_visibility"))
	assert_false(contact_source.contains("diagnostic_motion_enabled"))
	assert_false(contact_source.contains("diagnostic_phase"))
	assert_false(contact_source.contains("diagnostic_region"))
	assert_false(contact_source.contains("mix(1.0, 0.54"))
	assert_false(contact_source.contains("accent_color"))
	assert_false(contact_source.contains("accent_contact_thickness_px"))
	assert_false(contact_source.contains("flow_direction"))
	assert_false(contact_source.contains("flow_speed"))
	assert_false(contact_source.contains("touch_shift"))


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
	var rear_reflection := stage.get_node_or_null("RearWaterReflection") as Polygon2D
	var front_water := stage.get_node("FrontWater") as ColorRect
	var rear_material := rear_water.material as ShaderMaterial
	var rear_reflection_material := (
			rear_reflection.material as ShaderMaterial if rear_reflection != null else null)
	var front_material := front_water.material as ShaderMaterial
	assert_not_null(rear_material)
	assert_not_null(rear_reflection)
	assert_not_null(rear_reflection_material)
	assert_not_null(front_material)
	assert_eq(rear_material.shader.resource_path, FAR_WATER_SHADER_PATH)
	if rear_reflection_material != null:
		assert_eq(rear_reflection_material.shader.resource_path,
				FAR_REFLECTION_SHADER_PATH)
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
	if rear_reflection != null:
		assert_lt(reflection_grab.get_index(), rear_reflection.get_index())
		assert_lt(rear_reflection.get_index(), front_water.get_index())
		assert_eq(rear_reflection.texture_filter,
				CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(float(rear_reflection.get_meta("parallax_factor")), 0.55)
		assert_eq(rear_reflection.polygon, rear_water.polygon)
		assert_eq(rear_reflection.uv, rear_water.uv)
		assert_eq(rear_reflection.vertex_colors.size(),
				rear_water.vertex_colors.size())
		for vertex_index: int in range(rear_water.vertex_colors.size()):
			assert_true(rear_reflection.vertex_colors[vertex_index].is_equal_approx(
					rear_water.vertex_colors[vertex_index]))
	if rear_reflection_material != null:
		assert_gte(float(rear_reflection_material.get_shader_parameter(
				"reflection_strength")), 0.24)
		assert_lte(float(rear_reflection_material.get_shader_parameter(
				"reflection_strength")), 0.34)
		assert_gte(float(rear_reflection_material.get_shader_parameter(
				"reflection_height_px")), 84.0)
		assert_lte(float(rear_reflection_material.get_shader_parameter(
				"reflection_height_px")), 112.0)
	assert_null(stage.get_node_or_null("PlatformWaterGrab"))
	assert_null(stage.get_node_or_null("PlatformFoundation"))
	assert_lt(front_water.get_index(),
			stage.get_node("BattlePlatform").get_index())
	assert_gte(float(rear_material.get_shader_parameter("main_ring_strength")), 0.38)
	assert_gte(float(front_material.get_shader_parameter("main_ring_strength")), 0.35)
	assert_gte(float(rear_material.get_shader_parameter("caustic_strength")), 0.10)
	assert_gte(float(front_material.get_shader_parameter("caustic_strength")), 0.10)
	assert_gte(float(rear_material.get_shader_parameter("glint_strength")), 0.12)
	assert_gte(float(front_material.get_shader_parameter("glint_strength")), 0.12)
	assert_gte(float(rear_material.get_shader_parameter("micro_ring_strength")), 0.08)
	assert_gte(float(front_material.get_shader_parameter("micro_ring_strength")), 0.08)
	assert_gte(float(front_material.get_shader_parameter("reflection_height_px")), 500.0)
	assert_gte(float(front_material.get_shader_parameter("reflection_strength")), 0.5)
	assert_gte(float(front_material.get_shader_parameter("reflection_colorize")), 0.6)
	var front_surface: Color = front_material.get_shader_parameter("surface_color")
	var front_deep: Color = front_material.get_shader_parameter("deep_color")
	var shared_palette_contract: Array[Array] = [
		["surface_color", "surface_color"],
		["mid_color", "shallow_color"],
		["deep_color", "deep_color"],
		["ripple_color", "ripple_color"],
		["spring_glow_color", "spring_glow_color"],
	]
	for palette_pair: Array in shared_palette_contract:
		var rear_color: Color = rear_material.get_shader_parameter(palette_pair[0])
		var front_color: Color = front_material.get_shader_parameter(palette_pair[1])
		assert_lte(_rgb_distance(rear_color, front_color), 0.01,
				"rear and front water must share %s/%s palette anchors" % palette_pair)
	assert_gte(front_surface.s, 0.80)
	assert_gte(front_deep.s, 0.80)
	assert_between(front_surface.h * 360.0, 168.0, 190.0)
	assert_between(front_deep.h * 360.0, 180.0, 215.0)
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	assert_true(bool(screen.get("character_reflections_enabled")))
	assert_eq(screen.get("character_reflection_receiver_path"), NodePath("FrontWater"))
	var rear_source := FileAccess.get_file_as_string(FAR_WATER_SHADER_PATH)
	var rear_reflection_source := FileAccess.get_file_as_string(
			FAR_REFLECTION_SHADER_PATH)
	var front_source := FileAccess.get_file_as_string(WATER_SHADER_PATH)
	assert_true(rear_source.contains("motion_time() * anim_fps"))
	assert_true(rear_source.contains("secondary_distance_a"))
	assert_true(rear_source.contains("secondary_distance_b"))
	assert_true(rear_source.contains("glint_pulse"))
	assert_true(rear_source.contains("glint_segment"))
	assert_true(rear_source.contains("diagnostic_time_sec"))
	assert_true(rear_source.contains("local_position = VERTEX"))
	assert_true(rear_source.contains("spring_distance"))
	assert_true(rear_source.contains("ring_mask"))
	assert_true(rear_source.contains("shoreline_depth = COLOR.r"))
	assert_true(rear_source.contains("shore_depth_px"))
	assert_true(rear_source.contains("distance_atmosphere"))
	assert_false(rear_source.contains("polygon_uv"))
	assert_false(rear_source.contains("reflected_bank"))
	assert_false(rear_source.contains("flow_speed_px"))
	assert_false(rear_source.contains("flow_direction"))
	assert_false(rear_source.contains("sampler2D TEXTURE"))
	assert_true(rear_reflection_source.contains("hint_screen_texture"))
	assert_true(rear_reflection_source.contains("SCREEN_UV"))
	assert_true(rear_reflection_source.contains("shoreline_depth = COLOR.r"))
	assert_true(rear_reflection_source.contains("palette_reflection_from_luma"))
	assert_true(rear_reflection_source.contains("vegetation_signal"))
	assert_true(rear_reflection_source.contains("motion_time() * anim_fps"))
	assert_true(rear_reflection_source.contains("animated_offset"))
	assert_true(rear_reflection_source.contains("reflection_breathe_strength"))
	assert_true(rear_reflection_source.contains("signed_pixel_snap"))
	assert_false(rear_reflection_source.contains("flow_direction"),
			"rear reflection motion must remain zero-mean spring sway")
	assert_false(rear_reflection_source.contains("flow_speed"))
	assert_true(front_source.contains("motion_time() * anim_fps"))
	assert_true(front_source.contains("secondary_distance_a"))
	assert_true(front_source.contains("secondary_distance_b"))
	assert_true(front_source.contains("glint_pulse"))
	assert_true(front_source.contains("glint_segment"))
	assert_true(front_source.contains("reflection_sway"))
	assert_true(front_source.contains("diagnostic_time_sec"))
	assert_true(front_source.contains("hint_screen_texture"))
	assert_true(front_source.contains("SCREEN_UV"))
	assert_true(front_source.contains("p1_reflection_tex"))
	assert_true(front_source.contains("character_waterline_y"))
	assert_true(front_source.contains("reflection_height_px"))
	assert_true(front_source.contains("signed_radial_wave"))
	assert_true(front_source.contains("spring_distance"))
	assert_true(front_source.contains("ring_mask"))
	assert_true(front_source.contains("palette_reflection_from_luma"))
	assert_false(front_source.contains("shore_cluster"),
			"the platform silhouette owns the near-water shoreline")
	assert_false(front_source.contains("ripple_speed_px"))
	assert_false(front_source.contains("flow_direction"))
	assert_false(front_source.contains("slice_speed"))
	assert_false(front_source.contains("AtlasTexture"))


func test_scene7_platform_uses_an_internal_neutral_underside() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var surface_material := platform.material as ShaderMaterial
	assert_eq(surface_material.shader.resource_path,
			PLATFORM_ELEVATION_SHADER_PATH)
	assert_null(stage.get_node_or_null("PlatformWaterGrab"))
	assert_null(stage.get_node_or_null("PlatformFoundation"))
	assert_lt(stage.get_node("FrontWater").get_index(), platform.get_index())
	assert_eq(platform.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(_bottom_edge_pixel_count(platform.texture.get_image()), 316)
	var underside_tint: Color = surface_material.get_shader_parameter(
			"underside_tint")
	assert_between(underside_tint.h * 360.0, 285.0, 315.0)
	assert_between(underside_tint.s, 0.28, 0.38)
	assert_between(underside_tint.v, 0.36, 0.44)
	assert_between(float(surface_material.get_shader_parameter(
			"underside_strength")), 0.78, 0.86)
	assert_eq(float(surface_material.get_shader_parameter(
			"surface_bottom_row")), 95.0)
	assert_eq(float(surface_material.get_shader_parameter(
			"shallow_wall_rows")), 4.0)
	assert_eq(float(surface_material.get_shader_parameter(
			"edge_variation_rows")), 1.0)
	var platform_shader_source := FileAccess.get_file_as_string(
			PLATFORM_ELEVATION_SHADER_PATH)
	assert_true(platform_shader_source.contains("source_surface"))
	assert_true(platform_shader_source.contains("source_down"))
	assert_true(platform_shader_source.contains("bottom_edge"))
	assert_true(platform_shader_source.contains("underside_tint"))
	assert_true(platform_shader_source.contains("source_surface.a"))
	assert_true(platform_shader_source.contains("visible_bottom_row"))
	assert_true(platform_shader_source.contains("shallow_wall_rows"))
	assert_true(platform_shader_source.contains("edge_variation_rows"))
	assert_false(platform_shader_source.contains("hint_screen_texture"))
	assert_false(platform_shader_source.contains("SCREEN_UV"))
	assert_false(platform_shader_source.contains("outside_alpha"))
	assert_false(platform_shader_source.contains("submerged_shelf"))
	assert_false(platform_shader_source.contains("waterline_glint"))
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
	var world_grab := screen.get_node("WorldGrab") as BackBufferCopy
	var world_group := screen.get_node("WorldGroup") as Control
	var veil := screen.get_node_or_null("UiReadabilityVeil") as ColorRect
	var post_readability_grab := screen.get_node_or_null(
			"UiReadabilityPostGrab") as BackBufferCopy
	assert_not_null(veil)
	assert_not_null(post_readability_grab)
	if veil == null or post_readability_grab == null:
		return
	# WorldGrab 必须先捕获包含平台与双雄的完整世界；可读性层处理后再次捕获，
	# 最后交给 PostFX。缺任意一拍都会隐藏角色/平台或覆盖终结技黑白闪。
	assert_lt(world_group.get_index(), world_grab.get_index())
	assert_lt(world_grab.get_index(), veil.get_index())
	assert_lt(veil.get_index(), post_readability_grab.get_index())
	assert_lt(post_readability_grab.get_index(), post_fx.get_index())
	assert_eq(post_readability_grab.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	var platform := screen.stage.get_node("BattlePlatform") as TextureRect
	assert_true(platform.is_visible_in_tree())
	assert_gt(platform.modulate.a, 0.99)
	for character_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var display := world_group.get_node(character_name) as CharacterDisplay
		assert_true(display.is_visible_in_tree())
		assert_gt(display.modulate.a, 0.99)
		assert_not_null(display.get_render_texture())
	for ui_name: String in ["P1Hud", "P2Hud", "TimerLabel", "Buttons"]:
		assert_lt(veil.get_index(), screen.get_node(ui_name).get_index())
	assert_eq(veil.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	var veil_material := veil.material as ShaderMaterial
	assert_not_null(veil_material)
	if veil_material != null:
		assert_eq(veil_material.shader.resource_path, UI_READABILITY_SHADER_PATH)
		assert_eq(float(veil_material.get_shader_parameter("hud_support_strength")), 0.0)
		assert_eq(float(veil_material.get_shader_parameter("timer_support_strength")), 0.0)
		assert_eq(float(veil_material.get_shader_parameter("support_desaturation")), 0.0)
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
	assert_eq(float(post_material.get_shader_parameter("brightness")), 1.0)
	assert_eq(float(post_material.get_shader_parameter("saturation")), 1.0)
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
		assert_gte(palette_strength, 0.38, "%s needs the Scheme B oasis palette" % node_name)
		assert_lte(palette_strength, 0.46, "%s must retain source detail" % node_name)
		assert_gt(shadow_palette.g, shadow_palette.r * 3.0)
		assert_gt(shadow_palette.b, shadow_palette.g * 2.0)
		assert_gt(sunlit_palette.g, sunlit_palette.r * 3.5)
		assert_gt(sunlit_palette.b, sunlit_palette.r * 4.0)

	var background_material := \
			(stage.get_node("FarBackground") as TextureRect).material as ShaderMaterial
	var far_air: Color = background_material.get_shader_parameter("air_color")
	var far_horizon: Color = background_material.get_shader_parameter("horizon_color")
	assert_gt(far_air.g, far_air.r * 1.25)
	assert_gt(far_air.b, far_air.r * 1.15)
	assert_gt(far_horizon.r, far_horizon.b * 1.35)
	assert_gt(far_horizon.g, far_horizon.b * 1.2)
	assert_gte(float(background_material.get_shader_parameter(
			"far_saturation_retention")), 0.92)
	assert_lte(float(background_material.get_shader_parameter(
			"far_saturation_retention")), 0.98)
	assert_gte(float(background_material.get_shader_parameter("air_strength")), 0.04)
	assert_lte(float(background_material.get_shader_parameter("air_strength")), 0.08)

	var expected_surface := Color(0.133, 0.667, 0.6, 1.0)
	var expected_deep := Color(0.067, 0.267, 0.4, 1.0)
	var expected_glow := Color(0.44, 0.88, 0.72, 1.0)
	for node_name: String in ["RearWater", "RearWaterReflection", "FrontWater"]:
		var water_material := (stage.get_node(node_name) as CanvasItem).material as ShaderMaterial
		assert_eq(water_material.get_shader_parameter("surface_color"), expected_surface)
		assert_eq(water_material.get_shader_parameter("deep_color"), expected_deep)
		assert_eq(water_material.get_shader_parameter("spring_glow_color"), expected_glow)
	var contact_material := \
			(stage.get_node("PlatformSpringContact") as ColorRect).material as ShaderMaterial
	assert_eq(contact_material.get_shader_parameter("surface_color"), expected_surface)
	assert_eq(contact_material.get_shader_parameter("spring_glow_color"), expected_glow)

	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var plant_material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var plant_glow: Color = plant_material.get_shader_parameter("glow_color")
		assert_between(plant_glow.h * 360.0, 155.0, 175.0)
		assert_between(plant_glow.v, 0.82, 0.90)
		assert_between(float(plant_material.get_shader_parameter(
				"source_cyan_midtone_lift")), 0.07, 0.085)
		assert_between(float(plant_material.get_shader_parameter(
				"highlight_shoulder_strength")), 1.2, 1.5)

	var post_material := (screen.get_node("PostFX") as ColorRect).material as ShaderMaterial
	var shadow_tint: Color = post_material.get_shader_parameter("shadow_tint")
	var highlight_tint: Color = post_material.get_shader_parameter("highlight_tint")
	assert_eq(float(post_material.get_shader_parameter("brightness")), 1.0)
	assert_eq(float(post_material.get_shader_parameter("saturation")), 1.0)
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

	var approved_positions: Dictionary[String, Vector2] = {
		"P1CharDisplay": Vector2(96.0, 262.0),
		"P2CharDisplay": Vector2(1056.0, 262.0),
	}
	for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var base_node := base.get_node(node_name) as CharacterDisplay
		var scene7_node := screen.get_node("WorldGroup/%s" % node_name) as CharacterDisplay
		assert_eq(scene7_node.position, approved_positions[node_name])
		assert_eq(scene7_node.size, base_node.size)
		assert_eq(scene7_node.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(scene7_node.rim_color, Color(1.0, 0.91, 0.74, 1.0))
		assert_almost_eq(scene7_node.rim_strength, 0.0, 0.001)
		assert_almost_eq(scene7_node.backlight, 0.0, 0.001)
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
			for neutral_parameter: String in [
				"backlight",
				"warmth_amount",
				"rim_strength",
				"fill_amount",
			]:
				assert_almost_eq(
						float(material.get_shader_parameter(neutral_parameter)),
						0.0,
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
		assert_almost_eq(float(post_material.get_shader_parameter("brightness")), 1.0, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("contrast")), 1.0, 0.001)
		assert_almost_eq(float(post_material.get_shader_parameter("saturation")), 1.0, 0.001)
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


func _scene7_platform_visible_rect(layer: TextureRect) -> Rect2:
	var source_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var material := layer.material as ShaderMaterial
	var visible_source_bottom := minf(
			float(source_rect.end.y),
			float(material.get_shader_parameter("surface_bottom_row"))
					+ float(material.get_shader_parameter("shallow_wall_rows"))
					+ float(material.get_shader_parameter("edge_variation_rows")))
	var visible_source_rect := Rect2(
			Vector2(source_rect.position),
			Vector2(source_rect.size.x,
					visible_source_bottom - float(source_rect.position.y)))
	var source_size: Vector2 = layer.texture.get_size()
	var stretch_ratio := layer.size / source_size
	return Rect2(
			layer.position + visible_source_rect.position * stretch_ratio * layer.scale,
			visible_source_rect.size * stretch_ratio * layer.scale)


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


func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _bottom_edge_pixel_count(image: Image) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.5:
				continue
			var alpha_down := image.get_pixel(x, y + 1).a \
					if y + 1 < image.get_height() else 0.0
			if alpha_down < 0.5:
				count += 1
	return count


func _channel_pixel_count(image: Image, channel: int) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var value := color.r if channel == 0 else (
					color.g if channel == 1 else color.b)
			if color.a >= 0.5 and value >= 0.5:
				count += 1
	return count


func _opaque_pixel_count(image: Image) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			count += int(image.get_pixel(x, y).a > 0.08)
	return count
