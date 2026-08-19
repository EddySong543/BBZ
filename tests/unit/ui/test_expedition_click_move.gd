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
