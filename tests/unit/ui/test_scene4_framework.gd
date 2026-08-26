extends GutTest

const SCENE4_PATH := "res://src/ui/scenes/scene4.tscn"
const BATTLE4_PATH := "res://src/ui/battle_screen4.tscn"


func test_scene4_entry_keeps_the_shared_battle_contract() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE4_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE4_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	for node_path: String in ["P1Hud", "P2Hud", "Buttons", "DeathSwitchOverlay"]:
		assert_true(screen.has_node(node_path))
	BattleSetup.reset()


func test_scene4_achievement_spirits_preserve_the_ambient_flight() -> void:
	var stage := (load(SCENE4_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var spirits := stage.get_node_or_null("AchievementLeafSpirits")

	assert_not_null(spirits)
	assert_true(bool(spirits.call("trigger_ambient_swarm")))
	var ambient_count := int(spirits.call("get_active_spirit_count"))
	assert_between(ambient_count, 2, 3)
	assert_eq(String(spirits.call("get_active_swarm_kind")), "ambient")
	assert_true(bool(spirits.call("trigger_achievement_swarm")))
	var preserved_ambient_count := int(spirits.call(
			"get_active_spirit_count_by_kind", &"ambient"))
	var achievement_count := int(spirits.call(
			"get_active_spirit_count_by_kind", &"achievement"))
	assert_eq(preserved_ambient_count, ambient_count)
	assert_between(achievement_count, 18, 24 - ambient_count)
	assert_eq(
			int(spirits.call("get_active_spirit_count")),
			ambient_count + achievement_count)
	assert_eq(String(spirits.call("get_active_swarm_kind")), "achievement")
