extends GutTest

## 主界面晴风驿站结构与几何契约。只做运行时节点/资源/布局验证，不生成截图。

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
	assert_false(bool(contract["wasd_to_move"]), "主界面必须只保留鼠标左键移动")
	assert_true(bool(contract["shared_movement_controller"]),
			"主界面不得再维护独立移动实现")
	assert_eq(String(contract["movement_controller_script"]),
			"res://src/expedition/grid_movement_controller.gd")
	assert_false(world.visual_map.visible, "远征地图的田埂、作物和容器不得混入临时草地主界面")
	assert_eq(int(contract["visible_columns"]), 19)
	assert_eq(int(contract["visible_rows"]), 11)
	assert_eq(Vector2(contract["view_size"]), Vector2(1920.0, 1080.0),
			"19×11 格必须精确覆盖设计分辨率，不得露出绿色兜底外圈")
	var rendered_cell_size := Vector2(contract.get("rendered_cell_size", Vector2.ZERO))
	assert_almost_eq(rendered_cell_size.x, 1920.0 / 19.0, 0.001)
	assert_almost_eq(rendered_cell_size.y, 1080.0 / 11.0, 0.001)
	assert_eq(Vector2(contract["view_size"]) / rendered_cell_size,
			Vector2(19.0, 11.0), "画面四边必须以完整格结束")
	assert_eq(world.map_view.position, Vector2.ZERO)
	assert_eq(Vector2(contract.get("render_scale", Vector2.ZERO)),
			Vector2(16.0 / 19.0, 9.0 / 11.0))
	var screen_token_scale: Vector2 = world.player_token.scale \
			* Vector2(contract.get("render_scale", Vector2.ONE))
	assert_almost_eq(absf(screen_token_scale.x), absf(screen_token_scale.y), 0.001,
			"非正方形地图格不得拉伸角色比例")
	assert_eq(Vector2i(contract["hub_center_cell"]), Vector2i(16, 9))
	assert_eq(contract["center_entry_cells"], [
		Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8),
		Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9),
		Vector2i(15, 10), Vector2i(16, 10), Vector2i(17, 10),
	], "主要系统入口必须占据以出生点为中心的完整3×3")
	assert_eq(int(contract["portal_stone_count"]), 4)
	assert_eq(contract["portal_stone_cells"], [
		Vector2i(15, 8), Vector2i(17, 8),
		Vector2i(15, 10), Vector2i(17, 10),
	], "stone1-4 必须按行优先顺序占据中心3×3的四角")
	assert_eq(contract["portal_stone_texture_paths"], [
		"res://assets/ui/main_menu/stone1.png",
		"res://assets/ui/main_menu/stone2.png",
		"res://assets/ui/main_menu/stone3.png",
		"res://assets/ui/main_menu/stone4.png",
	])
	assert_eq(contract["portal_stone_foot_anchors"], [
		Vector2(63.0, 119.0), Vector2(65.5, 116.0),
		Vector2(64.0, 114.0), Vector2(64.0, 104.0),
	])
	assert_eq(float(contract["portal_stone_scale"]), 0.72)
	assert_eq(int(contract["portal_stone_shadow_count"]), 4)
	assert_eq(Vector2(contract["portal_cell_foot_point"]), Vector2(60.0, 90.0))
	assert_eq(float(contract["portal_float_amplitude"]), 3.0)
	assert_eq(float(contract["portal_float_period"]), 3.8)
	assert_eq(float(contract["portal_activation_duration"]), 2.0)
	assert_eq(contract["portal_blocked_cells"], contract["portal_stone_cells"],
			"四颗传送石所在格必须同时是移动阻挡格")
	assert_eq(Vector2i(contract["spawn_cell"]), Vector2i(16, 9),
			"角色每次都必须出生在中心3×3的正中央")
	assert_eq(Vector2i(contract["current_cell"]), Vector2i(contract["spawn_cell"]))
	assert_true(world._view_position_for_cell(Vector2i(contract["hub_center_cell"]))
			.is_equal_approx(Vector2(contract["view_size"]) * 0.5),
			"中心3×3不得偏左、偏右、偏上或偏下")
	assert_eq(world._cell_from_view_position(Vector2(0.5, 0.5)), Vector2i(7, 4),
			"左上边缘必须从完整格开始")
	assert_eq(world._cell_from_view_position(Vector2(1919.5, 1079.5)), Vector2i(25, 14),
			"右下边缘必须以完整格结束")
	assert_eq(int(contract["destination_count"]), 0,
			"匹配与远征改为直接按钮后，展示地图不得残留目的地格")
	assert_eq(int(contract["ground_cell_count"]), 32 * 18)
	assert_gt(int(contract["hero_frame_count"]), 0, "主界面角色必须使用真实英雄 idle 帧")
	assert_eq(Vector2(contract["hero_foot_anchor"]), Vector2(104.0, 156.0))
	assert_null(world.get_node_or_null("ExpeditionScreen"), "主界面不得实例化远征玩法屏")


