extends GutTest

const SCENE3 := preload("res://src/ui/scenes/scene3.tscn")
const CLIFF_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_cliff_grass_sway.gdshader")
const GLINT_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_sword_glint.gdshader")
const FISH_SCRIPT_PATH := (
		"res://src/ui/components/scene3_flying_fish_school.gd")


func _stage() -> Control:
	var stage := SCENE3.instantiate() as Control
	add_child_autofree(stage)
	return stage


func test_cliff_light_bands_follow_the_cloud_rhythm() -> void:
	var stage := _stage()
	var shader_source := FileAccess.get_file_as_string(CLIFF_SHADER_PATH)
	assert_true(
			shader_source.contains("uniform float cloud_band_light_strength"),
			"Scene3 cliff shader exposes a visible cloud-driven light band")
	assert_true(
			shader_source.contains("cloud_light_band"),
			"Scene3 cliff shader computes the light band in screen space")
	assert_true(
			shader_source.contains("SCREEN_UV"),
			"Both cliffs share one coherent screen-space cloud-light field")
	if not shader_source.contains(
			"uniform float cloud_band_light_strength"):
		return

	var sun_ray := stage.get_node("SunRayField") as ColorRect
	var sun_material := sun_ray.material as ShaderMaterial
	var cloud_roll_speed := float(
			sun_material.get_shader_parameter("cloud_roll_speed"))
	var cloud_billow_speed := float(
			sun_material.get_shader_parameter("cloud_billow_speed"))
	var phases: Array[float] = []
	for cliff_path in ["LeftCliff", "RightCliff"]:
		var cliff := stage.get_node(cliff_path) as TextureRect
		var material := cliff.material as ShaderMaterial
		assert_eq(
				material.shader.resource_path,
				CLIFF_SHADER_PATH,
				"%s keeps the active grass shader while receiving light"
						% cliff_path)
		assert_gte(
				float(material.get_shader_parameter(
						"cloud_band_light_strength")),
				0.18,
				"%s receives a clearly visible but restrained light band"
						% cliff_path)
		assert_gte(
				float(material.get_shader_parameter(
						"cloud_band_shadow_strength")),
				0.08,
				"%s receives a trailing cloud shadow band" % cliff_path)
		assert_almost_eq(
				float(material.get_shader_parameter("cloud_roll_speed")),
				cloud_roll_speed,
				0.001,
				"%s follows the ray field roll rhythm" % cliff_path)
		assert_almost_eq(
				float(material.get_shader_parameter("cloud_billow_speed")),
				cloud_billow_speed,
				0.001,
				"%s follows the ray field billow rhythm" % cliff_path)
		phases.append(float(
				material.get_shader_parameter("cloud_band_phase")))
	assert_gt(
			absf(phases[0] - phases[1]),
			0.5,
			"The two cliffs do not brighten in mechanical unison")


func test_right_cliff_removes_only_the_confirmed_source_artifact() -> void:
	var stage := _stage()
	var left := stage.get_node("LeftCliff") as TextureRect
	var right := stage.get_node("RightCliff") as TextureRect
	var left_material := left.material as ShaderMaterial
	var right_material := right.material as ShaderMaterial
	assert_eq(
			right_material.get_shader_parameter("artifact_cleanup_pixel"),
			Vector2(23.0, 41.0),
			"The confirmed pale source pixel is targeted in source coordinates")
	assert_eq(
			float(right_material.get_shader_parameter(
					"artifact_cleanup_strength")),
			1.0,
			"The confirmed artifact is fully removed")
	assert_eq(
			float(left_material.get_shader_parameter(
					"artifact_cleanup_strength")),
			0.0,
			"The cleanup does not affect the left cliff")
	var shader_source := FileAccess.get_file_as_string(CLIFF_SHADER_PATH)
	assert_true(shader_source.contains("artifact_cleanup_pixel"))
	assert_true(shader_source.contains("artifact_distance"))


