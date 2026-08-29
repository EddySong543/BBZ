extends GutTest

const SCENE8_PATH := "res://src/ui/scenes/scene8.tscn"
const RETIRED_SNOWFALL_SCRIPT_PATH := (
		"res://src/ui/components/scene8_snowfall_field.gd")
const LAKE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_open_lake.gdshader")


func test_scene8_uses_scene3_style_dual_depth_snow_motes() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var far := stage.get_node_or_null("SnowMotesFar") as GPUParticles2D
	var near := stage.get_node_or_null("SnowMotesNear") as GPUParticles2D
	assert_not_null(far)
	assert_not_null(near)
	if far == null or near == null:
		return
	assert_null(stage.get_node_or_null("SnowfallFar"))
	assert_null(stage.get_node_or_null("SnowfallNear"))
	assert_false(ResourceLoader.exists(RETIRED_SNOWFALL_SCRIPT_PATH))
	var far_process := far.process_material as ParticleProcessMaterial
	var near_process := near.process_material as ParticleProcessMaterial
	var blend := far.material as CanvasItemMaterial
	var texture := far.texture as GradientTexture2D
	assert_not_null(far_process)
	assert_not_null(near_process)
	assert_not_null(blend)
	assert_not_null(texture)
	if far_process == null or near_process == null or texture == null:
		return
	assert_eq(far.amount, 9)
	assert_eq(near.amount, 6)
	assert_eq(far.texture, near.texture)
	assert_eq(texture.width, 8)
	assert_eq(texture.height, 8)
	assert_eq(blend.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	assert_eq(far.lifetime, 11.0)
	assert_eq(far.preprocess, 8.0)
	assert_almost_eq(far.explosiveness, 0.12, 0.001)
	assert_almost_eq(far.randomness, 0.82, 0.001)
	assert_eq(near.lifetime, 8.0)
	assert_eq(near.preprocess, 5.0)
	assert_almost_eq(near.explosiveness, 0.18, 0.001)
	assert_almost_eq(near.randomness, 0.86, 0.001)
	assert_true(far.emitting)
	assert_true(near.emitting)
	assert_true(far.interpolate)
	assert_true(near.interpolate)
	assert_eq(far.fixed_fps, 30)
	assert_eq(near.fixed_fps, 30)
	assert_gt(far_process.direction.y, 0.95)
	assert_gt(near_process.direction.y, 0.95)
	assert_almost_eq(far_process.direction.x, -0.12, 0.001)
	assert_almost_eq(near_process.direction.x, 0.16, 0.001)
	assert_eq(far_process.emission_box_extents, Vector3(430, 170, 1))
	assert_eq(near_process.emission_box_extents, Vector3(390, 145, 1))
	assert_eq(far_process.initial_velocity_min, 2.5)
	assert_eq(far_process.initial_velocity_max, 5.0)
	assert_eq(near_process.initial_velocity_min, 5.5)
	assert_eq(near_process.initial_velocity_max, 10.0)
	assert_gt(far_process.gravity.y, 0.0)
	assert_gt(near_process.gravity.y, 0.0)
	assert_lt(far_process.scale_max, near_process.scale_min)
	assert_almost_eq(far_process.scale_min, 0.5, 0.001)
	assert_almost_eq(far_process.scale_max, 1.05, 0.001)
	assert_almost_eq(near_process.scale_min, 1.35, 0.001)
	assert_almost_eq(near_process.scale_max, 2.25, 0.001)
	assert_between(far_process.color.a, 0.28, 0.32)
	assert_between(near_process.color.a, 0.3, 0.38)
	assert_true(far_process.color.b > far_process.color.r)
	assert_true(near_process.color.g > near_process.color.r)
	assert_ne(far_process.color, near_process.color)
	assert_eq(far_process.color_ramp, near_process.color_ramp)
	assert_true(far_process.color_ramp is GradientTexture1D)
	assert_eq((far_process.color_ramp as GradientTexture1D).gradient.get_point_count(), 4)
	assert_eq(float(far.get_meta("pointer_parallax_factor")), 0.08)
	assert_eq(float(near.get_meta("pointer_parallax_factor")), 1.04)
	assert_lt(stage.get_node("FarGlacier").get_index(), far.get_index())
	assert_lt(far.get_index(), stage.get_node("PlatformWaterContact").get_index())
	assert_lt(stage.get_node("BattlePlatform").get_index(), near.get_index())
	assert_lt(near.get_index(), stage.get_node("ForegroundSnowfield").get_index())
	var scene_source := FileAccess.get_file_as_string(SCENE8_PATH)
	assert_false(scene_source.contains("SnowfallFar"))
	assert_false(scene_source.contains("SnowfallNear"))
	assert_false(scene_source.contains("scene8_snowfall_field.gd"))
	assert_false(scene_source.contains("draw_rect"))

	var lake_material := (
			stage.get_node("MirrorLake") as ColorRect).material as ShaderMaterial
	assert_eq(lake_material.shader.resource_path, LAKE_SHADER_PATH)