func test_portal_stones_float_and_activate_in_corner_order() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	assert_eq(world.portal_stones.size(), 4)
	assert_eq(world.portal_stone_shadows.size(), 4)
	for index: int in world.portal_stones.size():
		var idle_material := world.portal_stones[index].material as ShaderMaterial
		assert_eq(idle_material.get_shader_parameter("energy_color"), Color.WHITE)
		assert_eq(float(idle_material.get_shader_parameter("energy_mix")), 0.0,
				"未连接时四颗阵眼必须保持白色，而不是预先带有模式颜色")
		var expected_foot: Vector2 = Vector2(MainMenuWorld.PORTAL_STONE_CELLS[index]) \
				* MainMenuWorld.MAP_CELL + MainMenuWorld.TOKEN_CELL_FOOT_POINT
		var actual_foot: Vector2 = world.get("_portal_stone_home_positions")[index] \
				+ MainMenuWorld.PORTAL_STONE_FOOT_ANCHORS[index]
		assert_eq(actual_foot, expected_foot,
				"每张素材必须按自身透明像素底边对齐角色的格内落脚点")
		assert_eq(world.portal_stones[index].scale,
				MainMenuWorld.TOKEN_ASPECT_COMPENSATION * MainMenuWorld.PORTAL_STONE_SCALE)
	var initial_positions: Array[Vector2] = []
	for stone: TextureRect in world.portal_stones:
		initial_positions.append(stone.position)
	world._process(MainMenuWorld.PORTAL_FLOAT_PERIOD * 0.125)
	var moved_count: int = 0
	for index: int in world.portal_stones.size():
		if not world.portal_stones[index].position.is_equal_approx(initial_positions[index]):
			moved_count += 1
	assert_gt(moved_count, 0, "漂浮 idle 必须直接改变四块阵眼的位置")
	world.play_portal_activation(
			MainMenuWorld.PORTAL_ENERGY_GOLD, MainMenuWorld.PORTAL_ACTIVATION_DURATION)
	await get_tree().create_timer(0.18).timeout
	var levels: Array[float] = world.get("_portal_energy_levels")
	assert_gt(levels[0], 0.0, "左上阵眼必须首先开始充能")
	assert_eq(levels[1], 0.0)
	assert_eq(levels[2], 0.0)
	assert_eq(levels[3], 0.0)
	await get_tree().create_timer(MainMenuWorld.PORTAL_ACTIVATION_DURATION).timeout
	for stone: TextureRect in world.portal_stones:
		var material := stone.material as ShaderMaterial
		assert_eq(material.get_shader_parameter("energy_color"),
				MainMenuWorld.PORTAL_ENERGY_GOLD)
		assert_almost_eq(float(material.get_shader_parameter("energy_mix")), 1.0, 0.001)
	assert_true(bool(world.get_visual_contract()["portal_connection_complete"]))


func test_portal_stones_block_movement_and_play_recoil_feedback() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	for stone_cell: Vector2i in MainMenuWorld.PORTAL_STONE_CELLS:
		assert_false(world._is_main_cell_walkable(stone_cell))
	assert_true(world.request_move_to_cell(Vector2i(14, 8)))
	await world.movement_finished
	var beside_stone := Vector2i(world.get("_current_cell"))
	assert_eq(beside_stone, Vector2i(14, 8))
	assert_eq(float(world._grid_movement.facing_sign), -1.0)
	var stone_click := InputEventMouseButton.new()
	stone_click.button_index = MOUSE_BUTTON_LEFT
	stone_click.pressed = true
	stone_click.position = world._view_position_for_cell(Vector2i(15, 8))
	world._on_map_view_gui_input(stone_click)
	assert_eq(Vector2i(world.get("_current_cell")), beside_stone)
	assert_eq(float(world._grid_movement.facing_sign), 1.0,
			"角色位于石头左边时点击石头，必须先转向右再播放阻挡动画")
	await get_tree().create_timer(0.06).timeout
	assert_gt(float(world.get("_blocked_feedback_strength")), 0.0,
			"阻挡必须有角色前倾与阵眼反冲，不能只是静默失败")
	var stone_shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_portal_stone_energy.gdshader")
	assert_false(stone_shader_source.contains("impact_flash"),
			"撞击只保留角色前倾、石头反冲与能量碰撞，不得再整石白闪")
	assert_gt(float((world.portal_stones[0].material as ShaderMaterial).get_shader_parameter(
			"impact_pulse")), 0.0, "撞石头仍须保留模式色能量碰撞反馈")


