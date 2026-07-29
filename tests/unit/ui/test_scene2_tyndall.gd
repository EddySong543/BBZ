extends GutTest

const SCENE1_PATH := "res://src/ui/scenes/scene1.tscn"
const SCENE2_PATH := "res://src/ui/scenes/scene2.tscn"
const TYNDALL_SHADER_PATH := "res://assets/shaders/canvas_env_scene2_tyndall.gdshader"
const BRIDGE_LIGHT_SHADER_PATH := "res://assets/shaders/canvas_env_scene2_bridge_light.gdshader"


func test_scene2_tyndall_layers_follow_depth_occlusion_order() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	var far := stage.get_node("TyndallFar") as ColorRect
	var mist := stage.get_node("TyndallMist") as ColorRect

	assert_lt(stage.get_node("FarMountain2").get_index(), far.get_index())
	assert_lt(far.get_index(), stage.get_node("MidMountain").get_index())
	assert_lt(stage.get_node("Waterfall").get_index(), mist.get_index())
	assert_lt(mist.get_index(), stage.get_node("WaterfallRidgeContact").get_index())
	assert_false(stage.has_node("TyndallLanding"),
			"Ground light must land through receiving materials, not a fullscreen overlay")

	assert_eq((far.material as ShaderMaterial).shader.resource_path, TYNDALL_SHADER_PATH)
	assert_eq((mist.material as ShaderMaterial).shader.resource_path, TYNDALL_SHADER_PATH)
	var bridge_material := stage.get_node("StoneBridge").material as ShaderMaterial
	assert_eq(bridge_material.shader.resource_path, BRIDGE_LIGHT_SHADER_PATH)
	stage.free()


func test_scene2_tyndall_stays_pixel_stepped_and_restrained() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	for node_name in ["TyndallFar", "TyndallMist"]:
		var material := stage.get_node(node_name).material as ShaderMaterial
		assert_eq(float(material.get_shader_parameter("pixel_size")), 4.0)
		assert_gte(float(material.get_shader_parameter("intensity")), 0.02)
		assert_lte(float(material.get_shader_parameter("intensity")), 0.08)
		assert_true(material.shader.code.contains("floor(UV * grid)"))
	var river_material := stage.get_node("River").material as ShaderMaterial
	assert_gt(float(river_material.get_shader_parameter("daylight_strength")), 0.0)
	assert_gt(float(river_material.get_shader_parameter("daylight_shadow_strength")), 0.0)
	assert_gt(float(river_material.get_shader_parameter("tree_shadow_strength")), 0.0)
	stage.free()


func test_scene2_receivers_share_one_visible_screen_space_light_field() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	var receiver_names := [
		"Sky",
		"MidMountain",
		"WaterfallRidgeLeft",
		"Waterfall",
		"WaterfallCloudUpper",
		"MountainRight",
		"WaterfallCloudLower",
		"MountainLeft",
		"StoneBridge",
		"River",
	]
	for node_name in receiver_names:
		var material := stage.get_node(node_name).material as ShaderMaterial
		assert_not_null(material, "%s must receive the Scene2 light field" % node_name)
		if material == null or material.shader == null:
			continue
		assert_true(material.shader.code.contains("scene2_light_field"))
		assert_true(material.shader.code.contains("SCREEN_UV"),
				"%s must use scene coordinates instead of restarting light in local UV" % node_name)

	var sky_material := stage.get_node("Sky").material as ShaderMaterial
	assert_gte(float(sky_material.get_shader_parameter("scene_light_strength")), 0.15)
	assert_gte(float(sky_material.get_shader_parameter("scene_shadow_strength")), 0.15)
	var ridge_material := stage.get_node("WaterfallRidgeLeft").material as ShaderMaterial
	assert_gte(float(ridge_material.get_shader_parameter("receiver_light_strength")), 0.2)
	assert_gte(float(ridge_material.get_shader_parameter("receiver_shadow_strength")), 0.15)
	stage.free()


func test_scene1_remains_free_of_scene2_tyndall_layers() -> void:
	var stage := (load(SCENE1_PATH) as PackedScene).instantiate()
	assert_false(stage.has_node("TyndallFar"))
	assert_false(stage.has_node("TyndallMist"))
	assert_false(stage.has_node("TyndallLanding"))
	stage.free()