func test_sun_motes_use_two_sparse_speed_and_depth_layers() -> void:
	var stage := _stage()
	assert_true(
			stage.has_node("SunMotesFar"),
			"Scene3 has a sparse far sun-mote layer")
	assert_true(
			stage.has_node("SunMotesNear"),
			"Scene3 has a sparse near sun-mote layer")
	if not stage.has_node("SunMotesFar") \
			or not stage.has_node("SunMotesNear"):
		return

	var far := stage.get_node("SunMotesFar") as GPUParticles2D
	var near := stage.get_node("SunMotesNear") as GPUParticles2D
	assert_not_null(far)
	assert_not_null(near)
	assert_between(far.amount, 5, 10, "Far motes remain sparse")
	assert_between(near.amount, 3, 7, "Near motes remain sparse")
	assert_lte(far.amount + near.amount, 18, "The ray field never becomes dust")
	assert_true(far.local_coords, "Far live particles stay attached to parallax")
	assert_true(near.local_coords, "Near live particles stay attached to parallax")
	assert_true(
			far.texture is GradientTexture2D,
			"Far motes use a generated texture, not an external asset")
	assert_true(
			near.texture is GradientTexture2D,
			"Near motes use a generated texture, not an external asset")

	var far_process := far.process_material as ParticleProcessMaterial
	var near_process := near.process_material as ParticleProcessMaterial
	assert_not_null(far_process)
	assert_not_null(near_process)
	assert_eq(int(far_process.emission_shape), 3, "Far motes use a bounded box")
	assert_eq(int(near_process.emission_shape), 3, "Near motes use a bounded box")
	assert_lte(
			far_process.emission_box_extents.x,
			520.0,
			"Far motes stay inside the central light field")
	assert_lte(
			near_process.emission_box_extents.x,
			520.0,
			"Near motes stay inside the central light field")
	assert_gt(
			near_process.initial_velocity_max,
			far_process.initial_velocity_max,
			"Near motes drift faster than far motes")
	assert_between(
			far_process.scale_min,
			0.45,
			0.65,
			"Far motes are large enough to read like Scene1/2 ambient particles")
	assert_between(
			far_process.scale_max,
			0.9,
			1.2,
			"Far motes retain a restrained depth range")
	assert_between(
			near_process.scale_min,
			1.2,
			1.6,
			"Near motes use the larger Scene1/2 foreground scale")
	assert_between(
			near_process.scale_max,
			2.0,
			2.6,
			"Near motes are visibly larger without becoming a particle curtain")
	assert_lt(
			float(far.get_meta("parallax_factor")),
			float(near.get_meta("parallax_factor")),
			"The two mote layers keep distinct depth")

	assert_gt(
			far.get_index(),
			stage.get_node("SunRayField").get_index(),
			"Far motes are lit by the ray field")
	assert_lt(
			far.get_index(),
			stage.get_node("DawnSun").get_index(),
			"Far motes remain behind the sun and mountain silhouettes")
	assert_gt(
			near.get_index(),
			stage.get_node("MidSwordGrave").get_index(),
			"Near motes can cross in front of distant swords")
	assert_lt(
			near.get_index(),
			stage.get_node("CloudSeaBack").get_index(),
			"Clouds still occlude the near mote layer")


