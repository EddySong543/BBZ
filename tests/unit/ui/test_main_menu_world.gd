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
	assert_eq(int(contract["visible_columns"]), 23)
	assert_eq(int(contract["visible_rows"]), 13)
	assert_eq(Vector2(contract["view_size"]), Vector2(1920.0, 1080.0),
			"默认23×13格必须精确覆盖设计分辨率，不得露出绿色兜底外圈")
	var rendered_cell_size := Vector2(contract.get("rendered_cell_size", Vector2.ZERO))
	assert_almost_eq(rendered_cell_size.x, 1920.0 / 23.0, 0.001)
	assert_almost_eq(rendered_cell_size.y, 1080.0 / 13.0, 0.001)
	assert_lte((Vector2(contract["view_size"]) / rendered_cell_size)
			.distance_to(Vector2(23.0, 13.0)), 0.001,
			"默认档画面四边必须以完整格结束")
	assert_eq(world.map_view.position, Vector2.ZERO)
	assert_eq(Vector2(contract.get("render_scale", Vector2.ZERO)),
			Vector2(16.0 / 23.0, 9.0 / 13.0))
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
	assert_eq(world._cell_from_view_position(Vector2(0.5, 0.5)), Vector2i(5, 3),
			"左上边缘必须从完整格开始")
	assert_eq(world._cell_from_view_position(Vector2(1919.5, 1079.5)), Vector2i(27, 15),
			"右下边缘必须以完整格结束")
	assert_eq(int(contract["destination_count"]), 0,
			"模式入口改为直接按钮后，展示地图不得残留旧目的地格")
	assert_eq(int(contract["ground_cell_count"]), 32 * 18)
	assert_gt(int(contract["hero_frame_count"]), 0, "主界面角色必须使用真实英雄 idle 帧")
	assert_eq(Vector2(contract["hero_foot_anchor"]), Vector2(104.0, 156.0))
	assert_null(world.get_node_or_null("ExpeditionScreen"), "主界面不得实例化远征玩法屏")