func test_scene2_focus_hierarchy_uses_local_restrained_grading() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	var waterfall_material := stage.get_node("Waterfall").material as ShaderMaterial
	var river_material := stage.get_node("River").material as ShaderMaterial
	var ridge_material := stage.get_node("WaterfallRidgeLeft").material as ShaderMaterial
	var bridge_material := stage.get_node("StoneBridge").material as ShaderMaterial

	assert_gt(float(waterfall_material.get_shader_parameter("focus_quiet_strength")), 0.0)
	assert_lte(float(waterfall_material.get_shader_parameter("focus_quiet_strength")), 0.8,
			"Character rest zones must stay local and restrained")
	assert_gte(float(waterfall_material.get_shader_parameter("focus_quiet_saturation")), 0.9,
			"Rest zones must not turn the bright sanctuary gray")

	assert_between(
			float(river_material.get_shader_parameter("focus_quiet_strength")),
			0.2, 0.4)
	assert_between(
			float(river_material.get_shader_parameter("ui_quiet_strength")),
			0.15, 0.35)
	assert_gte(float(river_material.get_shader_parameter("glint_density")), 0.04,
			"Water glints are locally quieted rather than globally removed")
	assert_gte(float(ridge_material.get_shader_parameter("saturation")), 0.8,
			"The waterfall mountain must retain color instead of becoming gray")
	assert_between(
			float(bridge_material.get_shader_parameter("grass_highlight_reduction")),
			0.3, 0.7)
	stage.free()


func test_scene2_p1_limits_large_highlights_without_extra_fullscreen_work() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	var waterfall_material := stage.get_node("Waterfall").material as ShaderMaterial
	var ridge_material := stage.get_node("WaterfallRidgeLeft").material as ShaderMaterial
	var tree_material := stage.get_node("BlossomTree").material as ShaderMaterial
	var far_material := stage.get_node("FarMountain4").material as ShaderMaterial
	var mid_material := stage.get_node("MidMountain").material as ShaderMaterial

	assert_lt(float(waterfall_material.get_shader_parameter("scene_saturation")), 1.0)
	var foam_color := waterfall_material.get_shader_parameter("foam_color") as Color
	assert_lte(foam_color.get_luminance(), 0.85,
			"Waterfall foam keeps readable detail instead of becoming a white block")
	assert_lte(float(ridge_material.get_shader_parameter("brightness")), 0.98)
	assert_gte(float(ridge_material.get_shader_parameter("saturation")), 0.8,
			"The waterfall mountain keeps color instead of becoming gray")
	assert_true(tree_material.shader.code.contains("underpaint_texture"),
			"The approved branch-gap underpaint must remain")
	assert_true(tree_material.shader.code.contains("inverse_rotate_pixel_uv"),
			"The approved local branch sway must remain")
	assert_false(tree_material.shader.code.contains("scene2_light_field"),
			"The blossom tree must not receive the muddy screen-space light field")
	assert_false(tree_material.shader.code.contains("receiver_shadow_strength"),
			"The blossom tree must not reintroduce the gray-brown receiver shadow")
	assert_lt(
			float(far_material.get_shader_parameter("contrast")),
			float(mid_material.get_shader_parameter("contrast")),
			"Far scenery must remain quieter than the middle plane")
	stage.free()


func test_scene2_p2_uses_waterfall_led_staggered_motion() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	var waterfall_material := stage.get_node("Waterfall").material as ShaderMaterial
	var river_material := stage.get_node("River").material as ShaderMaterial
	var distant_water_material := stage.get_node("DistantWater").material as ShaderMaterial
	var upper_cloud_material := stage.get_node("WaterfallCloudUpper").material as ShaderMaterial
	var lower_cloud_material := stage.get_node("WaterfallCloudLower").material as ShaderMaterial

	assert_gt(
			float(waterfall_material.get_shader_parameter("anim_fps")),
			float(river_material.get_shader_parameter("anim_fps")),
			"The waterfall remains the primary environmental motion")
	assert_gt(
			float(river_material.get_shader_parameter("anim_fps")),
			float(distant_water_material.get_shader_parameter("anim_fps")),
			"Far water must move more quietly than foreground water")
	assert_gt(
			absf(float(upper_cloud_material.get_shader_parameter("flow_speed"))),
			absf(float(lower_cloud_material.get_shader_parameter("flow_speed"))),
			"The approved upper-cloud-leading drift relationship must remain")

	var total_particles := 0
	for node_name in ["PollenFar", "ValleyDust", "GroundPollen", "PollenNear"]:
		var particles := stage.get_node(node_name) as GPUParticles2D
		total_particles += particles.amount
		assert_gte(particles.randomness, 0.5,
				"Ambient particles need irregular emission instead of synchronized persistence")
	assert_lte(total_particles, 70,
			"Ambient particle count must stay subordinate to the waterfall")
	stage.free()
