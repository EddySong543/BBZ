class_name Scene7CrystalTortoise
extends Node2D

## Scene7-only code-drawn fantasy visitor. The resonance starts one visit;
## battle state only requests the same shell-first exit ahead of schedule.

signal visit_started()
signal exit_started(interrupted_by_attack: bool)
signal visit_finished()

enum VisitState {
	HIDDEN,
	ROLLING_IN,
	LOOKING,
	ROLLING_OUT,
}

const DRAW_PIXEL: float = 4.0
const BODY_SIZE: Vector2 = Vector2(88.0, 44.0)
const ART_DRAW_OFFSET: Vector2 = Vector2(0.0, -8.0)
const SCREEN_LEFT_X: float = -48.0
const SCREEN_RIGHT_X: float = 1968.0
const STOP_X_MIN: float = 800.0
const STOP_X_MAX: float = 1120.0
const DEFAULT_STOP_Y_MIN: float = 760.0
const DEFAULT_STOP_Y_MAX: float = 788.0
const DEFAULT_STOP_Y_CENTER: float = 774.0
const MIN_STOP_SEPARATION: float = 56.0
const MIN_STOP_Y_SEPARATION: float = 8.0
const ROTATION_STEP: float = PI / 8.0
const ROLLING_CONTACT_OFFSET_PX: float = 24.0
const SHELL_OUTLINE := Color(0.075, 0.16, 0.14, 1.0)
const SHELL_DEEP := Color(0.11, 0.30, 0.25, 1.0)
const SHELL_MID := Color(0.18, 0.52, 0.39, 1.0)
const SHELL_GREEN := Color(0.26, 0.72, 0.50, 1.0)
const SHELL_LIGHT := Color(0.43, 0.92, 0.65, 1.0)
const BODY_DARK := Color(0.18, 0.16, 0.11, 1.0)
const BODY_SHADOW := Color(0.32, 0.30, 0.18, 1.0)
const BODY_SAND := Color(0.57, 0.50, 0.30, 1.0)
const EYE_COLOR := Color(0.92, 0.77, 0.42, 1.0)
const SHELL_GLOW_COLOR := Color(0.34, 0.94, 0.66, 1.0)
const SHADOW_EDGE := Color(0.075, 0.13, 0.09, 0.14)
const SHADOW_CORE := Color(0.055, 0.105, 0.075, 0.24)
const GLOW_BASE_ALPHA: float = 0.07
const GLOW_PEAK_ALPHA: float = 0.18

