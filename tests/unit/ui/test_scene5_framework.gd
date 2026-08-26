extends GutTest

const SCENE5_PATH := "res://src/ui/scenes/scene5.tscn"
const BATTLE5_PATH := "res://src/ui/battle_screen5.tscn"


func test_scene5_entry_keeps_the_shared_battle_contract() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE5_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	for node_path: String in [
		"StageSlot/Stage/Sky",
		"StageSlot/Stage/BattlePlatform",
		"StageSlot/Stage/NearWheatLeft",
		"StageSlot/Stage/WindField",
		"P1Hud",
		"P2Hud",
		"Buttons",
	]:
		assert_true(screen.has_node(node_path))
	BattleSetup.reset()


func test_scene5_wind_field_receives_battle_response() -> void:
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame
	var wind_field := stage.get_node("WindField")
	watch_signals(wind_field)

	wind_field.call("trigger_battle_gust", 16.0, -1.0)
	assert_signal_emitted_with_parameters(wind_field, "gust_triggered", [1.0, -1.0])
	var wheat_material := (stage.get_node("FarWheat") as CanvasItem).material as ShaderMaterial
	assert_almost_eq(float(wheat_material.get_shader_parameter("gust_strength")), 1.0, 0.001)
	assert_almost_eq(float(wheat_material.get_shader_parameter("gust_direction")), -1.0, 0.001)
