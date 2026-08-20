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
	await get_tree().process_frame
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	assert_not_null(world)
	assert_null(menu.get_node_or_null("Background"), "旧对波背景不得继续占用主界面")
	var contract: Dictionary = world.get_visual_contract()
	assert_true(bool(contract["presentation_only"]), "主界面世界必须是纯展示组件")
	assert_true(bool(contract["uniform_grass_only"]), "当前主界面地表必须全部使用统一草方块")
	assert_true(bool(contract["click_to_move"]), "主界面格子必须接收左键移动")
	assert_true(bool(contract["wasd_to_move"]), "主界面必须支持 WASD 逐格移动")
	assert_true(bool(contract["shared_movement_controller"]),
			"主界面不得再维护独立移动实现")
	assert_eq(String(contract["movement_controller_script"]),
			"res://src/expedition/grid_movement_controller.gd")
	assert_false(world.visual_map.visible, "远征地图的田埂、作物和容器不得混入临时草地主界面")
	assert_eq(int(contract["visible_columns"]), 12)
	assert_eq(int(contract["visible_rows"]), 6)
	assert_eq(Vector2(contract["view_size"]), Vector2(1920.0, 1080.0),
			"12×6 格必须精确覆盖设计分辨率，不得露出绿色兜底外圈")
	var rendered_cell_size := Vector2(contract.get("rendered_cell_size", Vector2.ZERO))
	assert_eq(rendered_cell_size, Vector2(160.0, 180.0))
	assert_eq(Vector2(contract["view_size"]) / rendered_cell_size,
			Vector2(12.0, 6.0), "画面四边必须以完整偶数格结束")
	assert_eq(world.map_view.position, Vector2.ZERO)
	assert_eq(Vector2(contract.get("render_scale", Vector2.ZERO)),
			Vector2(4.0 / 3.0, 1.5))
	var screen_token_scale: Vector2 = world.player_token.scale \
			* Vector2(contract.get("render_scale", Vector2.ONE))
	assert_almost_eq(absf(screen_token_scale.x), absf(screen_token_scale.y), 0.001,
			"非正方形地图格不得拉伸角色比例")
	assert_eq(world.CENTER_SPAWN_CELLS, [
		Vector2i(15, 8), Vector2i(16, 8),
		Vector2i(15, 9), Vector2i(16, 9),
	], "32×18 地图只能使用几何中心四格作为出生池")
	assert_has(world.CENTER_SPAWN_CELLS, Vector2i(contract["spawn_cell"]),
			"每次加载的出生点必须位于整张地图正中心四格之一")
	assert_eq(Vector2i(contract["current_cell"]), Vector2i(contract["spawn_cell"]))
	assert_eq(int(contract["destination_count"]), 3)
	assert_eq(int(contract["ground_cell_count"]), 32 * 18)
	assert_gt(int(contract["hero_frame_count"]), 0, "主界面角色必须使用真实英雄 idle 帧")
	assert_eq(Vector2(contract["hero_foot_anchor"]), Vector2(104.0, 156.0))
	assert_null(world.get_node_or_null("ExpeditionScreen"), "主界面不得实例化远征玩法屏")


func test_main_menu_left_click_moves_character_across_multiple_cells() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var start: Vector2i = Vector2i(world.get("_current_cell"))
	var target: Vector2i = start + Vector2i.LEFT * 2
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


func test_main_menu_held_wasd_uses_expedition_immediate_logic_and_continuous_follow() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var start: Vector2i = Vector2i(world.get("_current_cell"))
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
	var target: Vector2i = start + Vector2i.UP * 3
	assert_eq(Vector2i(world.get("_current_cell")), target,
			"与远征一致：连续输入应立即提交逻辑格，不等待旧 Tween")
	assert_ne(Vector2(world.get("_current_logical_origin")), world._token_origin_for_cell(target),
			"视觉坐标应从当前位置连续追赶最新逻辑格")
	await world.movement_finished
	await get_tree().process_frame
	assert_eq(Vector2i(world.get("_current_cell")), target)
	assert_eq(Vector2(world.get("_current_logical_origin")), world._token_origin_for_cell(target))
	assert_false(world._grid_movement.is_moving())


func test_main_menu_reset_home_returns_to_this_loads_chosen_spawn() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var spawn_cell: Vector2i = Vector2i(world.get("_spawn_cell"))
	assert_true(world.request_step(Vector2i.LEFT))
	assert_ne(Vector2i(world.get("_current_cell")), spawn_cell)
	world.reset_home()
	await world.movement_finished
	await get_tree().process_frame
	assert_eq(Vector2i(world.get("_current_cell")), spawn_cell)
	assert_eq(Vector2i(world.get("_spawn_cell")), spawn_cell,
			"同一次主界面加载期间不得重新随机出生点")


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


func test_main_menu_merges_hero_and_item_codex_entry() -> void:
	var menu: Control = _make_menu()
	for path: String in [
		"UI/IdentityButton", "UI/SettingsButton", "UI/QuitButton",
		"UI/NavHeroes", "UI/NavShop",
	]:
		var button := menu.get_node(path) as Button
		assert_not_null(button, "%s 必须保留直接点击入口" % path)
		assert_true(button.visible)
	var codex := menu.get_node("UI/NavHeroes") as Button
	var old_items := menu.get_node("UI/NavItems") as Button
	assert_eq(codex.text, "", "主菜单图鉴入口与战斗 UI 一致，不再保留文字")
	assert_eq(codex.size, Vector2(108.0, 108.0), "主菜单图鉴入口复用战斗 UI 的 108x108 尺寸")
	assert_null(codex.get_node_or_null("Plate"), "图鉴入口不再使用主菜单长条羊皮板")
	var book := codex.get_node("BookIcon") as TextureRect
	assert_eq(book.texture.resource_path, "res://assets/ui/icons/codex_book.png",
			"合并入口使用战斗 UI 的书本图标")
	assert_eq(book.size, Vector2(64.0, 64.0), "书本图标保持战斗 UI 的 64x64 真像素尺寸")
	var bg := codex.get_node("Bg") as ColorRect
	assert_eq((bg.material as ShaderMaterial).shader.resource_path,
			"res://assets/shaders/canvas_button_jelly.gdshader")
	assert_eq((bg.material as ShaderMaterial).get_shader_parameter("fill_top"),
			Color(0.92, 0.87, 0.70), "图鉴方钮复用战斗 UI 奶油纸上色")
	assert_not_null(codex.get_node_or_null("ButtonJuice"), "图鉴方钮复用战斗 UI 按压反馈")
	assert_not_null(codex.get_node_or_null("BottomShadow"), "图鉴方钮复用战斗 UI 下投影")
	assert_false(old_items.visible, "旧道具入口退出布局和交互")
	assert_true(old_items.disabled)
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
