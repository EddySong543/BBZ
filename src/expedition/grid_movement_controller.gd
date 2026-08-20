class_name GridMovementController
extends RefCounted

## 主界面与远征共用的格子移动核心：键盘立即提交逻辑格，点击路径逐格等待视觉落稳，
## 角色视觉以与远征一致的临界阻尼连续追赶最新目标。

signal step_committed(
		from_cell: Vector2i,
		to_cell: Vector2i,
		direction: Vector2i,
		result: Dictionary)
signal step_attempted(from_cell: Vector2i, direction: Vector2i, result: Dictionary)
signal movement_finished(cell: Vector2i, completed: bool)

const GridPathfinderScript := preload("res://src/expedition/grid_pathfinder.gd")

const CRITICAL_DAMPING: float = 18.0
const MAX_FRAME_STEP: float = 1.0 / 20.0
const SNAP_DISTANCE: float = 0.05
const LOGICAL_PIXEL_STEP: float = 5.0
const HOP_STEPS: float = 2.0
const WOBBLE_AMPLITUDE: float = 0.026
const TURN_SWITCH_PROGRESS: float = 0.38
const TURN_SQUEEZE_MIN: float = 0.82
const TURN_SCALE_STEP: float = 0.05

var bounds: Rect2i
var cell_size: float
var token_offset: Vector2
var current_cell: Vector2i
var visual_origin: Vector2 = Vector2.ZERO
var target_origin: Vector2 = Vector2.ZERO
var visual_velocity: Vector2 = Vector2.ZERO
var initialized: bool = false

var step_active: bool = false
var step_start_origin: Vector2 = Vector2.ZERO
var step_target_origin: Vector2 = Vector2.ZERO
var step_direction: Vector2 = Vector2.ZERO
var step_side: float = 1.0
var facing_sign: float = 1.0
var turn_from_sign: float = 1.0
var turn_target_sign: float = 1.0
var turn_active: bool = false

var route_active: bool = false
var last_result_kind: String = ""

var _can_enter: Callable
var _commit_step: Callable
var _route: Array[Vector2i] = []
var _route_destination: Vector2i = Vector2i(-1, -1)
var _keyboard_finish_pending: bool = false


func configure(initial_cell: Vector2i, movement_bounds: Rect2i, p_cell_size: float,
		p_token_offset: Vector2, can_enter: Callable, commit_step: Callable) -> void:
	bounds = movement_bounds
	cell_size = p_cell_size
	token_offset = p_token_offset
	_can_enter = can_enter
	_commit_step = commit_step
	snap_to_cell(initial_cell)


func snap_to_cell(cell: Vector2i) -> void:
	current_cell = cell
	visual_origin = token_origin_for_cell(cell)
	target_origin = visual_origin
	visual_velocity = Vector2.ZERO
	initialized = true
	step_active = false
	turn_active = false
	cancel_route()
	_keyboard_finish_pending = false


func adopt_committed_cell(cell: Vector2i, direction: Vector2i) -> void:
	if not initialized:
		snap_to_cell(cell)
		return
	if cell == current_cell:
		return
	current_cell = cell
	_begin_visual_step(token_origin_for_cell(cell), direction)


func request_keyboard_step(direction: Vector2i) -> String:
	if absi(direction.x) + absi(direction.y) != 1:
		return "blocked"
	cancel_route()
	last_result_kind = _commit_direction(direction)
	_keyboard_finish_pending = true
	return last_result_kind


func request_path(destination: Vector2i) -> bool:
	if not bounds.has_point(destination) or not bool(_can_enter.call(destination)):
		return false
	_route = GridPathfinderScript.find_path(
			current_cell, destination, bounds, _can_enter)
	if destination != current_cell and _route.is_empty():
		movement_finished.emit(current_cell, false)
		return false
	_route_destination = destination
	route_active = true
	_keyboard_finish_pending = false
	return true


func cancel_route() -> void:
	_route.clear()
	route_active = false
	_route_destination = Vector2i(-1, -1)


func process(delta: float) -> void:
	_step_visual(delta)
	if is_moving():
		return
	if route_active:
		if _route.is_empty():
			var completed: bool = current_cell == _route_destination
			route_active = false
			movement_finished.emit(current_cell, completed)
			return
		var next_cell: Vector2i = _route.pop_front()
		var result_kind: String = _commit_direction(next_cell - current_cell)
		if result_kind != "move":
			_route.clear()
		return
	if _keyboard_finish_pending:
		_keyboard_finish_pending = false
		movement_finished.emit(current_cell, last_result_kind != "blocked")


func is_moving() -> bool:
	return initialized and visual_origin.distance_squared_to(target_origin) \
			> SNAP_DISTANCE * SNAP_DISTANCE


