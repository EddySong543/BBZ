extends GutTest

const GridMovementControllerScript := preload(
		"res://src/expedition/grid_movement_controller.gd")

var _committed_cell: Vector2i


func _can_enter(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, Vector2i(8, 8)).has_point(cell)


func _commit(direction: Vector2i) -> Dictionary:
	_committed_cell += direction
	return {"moved": true, "kind": "move", "cell": _committed_cell}


func test_repeated_keys_commit_immediately_and_share_one_continuous_target() -> void:
	_committed_cell = Vector2i(4, 4)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter, _commit)
	var start_origin: Vector2 = movement.visual_origin
	for direction: Vector2i in [Vector2i.UP, Vector2i.UP, Vector2i.RIGHT]:
		assert_eq(movement.request_keyboard_step(direction), "move")
	assert_eq(movement.current_cell, Vector2i(5, 2))
	assert_eq(movement.target_origin, movement.token_origin_for_cell(Vector2i(5, 2)))
	assert_eq(movement.visual_origin, start_origin,
			"连续输入不得为每一步启动互相阻塞的 Tween")

	var previous_distance: float = movement.visual_origin.distance_to(movement.target_origin)
	for frame: int in 180:
		movement.process(1.0 / 60.0)
		var current_distance: float = movement.visual_origin.distance_to(movement.target_origin)
		assert_lte(current_distance, previous_distance + 0.001,
				"共享临界阻尼不得过冲：frame=%d" % frame)
		previous_distance = current_distance
	assert_false(movement.is_moving())
	assert_almost_eq(movement.visual_origin.x, movement.target_origin.x, 0.05)
	assert_almost_eq(movement.visual_origin.y, movement.target_origin.y, 0.05)


func test_click_route_waits_for_each_visual_step_before_committing_next_cell() -> void:
	_committed_cell = Vector2i(2, 2)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter, _commit)
	assert_true(movement.request_path(Vector2i(5, 2)))
	movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(3, 2))
	for _frame: int in 4:
		movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(3, 2),
			"点击寻路必须逐格等待视觉落稳，不能瞬间结算整条路径")
	for _frame: int in 360:
		movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(5, 2))
	assert_false(movement.route_active)


func test_wasd_and_arrow_keys_use_the_same_shared_parser() -> void:
	for key_and_direction: Array in [
		[KEY_W, Vector2i.UP], [KEY_UP, Vector2i.UP],
		[KEY_S, Vector2i.DOWN], [KEY_DOWN, Vector2i.DOWN],
		[KEY_A, Vector2i.LEFT], [KEY_LEFT, Vector2i.LEFT],
		[KEY_D, Vector2i.RIGHT], [KEY_RIGHT, Vector2i.RIGHT],
	]:
		var event := InputEventKey.new()
		event.keycode = int(key_and_direction[0])
		event.pressed = true
		assert_eq(GridMovementControllerScript.direction_from_key(event),
				Vector2i(key_and_direction[1]))
