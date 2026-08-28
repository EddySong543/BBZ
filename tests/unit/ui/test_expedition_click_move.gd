extends GutTest

const EXPEDITION_SCENE_PATH := "res://src/expedition/expedition_screen.tscn"
const HeroDataScript := preload("res://src/battle/hero_data.gd")


func test_left_click_moves_one_grid_cell_through_existing_map_rules() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[0])
	await get_tree().process_frame
	assert_eq(screen._grid_movement.get_script().resource_path,
			"res://src/expedition/grid_movement_controller.gd",
			"远征与主界面必须引用同一移动控制器，不能再保留两套手感逻辑")

	var start: Vector2i = screen.map.player
	var target := Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if screen._is_walkable_map_cell(start + direction):
			target = start + direction
			break
	assert_ne(target, Vector2i(-1, -1), "出生点周围必须至少有一个可走格")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen._map_view_position_for_cell(target)
	assert_eq(screen._cell_from_map_view_position(click.position), target)
	screen._on_map_view_gui_input(click)
	await screen.movement_finished
	await get_tree().process_frame

	assert_eq(screen.map.player, target)
	assert_eq(screen.map.steps, 1, "自动移动每一步必须复用远征行动规则")
	assert_false(screen._click_route_active)
	assert_true(screen.map_view.gui_input.is_connected(screen._on_map_view_gui_input))
	BattleSetup.reset()


func test_mouse_wheel_zoom_remains_available_during_route_motion() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[0])
	await get_tree().process_frame
	var start: Vector2i = screen.map.player
	var target := Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if screen._is_walkable_map_cell(start + direction):
			target = start + direction
			break
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen._map_view_position_for_cell(target)
	screen._on_map_view_gui_input(click)
	assert_true(screen._grid_movement.route_active)

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	screen._on_map_view_gui_input(wheel_up)
	assert_eq(Vector2i(screen.get_zoom_contract()["current_grid"]), Vector2i(19, 11),
			"PVE角色移动中也必须接收滚轮缩放")
	screen._advance_view_zoom(screen.ZOOM_TRANSITION_DURATION)
	assert_lte(screen.map_world.scale.distance_to(Vector2(16.0 / 19.0, 9.0 / 11.0)), 0.001)
	BattleSetup.reset()


func test_left_click_still_targets_the_exact_cell_at_closest_zoom() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[0])
	await get_tree().process_frame
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	for _step: int in 2:
		screen._on_map_view_gui_input(wheel_up)
		screen._advance_view_zoom(screen.ZOOM_TRANSITION_DURATION)

	var start: Vector2i = screen.map.player
	var target := Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if screen._is_walkable_map_cell(start + direction):
			target = start + direction
			break
	assert_ne(target, Vector2i(-1, -1))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen._map_view_position_for_cell(target)
	assert_eq(screen._cell_from_map_view_position(click.position), target)
	screen._on_map_view_gui_input(click)
	await screen.movement_finished
	await get_tree().process_frame
	assert_eq(screen.map.player, target,
			"最近缩放档不得让点击移动落到相邻格")
	BattleSetup.reset()


func test_expedition_hover_previews_target_and_wasd_does_not_move() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[0])
	await get_tree().process_frame
	var start: Vector2i = screen.map.player
	var target := Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if screen._is_walkable_map_cell(start + direction):
			target = start + direction
			break
	assert_ne(target, Vector2i(-1, -1))
	var motion := InputEventMouseMotion.new()
	motion.position = screen._map_view_position_for_cell(target)
	screen._on_map_view_gui_input(motion)
	assert_eq(Vector2i(screen.get("_hovered_map_cell")), target)
	assert_gt((screen.get("_hovered_map_path") as Array).size(), 0)
	assert_true(screen.route_target_outline.visible)
	assert_eq(screen.route_target_outline.position,
			Vector2(target) * float(screen.MAP_CELL))
	assert_eq(screen.route_target_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_grid_target_outline.gdshader")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	screen._unhandled_input(key)
	await get_tree().process_frame
	assert_eq(screen.map.player, start,
			"远征模式的WASD与方向键不得再触发移动")
	BattleSetup.reset()
