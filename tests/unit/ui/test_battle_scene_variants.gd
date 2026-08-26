extends GutTest

const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE_VARIANTS: Array[Dictionary] = [
	{
		"battle": "res://src/ui/battle_screen1.tscn",
		"stage": "res://src/ui/scenes/scene1.tscn",
	},
	{
		"battle": "res://src/ui/battle_screen2.tscn",
		"stage": "res://src/ui/scenes/scene2.tscn",
	},
	{
		"battle": "res://src/ui/battle_screen3.tscn",
		"stage": "res://src/ui/scenes/scene3.tscn",
	},
]


func test_battle_screen_entries_are_current_and_loadable() -> void:
	assert_true(ResourceLoader.exists(BATTLE_BASE_PATH))
	for contract: Dictionary in BATTLE_VARIANTS:
		assert_true(ResourceLoader.exists(String(contract["battle"])))
		assert_true(ResourceLoader.exists(String(contract["stage"])))
	assert_false(ResourceLoader.exists("res://src/ui/battle_screen.tscn"))
	assert_false(ResourceLoader.exists("res://src/ui/battle_screen_scene2.tscn"))


func test_scene_variants_share_the_mature_battle_runtime() -> void:
	for contract: Dictionary in BATTLE_VARIANTS:
		BattleSetup.reset()
		var screen := (load(String(contract["battle"])) as PackedScene).instantiate()
		add_child(screen)
		await get_tree().process_frame

		assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
		assert_eq(screen.stage.scene_file_path, String(contract["stage"]))
		assert_true(screen.stage.pointer_parallax)
		assert_false(screen.stage.demo_click_shake)
		assert_not_null(screen.get_node_or_null("WorldGroup"))
		assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
		assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
		for node_path: String in ["P1Hud", "P2Hud", "Buttons", "DeathSwitchOverlay"]:
			assert_true(screen.has_node(node_path))

		screen.queue_free()
		await get_tree().process_frame
	BattleSetup.reset()