func test_main_menu_mouse_wheel_zooms_between_complete_grid_presets() -> void:
	var menu: Control = _make_menu()
	await get_tree().process_frame
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var contract: Dictionary = world.get_zoom_contract()
	assert_eq(contract["grid_presets"], [
		Vector2i(31, 17), Vector2i(27, 15), Vector2i(23, 13),
		Vector2i(19, 11), Vector2i(15, 9),
	])
	assert_eq(Vector2i(contract["current_grid"]), Vector2i(23, 13))
	assert_eq(Vector2i(contract["default_grid"]), Vector2i(23, 13))
	assert_eq(Vector2i(contract["closest_grid"]), Vector2i(15, 9))
	assert_almost_eq(float(contract["transition_duration"]), 0.15, 0.001)
	assert_almost_eq(float(contract["input_burst_window"]), 0.055, 0.001)
	assert_false(bool(contract["instant_switch"]))
	assert_false(bool(contract["transition_active"]))
	assert_null(world.get_node_or_null("MapView/ZoomFocusPulse"),
			"缩放只保留尺度转场，不得再叠加暗化或扩散脉冲")

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	world._on_map_view_gui_input(wheel_up)

	contract = world.get_zoom_contract()
	assert_eq(Vector2i(contract["current_grid"]), Vector2i(19, 11))
	assert_true(bool(contract["transition_active"]))
	var middle_scale := Vector2(16.0 / 23.0, 9.0 / 13.0)
	assert_lte(world.map_world.scale.distance_to(middle_scale), 0.001,
			"滚轮触发帧不得瞬间跳到下一档")
	world._on_map_view_gui_input(wheel_up)
	assert_eq(Vector2i(world.get_zoom_contract()["current_grid"]), Vector2i(19, 11),
			"55ms内同向滚轮事件必须合并，不能一次跨两档")
	world._advance_view_zoom(MainMenuWorld.ZOOM_TRANSITION_DURATION * 0.5)
	assert_gt(world.map_world.scale.x, middle_scale.x)
	assert_lt(world.map_world.scale.x, 16.0 / 19.0)
	assert_true(world._view_position_for_cell(MainMenuWorld.HUB_CENTER_CELL)
			.is_equal_approx(MainMenuWorld.VIEW_SIZE * 0.5),
			"动效中也必须持续以角色所在中心格为锚点")
	var transition_token_scale: Vector2 = world.player_token.scale * world.map_world.scale
	assert_almost_eq(absf(transition_token_scale.x), absf(transition_token_scale.y), 0.001,
			"动效中不得压扁角色")
	world._advance_view_zoom(MainMenuWorld.ZOOM_TRANSITION_DURATION * 0.5)
	assert_false(bool(world.get_zoom_contract()["transition_active"]))
	assert_lte(world.map_world.scale.distance_to(Vector2(16.0 / 19.0, 9.0 / 11.0)), 0.001)

	world._on_map_view_gui_input(wheel_up)
	world._advance_view_zoom(MainMenuWorld.ZOOM_TRANSITION_DURATION)
	assert_eq(Vector2i(world.get_zoom_contract()["current_grid"]), Vector2i(15, 9))
	assert_false(bool(world.get_zoom_contract()["transition_active"]))
	assert_lte(world.map_world.scale.distance_to(Vector2(16.0 / 15.0, 1.0)), 0.001)
	var rendered_cell_size: Vector2 = Vector2.ONE * MainMenuWorld.MAP_CELL \
			* world.map_world.scale
	assert_lte((MainMenuWorld.VIEW_SIZE / rendered_cell_size)
			.distance_to(Vector2(15, 9)), 0.001,
			"每个静止缩放档都必须以完整格精确铺满画面")
	assert_true(world._view_position_for_cell(MainMenuWorld.HUB_CENTER_CELL)
			.is_equal_approx(MainMenuWorld.VIEW_SIZE * 0.5),
			"滚轮缩放必须以角色所在中心格为锚点")
	assert_eq(world._cell_from_view_position(Vector2(0.5, 0.5)), Vector2i(9, 5))
	assert_eq(world._cell_from_view_position(Vector2(1919.5, 1079.5)), Vector2i(23, 13))
	var token_screen_scale: Vector2 = world.player_token.scale * world.map_world.scale
	assert_almost_eq(absf(token_screen_scale.x), absf(token_screen_scale.y), 0.001,
			"最近档也不得压扁角色")
	assert_lte(MainMenuWorld.TOKEN_SIZE.y * absf(token_screen_scale.y), 208.01,
			"最近档角色不得超过208px")
	for stone: TextureRect in world.portal_stones:
		var stone_screen_scale: Vector2 = stone.scale * world.map_world.scale
		assert_almost_eq(stone_screen_scale.x, stone_screen_scale.y, 0.001,
				"主界面阵眼也必须保持原始比例")
	var beam_bases: Array = world.get_visual_contract()["portal_beam_base_rects"]
	assert_eq(beam_bases.size(), 4)
	for beam_base_variant: Variant in beam_bases:
		var beam_base := Rect2(beam_base_variant)
		assert_lte(beam_base.size.distance_to(rendered_cell_size), 0.001,
				"四颗石头的单格光柱底面必须跟随当前缩放档")

	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	world._on_map_view_gui_input(wheel_down)
	world._advance_view_zoom(MainMenuWorld.ZOOM_TRANSITION_DURATION * 0.5)
	world._on_map_view_gui_input(wheel_up)
	assert_eq(Vector2i(world.get_zoom_contract()["current_grid"]), Vector2i(15, 9),
			"反向滚轮必须立即打断当前过渡")
	world._advance_view_zoom(MainMenuWorld.ZOOM_TRANSITION_DURATION)
	assert_lte(world.map_world.scale.distance_to(Vector2(16.0 / 15.0, 1.0)), 0.001)


