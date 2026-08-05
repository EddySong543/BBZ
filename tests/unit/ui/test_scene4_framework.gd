extends GutTest

const SCENE4_PATH := "res://src/ui/scenes/scene4.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE4_PATH := "res://src/ui/battle_screen4.tscn"
const SKY_TEXTURE_PATH := "res://assets/scenes/scene4/scene4_sky.png"
const FAR_FOREST_PATH := "res://assets/scenes/scene4/scene4_far_forest.png"
const BACKGROUND_TOP_LEAVES_PATH := "res://assets/scenes/scene4/scene4_background_top_leaves.png"
const BACKGROUND_TREE_PATH := "res://assets/scenes/scene4/scene4_background_tree.png"
const BACKGROUND_TREE_2_PATH := "res://assets/scenes/scene4/scene4_background_tree_2.png"
const BATTLE_PLATFORM_PATH := "res://assets/scenes/scene4/scene4_battle_platform.png"
const LEFT_TREE_PATH := "res://assets/scenes/scene4/scene4_foreground_left_tree.png"
const RIGHT_TREE_PATH := "res://assets/scenes/scene4/scene4_foreground_right_tree.png"
const TOP_LEAVES_PATH := "res://assets/scenes/scene4/scene4_top_leaves.png"
const RUIN_STONE_1_PATH := "res://assets/scenes/scene4/scene4_midground_ruin_stone_1.png"
const RUIN_STONE_2_PATH := "res://assets/scenes/scene4/scene4_midground_ruin_stone_2.png"
const SKY_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_sky_grade.gdshader"
const DEPTH_GRADE_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_depth_grade.gdshader"
const RELIC_GLOW_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_relic_glow.gdshader"
const CANOPY_SHAFTS_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_canopy_shafts.gdshader"
const MIDGROUND_MIST_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_midground_mist.gdshader"
const MOTE_SYNC_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_mote_sync.gdshader"
const FOREGROUND_FOG_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_foreground_fog.gdshader"
const CHARACTER_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_character_light.gdshader"
const SHADOW_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_root_contact_shadow.gdshader"
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"