# Pixel runs use grid-space x, y, width and height. They author a readable
# sprite-like silhouette while remaining transformable procedural drawing.
const SHELL_OUTLINE_RUNS: Array[Vector4] = [
	Vector4(-2, -5, 5, 1),
	Vector4(-4, -4, 9, 1),
	Vector4(-5, -3, 11, 1),
	Vector4(-6, -2, 13, 1),
	Vector4(-7, -1, 15, 1),
	Vector4(-7, 0, 15, 1),
	Vector4(-7, 1, 15, 1),
	Vector4(-6, 2, 13, 1),
	Vector4(-5, 3, 11, 1),
	Vector4(-3, 4, 7, 1),
]
const SHELL_FILL_RUNS: Array[Vector4] = [
	Vector4(-2, -4, 5, 1),
	Vector4(-4, -3, 9, 1),
	Vector4(-5, -2, 11, 1),
	Vector4(-6, -1, 13, 1),
	Vector4(-6, 0, 13, 1),
	Vector4(-6, 1, 13, 1),
	Vector4(-5, 2, 11, 1),
	Vector4(-4, 3, 9, 1),
]
const SHELL_LOWER_RUNS: Array[Vector4] = [
	Vector4(-5, 2, 4, 1),
	Vector4(2, 2, 3, 1),
	Vector4(-4, 3, 9, 1),
]
const SHELL_GREEN_RUNS: Array[Vector4] = [
	Vector4(-2, -4, 4, 1),
	Vector4(-4, -3, 3, 1),
	Vector4(1, -3, 4, 1),
	Vector4(-5, -2, 3, 1),
	Vector4(2, -2, 3, 1),
	Vector4(-4, -1, 3, 1),
	Vector4(2, 0, 3, 1),
	Vector4(-4, 1, 2, 1),
]
const SHELL_LIGHT_RUNS: Array[Vector4] = [
	Vector4(-1, -4, 2, 1),
	Vector4(-3, -3, 2, 1),
	Vector4(2, -3, 2, 1),
	Vector4(-4, -2, 1, 1),
	Vector4(3, -2, 1, 1),
	Vector4(3, 0, 1, 1),
]
const SHELL_SEAM_RUNS: Array[Vector4] = [
	Vector4(0, -3, 1, 5),
	Vector4(-4, -1, 4, 1),
	Vector4(1, -1, 4, 1),
	Vector4(-3, 2, 3, 1),
	Vector4(1, 2, 3, 1),
]
const SHELL_CONTOUR_GLOW_RUNS: Array[Vector4] = [
	Vector4(-2, -6, 2, 1),
	Vector4(1, -6, 2, 1),
	Vector4(-5, -5, 2, 1),
	Vector4(4, -5, 2, 1),
	Vector4(-7, -3, 1, 1),
	Vector4(7, -3, 1, 1),
	Vector4(-8, -1, 1, 1),
	Vector4(8, 0, 1, 1),
	Vector4(-7, 3, 1, 1),
	Vector4(6, 3, 1, 1),
	Vector4(-4, 5, 2, 1),
	Vector4(2, 5, 2, 1),
]
const HEAD_OUTLINE_RUNS_LEFT: Array[Vector4] = [
	Vector4(-9, -3, 2, 1),
	Vector4(-11, -2, 4, 1),
	Vector4(-13, -1, 6, 1),
	Vector4(-13, 0, 6, 1),
	Vector4(-12, 1, 5, 1),
]
const HEAD_FILL_RUNS_LEFT: Array[Vector4] = [
	Vector4(-9, -2, 2, 1),
	Vector4(-11, -1, 4, 1),
	Vector4(-12, 0, 5, 1),
	Vector4(-11, 1, 3, 1),
]
const HEAD_LIGHT_RUNS_LEFT: Array[Vector4] = [
	Vector4(-9, -2, 1, 1),
	Vector4(-10, -1, 2, 1),
	Vector4(-11, 0, 2, 1),
]
const HEAD_DETAIL_RUNS_LEFT: Array[Vector4] = [
	Vector4(-13, 0, 2, 1),
	Vector4(-11, 1, 2, 1),
]
const FAR_LEG_RUNS: Array[Vector4] = [
	Vector4(-3, 3, 2, 3),
	Vector4(2, 3, 2, 3),
]
const NEAR_LEG_RUNS: Array[Vector4] = [
	Vector4(-7, 3, 3, 3),
	Vector4(5, 3, 3, 3),
]
const LEG_FILL_RUNS: Array[Vector4] = [
	Vector4(-6, 4, 2, 1),
	Vector4(5, 4, 2, 1),
	Vector4(-7, 5, 2, 1),
	Vector4(-3, 5, 2, 1),
	Vector4(2, 5, 2, 1),
	Vector4(6, 5, 2, 1),
]
const CONTACT_SHADOW_EDGE_RUNS: Array[Vector4] = [
	Vector4(-7, 6, 4, 1),
	Vector4(-2, 6, 5, 1),
	Vector4(4, 6, 3, 1),
	Vector4(-5, 8, 3, 1),
	Vector4(1, 8, 4, 1),
]
const CONTACT_SHADOW_CORE_RUNS: Array[Vector4] = [
	Vector4(-6, 7, 5, 1),
	Vector4(0, 7, 6, 1),
]
const ROLLING_SHADOW_EDGE_RUNS: Array[Vector4] = [
	Vector4(-4, 7, 3, 1),
	Vector4(0, 7, 4, 1),
]
const ROLLING_SHADOW_CORE_RUNS: Array[Vector4] = [
	Vector4(-2, 8, 5, 1),
]

@export_group("Platform Placement")
@export_range(720.0, 820.0, 4.0) var stop_y_min: float = DEFAULT_STOP_Y_MIN
@export_range(720.0, 820.0, 4.0) var stop_y_max: float = DEFAULT_STOP_Y_MAX
@export_group("Visit Behavior")
@export_range(480.0, 1000.0, 20.0) var roll_speed_px_per_sec: float = 760.0
@export_range(0.8, 2.0, 0.05) var look_interval_sec: float = 1.25
@export_range(0.0, 1.0, 0.01) var resonance_visit_probability: float = 0.20
@export var resonance_path: NodePath = NodePath("../OasisResonance")