func test_decorative_chains_keep_three_authored_depths() -> void:
	var stage := _stage()
	var chain_texture_path := "res://assets/scenes/scene3/scene3_chain.png"
	var shader_path := (
			"res://assets/shaders/canvas_env_scene3_chain_depth.gdshader")
	var paths := ["BackgroundChain", "BackgroundChain2", "BackgroundChain3"]
	for path in paths:
		assert_true(stage.has_node(path), "%s exists" % path)
	if paths.any(func(path: String) -> bool: return not stage.has_node(path)):
		return

	var parallax_values: Array[float] = []
	for path in paths:
		var chain := stage.get_node(path) as TextureRect
		var material := chain.material as ShaderMaterial
		assert_eq(chain.texture.resource_path, chain_texture_path)
		assert_not_null(material, "%s uses an atmospheric depth material" % path)
		if material == null or material.shader == null:
			continue
		assert_eq(material.shader.resource_path, shader_path)
		assert_gte(
				float(material.get_shader_parameter("atmosphere_strength")),
				0.34,
				"%s is visibly absorbed by the dawn haze" % path)
		assert_lte(
				float(material.get_shader_parameter("saturation")),
				0.2,
				"%s cannot retain the playable chain's dark saturation" % path)
		var effective_alpha := (
				float(material.get_shader_parameter("alpha_scale"))
				* chain.self_modulate.a)
		assert_lte(
				effective_alpha,
				0.62,
				"%s remains a distant silhouette" % path)
		assert_gte(
				float(material.get_shader_parameter("repeat_x")),
				1.0,
				"%s keeps valid repeat sampling" % path)
		parallax_values.append(float(chain.get_meta("parallax_factor")))
	assert_lt(parallax_values[0], parallax_values[1])
	assert_lt(parallax_values[1], parallax_values[2])
	assert_lt(parallax_values[2], 1.0)

	var shader_source := FileAccess.get_file_as_string(shader_path)
	assert_true(shader_source.contains("fract(UV.x * repeats)"))


func test_distant_sword_glints_are_low_frequency_and_staggered() -> void:
	var stage := _stage()
	var paths := [
		"MidSwordGrave/LeftCluster/LowFrequencyGlint",
		"MidSwordGrave/RightCluster/LowFrequencyGlint",
	]
	for path in paths:
		assert_true(stage.has_node(path), "%s exists" % path)
	if not stage.has_node(paths[0]) or not stage.has_node(paths[1]):
		return

	var cycles: Array[float] = []
	var phases: Array[float] = []
	for path in paths:
		var glint := stage.get_node(path) as ColorRect
		var material := glint.material as ShaderMaterial
		assert_not_null(glint)
		assert_not_null(material)
		assert_eq(
				material.shader.resource_path,
				GLINT_SHADER_PATH,
				"%s uses the Scene3-only procedural glint" % path)
		var cycle_sec := float(material.get_shader_parameter("cycle_sec"))
		var phase := float(material.get_shader_parameter("phase_offset"))
		cycles.append(cycle_sec)
		phases.append(phase)
		assert_between(
				cycle_sec,
				8.0,
				14.0,
				"%s flashes only once every several seconds" % path)
		assert_between(
				float(material.get_shader_parameter("intensity")),
				0.32,
				0.68,
				"%s remains a restrained distant glint" % path)
		assert_lte(glint.size.x, 40.0, "%s stays spatially small" % path)
		assert_lte(glint.size.y, 40.0, "%s stays spatially small" % path)
	assert_gt(
			absf(phases[0] - phases[1]),
			0.1,
			"The two sword glints are visibly staggered")

	var glint_source := FileAccess.get_file_as_string(GLINT_SHADER_PATH)
	assert_true(
			glint_source.contains("fract(TIME / cycle_sec"),
			"Glints use a repeating low-frequency pulse")
	assert_true(
			glint_source.contains("pixel_grid"),
			"Glints keep a stepped pixel-art silhouette")


