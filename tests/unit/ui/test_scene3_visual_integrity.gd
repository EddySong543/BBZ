extends GutTest

const SCENE3 := preload("res://src/ui/scenes/scene3.tscn")
const BATTLE_SCREEN3 := preload("res://src/ui/battle_screen3.tscn")
const CLOUD_FLOOR_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_cloud_floor.gdshader")
const DISTANT_MOUNTAIN_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_distant_mountain_grade.gdshader")
const CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_character_light.gdshader")
const SUN_GRADE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_sun_grade.gdshader")
const SUN_HALO_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene3_sun_halo.gdshader")


func _stage() -> Control:
	var stage := SCENE3.instantiate() as Control
	add_child_autofree(stage)
	return stage


func test_cloud_floor_seals_the_bottom_without_covering_the_battle_plane() -> void:
	var stage := _stage()
	assert_true(stage.has_node("CloudSeaFoundation"))
	if not stage.has_node("CloudSeaFoundation"):
		return

	var floor := stage.get_node("CloudSeaFoundation") as ColorRect
	var material := floor.material as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.shader.resource_path, CLOUD_FLOOR_SHADER_PATH)
	assert_lt(
			stage.get_node("CloudSeaMid").get_index(),
			floor.get_index(),
			"The opaque cloud foundation sits behind the battle plane")
	assert_lt(
			floor.get_index(),
			stage.get_node("MainChain").get_index(),
			"The cloud foundation cannot cover the main chain")
	assert_lte(floor.position.x, 0.0)
	assert_gte(floor.position.x + floor.size.x, 1920.0)
	assert_gte(floor.position.y + floor.size.y, 1080.0)
	assert_gte(
			float(material.get_shader_parameter("bottom_alpha")),
			0.99,
			"The lower viewport boundary stays opaque during cloud motion")

	var shader_source := FileAccess.get_file_as_string(
			CLOUD_FLOOR_SHADER_PATH)
	assert_true(shader_source.contains("bottom_alpha"))
	assert_true(shader_source.contains("coverage"))


func test_distant_mountains_remove_pale_source_fringe_without_a_bright_rim() -> void:
	var stage := _stage()
	for path in ["DistantMountainRangeMid", "DistantMountainRangeNear"]:
		var mountain := stage.get_node(path) as TextureRect
		var material := mountain.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(
				material.shader.resource_path,
				DISTANT_MOUNTAIN_SHADER_PATH,
				"%s uses the Scene3-only edge cleanup" % path)
		if material.shader.resource_path != DISTANT_MOUNTAIN_SHADER_PATH:
			continue
		assert_gte(
				float(material.get_shader_parameter("edge_cleanup_strength")),
				0.7,
				"%s decisively removes the pale source fringe" % path)
		assert_lte(
				float(material.get_shader_parameter("edge_alpha_cutoff")),
				0.25,
				"%s keeps the mountain silhouette while cleaning its fringe"
						% path)
		assert_gte(
				float(material.get_shader_parameter("edge_erode_strength")),
				0.8,
				"%s removes the contaminated texel instead of recoloring an outline"
						% path)
		assert_lte(
				float(material.get_shader_parameter("edge_tint_strength")),
				0.2,
				"%s does not replace the white fringe with a dark fringe" % path)
		assert_eq(
				float(material.get_shader_parameter("receiver_rim_strength")),
				0.0,
				"%s does not redraw a white silhouette" % path)

	var shader_source := FileAccess.get_file_as_string(
			DISTANT_MOUNTAIN_SHADER_PATH)
	assert_true(shader_source.contains("inner_rgb"))
	assert_true(shader_source.contains("edge_contamination"))


func test_scene3_characters_use_opposed_dawn_light_and_cloud_fill() -> void:
	var battle := BATTLE_SCREEN3.instantiate() as Control
	var p1_display := battle.get_node("P1CharDisplay") as CharacterDisplay
	var p2_display := battle.get_node("P2CharDisplay") as CharacterDisplay
	assert_true(
			p2_display.flip_h,
			"P2 mirrors the Scene3 light direction as well as the sprite")
	for display in [p1_display, p2_display]:
		assert_lte(
				display.rim_strength,
				0.12,
				"Dawn light must not become a separate brown character outline")
		assert_gte(
				display.rim_color.b,
				0.8,
				"The remaining edge light stays pale rather than brown")
		assert_almost_eq(
				display.position.y,
				258.0,
				0.1,
				"Scene3 keeps the authored fighter baseline and lowers the chain")
	assert_almost_eq(
			p1_display.position.x,
			92.0,
			0.1,
			"Scene3 preserves the authored P1 horizontal adjustment")
	assert_almost_eq(
			p1_display.position.y,
			p2_display.position.y,
			0.1,
			"Both fighters share one chain contact baseline")

	var directions: Array[Vector2] = []
	for path in [
		"P1CharDisplay/SubViewport/AnimatedSprite2D",
		"P2CharDisplay/SubViewport/AnimatedSprite2D",
	]:
		var sprite := battle.get_node(path) as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		assert_eq(material.shader.resource_path, CHARACTER_SHADER_PATH)
		if material.shader.resource_path != CHARACTER_SHADER_PATH:
			continue
		assert_gte(
				float(material.get_shader_parameter("source_saturation")),
				1.0,
				"Scene3 light keeps authored costume color separation")
		assert_between(
				float(material.get_shader_parameter("cloud_bounce_amount")),
				0.02,
				0.1,
				"Cloud bounce lifts dark lower pixels without washing the sprite")
		directions.append(
				material.get_shader_parameter("light_dir") as Vector2)
	if directions.size() == 2:
		assert_gt(directions[0].x, 0.0, "P1 receives sun from the screen center")
		assert_lt(directions[1].x, 0.0, "P2 receives sun from the screen center")
		assert_gt(directions[0].y, 0.0, "The low sun lights the inward lower edge")
		assert_gt(directions[1].y, 0.0, "The low sun lights the inward lower edge")

	var post_fx := battle.get_node("PostFX") as ColorRect
	var post_material := post_fx.material as ShaderMaterial
	assert_gte(
			float(post_material.get_shader_parameter("saturation")),
			1.0,
			"Scene3 post grade keeps character palette separation")
	assert_lte(
			float(post_material.get_shader_parameter("split_strength")),
			0.1,
			"Full-screen split toning does not overpower character materials")
	battle.free()


