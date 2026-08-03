extends GutTest

const SCENE4_PATH := "res://src/ui/scenes/scene4.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE4_PATH := "res://src/ui/battle_screen4.tscn"
const SKY_TEXTURE_PATH := "res://assets/scenes/scene4/scene4_sky.png"
const BACKGROUND_TOP_LEAVES_PATH := "res://assets/scenes/scene4/scene4_background_top_leaves.png"
const BACKGROUND_TREE_PATH := "res://assets/scenes/scene4/scene4_background_tree.png"
const BACKGROUND_TREE_2_PATH := "res://assets/scenes/scene4/scene4_background_tree_2.png"
const BATTLE_PLATFORM_PATH := "res://assets/scenes/scene4/scene4_battle_platform.png"
const LEFT_TREE_PATH := "res://assets/scenes/scene4/scene4_foreground_left_tree.png"
const RIGHT_TREE_PATH := "res://assets/scenes/scene4/scene4_foreground_right_tree.png"
const TOP_LEAVES_PATH := "res://assets/scenes/scene4/scene4_top_leaves.png"
const SKY_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_sky_grade.gdshader"
const DEPTH_GRADE_SHADER_PATH := "res://assets/shaders/canvas_env_scene4_depth_grade.gdshader"
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
		"BackgroundTopLeaves": 0.08,
		"BackgroundTree": 0.15,
		"BackgroundTree2": 0.18,
		"CanopyMotes": 0.58,
		"BattlePlatform": 1.0,
		"LeftTree": 1.2,
		"RightTree": 1.2,
		"TopLeaves": 1.25,
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
			stage.get_node("BackgroundTopLeaves").get_index())
	assert_lt(stage.get_node("BackgroundTopLeaves").get_index(),
			stage.get_node("BackgroundTree2").get_index())

	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"))

	assert_true(scene_source.contains(SKY_SHADER_PATH))
	assert_true(scene_source.contains(DEPTH_GRADE_SHADER_PATH))
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
		"BackgroundTopLeaves": BACKGROUND_TOP_LEAVES_PATH,
		"BackgroundTree": BACKGROUND_TREE_PATH,
		"BackgroundTree2": BACKGROUND_TREE_2_PATH,
		"BattlePlatform": BATTLE_PLATFORM_PATH,
		"LeftTree": LEFT_TREE_PATH,
		"RightTree": RIGHT_TREE_PATH,
		"TopLeaves": TOP_LEAVES_PATH,
	}
	for node_path: String in expected_assets:
		var art := stage.get_node(node_path) as TextureRect
		assert_not_null(art)
		assert_not_null(art.texture)
		assert_eq(art.texture.resource_path, expected_assets[node_path])
		assert_eq(art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	assert_eq((stage.get_node("BackgroundTree") as Control).scale,
			Vector2(3.0, 3.0))
	assert_eq((stage.get_node("BattlePlatform") as Control).scale,
			Vector2(6.0, 6.0))
	assert_eq((stage.get_node("LeftTree") as Control).scale,
			Vector2(4.0, 4.0))
	assert_eq((stage.get_node("RightTree") as Control).scale,
			Vector2(4.0, 4.0))


func test_scene4_grades_every_environment_asset_by_depth_role() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var depth_layers: Array[String] = [
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
		assert_lte(float(material.get_shader_parameter("brightness")), 0.8)
		assert_lte(float(material.get_shader_parameter("saturation")), 0.8)

	var tree2_material := (
			stage.get_node("BackgroundTree2") as TextureRect
	).material as ShaderMaterial
	assert_lte(float(tree2_material.get_shader_parameter("brightness")), 0.64)
	assert_lte(float(tree2_material.get_shader_parameter("contrast")), 0.82)
	assert_gte(float(tree2_material.get_shader_parameter("haze_strength")), 0.18)

	var sky_material := (
			stage.get_node("Sky") as TextureRect
	).material as ShaderMaterial
	var sky_mid := sky_material.get_shader_parameter("mid_color") as Color
	var sky_light := sky_material.get_shader_parameter("light_color") as Color
	assert_gt(sky_mid.g, sky_mid.r)
	assert_gt(sky_mid.g, sky_mid.b)
	assert_gt(sky_light.get_luminance(), sky_mid.get_luminance())


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
	assert_not_null(motes)
	assert_true(motes.emitting)
	assert_between(motes.amount, 14, 18)
	assert_gte(motes.randomness, 0.75)
	assert_eq(motes.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_not_null(mote_process)
	assert_lt(mote_process.color.b, mote_process.color.g)
	assert_lte(mote_process.color.a, 0.32)


func test_scene4_reuses_character_geometry_but_owns_environment_materials() -> void:
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE4_PATH) as PackedScene).instantiate()
	for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var base_node := base.get_node(node_name) as Control
		var scene4_node := screen.get_node(node_name) as Control
		assert_eq(scene4_node.position, base_node.position)
		assert_eq(scene4_node.size, base_node.size)

	var light_directions: Array[Vector2] = []
	for side: String in ["P1", "P2"]:
		var sprite_path := "%sCharDisplay/SubViewport/AnimatedSprite2D" % side
		var scene4_sprite := screen.get_node(sprite_path) as AnimatedSprite2D
		var material := scene4_sprite.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, CHARACTER_SHADER_PATH)
		assert_lte(float(material.get_shader_parameter("rim_strength")), 0.1)
		assert_lte(float(material.get_shader_parameter("fill_amount")), 0.04)
		assert_gte(float(material.get_shader_parameter("backlight")), 0.15)
		assert_between(
				float(material.get_shader_parameter("forest_ambient_amount")),
				0.18,
				0.35)
		var forest_color := material.get_shader_parameter("forest_ambient_color") as Color
		assert_gt(forest_color.g, forest_color.r)
		assert_gt(forest_color.g, forest_color.b)
		light_directions.append(material.get_shader_parameter("light_dir") as Vector2)

	assert_gt(light_directions[0].x, 0.0)
	assert_lt(light_directions[1].x, 0.0)

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