func test_scene4_has_an_independent_shared_battle_entry() -> void:
	BattleSetup.reset()
	var battle_source := FileAccess.get_file_as_string(BATTLE4_PATH)
	var screen := (load(BATTLE4_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(ResourceLoader.exists(SCENE4_PATH))
	assert_true(ResourceLoader.exists(BATTLE4_PATH))
	assert_true(battle_source.contains(BATTLE_BASE_PATH))
	assert_false(battle_source.contains('parent="StageSlot/Stage"'))
	assert_false(battle_source.contains('[editable path="StageSlot/Stage"]'))
	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE4_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_not_null(screen.get_node_or_null("WorldGroup"))
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	assert_true(screen.has_node("P1Hud"))
	assert_true(screen.has_node("P2Hud"))
	assert_true(screen.has_node("Buttons"))
	assert_true(screen.has_node("DeathSwitchOverlay"))
	BattleSetup.reset()


func test_scene4_exposes_nearest_filtered_flat_parallax_layers() -> void:
	var scene_source := FileAccess.get_file_as_string(SCENE4_PATH)
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var layer_contract: Dictionary[String, float] = {
		"Sky": 0.0,
		"FarForest": 0.05,
		"BackgroundTopLeaves": 0.08,
		"BackgroundTree2": 0.1,
		"BackgroundTree": 0.22,
		"CanopyLightShafts": 0.32,
		"RuinStone1": 0.46,
		"RuinStone3": 0.46,
		"RuinStone4": 0.46,
		"RuinStone2": 0.52,
		"CanopyMotes": 0.58,
		"MidgroundMist": 0.7,
		"RuinMotes1": 0.46,
		"RuinMotes2": 0.52,
		"RuinMotes3": 0.46,
		"RuinMotes4": 0.46,
		"BattlePlatform": 1.0,
		"LeftTree": 1.2,
		"RightTree": 1.2,
		"TopLeaves": 1.25,
		"ForegroundMotes": 1.5,
		"ForegroundFog": 1.58,
	}
	for node_name: String in layer_contract:
		var layer := stage.get_node(node_name) as CanvasItem
		assert_not_null(layer)
		assert_eq(layer.get_parent(), stage)
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(float(layer.get_meta("parallax_factor")), layer_contract[node_name])
		if layer is Control:
			assert_eq((layer as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)

	assert_lt(stage.get_node("Sky").get_index(),
			stage.get_node("FarForest").get_index())
	assert_lt(stage.get_node("FarForest").get_index(),
			stage.get_node("BackgroundTree2").get_index())
	assert_lt(stage.get_node("BackgroundTree2").get_index(),
			stage.get_node("BackgroundTree").get_index())
	assert_lt(stage.get_node("BackgroundTree").get_index(),
			stage.get_node("BackgroundTopLeaves").get_index())
	assert_lt(stage.get_node("BackgroundTopLeaves").get_index(),
			stage.get_node("CanopyLightShafts").get_index())
	assert_lt(stage.get_node("CanopyLightShafts").get_index(),
			stage.get_node("MidgroundMist").get_index())
	assert_lt(stage.get_node("MidgroundMist").get_index(),
			stage.get_node("CanopyMotes").get_index())
	assert_lt(stage.get_node("FarForest").get_index(),
			stage.get_node("RuinStone1").get_index())
	assert_lt(stage.get_node("RuinStone1").get_index(),
			stage.get_node("RuinStone2").get_index())
	assert_lt(stage.get_node("RuinStone2").get_index(),
			stage.get_node("RuinStone3").get_index())
	assert_lt(stage.get_node("CanopyLightShafts").get_index(),
			stage.get_node("CanopyMotes").get_index())
	assert_lt(stage.get_node("TopLeaves").get_index(),
			stage.get_node("ForegroundMotes").get_index())
	assert_lt(stage.get_node("ForegroundMotes").get_index(),
			stage.get_node("ForegroundFog").get_index())

	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"))
	for removed_foreground: String in ["NearCenter", "NearLeft", "NearRight"]:
		assert_false(stage.has_node(removed_foreground))

	assert_true(scene_source.contains(SKY_SHADER_PATH))
	assert_true(scene_source.contains(DEPTH_GRADE_SHADER_PATH))
	assert_true(scene_source.contains(RELIC_GLOW_SHADER_PATH))
	assert_true(scene_source.contains(CANOPY_SHAFTS_SHADER_PATH))
	assert_true(scene_source.contains(MIDGROUND_MIST_SHADER_PATH))
	assert_true(scene_source.contains(MOTE_SYNC_SHADER_PATH))
	assert_true(scene_source.contains(FOREGROUND_FOG_SHADER_PATH))
	assert_false(scene_source.contains("canvas_env_scene4_canopy_sky"))
	assert_false(scene_source.contains("canvas_env_stars"))
	assert_false(scene_source.contains("canvas_env_moon"))
	assert_false(scene_source.contains("res://assets/import/"))
	assert_false(scene_source.contains("generated_images"))


func test_scene4_connects_formal_tree_assets_to_expected_layers() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var expected_assets: Dictionary[String, String] = {
		"Sky": SKY_TEXTURE_PATH,
		"FarForest": FAR_FOREST_PATH,
		"BackgroundTopLeaves": BACKGROUND_TOP_LEAVES_PATH,
		"BackgroundTree": BACKGROUND_TREE_PATH,
		"BackgroundTree2": BACKGROUND_TREE_2_PATH,
		"BattlePlatform": BATTLE_PLATFORM_PATH,
		"LeftTree": LEFT_TREE_PATH,
		"RightTree": RIGHT_TREE_PATH,
		"TopLeaves": TOP_LEAVES_PATH,
		"RuinStone1": RUIN_STONE_1_PATH,
		"RuinStone2": RUIN_STONE_2_PATH,
		"RuinStone3": RUIN_STONE_1_PATH,
		"RuinStone4": RUIN_STONE_1_PATH,
	}
	for node_path: String in expected_assets:
		var art := stage.get_node(node_path) as TextureRect
		assert_not_null(art)
		assert_not_null(art.texture)
		assert_eq(art.texture.resource_path, expected_assets[node_path])
		assert_eq(art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	assert_eq((stage.get_node("BackgroundTree") as Control).scale,
			Vector2(3.4, 3.4))
	assert_eq((stage.get_node("BackgroundTree2") as Control).scale,
			Vector2(4.2, 4.2))
	assert_eq((stage.get_node("FarForest") as Control).scale,
			Vector2(8.0, 8.0))
	assert_eq((stage.get_node("BackgroundTopLeaves") as Control).scale,
			Vector2(4.2, 4.2))
	assert_eq((stage.get_node("BattlePlatform") as Control).scale,
			Vector2(6.0, 6.0))
	assert_eq((stage.get_node("LeftTree") as Control).scale,
			Vector2(4.0, 4.0))
	assert_eq((stage.get_node("RightTree") as Control).scale,
			Vector2(4.0, 4.0))
	assert_eq((stage.get_node("RuinStone1") as Control).scale,
			Vector2(2.5, 2.5))
	assert_eq((stage.get_node("RuinStone2") as Control).scale,
			Vector2(2.5, 2.5))


func test_scene4_grades_every_environment_asset_by_depth_role() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var depth_layers: Array[String] = [
		"FarForest",
		"BackgroundTopLeaves",
		"BackgroundTree",
		"BackgroundTree2",
		"BattlePlatform",
		"LeftTree",
		"RightTree",
		"TopLeaves",
	]
	for node_name: String in depth_layers:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		assert_not_null(material.shader)
		assert_eq(material.shader.resource_path, DEPTH_GRADE_SHADER_PATH)
		assert_lte(float(material.get_shader_parameter("brightness")), 0.9)
		assert_lte(float(material.get_shader_parameter("saturation")), 0.8)
		assert_gte(float(material.get_shader_parameter("palette_strength")), 0.65)
		var palette_mid := material.get_shader_parameter("palette_mid") as Color
		assert_gt(palette_mid.g, palette_mid.b)
		assert_gt(palette_mid.b, palette_mid.r)

	var far_forest_material := (
			stage.get_node("FarForest") as TextureRect
	).material as ShaderMaterial
	assert_lte(float(far_forest_material.get_shader_parameter("contrast")), 0.7)
	assert_gte(float(far_forest_material.get_shader_parameter("haze_strength")), 0.3)

	var tree2_material := (
			stage.get_node("BackgroundTree2") as TextureRect
	).material as ShaderMaterial
	assert_lte(float(tree2_material.get_shader_parameter("brightness")), 0.78)
	assert_lte(float(tree2_material.get_shader_parameter("contrast")), 0.8)
	assert_gte(float(tree2_material.get_shader_parameter("haze_strength")), 0.2)

	var sky_material := (
			stage.get_node("Sky") as TextureRect
	).material as ShaderMaterial
	var sky_mid := sky_material.get_shader_parameter("mid_color") as Color
	var sky_light := sky_material.get_shader_parameter("light_color") as Color
	assert_gt(sky_mid.g, sky_mid.r)
	assert_gt(sky_mid.g, sky_mid.b)
	assert_gt(sky_light.get_luminance(), sky_mid.get_luminance())

	var shared_relic_energy_color := Color(0.604, 0.682, 0.725, 1)
	for stone_name: String in [
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]:
		var stone := stage.get_node(stone_name) as TextureRect
		var stone_material := stone.material as ShaderMaterial
		assert_not_null(stone_material)
		assert_eq(stone_material.shader.resource_path, RELIC_GLOW_SHADER_PATH)
		assert_between(
				float(stone_material.get_shader_parameter("glow_strength")),
				0.53,
				0.58)
		assert_between(
				float(stone_material.get_shader_parameter("exposure")),
				0.83,
				0.88)
		assert_between(
				float(stone_material.get_shader_parameter("palette_strength")),
				0.89,
				0.93)
		assert_eq(
				stone_material.get_shader_parameter("rune_color"),
				shared_relic_energy_color)
		assert_almost_eq(stone.modulate.a, 0.76, 0.001)
		assert_lte(
				float(stone_material.get_shader_parameter("rune_threshold")),
				0.07)
		assert_lte(
				float(stone_material.get_shader_parameter("pulse_speed")),
				0.11)
		assert_between(
				float(stone_material.get_shader_parameter("circuit_width_px")),
				0.1,
				0.15)
		assert_between(
				float(stone_material.get_shader_parameter("circuit_tail")),
				0.33,
				0.41)
		assert_between(
				float(stone_material.get_shader_parameter("base_charge")),
				0.14,
				0.19)
		assert_eq(
				float(stone_material.get_shader_parameter(
						"energy_pixel_size_px")),
				1.0)
		assert_between(
				float(stone_material.get_shader_parameter("motion_feather")),
				0.05,
				0.07)
		assert_true(stone_material.shader.code.contains("hash11"))
		assert_true(stone_material.shader.code.contains("vertical_segment"))
		assert_true(stone_material.shader.code.contains("horizontal_segment"))
		assert_true(stone_material.shader.code.contains("snapped_x"))
		assert_true(stone_material.shader.code.contains("snapped_y"))
		assert_true(stone_material.shader.code.contains("path_a_progress"))
		assert_true(stone_material.shader.code.contains("energy_pixel_size"))
		assert_true(stone_material.shader.code.contains("front_fade_a"))
		assert_true(stone_material.shader.code.contains("interior_gate"))
		assert_true(stone_material.shader.code.contains("groove_color"))
		assert_false(stone_material.shader.code.contains("color +="))
		assert_false(stone_material.shader.code.contains("vertical_filament"))

	var shafts := stage.get_node("CanopyLightShafts") as ColorRect
	var shafts_material := shafts.material as ShaderMaterial
	assert_not_null(shafts_material)
	assert_eq(shafts_material.shader.resource_path, CANOPY_SHAFTS_SHADER_PATH)
	assert_between(
			float(shafts_material.get_shader_parameter("beam_strength")),
			0.16,
			0.22)
	assert_true(shafts_material.shader.code.contains("slow_gate"))

	assert_false(stage.has_node("RuinStone2BranchOccluder"))

	var top_leaves := stage.get_node("TopLeaves") as TextureRect
	var top_leaves_material := top_leaves.material as ShaderMaterial
	assert_gte(
			float(top_leaves_material.get_shader_parameter("contrast")),
			1.06)
	assert_gte(
			float(top_leaves_material.get_shader_parameter(
					"alpha_cleanup_threshold")),
			0.18)
	assert_lte(
			float(top_leaves_material.get_shader_parameter(
					"sway_blend_strength")),
			0.24)
	assert_lte(
			float(top_leaves_material.get_shader_parameter(
					"sway_depth_influence")),
			0.4)
	assert_gte(top_leaves.modulate.a, 0.86)
	assert_between(
			float(top_leaves_material.get_shader_parameter("brightness")),
			0.7,
			0.74)
	assert_lte(
			float(top_leaves_material.get_shader_parameter("palette_strength")),
			0.76)

	var sway_speeds: Array[float] = []
	for moving_layer: String in [
		"BackgroundTopLeaves",
		"TopLeaves",
	]:
		var moving_material := (
				stage.get_node(moving_layer) as TextureRect
		).material as ShaderMaterial
		assert_gte(
				float(moving_material.get_shader_parameter("sway_strength_px")),
				2.0)
		sway_speeds.append(
				float(moving_material.get_shader_parameter("sway_speed")))
	assert_ne(sway_speeds[0], sway_speeds[1])
	assert_false((
			stage.get_node("LeftTree") as TextureRect
	).material.shader.code.contains("stepped_time"))
	assert_eq(float((
			stage.get_node("LeftTree") as TextureRect
	).material.get_shader_parameter("sway_strength_px")), 0.0)
	var right_material := (
			stage.get_node("RightTree") as TextureRect
	).material as ShaderMaterial
	assert_eq(float(right_material.get_shader_parameter("sway_strength_px")), 0.0)
	var left_material := (
			stage.get_node("LeftTree") as TextureRect
	).material as ShaderMaterial
	assert_between(
			float(left_material.get_shader_parameter("brightness")),
			0.8,
			0.84)
	assert_between(
			float(right_material.get_shader_parameter("brightness")),
			0.79,
			0.83)


func test_scene4_guides_keep_the_mature_character_baseline() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)

	assert_eq((stage.get_node("CompositionGuides/P1Baseline") as Marker2D).position,
			Vector2(480.0, 748.0))
	assert_eq((stage.get_node("CompositionGuides/P2Baseline") as Marker2D).position,
			Vector2(1440.0, 748.0))
	assert_eq((stage.get_node("CompositionGuides/PlatformBaseline") as Marker2D).position,
			Vector2(960.0, 748.0))
	assert_eq(float(stage.get_node("BattlePlatform").get_meta("parallax_factor")), 1.0)


func test_scene4_owns_authored_sky_grade_and_forest_motes() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var sky := stage.get_node("Sky") as TextureRect
	var sky_material := sky.material as ShaderMaterial
	assert_not_null(sky_material)
	assert_eq(sky_material.shader.resource_path, SKY_SHADER_PATH)
	assert_eq(sky.texture.resource_path, SKY_TEXTURE_PATH)

	var motes := stage.get_node("CanopyMotes") as GPUParticles2D
	var mote_process := motes.process_material as ParticleProcessMaterial
	var mote_sync := motes.material as ShaderMaterial
	assert_not_null(motes)
	assert_true(motes.emitting)
	assert_between(motes.amount, 26, 34)
	assert_gte(motes.randomness, 0.75)
	assert_eq(motes.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_not_null(mote_process)
	assert_not_null(mote_sync)
	assert_eq(mote_sync.shader.resource_path, MOTE_SYNC_SHADER_PATH)
	assert_gte(
			float(mote_sync.get_shader_parameter("shaft_response")),
			0.75)
	assert_eq(
			float(mote_sync.get_shader_parameter("relic_response")),
			0.0)
	assert_lt(mote_process.color.b, mote_process.color.g)
	assert_gte(mote_process.color.a, 0.57)

	var mist := stage.get_node("MidgroundMist") as ColorRect
	var mist_material := mist.material as ShaderMaterial
	assert_not_null(mist_material)
	assert_eq(mist_material.shader.resource_path, MIDGROUND_MIST_SHADER_PATH)
	assert_between(
			float(mist_material.get_shader_parameter("mist_strength")),
			0.06,
			0.08)
	assert_lte(
			float(mist_material.get_shader_parameter("band_half_width")),
			0.09)
	assert_true(mist_material.shader.code.contains("value_noise"))
	assert_true(mist_material.shader.code.contains("pixel_grid"))

	for ruin_mote_name: String in [
		"RuinMotes1",
		"RuinMotes2",
		"RuinMotes3",
		"RuinMotes4",
	]:
		var ruin_motes := stage.get_node(ruin_mote_name) as GPUParticles2D
		var ruin_sync := ruin_motes.material as ShaderMaterial
		var ruin_process := (
				ruin_motes.process_material as ParticleProcessMaterial
		)
		assert_true(ruin_motes.emitting)
		assert_between(ruin_motes.amount, 5, 7)
		assert_eq(ruin_sync.shader.resource_path, MOTE_SYNC_SHADER_PATH)
		assert_eq(
				float(ruin_sync.get_shader_parameter("relic_response")),
				1.0)
		assert_gte(
				float(ruin_sync.get_shader_parameter("shaft_response")),
				0.6)
		assert_eq(
				ruin_sync.get_shader_parameter("mote_tint"),
				Color(0.604, 0.682, 0.725, 0.9))
		assert_lte(ruin_process.scale_max, 1.0)
		assert_true(ruin_sync.shader.code.contains("relic_active"))

	var foreground_fog := stage.get_node("ForegroundFog") as ColorRect
	var foreground_fog_material := foreground_fog.material as ShaderMaterial
	assert_not_null(foreground_fog_material)
	assert_eq(
			foreground_fog_material.shader.resource_path,
			FOREGROUND_FOG_SHADER_PATH)
	assert_between(
			float(foreground_fog_material.get_shader_parameter("alpha_max")),
			0.3,
			0.38)
	assert_between(
			float(foreground_fog_material.get_shader_parameter("drift_speed")),
			0.02,
			0.03)
	assert_gte(
			float(foreground_fog_material.get_shader_parameter("scale_x")),
			2.3)
	var foreground_fog_color := (
			foreground_fog_material.get_shader_parameter("fog_color") as Color
	)
	assert_gt(foreground_fog_color.g, foreground_fog_color.r)
	assert_gt(foreground_fog_color.g, foreground_fog_color.b)
	assert_gte(foreground_fog.offset_top, 760.0)
	assert_lte(foreground_fog.offset_top, 800.0)
	assert_gte(foreground_fog.offset_bottom, 1080.0)
	assert_true(foreground_fog_material.shader.code.contains("pixel_grid"))
	assert_true(foreground_fog_material.shader.code.contains("crest_band"))

	assert_false(stage.has_node("LeafDrift"))
	var foreground_motes := stage.get_node("ForegroundMotes") as GPUParticles2D
	var foreground_process := (
			foreground_motes.process_material as ParticleProcessMaterial
	)
	var foreground_blend := (
			foreground_motes.material as CanvasItemMaterial
	)
	assert_true(foreground_motes.emitting)
	assert_between(foreground_motes.amount, 10, 18)
	assert_eq(
			foreground_blend.blend_mode,
			CanvasItemMaterial.BLEND_MODE_ADD)
	assert_gte(foreground_process.scale_min, 1.5)
	assert_lte(foreground_process.color.b, foreground_process.color.g)

	for removed_foreground: String in ["NearCenter", "NearLeft", "NearRight"]:
		assert_false(stage.has_node(removed_foreground))


func test_scene4_reuses_character_geometry_but_owns_environment_materials() -> void:
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE4_PATH) as PackedScene).instantiate()
	for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var base_node := base.get_node(node_name) as Control
		var scene4_node := screen.get_node(node_name) as Control
		assert_eq(scene4_node.position, base_node.position)
		assert_eq(scene4_node.size, base_node.size)

	var light_directions: Array[Vector2] = []
	var scene_exposures: Array[float] = []
	var flash_peaks: Array[float] = []
	var rim_peaks: Array[float] = []
	for side: String in ["P1", "P2"]:
		var sprite_path := "%sCharDisplay/SubViewport/AnimatedSprite2D" % side
		var scene4_sprite := screen.get_node(sprite_path) as AnimatedSprite2D
		var material := scene4_sprite.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, CHARACTER_SHADER_PATH)
		assert_lte(float(material.get_shader_parameter("rim_strength")), 0.1)
		assert_lte(float(material.get_shader_parameter("fill_amount")), 0.04)
		assert_gte(float(material.get_shader_parameter("backlight")), 0.25)
		assert_between(
				float(material.get_shader_parameter("forest_ambient_amount")),
				0.36,
				0.45)
		assert_lte(float(material.get_shader_parameter("scene_exposure")), 0.85)
		assert_lte(float(material.get_shader_parameter("flash_peak_strength")), 0.3)
		assert_lte(float(material.get_shader_parameter("flash_dark_response")), 0.5)
		assert_lte(float(material.get_shader_parameter("rim_peak_strength")), 0.25)
		var flash_color := material.get_shader_parameter("flash_color") as Color
		assert_lte(maxf(flash_color.r, maxf(flash_color.g, flash_color.b)), 0.85)
		var forest_color := material.get_shader_parameter("forest_ambient_color") as Color
		assert_gt(forest_color.g, forest_color.r)
		assert_gt(forest_color.g, forest_color.b)
		light_directions.append(material.get_shader_parameter("light_dir") as Vector2)
		scene_exposures.append(
				float(material.get_shader_parameter("scene_exposure")))
		flash_peaks.append(
				float(material.get_shader_parameter("flash_peak_strength")))
		rim_peaks.append(
				float(material.get_shader_parameter("rim_peak_strength")))

	assert_gt(light_directions[0].x, 0.0)
	assert_lt(light_directions[1].x, 0.0)
	assert_eq(scene_exposures[0], scene_exposures[1])
	assert_eq(flash_peaks[0], flash_peaks[1])
	assert_eq(rim_peaks[0], rim_peaks[1])

	for shadow_name: String in ["P1Shadow", "P2Shadow"]:
		var shadow := screen.get_node(shadow_name) as TextureRect
		var shadow_material := shadow.material as ShaderMaterial
		assert_not_null(shadow_material)
		assert_eq(shadow_material.shader.resource_path, SHADOW_SHADER_PATH)
		assert_eq(shadow.rotation, 0.0)

	var post_fx := screen.get_node("PostFX") as ColorRect
	var post_material := post_fx.material as ShaderMaterial
	assert_not_null(post_material)
	assert_eq(post_material.shader.resource_path, POSTFX_SHADER_PATH)
	assert_lte(float(post_material.get_shader_parameter("tint_strength")), 0.12)

	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)
	base.free()
	screen.free()
