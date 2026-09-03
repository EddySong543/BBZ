extends GutTest

const SCENE2_PATH := "res://src/ui/scenes/scene2.tscn"
const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const SCENE2_PARTICLES: Array[NodePath] = [
	^"PollenFar", ^"ValleyDust", ^"GroundPollen", ^"PollenNear",
]
const SCENE9_PARTICLES: Array[NodePath] = [
	^"SilverMotesFar", ^"SilverValleyDust", ^"SilverGroundPollen",
	^"SilverMotesNear",
]


func test_scene9_replicates_scene2_four_layer_particle_language() -> void:
	var scene2 := (load(SCENE2_PATH) as PackedScene).instantiate() as BattleStage
	var scene9 := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(scene2)
	add_child_autofree(scene9)

	assert_null(scene9.get_node_or_null("SilverChaffAmbient"))
	assert_null(scene9.get_node_or_null("SilverChaffGust"))
	for index: int in SCENE9_PARTICLES.size():
		var reference := scene2.get_node_or_null(
				SCENE2_PARTICLES[index]) as GPUParticles2D
		var adapted := scene9.get_node_or_null(
				SCENE9_PARTICLES[index]) as GPUParticles2D
		assert_not_null(reference)
		assert_not_null(adapted)
		if reference == null or adapted == null:
			continue
		assert_eq(adapted.amount, reference.amount)
		assert_eq(adapted.lifetime, reference.lifetime)
		assert_eq(adapted.preprocess, reference.preprocess)
		assert_eq(adapted.explosiveness, reference.explosiveness)
		assert_eq(adapted.randomness, reference.randomness)
		assert_eq(adapted.local_coords, reference.local_coords)
		assert_eq(adapted.texture_filter, reference.texture_filter)
		assert_null(adapted.get_script(),
				"Scene2-style particles must not be replaced at runtime")
		assert_eq(adapted.texture.get_size(), Vector2(8, 8))

		var reference_process := \
				reference.process_material as ParticleProcessMaterial
		var adapted_process := \
				adapted.process_material as ParticleProcessMaterial
		assert_not_null(reference_process)
		assert_not_null(adapted_process)
		if reference_process == null or adapted_process == null:
			continue
		assert_eq(adapted_process.direction, reference_process.direction)
		assert_eq(adapted_process.spread, reference_process.spread)
		assert_eq(adapted_process.initial_velocity_min,
				reference_process.initial_velocity_min)
		assert_eq(adapted_process.initial_velocity_max,
				reference_process.initial_velocity_max)
		assert_eq(adapted_process.gravity, reference_process.gravity)
		assert_eq(adapted_process.scale_min, reference_process.scale_min)
		assert_eq(adapted_process.scale_max, reference_process.scale_max)
		assert_eq(adapted_process.turbulence_enabled,
				reference_process.turbulence_enabled)
		assert_eq(adapted_process.turbulence_noise_strength,
				reference_process.turbulence_noise_strength)
		assert_eq(adapted_process.turbulence_noise_scale,
				reference_process.turbulence_noise_scale)


func test_scene9_particle_layers_are_palette_and_depth_adapted() -> void:
	var scene9 := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(scene9)
	var layers: Array[GPUParticles2D] = []
	for node_name: NodePath in SCENE9_PARTICLES:
		layers.append(scene9.get_node(node_name) as GPUParticles2D)

	var far := layers[0]
	var valley := layers[1]
	var ground := layers[2]
	var near := layers[3]
	assert_lt(scene9.get_node("DistantLeft").get_index(), far.get_index())
	assert_lt(far.get_index(), valley.get_index())
	assert_lt(valley.get_index(), scene9.get_node("ForegroundMid").get_index())
	assert_lt(scene9.get_node("ForegroundMid").get_index(), ground.get_index())
	assert_lt(ground.get_index(), near.get_index())
	assert_lt(near.get_index(), scene9.get_node("ForegroundLeft").get_index())
	assert_lt(float(far.get_meta("parallax_factor")),
			float(valley.get_meta("parallax_factor")))
	assert_lt(float(valley.get_meta("parallax_factor")),
			float(ground.get_meta("parallax_factor")))
	assert_lt(float(ground.get_meta("parallax_factor")),
			float(near.get_meta("parallax_factor")))

	for layer: GPUParticles2D in layers:
		assert_true(layer.emitting)
		assert_true(layer.local_coords)
		assert_true(layer.texture is GradientTexture2D)
		var process := layer.process_material as ParticleProcessMaterial
		assert_gt(process.color.b, process.color.r,
				"Scene9 adaptation must stay cool silver-blue, not Scene2 pink")
		assert_between(process.color.a, 0.25, 0.41)

	assert_eq(far.position, Vector2(960, 455))
	assert_eq(valley.position, Vector2(960, 400))
	assert_eq(ground.position, Vector2(960, 755))
	assert_eq(near.position, Vector2(960, 860))
	assert_eq((far.process_material as ParticleProcessMaterial).emission_box_extents,
			Vector3(900, 130, 1))
	assert_eq((ground.process_material as ParticleProcessMaterial).emission_box_extents,
			Vector3(920, 120, 1))


func test_scene9_uses_scene2_radial_texture_instead_of_hard_dots() -> void:
	var scene9 := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(scene9)
	var texture := (scene9.get_node("SilverMotesFar") as GPUParticles2D).texture
	assert_true(texture is GradientTexture2D)
	var image := texture.get_image()
	assert_not_null(image)
	if image == null:
		return
	assert_eq(image.get_size(), Vector2i(8, 8))
	var center_alpha := image.get_pixel(4, 4).a
	var mid_alpha := image.get_pixel(6, 4).a
	var edge_alpha := image.get_pixel(7, 4).a
	assert_gte(center_alpha, 0.9)
	assert_between(mid_alpha, 0.2, 0.9)
	assert_lte(edge_alpha, 0.08)
	assert_gt(center_alpha, mid_alpha)
	assert_gt(mid_alpha, edge_alpha)