func token_origin_for_cell(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size + token_offset


func quantized_visual_origin() -> Vector2:
	return token_offset + (
			(visual_origin - token_offset) / LOGICAL_PIXEL_STEP).round() * LOGICAL_PIXEL_STEP


func step_progress() -> float:
	var travel: Vector2 = step_target_origin - step_start_origin
	var length_squared: float = travel.length_squared()
	if length_squared <= 0.01:
		return 1.0
	return clampf((visual_origin - step_start_origin).dot(travel) / length_squared, 0.0, 1.0)


func step_offset() -> Vector2:
	if not step_active:
		return Vector2.ZERO
	var progress: float = step_progress()
	var arc: float = sin(progress * PI)
	var hop_steps: float = round(arc * HOP_STEPS)
	var lead_steps: float = round(arc)
	var turn_lean_steps: float = round(arc) if turn_active else 0.0
	return Vector2(
			step_direction.x * (lead_steps + turn_lean_steps) * LOGICAL_PIXEL_STEP,
			-hop_steps * LOGICAL_PIXEL_STEP)


func token_scale(render_compensation: float = 1.0) -> Vector2:
	var progress: float = step_progress()
	var rendered_facing: float = facing_sign
	var squeeze: float = 1.0
	var lift: float = 1.0
	if turn_active:
		if progress < TURN_SWITCH_PROGRESS:
			squeeze = lerpf(1.0, TURN_SQUEEZE_MIN, progress / TURN_SWITCH_PROGRESS)
			rendered_facing = turn_from_sign
		else:
			squeeze = lerpf(TURN_SQUEEZE_MIN, 1.0,
					(progress - TURN_SWITCH_PROGRESS) / (1.0 - TURN_SWITCH_PROGRESS))
			rendered_facing = turn_target_sign
		lift = 1.0 + sin(progress * PI) * 0.05
		squeeze = round(squeeze / TURN_SCALE_STEP) * TURN_SCALE_STEP
		lift = round(lift / TURN_SCALE_STEP) * TURN_SCALE_STEP
	return Vector2(
			render_compensation * squeeze * rendered_facing,
			render_compensation * lift)


func token_rotation() -> float:
	if not step_active:
		return 0.0
	var progress: float = step_progress()
	var alternating: float = sin(progress * TAU) * step_side
	var directional: float = sin(progress * PI) * step_direction.x * 0.35
	return (alternating + directional) * WOBBLE_AMPLITUDE


static func direction_from_key(event: InputEvent) -> Vector2i:
	if not (event is InputEventKey) or not event.pressed:
		return Vector2i.ZERO
	match (event as InputEventKey).keycode:
		KEY_W, KEY_UP:
			return Vector2i.UP
		KEY_S, KEY_DOWN:
			return Vector2i.DOWN
		KEY_A, KEY_LEFT:
			return Vector2i.LEFT
		KEY_D, KEY_RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.ZERO


func _commit_direction(direction: Vector2i) -> String:
	var target_cell: Vector2i = current_cell + direction
	if absi(direction.x) + absi(direction.y) != 1 or not bounds.has_point(target_cell):
		last_result_kind = "blocked"
		step_attempted.emit(current_cell, direction, {
			"moved": false,
			"kind": last_result_kind,
			"msgs": [],
		})
		return last_result_kind
	var from_cell: Vector2i = current_cell
	var result_value: Variant = _commit_step.call(direction)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	if not bool(result.get("moved", false)):
		last_result_kind = String(result.get("kind", "blocked"))
		step_attempted.emit(from_cell, direction, result)
		return last_result_kind
	current_cell = Vector2i(result.get("cell", target_cell))
	last_result_kind = String(result.get("kind", "move"))
	_begin_visual_step(token_origin_for_cell(current_cell), direction)
	step_attempted.emit(from_cell, direction, result)
	step_committed.emit(from_cell, current_cell, direction, result)
	return last_result_kind


func _begin_visual_step(next_target: Vector2, direction: Vector2i) -> void:
	if next_target.distance_squared_to(target_origin) <= 0.01:
		return
	_settle_in_progress_facing()
	step_start_origin = visual_origin
	step_target_origin = next_target
	step_direction = Vector2(direction).normalized()
	turn_from_sign = facing_sign
	turn_target_sign = signf(float(direction.x)) if direction.x != 0 else facing_sign
	turn_active = not is_equal_approx(turn_target_sign, facing_sign)
	step_side *= -1.0
	step_active = true
	target_origin = next_target


func _settle_in_progress_facing() -> void:
	if not turn_active:
		return
	facing_sign = turn_target_sign if step_progress() >= TURN_SWITCH_PROGRESS else turn_from_sign
	turn_active = false


func _step_visual(delta: float) -> void:
	if not initialized:
		return
	var remaining: Vector2 = target_origin - visual_origin
	if remaining.length_squared() <= SNAP_DISTANCE * SNAP_DISTANCE:
		visual_origin = target_origin
		visual_velocity = Vector2.ZERO
		_finish_step_visuals()
		return
	var frame_step: float = clampf(delta, 0.0, MAX_FRAME_STEP)
	if frame_step <= 0.0:
		return
	var displacement: Vector2 = visual_origin - target_origin
	var decay: float = exp(-CRITICAL_DAMPING * frame_step)
	var velocity_term: Vector2 = (
			visual_velocity + displacement * CRITICAL_DAMPING) * frame_step
	var next_position: Vector2 = (
			target_origin + (displacement + velocity_term) * decay)
	var next_velocity: Vector2 = (
			visual_velocity - velocity_term * CRITICAL_DAMPING) * decay
	if remaining.dot(next_position - target_origin) > 0.0:
		next_position = target_origin
		next_velocity = Vector2.ZERO
	elif next_position.distance_squared_to(target_origin) \
			<= SNAP_DISTANCE * SNAP_DISTANCE:
		next_position = target_origin
		next_velocity = Vector2.ZERO
	visual_origin = next_position
	visual_velocity = next_velocity
	if visual_origin == target_origin:
		_finish_step_visuals()


func _finish_step_visuals() -> void:
	if turn_active:
		facing_sign = turn_target_sign
	turn_active = false
	step_active = false
