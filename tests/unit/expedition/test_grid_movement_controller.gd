extends GutTest

const GridMovementControllerScript := preload(
		"res://src/expedition/grid_movement_controller.gd")

var _committed_cell: Vector2i


func _can_enter(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, Vector2i(8, 8)).has_point(cell)


func _commit(direction: Vector2i) -> Dictionary:
	_committed_cell += direction
	return {"moved": true, "kind": "move", "cell": _committed_cell}


func test_repeated_keys_keep_only_one_buffered_step_instead_of_flying() -> void:
	_committed_cell = Vector2i(4, 4)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter, _commit)
	var start_origin: Vector2 = movement.visual_origin
	assert_eq(movement.request_keyboard_step(Vector2i.UP), "move")
	assert_eq(movement.request_keyboard_step(Vector2i.UP), "queued")
	assert_eq(movement.request_keyboard_step(Vector2i.RIGHT), "queued",
			"连续回显只能替换一个缓冲步，不能一次提交整串格子")
	assert_eq(movement.current_cell, Vector2i(4, 3))
	assert_eq(movement.target_origin, movement.token_origin_for_cell(Vector2i(4, 3)))
	assert_eq(movement.visual_origin, start_origin,
			"第一步逻辑提交后，视觉仍从原位置连续追赶")

	for frame: int in 180:
		movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(5, 3),
			"三次快速输入最多执行当前步与最后一个缓冲步")
	assert_false(movement.is_moving())
	assert_almost_eq(movement.visual_origin.x, movement.target_origin.x, 0.05)
	assert_almost_eq(movement.visual_origin.y, movement.target_origin.y, 0.05)


func test_click_route_chains_straight_steps_before_a_full_stop() -> void:
	_committed_cell = Vector2i(2, 2)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter, _commit)
	assert_true(movement.request_path(Vector2i(5, 2)))
	movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(3, 2))
	var chained_while_moving: bool = false
	for _frame: int in 120:
		movement.process(1.0 / 60.0)
		if movement.current_cell == Vector2i(4, 2) and movement.is_moving():
			chained_while_moving = true
			break
	assert_true(chained_while_moving,
			"直线路径应在接近格心时衔接下一格，不能每格落稳后停一拍")
	for _frame: int in 360:
		movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(5, 2))
	assert_false(movement.route_active)
	assert_true(movement.is_motion_settled())


func test_motion_settled_rejects_pending_route_before_visual_motion_starts() -> void:
	_committed_cell = Vector2i(2, 2)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter, _commit)
	assert_true(movement.is_motion_settled())
	assert_true(movement.request_path(Vector2i(3, 2)))
	assert_false(movement.is_moving(),
			"路径刚获批但尚未process时，视觉坐标还没有开始变化")
	assert_false(movement.is_motion_settled(),
			"待启动路径同样必须拦住缩放，不能漏掉首帧竞态")
	movement.process(1.0 / 60.0)
	assert_true(movement.is_moving())
	assert_false(movement.is_motion_settled())
	for _frame: int in 360:
		movement.process(1.0 / 60.0)
	assert_true(movement.is_motion_settled(),
			"路径与视觉跟随全部结束后才重新允许缩放")


func test_click_route_chains_a_turn_without_waiting_for_full_settle() -> void:
	_committed_cell = Vector2i(2, 2)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter, _commit)
	assert_true(movement.request_path(Vector2i(3, 3)))
	movement.process(1.0 / 60.0)
	assert_eq(movement.current_cell, Vector2i(3, 2))
	var turn_chained_while_moving: bool = false
	for _frame: int in 120:
		movement.process(1.0 / 60.0)
		if movement.current_cell == Vector2i(3, 3) and movement.is_moving():
			turn_chained_while_moving = true
			break
	assert_true(turn_chained_while_moving,
			"转向应在接近格心时继承速度，不能等待临界阻尼完全归零后停一拍")


func test_blocked_horizontal_attempt_updates_facing_without_moving() -> void:
	_committed_cell = Vector2i(4, 4)
	var movement: GridMovementController = GridMovementControllerScript.new()
	movement.configure(
			_committed_cell, Rect2i(Vector2i.ZERO, Vector2i(8, 8)),
			120.0, Vector2(-44.0, -66.0), _can_enter,
			func(_direction: Vector2i) -> Dictionary:
				return {"moved": false, "kind": "blocked", "cell": _committed_cell})
	movement.facing_sign = -1.0
	assert_eq(movement.request_keyboard_step(Vector2i.RIGHT), "blocked")
	assert_eq(movement.current_cell, Vector2i(4, 4))
	assert_eq(movement.facing_sign, 1.0,
			"撞上右侧障碍时角色仍须先朝右，不能背对障碍播放阻挡动画")


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
