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
	assert_eq(beam_rect, Rect2(Vector2.ZERO, MainMenuWorld.VIEW_SIZE),
			"低分辨率光柱画布必须覆盖完整设计画面")
	assert_eq(base_rect.size, MainMenuWorld.RENDERED_CELL_SIZE * 3.0,
			"光柱底部必须覆盖中心3×3九格")
	assert_almost_eq(base_rect.get_center().x, MainMenuWorld.VIEW_SIZE.x * 0.5, 0.001)
	assert_almost_eq(base_rect.get_center().y, MainMenuWorld.VIEW_SIZE.y * 0.5, 0.001)
	assert_true(beam_rect.encloses(base_rect), "九格阵面必须位于贯穿屏幕顶部的光柱内部")
	assert_almost_eq(MainMenuWorld.PORTAL_BEAM_DURATION, 1.8, 0.001)
	assert_gte(MainMenuWorld.PORTAL_BEAM_PEAK_HOLD_RATIO, 0.08,
			"光柱冲顶后必须保留可读的峰值停留，不能立刻切场景")
	assert_false(world.portal_beam.visible)
	var procedural_contract: Dictionary = world.portal_beam.get_visual_contract()
	assert_eq(procedural_contract["implementation"],
			"ref44_contoured_pixel_portal_beam")
	assert_eq(procedural_contract["reference_profile"], "ref44")
	assert_true(bool(procedural_contract["uses_ref44_contour"]))
	assert_true(bool(procedural_contract["uses_single_connected_column"]))
	assert_true(bool(procedural_contract["uses_colored_outline"]))
	assert_true(bool(procedural_contract["uses_ivory_core"]))
	assert_false(bool(procedural_contract["uses_internal_cutouts"]))
	assert_true(bool(procedural_contract["uses_subviewport"]))
	assert_true(bool(procedural_contract["uses_runtime_viewport_texture"]))
	assert_false(bool(procedural_contract["uses_external_texture"]))
	assert_false(bool(procedural_contract["uses_shader"]))
	assert_false(bool(procedural_contract["uses_sprite_sheet"]))
	assert_false(bool(procedural_contract["uses_antialiasing"]))
	assert_false(bool(procedural_contract["uses_continuous_gradients"]))
	assert_false(bool(procedural_contract["uses_tapered_staircase_edges"]))
	assert_false(bool(procedural_contract["uses_full_frame_additive_blend"]))
	assert_true(bool(procedural_contract["uses_controlled_value_layers"]))
	assert_true(bool(procedural_contract["uses_connected_profile"]))
	assert_false(bool(procedural_contract["uses_full_body_rect"]))
	assert_false(bool(procedural_contract["uses_flat_top_cap"]))
	assert_true(bool(procedural_contract["uses_coherent_upward_streams"]))
	assert_false(bool(procedural_contract["uses_hash_mosaic"]))
	assert_false(bool(procedural_contract["uses_isolated_noise_chunks"]))
	assert_true(bool(procedural_contract["core_rises_before_body"]))
	assert_eq(procedural_contract["color_mode"], "ref44_purple_ivory")
	assert_eq(procedural_contract["outline_color"], Color("822B85"))
	assert_eq(procedural_contract["core_color"], Color("FDFCF7"))
	assert_between(float(procedural_contract["top_width_ratio"]), 0.52, 0.66)
	assert_eq(Vector2i(procedural_contract["logical_canvas_size"]),
			Vector2i(240, 135))
	assert_eq(int(procedural_contract["integer_scale"]), 8)
	assert_eq(int(procedural_contract["pixel_block_size_px"]), 8)
	assert_true(bool(procedural_contract["texture_filter_nearest"]))
	assert_eq(int(procedural_contract["animation_fps"]), 12)
	assert_eq(int(procedural_contract["palette_level_count"]), 5)
	assert_eq(int(procedural_contract["leading_prong_count"]), 1)
	assert_eq(int(procedural_contract["silhouette_state_count"]), 6)
	assert_eq(int(procedural_contract["beam_stage_count"]), 5)
	assert_gte(int(procedural_contract["column_layer_count"]), 4)
	assert_gte(int(procedural_contract["upward_stream_count"]), 5)
	assert_eq(int(procedural_contract["edge_tongue_count"]), 0)
	assert_gte(int(procedural_contract["base_pulse_ring_count"]), 3)
	assert_true(bool(procedural_contract["profile_spans_portal_width"]),
			"轮廓的活动边界必须覆盖中央三列，不能缩成中心一格")
	assert_true(bool(procedural_contract["base_spans_nine_cells"]),
			"底部爆发的活动边界必须横跨中央完整3×3阵面")
	assert_gte(float(procedural_contract["main_body_width_px"]), base_rect.size.x)
	world.complete_portal_connection(MainMenuWorld.PORTAL_ENERGY_GOLD)
	await world.play_portal_beam(MainMenuWorld.PORTAL_ENERGY_GOLD, 0.12)
	assert_true(world.portal_beam.visible)
	assert_almost_eq(float(world.portal_beam.beam_progress), 1.0, 0.001)
	assert_eq(world.portal_beam.beam_color, Color("C65FBF"),
			"石头继续使用模式色，光柱本体采用ref44的紫色轮廓")
	procedural_contract = world.portal_beam.get_visual_contract()
	assert_true(bool(procedural_contract["reaches_screen_top"]))
	var logical_base := Rect2i(procedural_contract["logical_base_rect"])
	var logical_body := Rect2i(procedural_contract["main_body_rect_logical"])
	assert_lte(logical_body.position.x, logical_base.position.x)
	assert_gte(logical_body.end.x, logical_base.end.x)
	assert_eq(logical_body.position.y, 0)
	assert_gt(int(procedural_contract["visible_upward_stream_count"]), 0,
			"柱体内部必须存在沿亮核上升的像素光痕")
	assert_eq(int(procedural_contract["visible_edge_tongue_count"]), 0,
			"ref44轮廓必须保持干净，不再挂接分散的边缘能量舌")
	world.set_process(false)
	world.portal_beam.set_anim_time(3.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var frame_a: Dictionary = world.portal_beam.get_runtime_pixel_metrics()
	world.portal_beam.set_anim_time(3.25)
	await get_tree().process_frame
	await get_tree().process_frame
	var frame_b: Dictionary = world.portal_beam.get_runtime_pixel_metrics()
	world.set_process(true)
	assert_true(bool(frame_a["image_ready"]), "低分辨率运行画布必须产生实际像素数据")
	assert_true(bool(frame_a["base_spans_full_rect"]),
			"九格底部爆发的活动边界必须覆盖完整阵面")
	assert_between(float(frame_a["base_coverage_ratio"]), 0.90, 1.0,
			"ref44式光柱底座必须完整覆盖九格阵面，不能退回零散白块")
	assert_eq(int(frame_a["covered_column_rows"]), logical_body.size.y,
			"实际渲染的光柱每一行都必须贯穿到屏幕顶端")
	assert_between(float(frame_a["column_fill_ratio"]), 0.85, 0.99,
			"连续柱体必须覆盖九格宽度，同时通过边缘起伏避免等宽长方形")
	assert_gte(int(frame_a["distinct_row_width_count"]), 4,
			"主体至少需要四种横截面宽度，不能仍是等宽长方形")
	assert_gt(int(frame_a["bright_pixel_count"]), 0,
			"紫色主体、浅紫内层和象牙白亮核必须形成可测量的亮度层次")
	assert_ne(int(frame_a["frame_signature"]), int(frame_b["frame_signature"]),
			"维持阶段的上行能流必须持续变化，不能冲顶后成为静态白块")
	assert_false(ResourceLoader.exists(
			"res://assets/shaders/canvas_ui_portal_beam.gdshader"),
			"程序化色带接管后不得继续保留旧光柱shader运行链")


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


func test_main_menu_uses_single_banner_and_pre_anchor_bottom_dock() -> void:
	var menu: Control = _make_menu()
	await get_tree().create_timer(1.1).timeout
	var expected_banner_rect := Rect2(Vector2(788.0, 916.0), Vector2(344.0, 108.0))
	var expected_switch_rect := Rect2(Vector2(1156.0, 934.0), Vector2(72.0, 72.0))
	assert_null(menu.get_node_or_null("UI/ModeMatch"))
	assert_null(menu.get_node_or_null("UI/ModeTower"))
	var banner_button := menu.get_node("UI/ModeBanner") as Button
	var switch_button := menu.get_node("UI/ModeSwitch") as Button
	assert_true(Rect2(banner_button.position, banner_button.size).is_equal_approx(
			expected_banner_rect), "中央Banner恢复到格子锚定式实施前的位置")
	assert_true(Rect2(switch_button.position, switch_button.size).is_equal_approx(
			expected_switch_rect), "模式切换钮恢复到Banner右侧的独立位置")
	assert_eq(banner_button.text, "")
	assert_eq(switch_button.text, "")
	var banner_art := banner_button.get_node("Banner") as TextureRect
	assert_eq(banner_art.texture.resource_path,
			"res://assets/ui/main_menu/battle_banner.png")
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
	assert_null(switch_button.get_node_or_null("Icon"),
			"模式切换不得继续使用语义含混的通用switch图标")
	var carousel_glyph := switch_button.get_node("CarouselGlyph") as Control
	assert_eq(int(carousel_glyph.get("selected_index")), 0)
	var switch_bg := switch_button.get_node("Bg") as ColorRect
	assert_eq((switch_bg.material as ShaderMaterial).shader.resource_path,
			"res://assets/shaders/canvas_button_jelly.gdshader")
	assert_almost_eq(float((switch_bg.material as ShaderMaterial).get_shader_parameter(
			"aspect")), 1.0, 0.001)
	assert_null(banner_button.get_node_or_null("GridAnchor"),
			"屏幕层UI不得继续描亮地面格子")
	var layout_contract: Dictionary = menu.call("get_bottom_ui_layout_contract")
	assert_eq(layout_contract["implementation"], "single_banner_bottom_dock")
	assert_false(bool(layout_contract["uses_continuous_bottom_bar"]))
	assert_true(bool(layout_contract["uses_separate_ui_islands"]))
	assert_false(bool(layout_contract["secondary_tabs_partially_offscreen"]))
	assert_true(bool(layout_contract["reuses_battle_ui_palette"]))
	assert_false(bool(layout_contract["switch_overlaps_banner_edge"]))
	assert_eq(banner_button.find_children("Banner", "TextureRect", true, false).size(), 1,
			"两个模式只能交换同一张Banner，不得同时挂两张图")
	switch_button.pressed.emit()
	assert_eq(banner_art.texture.resource_path,
			"res://assets/ui/main_menu/expedition_banner.png")
	assert_eq(int(carousel_glyph.get("selected_index")), 1,
			"轮播箭头与页码必须跟随当前模式反向")
	assert_eq((menu.get_node("UI/NavHeroes") as Button).position, Vector2(48.0, 916.0))
	assert_eq((menu.get_node("UI/NavBackpack") as Button).position, Vector2(1640.0, 916.0))
	assert_eq((menu.get_node("UI/NavWarehouse") as Button).position, Vector2(1772.0, 916.0))
	assert_eq((menu.get_node("UI/NetLobbyButton") as Button).position, Vector2(1652.0, 108.0))


func test_main_menu_merges_hero_and_item_codex_entry() -> void:
	var menu: Control = _make_menu()
	for path: String in [
		"UI/IdentityButton", "UI/SettingsButton", "UI/QuitButton",
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
	assert_eq(warehouse.tooltip_text, "仓库（占位）")
	assert_not_null(warehouse.get_node_or_null("Icon"))
	assert_not_null(menu.get_node_or_null("UI/IdentityButton/AvatarFrame"))


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


func test_match_state_uses_icon_and_blue_portal_energy_then_restores_on_cancel() -> void:
	var menu: Control = _make_menu()
	var match_entry := menu.get_node("UI/ModeBanner") as Button
	var world := menu.get_node("MenuWorld") as MainMenuWorld
	menu.call("_start_search")
	await get_tree().create_timer(1.15).timeout
	assert_null(match_entry.get_node_or_null("Caption"))
	assert_null(match_entry.get_node_or_null("Status"))
	assert_eq(match_entry.tooltip_text, "匹配中 0:01")
	assert_eq((match_entry.get_node("Banner") as TextureRect).self_modulate,
			Color("FFD4B8"))
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
	assert_eq((match_entry.get_node("Banner") as TextureRect).self_modulate,
			Color.WHITE)
	await get_tree().create_timer(0.35).timeout
	assert_almost_eq(float(world.get_visual_contract()["portal_energy_mix"]), 0.0, 0.001)
