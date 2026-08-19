extends GutTest

## 主界面晴风驿站结构与几何契约。只做运行时节点/资源/布局验证，不生成截图。

const MainMenuEntryScript := preload("res://src/ui/components/main_menu_entry.gd")


func _make_menu() -> Control:
	var packed := load("res://src/ui/main_menu.tscn") as PackedScene
	var menu := packed.instantiate() as Control
	add_child_autofree(menu)
	return menu


func test_main_menu_uses_presentation_only_qingfeng_world() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	assert_not_null(world)
	assert_null(menu.get_node_or_null("Background"), "旧对波背景不得继续占用主界面")
	var contract: Dictionary = world.get_visual_contract()
	assert_true(bool(contract["presentation_only"]), "主界面世界必须是纯展示组件")
	assert_true(bool(contract["uniform_grass_only"]), "当前主界面地表必须全部使用统一草方块")
	assert_true(bool(contract["click_to_move"]), "主界面格子必须接收左键移动")
	assert_true(bool(contract["wasd_to_move"]), "主界面必须支持 WASD 逐格移动")
	assert_false(world.visual_map.visible, "远征地图的田埂、作物和容器不得混入临时草地主界面")
	assert_eq(int(contract["visible_columns"]), 13)
	assert_eq(int(contract["visible_rows"]), 7)
	assert_eq(Vector2(contract["view_size"]), Vector2(1872.0, 1008.0))
	assert_eq(Vector2(contract["view_size"]) / float(contract["rendered_cell"]),
			Vector2(13.0, 7.0), "画面四边必须以完整格结束")
	assert_eq(int(contract["destination_count"]), 3)
	assert_eq(int(contract["ground_cell_count"]), 32 * 18)
	assert_gt(int(contract["hero_frame_count"]), 0, "主界面角色必须使用真实英雄 idle 帧")
	assert_eq(Vector2(contract["hero_foot_anchor"]), Vector2(104.0, 156.0))
	assert_null(world.get_node_or_null("ExpeditionScreen"), "主界面不得实例化远征玩法屏")


func test_main_menu_left_click_moves_character_across_multiple_cells() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var target: Vector2i = world.HOME_CELL + Vector2i.LEFT * 2
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world._view_position_for_cell(target)
	assert_eq(world._cell_from_view_position(click.position), target)
	world._on_map_view_gui_input(click)
	await world.movement_finished
	await get_tree().process_frame
	assert_eq(Vector2i(world.get("_current_cell")), target)
	assert_eq(Vector2(world.get("_current_logical_origin")), world._token_origin_for_cell(target))


func test_main_menu_held_wasd_buffers_steps_without_restarting_current_tween() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_W
	key_event.pressed = true
	world._unhandled_input(key_event)
	for _index: int in 2:
		var echo_event := InputEventKey.new()
		echo_event.keycode = KEY_W
		echo_event.pressed = true
		echo_event.echo = true
		world._unhandled_input(echo_event)
	await world.movement_finished
	await get_tree().process_frame
	var target: Vector2i = world.HOME_CELL + Vector2i.UP * 3
	assert_eq(Vector2i(world.get("_current_cell")), target)
	assert_eq(Vector2(world.get("_current_logical_origin")), world._token_origin_for_cell(target))
	assert_false(bool(world.get("_keyboard_runner_active")))
	assert_true((world.get("_keyboard_step_queue") as Array).is_empty())


func test_main_menu_modes_are_world_entries_not_legacy_cards() -> void:
	var menu: Control = _make_menu()
	var expected_ids := {
		"UI/ModeMatch": "match",
		"UI/ModeStory": "story",
		"UI/ModeTower": "expedition",
	}
	for path: String in expected_ids:
		var entry := menu.get_node(path) as MainMenuEntry
		assert_not_null(entry)
		assert_eq(entry.get_script(), MainMenuEntryScript)
		assert_eq(entry.destination_id, expected_ids[path])
		assert_eq(entry.focus_mode, Control.FOCUS_ALL)
		assert_false(entry.disabled)


func test_main_menu_keeps_direct_secondary_navigation() -> void:
	var menu: Control = _make_menu()
	for path: String in [
		"UI/IdentityButton", "UI/SettingsButton", "UI/QuitButton",
		"UI/NavHeroes", "UI/NavItems", "UI/NavShop",
	]:
		var button := menu.get_node(path) as Button
		assert_not_null(button, "%s 必须保留直接点击入口" % path)
		assert_true(button.visible)
	assert_not_null(menu.get_node_or_null("UI/IdentityButton/AvatarFrame"))


func test_world_focus_only_changes_presentation_state() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	world.focus_destination("expedition")
	assert_eq(String(world.get("_focused_destination")), "expedition")
	assert_true(bool(world.get_visual_contract()["presentation_only"]))
	world.focus_destination("")
	assert_eq(String(world.get("_focused_destination")), "")


func test_match_state_updates_world_entry_and_restores_it_on_cancel() -> void:
	var menu: Control = _make_menu()
	var match_entry := menu.get_node("UI/ModeMatch") as MainMenuEntry
	menu.call("_start_search")
	menu.call("_process", 1.1)
	assert_true(match_entry.get_node("Title").text.begins_with("匹配中"))
	assert_eq(match_entry.get_node("Subtitle").text, "0:01")
	assert_true(bool(match_entry.get("_emphasized")))
	menu.call("_cancel_search")
	assert_eq(match_entry.get_node("Title").text, "匹配对战")
	assert_eq(match_entry.get_node("Subtitle").text, "1v1 同时盲选对决")
	assert_false(bool(match_entry.get("_emphasized")))
