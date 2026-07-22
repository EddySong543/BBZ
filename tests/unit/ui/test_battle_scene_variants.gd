extends GutTest

const SCENE1_PATH := "res://src/ui/scenes/scene1.tscn"
const SCENE2_PATH := "res://src/ui/scenes/scene2.tscn"


func test_default_battle_screen_still_uses_scene1() -> void:
	var screen := (load("res://src/ui/battle_screen.tscn") as PackedScene).instantiate()
	var stage := screen.get_node("Stage") as BattleStage
	assert_eq(stage.scene_file_path, SCENE1_PATH,
			"现有 BattleScreen 必须继续以 Scene1 为默认舞台")
	screen.free()


func test_scene2_battle_variant_replaces_only_the_stage() -> void:
	BattleSetup.reset()
	var screen := (load("res://src/ui/battle_screen_scene2.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("Stage"),
			"Scene2 变体的 @onready Stage 必须绑定替换后的节点")
	assert_eq(screen.stage.scene_file_path, SCENE2_PATH,
			"独立 Scene2 战斗场景必须加载 Scene2 舞台")
	assert_true(screen.stage.pointer_parallax,
			"Scene2 舞台继续沿用 BattleScreen 的鼠标视差")
	assert_false(screen.stage.demo_click_shake,
			"Scene2 舞台集成后不得启用独立预览点击震屏")
	assert_not_null(screen.get_node_or_null("WorldGroup"),
			"Scene2 变体继续执行成熟的战斗世界归组")
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	BattleSetup.reset()


func test_scene2_variant_preserves_character_geometry() -> void:
	BattleSetup.reset()
	var screen := (load("res://src/ui/battle_screen_scene2.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.p1_char_display.position, Vector2(96, 258))
	assert_eq(screen.p2_char_display.position, Vector2(1056, 258))
	assert_eq(screen.p1_char_display.size, Vector2(768, 768))
	assert_eq(screen.p2_char_display.size, Vector2(768, 768))
	assert_eq(screen.p1_char_display.sprite_scale, Vector2(2, 2))
	assert_eq(screen.p2_char_display.sprite_scale, Vector2(2, 2))
	assert_eq(screen.p1_char_display.anim_fps, 12.0)
	assert_eq(screen.p2_char_display.anim_fps, 12.0)
	BattleSetup.reset()


func test_scene2_foreground_grounding_contract() -> void:
	var stage := (load(SCENE2_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)

	var bridge := stage.get_node("StoneBridge") as TextureRect
	var tree := stage.get_node("BlossomTree") as TextureRect
	var distant_water := stage.get_node("DistantWater") as ColorRect
	var river := stage.get_node("River") as ColorRect
	var river_material := river.material as ShaderMaterial

	assert_eq(bridge.position, Vector2(-50, 650),
			"Scene2 bridge must keep its art-aligned standing surface at y=745")
	assert_eq(bridge.size, Vector2(2020, 469))
	assert_eq(tree.position + Vector2(0, tree.size.y), Vector2(1240, 756),
			"The blossom tree root must meet the raised bridge surface")
	assert_eq(distant_water.position, Vector2(-48, 795))
	assert_eq(distant_water.size, Vector2(2016, 75))
	assert_eq(river.position, Vector2(-48, 870))
	assert_eq(river.size, Vector2(2016, 205))
	assert_eq(river_material.get_shader_parameter("size_px"), Vector2(2016, 205))
	assert_false(river_material.shader.code.contains("impact_ring"),
			"Scene2 river must not continuously expand waterfall-impact rings")