func test_main_menu_accepts_zoom_while_player_or_camera_is_moving() -> void:
	var menu: Control = _make_menu()
	await get_tree().process_frame
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var destination := MainMenuWorld.HUB_CENTER_CELL + Vector2i.DOWN
	assert_true(world.request_move_to_cell(destination))
	assert_true(world._grid_movement.route_active)

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	world._on_map_view_gui_input(wheel_up)
	assert_eq(Vector2i(world.get_zoom_contract()["current_grid"]), Vector2i(19, 11),
			"角色或镜头移动期间也必须接收缩放输入")
	world._advance_view_zoom(MainMenuWorld.ZOOM_TRANSITION_DURATION)
	assert_lte(world.map_world.scale.distance_to(Vector2(16.0 / 19.0, 9.0 / 11.0)), 0.001)


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
				world._current_aspect_compensation() * MainMenuWorld.PORTAL_STONE_SCALE)
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
	# The first beam starts after the 0.08 s ignition delay plus the glow lead.
	# Leave one rendered tick of margin so a busy full-suite run does not sample
	# the tween on the exact callback boundary.
	await get_tree().create_timer(0.24).timeout
	var levels: Array[float] = world.get("_portal_energy_levels")
	var beam_levels: Array[float] = world.get("_portal_beam_levels")
	assert_gt(levels[0], 0.0, "左上阵眼必须首先开始充能")
	assert_gt(beam_levels[0], 0.0, "左上阵眼发光后必须从自身格子升起光柱")
	assert_eq(levels[1], 0.0)
	assert_eq(beam_levels[1], 0.0)
	assert_eq(levels[2], 0.0)
	assert_eq(levels[3], 0.0)
	await get_tree().create_timer(MainMenuWorld.PORTAL_ACTIVATION_DURATION).timeout
	for index: int in world.portal_stones.size():
		var stone: TextureRect = world.portal_stones[index]
		var material := stone.material as ShaderMaterial
		assert_eq(material.get_shader_parameter("energy_color"),
				MainMenuWorld.PORTAL_ENERGY_GOLD)
		assert_almost_eq(float(material.get_shader_parameter("energy_mix")), 1.0, 0.001)
		assert_true(world.portal_beams[index].visible)
		assert_almost_eq(float(world.portal_beams[index].beam_progress), 1.0, 0.001,
				"已经匹配的石头必须持续向上发射完整光柱")
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


func test_each_connected_stone_sustains_one_cell_beam_until_all_four_match() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	var stone_shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_portal_stone_energy.gdshader")
	assert_true(stone_shader_source.contains("connected_flicker"),
			"稳定模式色必须继续闪烁，不能在energy_mix=1后彻底静止")
	assert_eq(world.portal_beams.size(), 4)
	var contract: Dictionary = world.get_visual_contract()
	var base_rects: Array = contract["portal_beam_base_rects"]
	assert_eq(base_rects.size(), 4)
	for index: int in world.portal_beams.size():
		var beam: PortalPixelBeam = world.portal_beams[index]
		assert_eq(Rect2(beam.position, beam.size), Rect2(Vector2.ZERO,
				MainMenuWorld.VIEW_SIZE))
		assert_false(beam.visible)
		var base_rect := Rect2(base_rects[index])
		assert_lte(base_rect.size.distance_to(Vector2(contract["rendered_cell_size"])),
				0.001, "每束光柱底部只能覆盖对应石头的一格")
		assert_lte(base_rect.get_center().distance_to(
				world._view_position_for_cell(MainMenuWorld.PORTAL_STONE_CELLS[index])),
				0.71)
	world.complete_portal_connection(MainMenuWorld.PORTAL_ENERGY_GOLD)
	await world.wait_for_portal_beams(0.12)
	for beam: PortalPixelBeam in world.portal_beams:
		assert_true(beam.visible, "完全匹配时四颗石头必须同时维持向上光柱")
		assert_almost_eq(float(beam.beam_progress), 1.0, 0.001)
		assert_true(bool(beam.get_visual_contract()["reaches_screen_top"]))


func test_mode_entry_uses_portal_only_bottom_up_wave_curtain() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	assert_true(source.contains("wait_for_portal_beams"))
	assert_true(source.contains("TransitionManager.portal_transition_to("))
	assert_false(source.contains("get_tree().change_scene_to_file(EXPEDITION_SCENE)"))


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