var _state: VisitState = VisitState.HIDDEN
var _state_age: float = 0.0
var _visual_position: Vector2 = Vector2(SCREEN_LEFT_X, DEFAULT_STOP_Y_CENTER)
var _target_stop_position: Vector2 = Vector2(960.0, DEFAULT_STOP_Y_CENTER)
var _travel_origin: Vector2 = Vector2.ZERO
var _travel_target: Vector2 = Vector2.ZERO
var _travel_duration: float = 1.0
var _travel_turns: int = 2
var _rotation_origin: float = 0.0
var _shell_rotation: float = 0.0
var _entered_from_left: bool = true
var _initial_look_direction: int = 1
var _look_direction: int = 1
var _visit_count: int = 0
var _completed_exit_count: int = 0
var _last_exit_was_attack: bool = false
var _has_previous_side: bool = false
var _previous_side_was_left: bool = true
var _same_side_streak: int = 0
var _has_previous_stop: bool = false
var _previous_stop_x: float = 960.0
var _has_previous_stop_y: bool = false
var _previous_stop_y: float = DEFAULT_STOP_Y_CENTER
var _next_spawn_roll_override: float = -1.0
var _resonance: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_resonance = get_node_or_null(resonance_path)
	if _resonance != null:
		if _resonance.has_signal(&"resonance_started"):
			_resonance.connect(
					&"resonance_started", Callable(self, "_on_resonance_started"))
		if _resonance.has_signal(&"countdown_idle_closed"):
			_resonance.connect(
					&"countdown_idle_closed", Callable(self, "request_exit"))
	visible = false
	set_process(false)


func _on_resonance_started() -> void:
	var spawn_roll := _rng.randf()
	if _next_spawn_roll_override >= 0.0:
		spawn_roll = _next_spawn_roll_override
		_next_spawn_roll_override = -1.0
	if spawn_roll < resonance_visit_probability:
		start_visit()


func start_visit() -> void:
	if _state != VisitState.HIDDEN:
		return
	_choose_visit_geometry()
	_state = VisitState.ROLLING_IN
	_state_age = 0.0
	_visual_position = Vector2(
			SCREEN_LEFT_X if _entered_from_left else SCREEN_RIGHT_X,
			_target_stop_position.y)
	_shell_rotation = 0.0
	_configure_travel(_visual_position, _target_stop_position)
	_visit_count += 1
	_last_exit_was_attack = false
	visible = true
	set_process(true)
	queue_redraw()
	visit_started.emit()


func request_exit(interrupted_by_attack: bool) -> void:
	if _state == VisitState.HIDDEN or _state == VisitState.ROLLING_OUT:
		return
	_state = VisitState.ROLLING_OUT
	_state_age = 0.0
	_last_exit_was_attack = interrupted_by_attack
	var exit_x := SCREEN_LEFT_X if _entered_from_left else SCREEN_RIGHT_X
	_configure_travel(
			_visual_position, Vector2(exit_x, _target_stop_position.y))
	set_process(true)
	queue_redraw()
	exit_started.emit(interrupted_by_attack)


func _process(delta: float) -> void:
	_state_age += delta
	match _state:
		VisitState.ROLLING_IN:
			_update_rolling_travel(true)
		VisitState.LOOKING:
			_visual_position = _target_stop_position
			var look_index := int(floor(_state_age / look_interval_sec))
			_look_direction = _initial_look_direction \
					if look_index % 2 == 0 else -_initial_look_direction
		VisitState.ROLLING_OUT:
			_update_rolling_travel(false)
		_:
			pass
	if _state != VisitState.HIDDEN:
		queue_redraw()


func _update_rolling_travel(rolling_in: bool) -> void:
	var linear_progress := clampf(_state_age / _travel_duration, 0.0, 1.0)
	var travel_progress := _ease_out_quadratic(linear_progress) if rolling_in \
			else _ease_in_quadratic(linear_progress)
	_visual_position = _travel_origin.lerp(_travel_target, travel_progress)
	_visual_position = _visual_position.round()
	var direction_sign := signf(_travel_target.x - _travel_origin.x)
	var raw_rotation := _rotation_origin \
			+ travel_progress * float(_travel_turns) * TAU * direction_sign
	_shell_rotation = roundf(raw_rotation / ROTATION_STEP) * ROTATION_STEP
	if linear_progress < 1.0:
		return
	if rolling_in:
		_state = VisitState.LOOKING
		_state_age = 0.0
		_visual_position = _target_stop_position
		_shell_rotation = 0.0
		_look_direction = _initial_look_direction
	else:
		_finish_exit()