func test_connected_stones_keep_flickering_and_beam_reaches_screen_top_from_nine_cell_base() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var stone_shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_portal_stone_energy.gdshader")
	assert_true(stone_shader_source.contains("connected_flicker"),
			"稳定模式色必须继续闪烁，不能在energy_mix=1后彻底静止")
	assert_not_null(world.portal_beam)
	var contract: Dictionary = world.get_visual_contract()
	var beam_rect := Rect2(contract["portal_beam_rect"])
	var base_rect := Rect2(contract["portal_beam_base_rect"])
	assert_almost_eq(beam_rect.position.y, 0.0, 0.001,
			"光柱必须一直延伸到屏幕上边界")
	assert_eq(base_rect.size, MainMenuWorld.RENDERED_CELL_SIZE * 3.0,
			"光柱底部必须覆盖中心3×3九格")
	assert_almost_eq(base_rect.get_center().x, MainMenuWorld.VIEW_SIZE.x * 0.5, 0.001)
	assert_almost_eq(base_rect.get_center().y, MainMenuWorld.VIEW_SIZE.y * 0.5, 0.001)
	assert_true(beam_rect.encloses(base_rect), "九格阵面必须位于贯穿屏幕顶部的光柱内部")
	assert_almost_eq(MainMenuWorld.PORTAL_BEAM_DURATION, 1.8, 0.001)
	assert_false(world.portal_beam.visible)
	world.complete_portal_connection(MainMenuWorld.PORTAL_ENERGY_GOLD)
	await world.play_portal_beam(MainMenuWorld.PORTAL_ENERGY_GOLD, 0.12)
	assert_true(world.portal_beam.visible)
	assert_almost_eq(float(world.portal_beam_material.get_shader_parameter("beam_phase")),
			1.0, 0.001)
	assert_eq(world.portal_beam_material.get_shader_parameter("beam_color"),
			MainMenuWorld.PORTAL_ENERGY_GOLD)


func test_mode_entry_source_no_longer_calls_wave_curtain_transition() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	assert_false(source.contains(
			"TransitionManager.transition_to(\"res://src/expedition/expedition_screen.tscn\")"))
	assert_false(source.contains("TransitionManager.transition_to(BP_SCENE)"))
	assert_true(source.contains("play_portal_beam"))
	assert_true(source.contains("change_scene_to_file"))


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


func test_main_menu_disables_wasd_and_keeps_mouse_as_only_movement_input() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var start: Vector2i = Vector2i(world.get("_current_cell"))
	var source := FileAccess.get_file_as_string(
			"res://src/ui/components/main_menu_world.gd")
	assert_false(source.contains("func _unhandled_input"))
	assert_false(bool(world.get_visual_contract()["wasd_to_move"]))
	assert_eq(Vector2i(world.get("_current_cell")), start)


