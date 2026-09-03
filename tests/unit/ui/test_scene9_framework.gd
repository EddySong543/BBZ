extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const BATTLE9_PATH := "res://src/ui/battle_screen9.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const SHARED_STAGE_SCRIPT_PATH := "res://src/ui/components/battle_stage.gd"
const SCENE9_STAGE_SCRIPT_PATH := (
		"res://src/ui/components/scene9_battle_stage.gd")
const SCENE9_CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_character_light.gdshader")
const SCENE9_CONTACT_SHADOW_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_character_contact_shadow.gdshader")
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"
const STATIC_DEPTH_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_static_depth.gdshader")
const PIXEL_CLOUD_MOTION_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_pixel_cloud_motion.gdshader")
const FOREGROUND_WIND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_foreground_wind.gdshader")
const DISTANT_GRASS_WIND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_distant_grass_wind.gdshader")
const DISTANT_GRASS_CONTACT_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_distant_grass_interlock.gdshader")
const PLATFORM_CONTACT_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_platform_interlock.gdshader")
const SKY_PATH := "res://assets/scenes/scene9/scene9_sky.png"
const PLATFORM_PATH := "res://assets/scenes/scene9/scene9_battle_platform.png"
const PLATFORM2_PATH := "res://assets/scenes/scene9/scene9_battle_platform2.png"
const PLATFORM_ASSEMBLY_PATH := (
		"res://assets/scenes/scene9/scene9_battle_platform_assembled.png")
const NEW_PLATFORM_PATH := "res://assets/scenes/scene9/scene9_platform_new.png"
const LEFT_MOUNTAIN_PATH := "res://assets/scenes/scene9/scene9_mountain_left.png"
const RIGHT_MOUNTAIN_PATH := "res://assets/scenes/scene9/scene9_mountain_right.png"
const GRASS_PATH := "res://assets/scenes/scene9/scene9_grass.png"
const RETIRED_FLOATING_ISLAND_PATH := (
		"res://assets/scenes/scene9/scene9_floating_island.png")
const RETIRED_WATERFALL_SCRIPT_PATH := (
		"res://src/ui/components/scene9_pixel_waterfall_raster.gd")
const CLOUD_FIELD_SCRIPT_PATH := (
		"res://src/ui/components/scene9_procedural_cloud_field.gd")
const DISTANT_CLOUD_BANK_SCRIPT_PATH := (
		"res://src/ui/components/scene9_distant_pixel_cloud_bank.gd")
const CLOUD_BLUEPRINT_PATH := (
		"res://src/ui/components/scene9_cloud_blueprint.gd")
const DISTANT_LEFT_PATH := "res://assets/scenes/scene9/scene9_distant_left.png"
const DISTANT_RIGHT_PATH := "res://assets/scenes/scene9/scene9_distant_right.png"
const DISTANT_ROAD_PATH := "res://assets/scenes/scene9/scene9_distant_road.png"
const FOREGROUND_LEFT_PATH := (
		"res://assets/scenes/scene9/scene9_foreground_left.png")
const FOREGROUND_RIGHT_PATH := (
		"res://assets/scenes/scene9/scene9_foreground_right.png")
const REMOVED_REJECTED_RESOURCES: Array[String] = [
	"res://assets/scenes/scene9/scene9_grass_01.png",
	"res://assets/scenes/scene9/scene9_grass_02.png",
	"res://assets/scenes/scene9/scene9_grass_03.png",
	"res://src/ui/components/scene9_silver_grassland.gd",
	"res://assets/scenes/scene9/scene9_platform_interlock_map.png",
	"res://tools/generate_scene9_platform_interlock_mask.gd",
]


func test_scene9_resources_exist_with_owned_environment_assets() -> void:
	assert_true(ResourceLoader.exists(SCENE9_PATH))
	assert_true(ResourceLoader.exists(BATTLE9_PATH))
	assert_true(ResourceLoader.exists(SCENE9_STAGE_SCRIPT_PATH))
	assert_true(ResourceLoader.exists(SKY_PATH))
	assert_true(ResourceLoader.exists(PLATFORM_PATH))
	assert_true(ResourceLoader.exists(PLATFORM2_PATH))
	assert_true(ResourceLoader.exists(PLATFORM_ASSEMBLY_PATH))
	assert_true(ResourceLoader.exists(NEW_PLATFORM_PATH))
	assert_true(ResourceLoader.exists(LEFT_MOUNTAIN_PATH))
	assert_true(ResourceLoader.exists(RIGHT_MOUNTAIN_PATH))
	assert_true(ResourceLoader.exists(GRASS_PATH))
	assert_false(ResourceLoader.exists(RETIRED_FLOATING_ISLAND_PATH))
	assert_false(ResourceLoader.exists(RETIRED_WATERFALL_SCRIPT_PATH))
	assert_true(ResourceLoader.exists(CLOUD_FIELD_SCRIPT_PATH))
	assert_true(ResourceLoader.exists(DISTANT_CLOUD_BANK_SCRIPT_PATH))
	assert_true(ResourceLoader.exists(CLOUD_BLUEPRINT_PATH))
	assert_true(ResourceLoader.exists(DISTANT_LEFT_PATH))
	assert_true(ResourceLoader.exists(DISTANT_RIGHT_PATH))
	assert_true(ResourceLoader.exists(DISTANT_ROAD_PATH))
	assert_true(ResourceLoader.exists(FOREGROUND_LEFT_PATH))
	assert_true(ResourceLoader.exists(FOREGROUND_RIGHT_PATH))
	var stage_source := FileAccess.get_file_as_string(SCENE9_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE9_PATH)
	var project_dir := DirAccess.open("res://")
	assert_not_null(project_dir)
	for rejected_resource: String in REMOVED_REJECTED_RESOURCES:
		assert_false(project_dir.file_exists(rejected_resource.trim_prefix("res://")),
				"Rejected Scene9 generated resource must stay removed: %s"
				% rejected_resource)
	assert_false(stage_source.contains("res://assets/import/"))
	assert_false(stage_source.contains("scene9_cloud_layer.png"),
			"Scene9 cloud must be code-only and must not sample imported cloud art")
	assert_false(stage_source.contains("res://assets/scenes/scene8/"))
	assert_false(battle_source.contains("scene8"))
	assert_false(battle_source.contains("canvas_env_scene8"))