func _choose_visit_geometry() -> void:
	var candidate_side := _rng.randi_range(0, 1) == 0
	if _has_previous_side and candidate_side == _previous_side_was_left \
			and _same_side_streak >= 2:
		candidate_side = not candidate_side
	_entered_from_left = candidate_side
	if _has_previous_side and _entered_from_left == _previous_side_was_left:
		_same_side_streak += 1
	else:
		_same_side_streak = 1
	_previous_side_was_left = _entered_from_left
	_has_previous_side = true

	var candidate_x := _rng.randf_range(STOP_X_MIN, STOP_X_MAX)
	if _has_previous_stop \
			and absf(candidate_x - _previous_stop_x) < MIN_STOP_SEPARATION:
		var shift_sign := 1.0 \
				if _previous_stop_x <= (STOP_X_MIN + STOP_X_MAX) * 0.5 else -1.0
		candidate_x = _previous_stop_x + shift_sign * (
				MIN_STOP_SEPARATION + _rng.randf_range(8.0, 28.0))
	candidate_x = clampf(candidate_x, STOP_X_MIN, STOP_X_MAX)
	candidate_x = roundf(candidate_x / DRAW_PIXEL) * DRAW_PIXEL
	var stop_y_lower := minf(stop_y_min, stop_y_max)
	var stop_y_upper := maxf(stop_y_min, stop_y_max)
	var stop_y_center := (stop_y_lower + stop_y_upper) * 0.5
	var candidate_y := _rng.randf_range(stop_y_lower, stop_y_upper)
	if _has_previous_stop_y \
			and absf(candidate_y - _previous_stop_y) < MIN_STOP_Y_SEPARATION:
		var y_shift_sign := 1.0 \
				if _previous_stop_y <= stop_y_center else -1.0
		candidate_y = _previous_stop_y + y_shift_sign * (
				MIN_STOP_Y_SEPARATION + _rng.randf_range(4.0, 12.0))
	candidate_y = clampf(candidate_y, stop_y_lower, stop_y_upper)
	candidate_y = roundf(candidate_y / DRAW_PIXEL) * DRAW_PIXEL
	_target_stop_position = Vector2(candidate_x, candidate_y)
	_previous_stop_x = candidate_x
	_has_previous_stop = true
	_previous_stop_y = candidate_y
	_has_previous_stop_y = true
	_initial_look_direction = 1 if _entered_from_left else -1


func _configure_travel(origin: Vector2, target: Vector2) -> void:
	_travel_origin = origin
	_travel_target = target
	_travel_duration = maxf(0.35,
			origin.distance_to(target) / roll_speed_px_per_sec)
	_travel_turns = maxi(2, int(round(origin.distance_to(target) / 120.0)))
	_rotation_origin = _shell_rotation


func _finish_exit() -> void:
	_state = VisitState.HIDDEN
	_state_age = 0.0
	_completed_exit_count += 1
	visible = false
	set_process(false)
	queue_redraw()
	visit_finished.emit()


func _ease_out_quadratic(progress: float) -> float:
	return 1.0 - (1.0 - progress) * (1.0 - progress)


func _ease_in_quadratic(progress: float) -> float:
	return progress * progress


func _draw() -> void:
	if _state == VisitState.HIDDEN:
		return
	var origin := (_visual_position / DRAW_PIXEL).round() * DRAW_PIXEL \
			+ ART_DRAW_OFFSET
	var glow_phase := _glow_phase()
	if _state == VisitState.ROLLING_IN or _state == VisitState.ROLLING_OUT:
		_draw_contact_shadow(origin, true)
		var grounded_origin := _grounded_rolling_shell_origin(
				origin, _shell_rotation)
		draw_set_transform(grounded_origin, _shell_rotation, Vector2.ONE)
		_draw_shell(Vector2.ZERO, glow_phase)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_draw_contact_shadow(origin, false)
	_draw_legs(origin)
	_draw_head(origin, _look_direction)
	_draw_shell(origin, glow_phase)