func test_main_menu_hover_draws_exact_target_and_full_route_footprint_stream() -> void:
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
	assert_almost_eq(float(world.route_target_material.get_shader_parameter(
			"outline_alpha")), 1.0, 0.001,
			"目标描边必须完全盖住底层格边，不能透出底部边线颜色")
	var route_contract: Dictionary = GridRoutePreview.get_style_contract()
	assert_eq(route_contract["implementation"],
			"full_route_alternating_footprint_stream")
	assert_true(bool(route_contract["uses_footprints"]))
	assert_true(bool(route_contract["alternates_left_right"]))
	assert_true(bool(route_contract["covers_full_route"]))
	assert_true(bool(route_contract["count_scales_with_route_length"]))
	assert_false(bool(route_contract["uses_fixed_visible_count"]))
	assert_false(bool(route_contract["uses_footprint_count_cap"]))
	assert_true(bool(route_contract["moves_continuously_forward"]))
	assert_true(bool(route_contract["uses_distance_sampling"]))
	assert_true(bool(route_contract["uses_smoothed_turn_tangents"]))
	assert_false(bool(route_contract["uses_loop_gap"]))
	assert_false(bool(route_contract["fills_every_path_cell"]))
	assert_false(bool(route_contract["lights_individual_footprints"]))
	assert_lt(float(route_contract["stream_speed_cells_per_second"]), 0.55)
	assert_false(bool(route_contract["uses_inset_edge_bars"]))
	assert_false(bool(route_contract["uses_arrows"]))
	assert_false(bool(route_contract["uses_continuous_ribbon"]))
	assert_false(bool(route_contract["uses_chevrons"]))
	assert_false(bool(route_contract["uses_dashes"]))
	assert_false(bool(route_contract["uses_nodes"]))
	assert_false(bool(route_contract["uses_toe_details"]))
	assert_false(bool(route_contract["uses_ground_shadow"]))
	assert_false(bool(route_contract["uses_inner_core"]))
	assert_false(bool(route_contract["uses_glow"]))
	assert_false(bool(route_contract["uses_external_texture"]))
	assert_false(bool(route_contract["uses_sprite_sheet"]))


func test_bottom_up_wave_curtain_exists_only_for_portal_scene_changes() -> void:
	var source := FileAccess.get_file_as_string(
			"res://src/core/transition_manager.gd")
	assert_true(source.contains("canvas_portal_vertical_wave.gdshader"))
	assert_true(source.contains("func portal_transition_to("))
	assert_not_null(TransitionManager.get_node_or_null("PortalWaveVeil"),
			"传送专用波幕应常驻，但只在主界面传送时显示")
	assert_false((TransitionManager.get_node("PortalWaveVeil") as ColorRect).visible)
	var shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_portal_vertical_wave.gdshader")
	assert_true(shader_source.contains("float yp = 1.0 - uv.y"),
			"旧横向波幕必须改为从屏幕底部向顶部推进")
	assert_true(shader_source.contains("step(yp, front)"))
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