func test_flying_fish_schools_are_sparse_and_cloud_occluded() -> void:
	var stage := _stage()
	var paths := ["FlyingFishFar", "FlyingFishNear"]
	for path in paths:
		assert_true(stage.has_node(path), "%s exists" % path)
	if not stage.has_node(paths[0]) or not stage.has_node(paths[1]):
		return

	var far := stage.get_node(paths[0]) as Node2D
	var near := stage.get_node(paths[1]) as Node2D
	assert_eq(far.get_script().resource_path, FISH_SCRIPT_PATH)
	assert_eq(near.get_script().resource_path, FISH_SCRIPT_PATH)
	assert_lt(stage.get_node("CloudSeaBack").get_index(), far.get_index())
	assert_lt(far.get_index(), stage.get_node("CloudSeaMid").get_index())
	assert_lt(
			stage.get_node("CloudSeaFoundation").get_index(),
			near.get_index())
	assert_lt(near.get_index(), stage.get_node("MainChain").get_index())
	assert_lt(near.get_index(), stage.get_node("CloudSeaFront").get_index())
	assert_lt(
			float(far.get_meta("parallax_factor")),
			float(near.get_meta("parallax_factor")),
			"Far and near schools occupy distinct cloud depths")

	for school in [far, near]:
		assert_gte(
				float(school.get("interval_min_sec")),
				14.0,
				"Fish schools remain occasional ambient events")
		assert_lte(
				int(school.get("fish_count_max")),
				5,
				"A school cannot become a screen-filling swarm")
		assert_gte(
				int(school.get("fish_count_min")),
				3,
				"Each event still reads as a small school")
		assert_between(
				float(school.get("leap_duration_min")),
				1.8,
				2.0,
				"Winged fish remain airborne long enough to read their flap")
		assert_eq(
				int(school.call("get_pool_size")),
				12,
				"Each depth layer reuses a bounded sprite pool")
	assert_eq(int(far.get("fish_count_min")), 4)
	assert_eq(int(far.get("fish_count_max")), 5)
	assert_eq(int(near.get("fish_count_min")), 3)
	assert_eq(int(near.get("fish_count_max")), 4)
	assert_lte(
			int(far.get("fish_count_max")) + int(near.get("fish_count_max")),
			9,
			"The larger silhouettes are balanced by a smaller combined group")


func test_flying_fish_use_a_generated_pixel_atlas_and_parabolic_motion() -> void:
	var stage := _stage()
	if not stage.has_node("FlyingFishFar"):
		fail_test("FlyingFishFar exists")
		return

	var far := stage.get_node("FlyingFishFar") as Node2D
	assert_true(
			bool(far.call("trigger_school", 1)),
			"A deterministic preview can trigger one school")
	await get_tree().process_frame
	assert_between(
			int(far.call("get_active_fish_count")),
			4,
			5,
			"The far school allocates only its configured fish count")

	var source := FileAccess.get_file_as_string(FISH_SCRIPT_PATH)
	assert_true(
			source.contains("ImageTexture.create_from_image"),
			"Fish art is generated locally without a downloaded asset")
	assert_true(
			source.contains("4.0 * arc_height * t * (1.0 - t)"),
			"Fish use a true bounded leap arc")
	assert_true(
			source.contains("texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST"),
			"Generated fish retain nearest-neighbor pixel edges")
	assert_true(
			source.contains("_paint_wings"),
			"The generated atlas includes a dedicated wing silhouette")
	assert_true(
			source.contains("FRAME_COUNT := 4"),
			"Winged fish use a four-frame flap cycle")
	var first_fish := far.get_node("Fish00") as Sprite2D
	assert_eq(first_fish.hframes, 4)
	assert_eq(first_fish.texture.get_width() / first_fish.hframes, 24)
	assert_eq(first_fish.texture.get_height(), 16)


func test_scene3_richness_effects_do_not_leak_into_other_stages() -> void:
	var scene1_source := FileAccess.get_file_as_string(
			"res://src/ui/scenes/scene1.tscn")
	var scene2_source := FileAccess.get_file_as_string(
			"res://src/ui/scenes/scene2.tscn")
	for source in [scene1_source, scene2_source]:
		assert_false(source.contains("SunMotesFar"))
		assert_false(source.contains("SunMotesNear"))
		assert_false(source.contains("scene3_sword_glint"))
		assert_false(source.contains("FlyingFish"))
		assert_false(source.contains("scene3_flying_fish_school"))