func _draw_contact_shadow(origin: Vector2, rolling: bool) -> void:
	if rolling:
		_draw_pixel_runs(origin, ROLLING_SHADOW_EDGE_RUNS, SHADOW_EDGE)
		_draw_pixel_runs(origin, ROLLING_SHADOW_CORE_RUNS, SHADOW_CORE)
		return
	_draw_pixel_runs(origin, CONTACT_SHADOW_EDGE_RUNS, SHADOW_EDGE)
	_draw_pixel_runs(origin, CONTACT_SHADOW_CORE_RUNS, SHADOW_CORE)


func _grounded_rolling_shell_origin(
		origin: Vector2, shell_rotation: float) -> Vector2:
	var rotated_bottom := _rotated_shell_max_y(shell_rotation)
	return origin + Vector2(
			0.0, ROLLING_CONTACT_OFFSET_PX - rotated_bottom)


func _rotated_shell_max_y(shell_rotation: float) -> float:
	var maximum_y := -INF
	for run: Vector4 in SHELL_OUTLINE_RUNS:
		var left := run.x * DRAW_PIXEL
		var top := run.y * DRAW_PIXEL
		var right := (run.x + run.z) * DRAW_PIXEL
		var bottom := (run.y + run.w) * DRAW_PIXEL
		for corner: Vector2 in [
			Vector2(left, top), Vector2(right, top),
			Vector2(left, bottom), Vector2(right, bottom),
		]:
			maximum_y = maxf(maximum_y, corner.rotated(shell_rotation).y)
	return maximum_y


func _draw_legs(origin: Vector2) -> void:
	_draw_pixel_runs(origin, FAR_LEG_RUNS, BODY_DARK)
	_draw_pixel_runs(origin, NEAR_LEG_RUNS, BODY_DARK)
	_draw_pixel_runs(origin, LEG_FILL_RUNS, BODY_SHADOW)


func _draw_head(origin: Vector2, direction: int) -> void:
	_draw_pixel_runs(origin, HEAD_OUTLINE_RUNS_LEFT, BODY_DARK, direction)
	_draw_pixel_runs(origin, HEAD_FILL_RUNS_LEFT, BODY_SHADOW, direction)
	_draw_pixel_runs(origin, HEAD_LIGHT_RUNS_LEFT, BODY_SAND, direction)
	_draw_pixel_runs(origin, HEAD_DETAIL_RUNS_LEFT, BODY_DARK, direction)
	var eye_run := Vector4(-11, -1, 1, 1)
	_draw_pixel_run(origin, eye_run, EYE_COLOR, direction)



func _draw_shell(origin: Vector2, glow_phase: float) -> void:
	var contour_glow := SHELL_GLOW_COLOR
	contour_glow.a = lerpf(GLOW_BASE_ALPHA, GLOW_PEAK_ALPHA, glow_phase)
	_draw_pixel_runs(origin, SHELL_CONTOUR_GLOW_RUNS, contour_glow)
	_draw_pixel_runs(origin, SHELL_OUTLINE_RUNS, SHELL_OUTLINE)
	_draw_pixel_runs(origin, SHELL_FILL_RUNS, SHELL_MID)
	_draw_pixel_runs(origin, SHELL_LOWER_RUNS, SHELL_DEEP)
	_draw_pixel_runs(origin, SHELL_GREEN_RUNS, SHELL_GREEN)
	var facet_light := SHELL_LIGHT.lerp(
			Color(0.58, 1.0, 0.76, 1.0), glow_phase * 0.28)
	_draw_pixel_runs(origin, SHELL_LIGHT_RUNS, facet_light)
	_draw_pixel_runs(origin, SHELL_SEAM_RUNS, SHELL_DEEP)


func _glow_phase() -> float:
	return 0.5 + 0.5 * sin(_state_age * 1.8)


func _draw_pixel_runs(
		origin: Vector2,
		runs: Array[Vector4],
		color: Color,
		direction: int = -1) -> void:
	for run: Vector4 in runs:
		_draw_pixel_run(origin, run, color, direction)