func test_main_menu_uses_single_banner_and_pre_anchor_bottom_dock() -> void:
	var menu: Control = _make_menu()
	await get_tree().create_timer(1.1).timeout
	var expected_banner_rect := Rect2(Vector2(788.0, 916.0), Vector2(344.0, 108.0))
	assert_null(menu.get_node_or_null("UI/ModeMatch"))
	assert_null(menu.get_node_or_null("UI/ModeTower"))
	var banner_button := menu.get_node("UI/ModeBanner") as Button
	assert_true(Rect2(banner_button.position, banner_button.size).is_equal_approx(
			expected_banner_rect), "中央Banner恢复到格子锚定式实施前的位置")
	assert_eq(banner_button.text, "")
	var banner_art := banner_button.get_node("Banner") as TextureRect
	assert_eq(banner_art.texture.resource_path,
			"res://assets/ui/main_menu/expedition_banner.png")
	assert_eq(banner_art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq(banner_art.offset_left, 0.0)
	assert_eq(banner_art.offset_top, 0.0)
	assert_eq(banner_art.offset_right, 0.0)
	assert_eq(banner_art.offset_bottom, 0.0)
	assert_not_null(banner_art.material,
			"像素外框必须直接作用于Banner图片，不得只放在图片背后")
	if banner_art.material != null:
		assert_eq((banner_art.material as ShaderMaterial).shader.resource_path,
				"res://assets/shaders/canvas_mode_banner_frame.gdshader")
	var banner_bg := banner_button.get_node("Bg") as ColorRect
	var banner_material := banner_bg.material as ShaderMaterial
	assert_eq(banner_material.shader.resource_path,
			"res://assets/shaders/canvas_button_jelly.gdshader")
	assert_almost_eq(float(banner_material.get_shader_parameter("aspect")),
			expected_banner_rect.size.aspect(), 0.001,
			"Banner像素框必须按长方形比例计算，不得拉伸方钮边框")
	assert_eq(banner_material.get_shader_parameter("fill_top"),
			Color(0.92, 0.87, 0.70), "主界面必须恢复战斗UI的奶油纸面色系")
	assert_not_null(banner_button.get_node_or_null("BottomShadow"),
			"Banner复用图鉴、背包的同形底部投影")
	assert_false(banner_bg.visible,
			"Banner画面填满内部时，不得让奶油底板透过画面形成第二层底色")
	var frame_overlay := banner_button.get_node("FrameOverlay") as ColorRect
	var frame_material := frame_overlay.material as ShaderMaterial
	assert_eq(frame_material.shader.resource_path,
			"res://assets/shaders/canvas_button_jelly.gdshader")
	assert_almost_eq(float(frame_material.get_shader_parameter("fill_alpha")),
			0.0, 0.001, "外框中心必须透明，让Banner填满内部")
	assert_almost_eq(float(frame_material.get_shader_parameter("aspect")),
			expected_banner_rect.size.aspect(), 0.001)
	assert_eq(banner_button.get_child(banner_button.get_child_count() - 1),
			frame_overlay, "像素外框必须覆盖在Banner画面之上")
	assert_null(banner_button.get_node_or_null("BannerShadow"),
			"不再复制Banner图片模拟投影")
	assert_null(banner_button.get_node_or_null("GridAnchor"),
			"屏幕层UI不得继续描亮地面格子")
	var layout_contract: Dictionary = menu.call("get_bottom_ui_layout_contract")
	assert_eq(layout_contract["implementation"], "single_banner_bottom_dock")
	assert_false(bool(layout_contract["uses_continuous_bottom_bar"]))
	assert_true(bool(layout_contract["uses_separate_ui_islands"]))
	assert_false(bool(layout_contract["secondary_tabs_partially_offscreen"]))
	assert_true(bool(layout_contract["reuses_battle_ui_palette"]))
	assert_eq(banner_button.find_children("Banner", "TextureRect", true, false).size(), 1,
			"两个模式只能交换同一张Banner，不得同时挂两张图")
	assert_eq((menu.get_node("UI/NavHeroes") as Button).position, Vector2(48.0, 916.0))
	assert_eq((menu.get_node("UI/NavBackpack") as Button).position, Vector2(1640.0, 916.0))
	assert_eq((menu.get_node("UI/NavWarehouse") as Button).position, Vector2(1772.0, 916.0))
	assert_null(menu.get_node_or_null("UI/IdentityButton"),
			"主界面不再展示个人头像框或个人资料入口")
	assert_null(menu.get_node_or_null("UI/QuitButton"),
			"主界面退出按钮及其点击入口已经移除")


func test_main_menu_merges_hero_and_item_codex_entry() -> void:
	var menu: Control = _make_menu()
	for path: String in [
		"UI/NavHeroes", "UI/NavBackpack", "UI/NavWarehouse",
	]:
		var button := menu.get_node(path) as Button
		assert_not_null(button, "%s 必须保留直接点击入口" % path)
		assert_true(button.visible)
	var codex := menu.get_node("UI/NavHeroes") as Button
	assert_eq(codex.text, "", "主菜单图鉴入口与战斗 UI 一致，不再保留文字")
	assert_true(codex.size.is_equal_approx(Vector2(108.0, 108.0)),
			"次要入口恢复为格子锚定式之前的完整方形按钮")
	assert_null(codex.get_node_or_null("Plate"), "图鉴入口不再使用主菜单长条羊皮板")
	var book := codex.get_node("BookIcon") as TextureRect
	assert_eq(book.texture.resource_path, "res://assets/ui/icons/codex_book.png",
			"合并入口使用战斗 UI 的书本图标")
	assert_true(book.size.is_equal_approx(Vector2(64.0, 64.0)),
			"完整方钮恢复原有图标占比")
	var bg := codex.get_node("Bg") as ColorRect
	assert_eq((bg.material as ShaderMaterial).shader.resource_path,
			"res://assets/shaders/canvas_button_jelly.gdshader")
	assert_eq((bg.material as ShaderMaterial).get_shader_parameter("fill_top"),
			Color(0.92, 0.87, 0.70), "底部按钮复用战斗UI奶油纸面上色")
	assert_not_null(codex.get_node_or_null("ButtonJuice"), "图鉴方钮复用战斗 UI 按压反馈")
	assert_not_null(codex.get_node_or_null("BottomShadow"), "图鉴方钮复用战斗 UI 下投影")
	assert_null(codex.get_node_or_null("GridAnchor"), "回退状态不得包含格子锚定描边")
	assert_null(menu.get_node_or_null("UI/NavItems"), "旧道具独立入口彻底退出场景")
	assert_null(menu.get_node_or_null("UI/NavShop"), "商店占位 UI 彻底退出场景")
	var backpack := menu.get_node("UI/NavBackpack") as Button
	assert_eq((backpack.get_node("Icon") as TextureRect).texture.resource_path,
			"res://assets/ui/icons/backpack.png")
	assert_null(backpack.get_node_or_null("Caption"))
	assert_eq(backpack.tooltip_text, "背包")
	var warehouse := menu.get_node("UI/NavWarehouse") as Button
	assert_eq(warehouse.text, "")
	assert_eq(warehouse.tooltip_text, "仓库")
	assert_not_null(warehouse.get_node_or_null("Icon"))
	var warehouse_overlay := menu.get_node("WarehouseOverlay") as WarehouseScreen
	assert_not_null(warehouse_overlay,
			"仓库入口必须打开真实浮层，不再保留占位点击")
	assert_false(warehouse_overlay.visible)
	assert_null(menu.get_node_or_null("UI/IdentityButton"))
	assert_null(menu.get_node_or_null("UI/QuitButton"))
	assert_null(menu.get_node_or_null("UI/SettingsButton"),
			"主界面不再显示设置齿轮入口")


func test_main_menu_escape_opens_the_shared_pause_menu() -> void:
	var menu: Control = _make_menu()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	menu._unhandled_input(escape)
	var pause := menu.get_node_or_null("PauseMenu") as CanvasLayer
	assert_not_null(pause)
	assert_gt(pause.layer, TransitionManager.layer,
			"主界面暂停层必须覆盖角色、传送石与全局过场画布")
	assert_true(get_tree().paused, "主界面 ESC 一级菜单应暂停世界动画")
	(pause as PauseMenuOverlay)._close()
	assert_false(get_tree().paused)


func test_pre_anchor_shortcut_stays_fully_visible_on_hover() -> void:
	var menu: Control = _make_menu()
	await get_tree().create_timer(1.1).timeout
	var codex := menu.get_node("UI/NavHeroes") as Button
	var home_position: Vector2 = codex.position
	assert_lte(codex.position.y + codex.size.y, MainMenuWorld.VIEW_SIZE.y,
			"前锚定版本的方钮必须完整处于屏幕内")
	codex.mouse_entered.emit()
	await get_tree().create_timer(0.14).timeout
	assert_true(codex.position.is_equal_approx(home_position),
			"前锚定版本没有边缘标签升降行为")
	codex.mouse_exited.emit()
	assert_true(codex.position.is_equal_approx(home_position))


func test_world_focus_only_changes_presentation_state() -> void:
	var menu: Control = _make_menu()
	var world: MainMenuWorld = menu.get_node("MenuWorld") as MainMenuWorld
	world.focus_destination("expedition")
	assert_eq(String(world.get("_focused_destination")), "",
			"直接底栏入口不再联动展示地图目的地")
	assert_true(bool(world.get_visual_contract()["presentation_only"]))
	world.focus_destination("")
	assert_eq(String(world.get("_focused_destination")), "")