func test_scene9_framework_is_a_direct_editable_stage() -> void:
	if not ResourceLoader.exists(SCENE9_PATH):
		return
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_not_null(stage)
	if stage == null:
		return
	assert_eq((stage.get_script() as Script).resource_path,
			SCENE9_STAGE_SCRIPT_PATH)
	assert_eq(stage.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(stage.anchor_right, 1.0)
	assert_eq(stage.anchor_bottom, 1.0)
	assert_null(stage.get_node_or_null("FrameworkBackdrop"),
			"The imported Scene9 sky replaces the temporary color backdrop")
	var sky := stage.get_node_or_null("SceneSky") as TextureRect
	assert_not_null(sky)
	if sky != null:
		assert_eq(sky.get_parent(), stage)
		assert_eq(sky.texture.resource_path, SKY_PATH)
		assert_eq(sky.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(sky.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(sky.position, Vector2(34.0, -25.0))
		assert_eq(sky.size, Vector2(576.0, 324.0))
		assert_eq(sky.scale, Vector2(4.0, 4.0))
		assert_eq(float(sky.get_meta("parallax_factor")), 0.0)
		assert_eq(float(sky.get_meta("pointer_parallax_factor")), 0.0)
		assert_eq(String(sky.get_meta("composition_role")), "pixel_sky")
	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"),
				"Scene9 framework must keep later art directly editable")


func test_scene9_keeps_only_the_new_code_cloud_as_a_direct_sky_layer() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var cloud := stage.get_node_or_null("DistantPixelCloudBank") as TextureRect
	assert_not_null(cloud)
	assert_null(stage.get_node_or_null("FloatingIsland"),
			"The abandoned floating island must not return")
	assert_false(ResourceLoader.exists(RETIRED_FLOATING_ISLAND_PATH))
	assert_false(ResourceLoader.exists(RETIRED_WATERFALL_SCRIPT_PATH))
	assert_null(stage.get_node_or_null("CloudLayer"),
			"The retired imported cloud node must not return")
	assert_eq((cloud.get_script() as Script).resource_path,
			DISTANT_CLOUD_BANK_SCRIPT_PATH)
	var cloud_material := cloud.material as ShaderMaterial
	assert_not_null(cloud_material)
	assert_eq(cloud_material.shader.resource_path, PIXEL_CLOUD_MOTION_SHADER_PATH)
	assert_almost_eq(cloud.position.x, -504.0, 0.001)
	assert_almost_eq(cloud.position.y, 107.0, 0.001,
			"The user's current manual cloud placement must remain untouched")
	assert_eq(cloud.size, Vector2(2368.0, 544.0))
	assert_eq(cloud.scale, Vector2(1.4, 1.4))
	assert_eq(float(cloud.get("animation_fps")), 12.0)
	assert_eq(int(cloud.get("loop_frame_count")), 216)
	assert_almost_eq(float(cloud.call("cycle_duration_seconds")), 18.0, 0.001)
	assert_eq(cloud.call("pixel_source_size"), Vector2i(592, 136))
	assert_lt(stage.get_node("SceneSky").get_index(),
			stage.get_node("DistantPixelCloudBank").get_index())


func test_scene9_connects_three_new_assets_as_direct_editable_layers() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var expected: Dictionary[String, Dictionary] = {
		"DistantLeftMountain": {
			"path": LEFT_MOUNTAIN_PATH,
			"position": Vector2(184.0, 59.0),
			"size": Vector2(288.0, 216.0),
			"scale": Vector2(4.0, 4.0),
			"role": "distant_left_mountain",
			"parallax": 0.15,
			"pointer": 0.1,
		},
		"DistantRightMountain": {
			"path": RIGHT_MOUNTAIN_PATH,
			"position": Vector2(381.0, -36.0),
			"size": Vector2(408.0, 144.0),
			"scale": Vector2(6.0, 6.0),
			"role": "distant_right_mountain",
			"parallax": 0.15,
			"pointer": 0.1,
		},
		"BattlePlatformNew": {
			"path": NEW_PLATFORM_PATH,
			"position": Vector2(-17.0, 490.0),
			"size": Vector2(408.0, 136.0),
			"scale": Vector2(6.0, 6.0),
			"role": "battle_platform_new",
			"parallax": 1.0,
			"pointer": 0.0,
		},
	}
	for node_name: String in expected:
		var layer := stage.get_node_or_null(node_name) as Control
		assert_not_null(layer)
		if layer == null:
			continue
		var contract: Dictionary = expected[node_name]
		assert_eq(layer.get_parent(), stage)
		var texture := layer.get("texture") as Texture2D
		assert_not_null(texture)
		assert_eq(texture.resource_path, contract["path"])
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(layer.position, contract["position"])
		assert_eq(layer.size, contract["size"])
		assert_eq(layer.scale, contract["scale"])
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(String(layer.get_meta("composition_role")), contract["role"])
		assert_almost_eq(float(layer.get_meta("parallax_factor")),
				float(contract["parallax"]), 0.001)
		assert_almost_eq(float(layer.get_meta("pointer_parallax_factor")),
				float(contract["pointer"]), 0.001)
	assert_lt(stage.get_node("SceneSky").get_index(),
			stage.get_node("DistantLeftMountain").get_index())
	assert_lt(stage.get_node("DistantRightMountain").get_index(),
			stage.get_node("DistantLeftMountain").get_index())
	assert_lt(stage.get_node("DistantLeftMountain").get_index(),
			stage.get_node("DistantPixelCloudBank").get_index())
	assert_lt(stage.get_node("BattlePlatformNew").get_index(),
			stage.get_node("ForegroundMid").get_index())
	for preserved_name: String in ["SceneSky", "DistantRight2",
			"DistantLeft2", "DistantPixelCloudBank", "DistantLeftMountain",
			"DistantRightMountain", "DistantLeft", "DistantRight", "BattlePlatformNew",
			"ForegroundMid", "ForegroundLeft", "ForegroundRight", "CompositionGuides"]:
		assert_not_null(stage.get_node_or_null(preserved_name),
				"Existing Scene9 node must remain present: %s" % preserved_name)
	for retired_name: String in ["DistantRoad", "CloudLayer", "BattlePlatformAssembly",
			"FloatingIsland"]:
		assert_null(stage.get_node_or_null(retired_name),
				"Retired Scene9 node must not return: %s" % retired_name)


func test_scene9_preserves_current_manual_environment_composition() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_null(stage.get_node_or_null("SilverGrassland"))
	assert_null(stage.get_node_or_null("PerspectiveGround"))
	var stage_source := FileAccess.get_file_as_string(SCENE9_PATH)
	assert_false(stage_source.contains("scene9_grass_01"))
	assert_false(stage_source.contains("silver_ground"))
	var expected_assets: Dictionary[String, String] = {
		"DistantLeft": DISTANT_LEFT_PATH,
		"DistantLeft2": DISTANT_LEFT_PATH,
		"DistantRight": DISTANT_RIGHT_PATH,
		"DistantRight2": DISTANT_RIGHT_PATH,
		"BattlePlatformNew": NEW_PLATFORM_PATH,
		"ForegroundMid": GRASS_PATH,
	}
	var protected_manual_rects: Dictionary[String, Rect2] = {
		"DistantLeft": Rect2(-263.0, 477.0, 332.0, 188.0),
		"DistantLeft2": Rect2(1060.0001, 485.0, 332.0, 188.0),
		"DistantRight": Rect2(-1486.0, 433.99997, 408.0, 136.0),
		"DistantRight2": Rect2(-108.0, 426.0, 408.0, 136.0),
		"BattlePlatformNew": Rect2(-17.0, 490.0, 408.0, 136.0),
		"ForegroundMid": Rect2(253.0, 746.0, 408.0, 136.0),
	}
	for node_name: String in expected_assets:
		var layer := stage.get_node_or_null(node_name) as Control
		assert_not_null(layer)
		if layer == null:
			continue
		assert_eq(layer.get_parent(), stage)
		var texture := layer.get("texture") as Texture2D
		assert_eq(texture.resource_path, expected_assets[node_name])
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		var protected_rect := protected_manual_rects[node_name]
		assert_almost_eq(layer.position.x, protected_rect.position.x, 0.001)
		assert_almost_eq(layer.position.y, protected_rect.position.y, 0.001)
		assert_almost_eq(layer.size.x, protected_rect.size.x, 0.001)
		assert_almost_eq(layer.size.y, protected_rect.size.y, 0.001)
	for retired_name: String in ["DistantRoad", "CloudLayer", "BattlePlatformAssembly"]:
		assert_null(stage.get_node_or_null(retired_name))


func test_scene9_uses_one_pixel_consistent_pointer_fixed_platform() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform := stage.get_node_or_null("BattlePlatformNew") as TextureRect
	assert_not_null(platform)
	if platform == null:
		return
	assert_true(platform.visible)
	assert_eq(platform.texture.resource_path, NEW_PLATFORM_PATH)
	assert_eq(platform.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(platform.position, Vector2(-17.0, 490.0))
	assert_eq(platform.size, Vector2(408.0, 136.0))
	assert_eq(platform.scale, Vector2(6.0, 6.0))
	assert_eq(float(platform.get_meta("parallax_factor")), 1.0)
	assert_eq(float(platform.get_meta("pointer_parallax_factor")), 0.0)
	assert_eq(float(platform.get_meta("dolly_parallax_factor")), 1.0)
	assert_eq(platform.size * platform.scale \
			/ Vector2(platform.texture.get_size()), Vector2(6.0, 6.0))
	for legacy_name: String in ["BattlePlatformAssembly", "BattlePlatform",
			"BattlePlatform2", "BattlePlatform3", "BattlePlatform4", "BattlePlatform5"]:
		assert_null(stage.get_node_or_null(legacy_name))
	for foreground_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var foreground := stage.get_node(foreground_name) as Control
		assert_eq(foreground.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(foreground.scale, Vector2(3.0, 3.0))
		assert_gt(float(foreground.get_meta("parallax_factor")), 1.0)
	var platform_used_rect := _displayed_used_rect(platform)
	assert_lte(platform_used_rect.position.x + stage.position.x, 0.0)
	assert_gte(platform_used_rect.end.x + stage.position.x, 1920.0)
	var centered_position := platform.position
	for pointer_x: float in [-1.0, 1.0]:
		stage.set("_pnx", pointer_x)
		stage.call("_process", 0.0)
		assert_eq(stage.pointer_ground_offset(), Vector2.ZERO)
		assert_lte(platform.position.distance_to(centered_position), 0.001,
				"Scene9 active platform must ignore horizontal pointer movement")


func test_scene9_platform_has_no_generated_extension() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var platform := stage.get_node("BattlePlatformNew") as TextureRect
	var material := platform.material as ShaderMaterial
	assert_true(material.resource_local_to_scene)
	assert_eq(material.shader.resource_path, PLATFORM_CONTACT_SHADER_PATH)
	assert_eq(platform.texture.resource_path, NEW_PLATFORM_PATH,
			"Scene9 must draw only the current authored platform")
	assert_false(bool(material.get_shader_parameter("contact_enabled")),
			"The rejected alpha interlock must stay disabled")
	assert_true(bool(material.get_shader_parameter("contact_shadow_enabled")),
			"Only the approved local contact shadow may bridge the seam")
	var stage_source := FileAccess.get_file_as_string(SCENE9_PATH)
	var shader_source := FileAccess.get_file_as_string(PLATFORM_CONTACT_SHADER_PATH)
	assert_false(stage_source.contains("scene9_platform_interlock_map"),
			"Scene9 must not reference the rejected generated extension map")
	assert_false(shader_source.contains("scene9_platform_interlock_map"))
	var project_dir := DirAccess.open("res://")
	assert_not_null(project_dir)
	if project_dir != null:
		assert_false(project_dir.file_exists(
				"assets/scenes/scene9/scene9_platform_interlock_map.png"))
		assert_false(project_dir.file_exists(
				"tools/generate_scene9_platform_interlock_mask.gd"))
	for legacy_name: String in ["BattlePlatformAssembly", "BattlePlatform",
			"BattlePlatform2", "BattlePlatform3", "BattlePlatform4", "BattlePlatform5"]:
		assert_null(stage.get_node_or_null(legacy_name))


func test_scene9_static_depth_and_join_layers_are_one_scene_local_system() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	stage.set_process(false)
	var stage_source := FileAccess.get_file_as_string(SCENE9_PATH)
	var shader_source := FileAccess.get_file_as_string(STATIC_DEPTH_SHADER_PATH)
	assert_false(stage_source.contains("z_index ="),
			"Scene9 manual hierarchy must not be overridden by serialized z-index values")
	assert_false(shader_source.contains("ordered_threshold"))
	assert_false(shader_source.contains("horizon_fade"),
			"Rejected dotted horizon fade must stay removed")
	assert_false(shader_source.contains("contact_edge"),
			"Rejected generated platform contact edge must stay removed")
	assert_false(shader_source.contains("contact_color"))
	assert_false(shader_source.contains("contact_strength"))
	assert_false(shader_source.contains("surface_depth_grade"),
			"Platform integration must not be synthesized from local UV gradients")
	assert_false(shader_source.contains("surface_top_tint"))
	assert_false(shader_source.contains("surface_bottom_tint"))
	assert_true(shader_source.contains("hint_range(0.0, 2.0, 0.01)"),
			"Scene9 Inspector must expose the full near-grass brightness range")
	var far_names: Array[String] = [
		"DistantLeft",
		"DistantLeft2",
		"DistantRight",
		"DistantRight2",
	]
	var base_positions: Dictionary[String, Vector2] = {}
	for node_name: String in far_names:
		var layer := stage.get_node(node_name) as Control
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		assert_true(material.resource_local_to_scene)
		var expected_shader := DISTANT_GRASS_CONTACT_SHADER_PATH \
				if node_name.begins_with("DistantLeft") \
				else DISTANT_GRASS_WIND_SHADER_PATH
		assert_eq(material.shader.resource_path, expected_shader)
		assert_eq(layer.z_index, 0)
		assert_eq(float(layer.get_meta("parallax_factor")), 1.0,
				"Scene9 distant terrain must share the platform ground plane")
		assert_eq(float(layer.get_meta("pointer_parallax_factor")), 0.0,
				"Scene9 distant grass and road are ground and must ignore the mouse")
		assert_eq(float(layer.get_meta("dolly_parallax_factor")), 1.0,
				"Scene9 distant terrain must stay attached during focus dolly")
		assert_eq(layer.scale,
				Vector2(5.0, 5.0) if node_name == "DistantLeft2" else Vector2(6.0, 5.0),
				"Preserve the current accepted manual terrain scale")
		base_positions[node_name] = layer.position
	assert_null(stage.get_node_or_null("DistantRoad"),
			"The rejected standalone road extension must stay absent")
	for grass_name: String in far_names:
		var grass_material := (stage.get_node(grass_name) as Control).material \
				as ShaderMaterial
		assert_gte(float(grass_material.get_shader_parameter("root_y")), 0.95)
		assert_gte(float(grass_material.get_shader_parameter("sway_px")), 2.5)
		assert_gte(float(grass_material.get_shader_parameter("detail_px")), 0.5)
		assert_gte(float(grass_material.get_shader_parameter("gust_lift_px")), 0.7)
		assert_lte(float(grass_material.get_shader_parameter("cycle_sec")), 11.0)
		assert_gte(float(grass_material.get_shader_parameter(
				"field_wave_strength")), 0.14)
		assert_gte(float(grass_material.get_shader_parameter("brightness")), 0.98)
		var far_tint: Color = grass_material.get_shader_parameter("tint_color")
		assert_gte(far_tint.g, far_tint.r)
		assert_gte(far_tint.b, far_tint.g,
				"Current far grass intentionally leans toward the approved silver-blue palette")
	var mid := stage.get_node("ForegroundMid") as Control
	var mid_grass_material := mid.material as ShaderMaterial
	assert_eq(mid.z_index, 0)
	assert_eq(mid_grass_material.shader.resource_path,
			FOREGROUND_WIND_SHADER_PATH)
	assert_almost_eq(float(mid_grass_material.get_shader_parameter(
			"brightness")), 1.08, 0.001)
	assert_almost_eq(float(mid_grass_material.get_shader_parameter(
			"saturation")), 0.35, 0.001)
	assert_almost_eq(float(mid_grass_material.get_shader_parameter(
			"contrast")), 0.94, 0.001)
	var shared_grass_tint: Color = mid_grass_material.get_shader_parameter(
			"tint_color")
	assert_eq(shared_grass_tint, Color(0.98, 0.99, 1.0, 1.0))
	assert_eq(float(mid.get_meta("parallax_factor")), 1.18)
	assert_eq(float(mid.get_meta("pointer_parallax_factor")), 1.08)
	assert_eq(float(mid.get_meta("dolly_parallax_factor")), 1.18)
	var mid_texture := mid.get("texture") as Texture2D
	var mid_pixel_scale := mid.size * mid.scale / Vector2(mid_texture.get_size())
	assert_eq(mid_pixel_scale, Vector2(4.0, 4.0))
	var mid_graded_luma := _mean_graded_luma(mid)
	var foreground_graded_lumas: Array[float] = []
	for foreground_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var foreground := stage.get_node(foreground_name) as Control
		var near_material := foreground.material as ShaderMaterial
		assert_eq(foreground.z_index, 0)
		assert_true(near_material.resource_local_to_scene)
		assert_eq(near_material.shader.resource_path, FOREGROUND_WIND_SHADER_PATH)
		assert_eq(float(foreground.get_meta("parallax_factor")), 1.18)
		assert_eq(float(foreground.get_meta("pointer_parallax_factor")), 1.08)
		assert_eq(float(foreground.get_meta("dolly_parallax_factor")), 1.18)
		assert_almost_eq(float(near_material.get_shader_parameter("brightness")),
				1.06, 0.001)
		assert_almost_eq(float(near_material.get_shader_parameter("contrast")),
				0.96, 0.001)
		assert_eq(near_material.get_shader_parameter("tint_color"),
				shared_grass_tint)
		assert_almost_eq(float(near_material.get_shader_parameter("saturation")),
				0.58, 0.001)
		var foreground_pixel_scale := foreground.size * foreground.scale \
				/ Vector2((foreground.get("texture") as Texture2D).get_size())
		assert_eq(foreground_pixel_scale, Vector2(3.0, 3.0))
		foreground_graded_lumas.append(_mean_graded_luma(foreground))
	assert_lte(absf(foreground_graded_lumas[0] - foreground_graded_lumas[1]), 0.02,
			"Different source art may vary slightly while sharing one near color plane")
	assert_lte(absf(mid_graded_luma - foreground_graded_lumas[0]), 0.16,
			"Mid and near grass may separate in depth without returning to two color styles")
	assert_lt(stage.get_node("SceneSky").get_index(),
			stage.get_node("DistantPixelCloudBank").get_index())
	for grass_name: String in far_names:
		assert_lt(stage.get_node("DistantPixelCloudBank").get_index(),
				stage.get_node(grass_name).get_index(),
				"The code cloud must remain behind every distant terrain bank")
		assert_lt(stage.get_node(grass_name).get_index(), mid.get_index())
	var platform := stage.get_node("BattlePlatformNew") as TextureRect
	var platform_material := platform.material as ShaderMaterial
	assert_eq(platform.z_index, 0)
	assert_lt(platform.get_index(), mid.get_index(),
			"The authored mid-grass silhouette must cover the platform naturally")
	assert_lt(platform.get_index(),
			stage.get_node("ForegroundLeft").get_index())
	assert_true(platform_material.resource_local_to_scene)
	assert_eq(platform_material.shader.resource_path, PLATFORM_CONTACT_SHADER_PATH)
	assert_almost_eq(float(platform_material.get_shader_parameter("brightness")),
			1.1, 0.001)
	assert_false(bool(platform_material.get_shader_parameter("contact_enabled")))
	assert_true(bool(platform_material.get_shader_parameter("contact_shadow_enabled")))
	stage.set("_time", 0.0)
	stage.set("_pnx", 1.0)
	stage.set("pointer_zoom", 0.0)
	stage.call("_process", 0.0)
	for node_name: String in far_names:
		var offset := (stage.get_node(node_name) as Control).position \
				- base_positions[node_name]
		assert_lte(offset.length(), 0.001,
				"Scene9 distant terrain must remain fixed under pointer motion")
	var near_reference := stage.get_node("ForegroundMid") as Control
	var near_reference_index: int = stage.get("_layers").find(near_reference)
	var near_reference_base: Vector2 = stage.get("_bases")[near_reference_index]
	var near_reference_offset := near_reference.position - near_reference_base
	for foreground_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var foreground := stage.get_node(foreground_name) as Control
		var registered_index: int = stage.get("_layers").find(foreground)
		var foreground_base: Vector2 = stage.get("_bases")[registered_index]
		assert_lte((foreground.position - foreground_base).distance_to(
				near_reference_offset), 0.001,
				"Scene9 mid/left/right foreground must move as one near plane")


func test_scene9_ground_override_does_not_leak_to_scenes_1_through_8() -> void:
	for scene_number: int in range(1, 9):
		var legacy_path := "res://src/ui/scenes/scene%d.tscn" % scene_number
		var source := FileAccess.get_file_as_string(legacy_path)
		assert_false(source.contains(SCENE9_STAGE_SCRIPT_PATH),
				"Legacy scene %d must not reference the Scene9 override" % scene_number)
		var legacy := (load(legacy_path) as PackedScene).instantiate() as BattleStage
		add_child_autofree(legacy)
		assert_eq((legacy.get_script() as Script).resource_path,
				SHARED_STAGE_SCRIPT_PATH)
		legacy.set("_pnx", 1.0)
		assert_eq(legacy.pointer_ground_offset(), Vector2(
				-legacy.pointer_strength * legacy.ground_parallax, 0.0))


func test_scene9_code_cloud_has_a_readable_alpha_footprint() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var cloud := stage.get_node("DistantPixelCloudBank") as TextureRect
	assert_gte(cloud.size.x, 2200.0)
	assert_gte(cloud.size.y, 540.0)
	assert_lte(cloud.global_position.y, 60.0,
			"The stage-local offset may change, but the cloud horizon must remain high")
	var coverage := cloud.call("coverage_snapshot", 0) as Dictionary
	assert_gte(int(coverage["bottom_covered_columns"]), 400,
			"The single code-only cloud must retain the authored horizontal span")
	assert_eq(int(coverage["left_padding_opaque_pixels"]), 0,
			"The cloud canvas must not repeat the source into its left padding")
	assert_eq(int(coverage["right_padding_opaque_pixels"]), 0,
			"The cloud canvas must not repeat the source into its right padding")


func test_scene9_guides_preserve_mature_character_geometry() -> void:
	if not ResourceLoader.exists(SCENE9_PATH):
		return
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var guides := stage.get_node("CompositionGuides") as Node2D
	assert_true(guides.top_level,
			"CompositionGuides must not inherit Scene9's authored environment offset")
	assert_eq(guides.position,
			Vector2.ZERO,
			"CompositionGuides parent must stay at the scene origin")
	var expected_positions: Dictionary[String, Vector2] = {
		"P1Baseline": Vector2(480.0, 748.0),
		"P2Baseline": Vector2(1440.0, 748.0),
		"PlatformBaseline": Vector2(960.0, 748.0),
	}
	for marker_name: String in expected_positions:
		var marker := guides.get_node(marker_name) as Marker2D
		assert_eq(marker.position, expected_positions[marker_name])
		assert_lte(marker.global_position.distance_to(
				expected_positions[marker_name]), 0.001,
				"Guide must resolve to its mature screen coordinate: %s" % marker_name)


func test_scene9_entry_reuses_shared_ui_characters_input_and_parallax() -> void:
	if not ResourceLoader.exists(BATTLE9_PATH):
		return
	BattleSetup.reset()
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE9_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE9_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_false(screen.character_reflections_enabled)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p1_char_display.position,
			(base.get_node("P1CharDisplay") as CharacterDisplay).position)
	assert_eq(screen.p2_char_display.position,
			(base.get_node("P2CharDisplay") as CharacterDisplay).position)
	assert_eq(screen.p1_char_display.size,
			(base.get_node("P1CharDisplay") as CharacterDisplay).size)
	assert_eq(screen.p2_char_display.size,
			(base.get_node("P2CharDisplay") as CharacterDisplay).size)
	assert_not_null(screen.p1_char_display.get_render_texture())
	assert_not_null(screen.p2_char_display.get_render_texture())
	var guides := screen.stage.get_node("CompositionGuides") as Node2D
	var guide_screen_positions: Dictionary[String, Vector2] = {
		"P1Baseline": Vector2(480.0, 748.0),
		"P2Baseline": Vector2(1440.0, 748.0),
		"PlatformBaseline": Vector2(960.0, 748.0),
	}
	for marker_name: String in guide_screen_positions:
		var marker := guides.get_node(marker_name) as Marker2D
		assert_lte(marker.global_position.distance_to(
				guide_screen_positions[marker_name]), 0.001,
				"BattleScreen9 guide must remain at screen coordinate: %s" % marker_name)
	var world := screen.get("_world") as Control
	assert_not_null(world)
	for pointer_x: float in [-1.0, 1.0]:
		screen.stage.set("_pnx", pointer_x)
		screen.stage.call("_process", 0.0)
		screen.call("_process", 0.0)
		assert_eq(world.position, Vector2.ZERO,
				"Scene9 fighters must remain fixed with the platform at pointer extremes")
		for marker_name: String in guide_screen_positions:
			var marker := guides.get_node(marker_name) as Marker2D
			assert_lte(marker.global_position.distance_to(
					guide_screen_positions[marker_name]), 0.001,
					"Composition guide must ignore Scene9 environment motion")
	for node_path: String in [
		"P1Hud",
		"P2Hud",
		"TimerLabel",
		"Buttons",
		"DeathSwitchOverlay",
	]:
		assert_true(screen.has_node(node_path))
	base.free()
	BattleSetup.reset()


func test_scene9_owns_pixel_character_grade_and_contact_shadows() -> void:
	if not ResourceLoader.exists(BATTLE9_PATH):
		return
	assert_true(ResourceLoader.exists(SCENE9_CHARACTER_SHADER_PATH))
	assert_true(ResourceLoader.exists(SCENE9_CONTACT_SHADOW_SHADER_PATH))
	BattleSetup.reset()
	var screen := (load(BATTLE9_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for shadow: TextureRect in [screen.p1_shadow, screen.p2_shadow]:
		assert_not_null(shadow)
		assert_true(shadow.visible)
		assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(shadow.size, Vector2(132.0, 32.0))
		assert_eq(shadow.rotation, 0.0)
		var shadow_material := shadow.material as ShaderMaterial
		assert_not_null(shadow_material)
		if shadow_material != null:
			assert_true(shadow_material.resource_local_to_scene)
			assert_eq(shadow_material.shader.resource_path,
					SCENE9_CONTACT_SHADOW_SHADER_PATH)
			assert_eq(shadow_material.get_shader_parameter("grid_cells"),
					Vector2(44.0, 10.0))
			assert_eq(float(shadow_material.get_shader_parameter("alpha_levels")),
					4.0)
	assert_eq(screen.p1_shadow.position, Vector2(414.0, 732.0))
	assert_eq(screen.p2_shadow.position, Vector2(1374.0, 732.0))
	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)
	var character_materials: Array[ShaderMaterial] = []
	for display: CharacterDisplay in [
		screen.p1_char_display,
		screen.p2_char_display,
	]:
		assert_almost_eq(display.rim_strength, 0.14, 0.001)
		assert_almost_eq(display.backlight, 0.08, 0.001)
		assert_almost_eq(display.warmth_amount, 0.025, 0.001)
		assert_almost_eq(display.fill_amount, 0.02, 0.001)
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") \
				as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		character_materials.append(material)
		assert_true(material.resource_local_to_scene)
		assert_eq(material.shader.resource_path, SCENE9_CHARACTER_SHADER_PATH)
		assert_almost_eq(float(material.get_shader_parameter("rim_strength")),
				display.rim_strength, 0.001)
		assert_almost_eq(float(material.get_shader_parameter("backlight")),
				display.backlight, 0.001)
		assert_almost_eq(float(material.get_shader_parameter("warmth_amount")),
				display.warmth_amount, 0.001)
		assert_almost_eq(float(material.get_shader_parameter("fill_amount")),
				display.fill_amount, 0.001)
		assert_almost_eq(float(material.get_shader_parameter("grass_bounce_amount")),
				0.07, 0.001)
	assert_eq(character_materials.size(), 2)
	if character_materials.size() == 2:
		assert_ne(character_materials[0], character_materials[1],
				"P1/P2 runtime character materials must stay isolated")
		assert_gt((character_materials[0].get_shader_parameter("light_dir") as Vector2).x,
				0.0)
		assert_lt((character_materials[1].get_shader_parameter("light_dir") as Vector2).x,
				0.0)
	var character_shader_source := FileAccess.get_file_as_string(
			SCENE9_CHARACTER_SHADER_PATH)
	assert_true(character_shader_source.contains("luma_preserving_palette"))
	assert_true(character_shader_source.contains("grass_bounce_amount"))
	assert_true(character_shader_source.contains("floor(grass_bounce * 4.0"))
	assert_true(character_shader_source.contains("TEXTURE_PIXEL_SIZE"))
	assert_false(character_shader_source.contains("SCREEN_TEXTURE"))
	var shadow_shader_source := FileAccess.get_file_as_string(
			SCENE9_CONTACT_SHADOW_SHADER_PATH)
	assert_true(shadow_shader_source.contains("snapped_uv"))
	assert_true(shadow_shader_source.contains("alpha_levels"))
	BattleSetup.reset()


func test_scene9_uses_a_local_neutral_post_process() -> void:
	if not ResourceLoader.exists(BATTLE9_PATH):
		return
	var screen := (load(BATTLE9_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var material := (screen.get_node("PostFX") as ColorRect).material \
			as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_true(material.resource_local_to_scene)
	assert_eq(material.shader.resource_path, POSTFX_SHADER_PATH)
	assert_eq(float(material.get_shader_parameter("barrel_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("edge_blur_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("brightness")), 1.0)
	assert_eq(float(material.get_shader_parameter("contrast")), 1.0)
	assert_eq(float(material.get_shader_parameter("saturation")), 1.0)
	assert_eq(float(material.get_shader_parameter("tint_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("split_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("vignette_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("grain_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("heat_haze_strength")), 0.0)


func _displayed_used_rect(layer: Control) -> Rect2:
	var texture := layer.get("texture") as Texture2D
	var used_rect := _alpha_used_rect(texture.get_image(), 0.03)
	var local_rect := Rect2(Vector2(used_rect.position), Vector2(used_rect.size))
	var layer_transform := Transform2D(
			layer.rotation, layer.scale, 0.0, layer.position)
	var corners: Array[Vector2] = [
		layer_transform * local_rect.position,
		layer_transform * Vector2(local_rect.end.x, local_rect.position.y),
		layer_transform * local_rect.end,
		layer_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


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


func _mean_graded_luma(layer: Control) -> float:
	var image := (layer.get("texture") as Texture2D).get_image()
	var material := layer.material as ShaderMaterial
	var tint: Color = material.get_shader_parameter("tint_color")
	var brightness := float(material.get_shader_parameter("brightness"))
	var saturation := float(material.get_shader_parameter("saturation"))
	var contrast := float(material.get_shader_parameter("contrast"))
	var steps := maxf(float(material.get_shader_parameter("palette_steps")) - 1.0,
			1.0)
	var total_luma := 0.0
	var opaque_count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.03:
				continue
			var source := Vector3(color.r, color.g, color.b)
			var source_luma := source.dot(Vector3(0.2126, 0.7152, 0.0722))
			var graded := Vector3(source_luma, source_luma, source_luma).lerp(
					source, saturation)
			graded = (graded - Vector3(0.5, 0.5, 0.5)) * contrast \
					+ Vector3(0.5, 0.5, 0.5)
			graded *= Vector3(tint.r, tint.g, tint.b) * brightness
			graded = graded.clamp(Vector3.ZERO, Vector3.ONE)
			graded = Vector3(
					roundf(graded.x * steps) / steps,
					roundf(graded.y * steps) / steps,
					roundf(graded.z * steps) / steps)
			total_luma += graded.dot(Vector3(0.2126, 0.7152, 0.0722))
			opaque_count += 1
	return total_luma / float(maxi(opaque_count, 1))


func _opaque_pixel_count_in_rows(
		image: Image, start_row: int, end_row: int, threshold: float) -> int:
	var count := 0
	for y: int in range(maxi(start_row, 0), mini(end_row, image.get_height())):
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= threshold:
				count += 1
	return count