func test_main_menu_hover_draws_exact_rounded_target_and_regular_route_markers() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var target: Vector2i = Vector2i(world.get("_current_cell")) + Vector2i.LEFT * 3
	var motion := InputEventMouseMotion.new()
	motion.position = world._view_position_for_cell(target)
	world._on_map_view_gui_input(motion)
	assert_eq(Vector2i(world.get("_hovered_cell")), target)
	assert_gt((world.get("_hovered_path") as Array).size(), 0)
	assert_true(bool(world.get_visual_contract()["route_preview_connected"]))
	assert_true(world.route_target_outline.visible)
	assert_eq(world.route_target_outline.position,
			Vector2(target) * MainMenuWorld.MAP_CELL,
			"目标描边必须与逻辑格左上角使用同一世界坐标，不能另加视觉偏移")
	assert_eq(world.route_target_outline.size,
			Vector2.ONE * MainMenuWorld.MAP_CELL)
	assert_eq(world.route_target_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_grid_target_outline.gdshader")
	assert_almost_eq(float(world.route_target_material.get_shader_parameter(
			"cell_inset_px")), 1.0, 0.001)
	assert_almost_eq(float(world.route_target_material.get_shader_parameter(
			"corner_radius_px")), 16.0, 0.001)
	assert_almost_eq(float(world.route_target_material.get_shader_parameter(
			"pixel_step_px")), 4.0, 0.001)


func test_global_wave_curtain_is_removed_from_all_regular_scene_changes() -> void:
	var source := FileAccess.get_file_as_string(
			"res://src/core/transition_manager.gd")
	assert_false(source.contains("canvas_transition_wave.gdshader"))
	assert_false(source.contains("WAVE_SHADER"))
	assert_false(source.contains("_apply_winner_style"))
	assert_null(TransitionManager.get_node_or_null("Veil"),
			"远征返回主界面等常规切场不得再存在旧波幕节点")
	assert_not_null(TransitionManager.get_node_or_null("BootPixelVeil"),
			"Boot独立曝光环不是旧波幕，继续保留")


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


func test_main_menu_modes_are_direct_bottom_dock_buttons() -> void:
	var menu: Control = _make_menu()
	await get_tree().create_timer(1.1).timeout
	for path: String in ["UI/ModeMatch", "UI/ModeTower"]:
		var entry := menu.get_node(path) as Button
		assert_not_null(entry)
		assert_null(entry.get_script(), "匹配与远征不再使用世界卡片脚本")
		assert_eq(entry.focus_mode, Control.FOCUS_ALL)
		assert_false(entry.disabled)
		assert_true(entry.size.is_equal_approx(Vector2(108, 108)))
		assert_almost_eq(entry.position.y, 916.0, 0.01)
		assert_eq(entry.text, "")
		assert_null(entry.get_node_or_null("Caption"), "底部按钮不得保留文字标题")
		assert_null(entry.get_node_or_null("Status"), "底部按钮不得保留计时文字")
		var icon_size := (entry.get_node("Icon") as TextureRect).size
		assert_almost_eq(icon_size.x, 64.0, 0.001)
		assert_almost_eq(icon_size.y, 64.0, 0.001)
	assert_eq((menu.get_node("UI/ModeTower") as Button).position.x
			- ((menu.get_node("UI/ModeMatch") as Button).position.x + 108.0), 24.0)


func test_main_menu_merges_hero_and_item_codex_entry() -> void:
	var menu: Control = _make_menu()
	for path: String in [
		"UI/IdentityButton", "UI/SettingsButton", "UI/QuitButton",
		"UI/NavHeroes", "UI/NavBackpack",
	]:
		var button := menu.get_node(path) as Button
		assert_not_null(button, "%s 必须保留直接点击入口" % path)
		assert_true(button.visible)
	var codex := menu.get_node("UI/NavHeroes") as Button
	assert_eq(codex.text, "", "主菜单图鉴入口与战斗 UI 一致，不再保留文字")
	assert_true(codex.size.is_equal_approx(Vector2(108.0, 108.0)),
			"主菜单图鉴入口复用战斗 UI 的 108x108 尺寸")
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
	assert_null(menu.get_node_or_null("UI/NavItems"), "旧道具独立入口彻底退出场景")
	assert_null(menu.get_node_or_null("UI/NavShop"), "商店占位 UI 彻底退出场景")
	var backpack := menu.get_node("UI/NavBackpack") as Button
	assert_eq((backpack.get_node("Icon") as TextureRect).texture.resource_path,
			"res://assets/ui/icons/backpack.png")
	assert_null(backpack.get_node_or_null("Caption"))
	assert_eq(backpack.tooltip_text, "背包")
	assert_not_null(menu.get_node_or_null("UI/IdentityButton/AvatarFrame"))


func test_world_focus_only_changes_presentation_state() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	world.focus_destination("expedition")
	assert_eq(String(world.get("_focused_destination")), "",
			"直接底栏入口不再联动展示地图目的地")
	assert_true(bool(world.get_visual_contract()["presentation_only"]))
	world.focus_destination("")
	assert_eq(String(world.get("_focused_destination")), "")


func test_match_state_uses_icon_and_blue_portal_energy_then_restores_on_cancel() -> void:
	var menu: Control = _make_menu()
	var match_entry := menu.get_node("UI/ModeMatch") as Button
	var world := menu.get_node("MenuWorld") as MainMenuWorld
	menu.call("_start_search")
	await get_tree().create_timer(1.15).timeout
	assert_null(match_entry.get_node_or_null("Caption"))
	assert_null(match_entry.get_node_or_null("Status"))
	assert_eq(match_entry.tooltip_text, "匹配中 0:01")
	assert_eq((match_entry.get_node("Bg") as ColorRect).self_modulate, Color("FFD4B8"))
	for stone: TextureRect in world.portal_stones:
		assert_eq((stone.material as ShaderMaterial).get_shader_parameter("energy_color"),
				MainMenuWorld.PORTAL_ENERGY_BLUE)
	var search_levels: Array[float] = world.get("_portal_energy_levels")
	assert_gt(search_levels[0], 0.9)
	assert_gt(search_levels[1], 0.9)
	assert_gt(search_levels[2], 0.9)
	assert_eq(search_levels[3], 0.0,
			"匹配成功前第四颗必须保持白色，避免虚假显示连接完成")
	world.complete_portal_connection(MainMenuWorld.PORTAL_ENERGY_BLUE)
	assert_true(bool(world.get_visual_contract()["portal_connection_complete"]))
	menu.call("_cancel_search")
	assert_eq(match_entry.tooltip_text, "匹配")
	assert_eq((match_entry.get_node("Bg") as ColorRect).self_modulate, Color.WHITE)
	await get_tree().create_timer(0.35).timeout
	assert_almost_eq(float(world.get_visual_contract()["portal_energy_mix"]), 0.0, 0.001)
