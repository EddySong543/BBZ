extends GutTest

const SCENE6_PATH := "res://src/ui/scenes/scene6.tscn"
const BATTLE6_PATH := "res://src/ui/battle_screen6.tscn"


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
