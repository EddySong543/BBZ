extends GutTest

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"
const CHARACTER_SHADER_PATH := "res://assets/shaders/character_light.gdshader"
const POSTFX_SHADER_PATH := "res://assets/shaders/post_fx_color_grade.gdshader"


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


func test_scene7_exposes_flat_textureless_parallax_layers() -> void:
	if not ResourceLoader.exists(SCENE7_PATH):
		return

	var scene_source: String = FileAccess.get_file_as_string(SCENE7_PATH)
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var layer_contract: Dictionary[String, float] = {
		"Sky": 0.0,
		"FarBackground": 0.18,
		"Midground": 0.55,
		"BattlePlatform": 1.0,
		"Foreground": 1.25,
	}
	var previous_index: int = -1
	for node_name: String in layer_contract:
		var layer := stage.get_node_or_null(node_name) as TextureRect
		assert_not_null(layer, "%s must be a direct editable layer" % node_name)
		if layer == null:
			continue
		assert_eq(layer.get_parent(), stage)
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_null(layer.texture)
		assert_eq(float(layer.get_meta("parallax_factor")), layer_contract[node_name])
		assert_gt(layer.get_index(), previous_index)
		previous_index = layer.get_index()

	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"))
	assert_true(bool(stage.get_meta("framework_only", false)))
	assert_eq(String(stage.get_meta("theme_name", "")), "Scene7 中性框架")
	assert_not_null(stage.get_node_or_null("PreviewBackdrop") as ColorRect)
	assert_false(scene_source.contains("res://assets/import/"))
	assert_false(scene_source.contains("res://assets/scenes/"))
	assert_false(scene_source.contains("canvas_env_scene"))


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


func test_scene7_reuses_character_geometry_with_neutral_visual_parameters() -> void:
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
		assert_eq(scene7_node.rim_strength, 0.0)
		assert_eq(scene7_node.backlight, 0.0)
		assert_eq(scene7_node.warmth_amount, 0.0)
		assert_eq(scene7_node.fill_amount, 0.0)
		assert_not_null(scene7_node.get_render_texture())
		var sprite := scene7_node.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
		assert_not_null(sprite.sprite_frames)
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material != null:
			assert_eq(material.shader.resource_path, CHARACTER_SHADER_PATH)

	for shadow_name: String in ["P1Shadow", "P2Shadow"]:
		var shadow := screen.get_node("WorldGroup/%s" % shadow_name) as TextureRect
		assert_eq(shadow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(shadow.rotation, 0.0)

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
		assert_eq(float(post_material.get_shader_parameter("brightness")), 1.0)
		assert_eq(float(post_material.get_shader_parameter("contrast")), 1.0)
		assert_eq(float(post_material.get_shader_parameter("saturation")), 1.0)
		assert_eq(float(post_material.get_shader_parameter("tint_strength")), 0.0)
		assert_eq(float(post_material.get_shader_parameter("split_strength")), 0.0)
		assert_eq(float(post_material.get_shader_parameter("vignette_strength")), 0.0)
		assert_eq(float(post_material.get_shader_parameter("grain_amount")), 0.0)
		assert_eq(float(post_material.get_shader_parameter("heat_haze_strength")), 0.0)
	base.free()
	BattleSetup.reset()