func test_chain_contact_moves_with_the_lowered_main_chain() -> void:
	var stage := _stage()
	var main_chain := stage.get_node("MainChain") as TextureRect
	var occluder := stage.get_node("ChainFootOccluder") as TextureRect
	var material := occluder.material as ShaderMaterial
	assert_not_null(material)
	assert_almost_eq(
			main_chain.position.y,
			592.0,
			0.1,
			"Only the playable chain is lowered by twenty pixels")
	assert_eq(
			occluder.position,
			main_chain.position,
			"The narrow foreground lip follows the lowered chain exactly")
	assert_eq(
			occluder.size,
			main_chain.size,
			"The foreground lip keeps the playable chain geometry")
	assert_lte(
			float(material.get_shader_parameter("foot_half_width")),
			0.045,
			"The foreground chain lip stays under the shoes, not the whole body")
	assert_lte(
			float(material.get_shader_parameter("foot_feather")),
			0.015,
			"The chain lip cannot spread into a broad character-cutting band")
	assert_between(
			float(material.get_shader_parameter("alpha_scale")),
			0.78,
			0.94,
			"The contact lip remains readable without looking pasted on")

	var battle := BATTLE_SCREEN3.instantiate() as Control
	for path in ["P1Shadow", "P2Shadow"]:
		var shadow := battle.get_node(path) as TextureRect
		assert_almost_eq(
				shadow.position.y,
				740.0,
				0.1,
				"%s follows the lowered chain surface" % path)
	battle.free()


func test_sun_has_visible_bloom_and_low_frequency_living_light() -> void:
	var stage := _stage()
	var sun := stage.get_node("DawnSun") as TextureRect
	var sun_material := sun.material as ShaderMaterial
	assert_eq(sun_material.shader.resource_path, SUN_GRADE_SHADER_PATH)
	if sun_material.get_shader_parameter("pulse_cycle_sec") == null:
		fail_test("The Scene3 sun disc exposes a low-frequency pulse")
		return
	assert_between(
			float(sun_material.get_shader_parameter("pulse_cycle_sec")),
			5.0,
			12.0,
			"The disc breathes slowly instead of flickering")
	assert_between(
			float(sun_material.get_shader_parameter("pulse_amount")),
			0.03,
			0.14,
			"The disc animation remains visible but restrained")

	var halo := stage.get_node("SunHalo") as ColorRect
	var halo_material := halo.material as ShaderMaterial
	assert_eq(halo_material.shader.resource_path, SUN_HALO_SHADER_PATH)
	assert_gte(
			float(halo_material.get_shader_parameter("corona_intensity")),
			0.16,
			"The sun emits a visible animated corona without thickening the disc")
	var total_emission := (
			float(halo_material.get_shader_parameter("core_intensity"))
			+ float(halo_material.get_shader_parameter("corona_intensity"))
			+ float(halo_material.get_shader_parameter("glow_intensity")))
	assert_gte(
			total_emission,
			0.38,
			"The layered halo is visibly brighter than the previous flat disc")
	assert_between(
			float(halo_material.get_shader_parameter("breath_cycle_sec")),
			5.0,
			12.0,
			"The halo expands and contracts at a low frequency")

	var halo_source := FileAccess.get_file_as_string(SUN_HALO_SHADER_PATH)
	assert_true(halo_source.contains("corona"))
	assert_true(halo_source.contains("breath_cycle_sec"))


func test_cloud_sea_has_no_rejected_interlayer_sunlight() -> void:
	var stage := _stage()
	assert_false(stage.has_node("CloudLightBackMid"))
	assert_false(stage.has_node("CloudLightMidFront"))
	var scene_source := FileAccess.get_file_as_string(
			"res://src/ui/scenes/scene3.tscn")
	assert_false(scene_source.contains("scene3_cloud_interlayer_light"))
	assert_false(scene_source.contains("gap_ray_rim_strength"))
	var cloud_shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_env_scene3_cloud_sea.gdshader")
	assert_false(cloud_shader_source.contains("gap_ray_receiver_field"))
	assert_false(cloud_shader_source.contains("gap_ray_rim_strength"))
