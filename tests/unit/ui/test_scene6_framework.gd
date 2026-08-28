extends GutTest

const SCENE6_PATH := "res://src/ui/scenes/scene6.tscn"
const BATTLE6_PATH := "res://src/ui/battle_screen6.tscn"
const SCENE6_CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene6_character_light.gdshader")


func test_scene6_entry_keeps_the_shared_battle_contract() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE6_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE6_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	for node_path: String in ["P1Hud", "P2Hud", "Buttons", "DeathSwitchOverlay"]:
		assert_true(screen.has_node(node_path))
	BattleSetup.reset()


func test_scene6_keeps_the_authored_valley_layers_and_magma() -> void:
	var stage := (load(SCENE6_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	for node_path: String in [
		"FarBackground",
		"MidgroundLeft",
		"MidgroundRight",
		"MagmaLake",
		"BattlePlatform",
		"ForegroundLeft",
		"ForegroundRight",
		"MagmaSecrets",
	]:
		assert_true(stage.has_node(node_path))
	var magma := stage.get_node("MagmaLake") as ColorRect
	assert_true(magma.visible)
	assert_not_null(magma.material)
	assert_lt(magma.get_index(), stage.get_node("BattlePlatform").get_index())


func test_scene6_character_grade_is_slot_symmetric_and_character_agnostic() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE6_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var materials: Array[ShaderMaterial] = []
	for display: CharacterDisplay in [
		screen.p1_char_display,
		screen.p2_char_display,
	]:
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") \
				as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		materials.append(material)
		assert_not_null(material)
		assert_eq(material.shader.resource_path, SCENE6_CHARACTER_SHADER_PATH)
		assert_false(material.shader.code.contains("TIME"),
				"Scene6角色调色不得随时间呼吸")
		assert_false(material.shader.code.contains("floor("),
				"角色移动时不得跨越量化光带产生红色跳变")
		assert_false(material.shader.code.contains("neutral_palette_amount"),
				"Scene6不得再用全身中性色调色板制造环境红")
		assert_false(material.shader.code.contains("furnace_heat_shift"),
				"Scene6不得回退到全身保亮度热染色")
		assert_true(material.shader.code.contains("scene_grade_shadow"),
				"Scene6角色必须有覆盖全身的烟紫暗部综合色阶")
		assert_true(material.shader.code.contains("scene_grade_mid"),
				"Scene6角色必须有覆盖全身的焦铜中间调综合色阶")
		assert_true(material.shader.code.contains("scene_grade_highlight"),
				"Scene6角色必须有覆盖全身的灰金亮部综合色阶")
		assert_true(material.shader.code.contains("scene_grade_amount"),
				"Scene6角色调色必须具有明确可见的整体权重")
		assert_true(material.shader.code.contains("form_normal"),
				"角色光照必须具有贴合身体体积的稳定光向")
		assert_true(material.shader.code.contains("lava_bounce_amount"))
		assert_false(material.shader.code.contains("forge_key_amount"),
				"不得用亮面提光伪装环境融合")
		assert_false(material.shader.code.contains("outside_alpha"),
				"不得采样轮廓制造随待机帧跳变的暖色闪边")
		assert_false(material.shader.code.contains("TEXTURE_PIXEL_SIZE"),
				"Scene6角色不应再生成逐像素轮廓光")
		assert_almost_eq(float(material.get_shader_parameter(
				"flash_peak_strength")), 0.0, 0.001)
		assert_between(float(material.get_shader_parameter(
				"source_saturation")), 0.98, 1.02,
				"角色主体应保留原素材饱和度")
		assert_gte(float(material.get_shader_parameter(
				"scene_grade_amount")), 0.42,
				"整体调色不能再次弱到近似原版角色")
		assert_between(float(material.get_shader_parameter(
				"scene_identity_floor")), 0.55, 0.72,
				"高饱和角色也要入场，但须保留主色身份")
		assert_between(float(material.get_shader_parameter(
				"backlight")), 0.10, 0.20,
				"体积暗面必须可见但不能压成暗洞角色")
		display.flash_white(0.05)
		display.pulse_rim(1.4, 0.05)
		assert_almost_eq(float(material.get_shader_parameter(
				"flash_peak_strength")), 0.0, 0.001)
		assert_almost_eq(float(material.get_shader_parameter(
				"rim_strength_cap")), 0.0, 0.001,
				"共享pulse_rim调用在Scene6必须被材质硬禁用")

	for parameter: StringName in [
		&"source_saturation",
		&"source_contrast",
		&"scene_exposure",
		&"highlight_compression",
		&"backlight",
		&"shadow_tint",
		&"skin_warmth",
		&"warmth_amount",
		&"rim_color",
		&"rim_strength",
		&"rim_strength_cap",
		&"fill_color",
		&"fill_amount",
		&"form_center",
		&"form_roundness",
		&"form_depth",
		&"shadow_hue_amount",
		&"scene_grade_shadow",
		&"scene_grade_mid",
		&"scene_grade_highlight",
		&"scene_grade_amount",
		&"scene_value_amount",
		&"scene_identity_floor",
		&"lava_bounce_color",
		&"lava_bounce_amount",
		&"lava_bounce_luma_lift",
		&"lava_bounce_start",
		&"lava_bounce_softness",
	]:
		assert_eq(materials[0].get_shader_parameter(parameter),
				materials[1].get_shader_parameter(parameter),
				"P1/P2不得按当前英雄分别调色: %s" % parameter)
	var p1_direction := Vector2(materials[0].get_shader_parameter("light_dir"))
	var p2_direction := Vector2(materials[1].get_shader_parameter("light_dir"))
	assert_almost_eq(p1_direction.x, -p2_direction.x, 0.001)
	assert_almost_eq(p1_direction.y, p2_direction.y, 0.001)
	BattleSetup.reset()