func _draw_pixel_run(
		origin: Vector2,
		run: Vector4,
		color: Color,
		direction: int = -1) -> void:
	var grid_x := run.x
	if direction > 0:
		grid_x = -run.x - run.z
	draw_rect(Rect2(
			origin + Vector2(grid_x, run.y) * DRAW_PIXEL,
			Vector2(run.z, run.w) * DRAW_PIXEL), color)


func set_random_seed_for_test(value: int) -> void:
	_rng.seed = value
	_has_previous_side = false
	_same_side_streak = 0
	_has_previous_stop = false
	_has_previous_stop_y = false
	_next_spawn_roll_override = -1.0


func set_next_spawn_roll_for_test(value: float) -> void:
	_next_spawn_roll_override = clampf(value, 0.0, 1.0)


func is_visit_active() -> bool:
	return _state != VisitState.HIDDEN


func is_rolling_in() -> bool:
	return _state == VisitState.ROLLING_IN


func is_looking() -> bool:
	return _state == VisitState.LOOKING


func is_rolling_out() -> bool:
	return _state == VisitState.ROLLING_OUT


func is_drinking() -> bool:
	return false


func entered_from_left() -> bool:
	return _entered_from_left


func visual_position() -> Vector2:
	return _visual_position


func target_stop_position() -> Vector2:
	return _target_stop_position


func look_direction() -> int:
	return _look_direction


func shell_rotation() -> float:
	return _shell_rotation


func rolling_ground_gap_px() -> float:
	if _state != VisitState.ROLLING_IN and _state != VisitState.ROLLING_OUT:
		return 0.0
	var origin := (_visual_position / DRAW_PIXEL).round() * DRAW_PIXEL \
			+ ART_DRAW_OFFSET
	var grounded_origin := _grounded_rolling_shell_origin(
			origin, _shell_rotation)
	var shell_bottom := grounded_origin.y \
			+ _rotated_shell_max_y(_shell_rotation)
	var contact_plane := origin.y + ROLLING_CONTACT_OFFSET_PX
	return contact_plane - shell_bottom


func current_travel_duration() -> float:
	return _travel_duration


func visit_count() -> int:
	return _visit_count


func completed_exit_count() -> int:
	return _completed_exit_count


func last_exit_was_attack() -> bool:
	return _last_exit_was_attack


func pose_count() -> int:
	return 3


func uses_external_texture() -> bool:
	return false


func uses_authored_pixel_masks() -> bool:
	return true


func has_bounding_box_glow() -> bool:
	return false


func has_rectangular_ground_shadow() -> bool:
	return false


func pixel_grid_size() -> float:
	return DRAW_PIXEL


func authored_shell_cell_count() -> int:
	return _pixel_cell_count(SHELL_OUTLINE_RUNS)


func authored_body_cell_count() -> int:
	return _pixel_cell_count(HEAD_OUTLINE_RUNS_LEFT) \
			+ _pixel_cell_count(FAR_LEG_RUNS) \
			+ _pixel_cell_count(NEAR_LEG_RUNS)


func visible_leg_cluster_count() -> int:
	return 4


func head_pixel_size() -> Vector2:
	return Vector2(24.0, 20.0)


func has_shell_contour_glow() -> bool:
	return true


func contour_glow_cell_count() -> int:
	return _pixel_cell_count(SHELL_CONTOUR_GLOW_RUNS)


func has_stepped_contact_shadow() -> bool:
	return true


func contact_shadow_cell_count() -> int:
	return _pixel_cell_count(CONTACT_SHADOW_EDGE_RUNS) \
			+ _pixel_cell_count(CONTACT_SHADOW_CORE_RUNS)


func contact_shadow_height_px() -> float:
	return 3.0 * DRAW_PIXEL


func glow_base_alpha() -> float:
	return GLOW_BASE_ALPHA


func glow_peak_alpha() -> float:
	return GLOW_PEAK_ALPHA


func current_glow_alpha() -> float:
	return lerpf(GLOW_BASE_ALPHA, GLOW_PEAK_ALPHA, _glow_phase())


func contact_shadow_rotates_with_shell() -> bool:
	return false


func body_pixel_size() -> Vector2:
	return BODY_SIZE


func _pixel_cell_count(runs: Array[Vector4]) -> int:
	var total := 0
	for run: Vector4 in runs:
		total += int(run.z * run.w)
	return total
