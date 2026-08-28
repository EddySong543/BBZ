extends RefCounted

## Shared stepped zoom state for the main-menu and expedition grid views.
## Every resting preset ends on complete cells; only the short transition is continuous.

const GRID_PRESETS: Array[Vector2i] = [
	Vector2i(31, 17),
	Vector2i(27, 15),
	Vector2i(23, 13),
	Vector2i(19, 11),
	Vector2i(15, 9),
]
const DEFAULT_PRESET_INDEX: int = 2
const TRANSITION_DURATION_SECONDS: float = 0.15
const PRIMARY_PHASE_DURATION_SECONDS: float = 0.09
const PRIMARY_PHASE_DISTANCE: float = 0.92
const INPUT_BURST_WINDOW_SECONDS: float = 0.055

var current_scale: Vector2 = Vector2.ONE
var target_scale: Vector2 = Vector2.ONE
var current_grid: Vector2i = GRID_PRESETS[DEFAULT_PRESET_INDEX]
var closest_grid: Vector2i = GRID_PRESETS[GRID_PRESETS.size() - 1]

var _view_size: Vector2 = Vector2.ZERO
var _cell_size: float = 1.0
var _target_index: int = DEFAULT_PRESET_INDEX
var _transition_start_scale: Vector2 = Vector2.ONE
var _transition_elapsed: float = 0.0
var _transition_active: bool = false
var _burst_remaining: float = 0.0
var _last_direction: int = 0
var _configured: bool = false


func configure(view_size: Vector2, cell_size: float) -> void:
	assert(view_size.x > 0.0 and view_size.y > 0.0,
			"Grid view zoom requires a positive view size.")
	assert(cell_size > 0.0, "Grid view zoom requires a positive cell size.")
	_view_size = view_size
	_cell_size = cell_size
	_target_index = DEFAULT_PRESET_INDEX
	current_grid = GRID_PRESETS[_target_index]
	closest_grid = GRID_PRESETS[GRID_PRESETS.size() - 1]
	current_scale = _scale_for_grid(current_grid)
	target_scale = current_scale
	_transition_start_scale = current_scale
	_transition_elapsed = 0.0
	_transition_active = false
	_burst_remaining = 0.0
	_last_direction = 0
	_configured = true


func request_zoom(zoom_in: bool) -> bool:
	if not _configured:
		return false
	var direction: int = 1 if zoom_in else -1
	if _burst_remaining > 0.0 and direction == _last_direction:
		return false
	var next_index: int = clampi(
			_target_index + direction, 0, GRID_PRESETS.size() - 1)
	if next_index == _target_index:
		return false
	_target_index = next_index
	current_grid = GRID_PRESETS[_target_index]
	target_scale = _scale_for_grid(current_grid)
	_transition_start_scale = current_scale
	_transition_elapsed = 0.0
	_transition_active = not current_scale.is_equal_approx(target_scale)
	_burst_remaining = INPUT_BURST_WINDOW_SECONDS
	_last_direction = direction
	return true


## Two-stage, monotonic focus motion: a decisive 92% push followed by a short settle.
func advance(delta: float) -> bool:
	if delta <= 0.0:
		return false
	_burst_remaining = maxf(0.0, _burst_remaining - delta)
	if not _transition_active:
		return false
	_transition_elapsed = minf(
			_transition_elapsed + delta, TRANSITION_DURATION_SECONDS)
	var eased: float = _transition_eased_progress(_transition_elapsed)
	current_scale = _transition_start_scale.lerp(target_scale, eased)
	if _transition_elapsed >= TRANSITION_DURATION_SECONDS:
		current_scale = target_scale
		_transition_active = false
	return true


func get_contract() -> Dictionary:
	return {
		"grid_presets": GRID_PRESETS.duplicate(),
		"default_grid": GRID_PRESETS[DEFAULT_PRESET_INDEX],
		"current_grid": current_grid,
		"closest_grid": closest_grid,
		"current_scale": current_scale,
		"target_scale": target_scale,
		"transition_duration": TRANSITION_DURATION_SECONDS,
		"primary_phase_duration": PRIMARY_PHASE_DURATION_SECONDS,
		"primary_phase_distance": PRIMARY_PHASE_DISTANCE,
		"transition_active": _transition_active,
		"transition_progress": clampf(
				_transition_elapsed / TRANSITION_DURATION_SECONDS, 0.0, 1.0),
		"zoom_direction": _last_direction,
		"instant_switch": false,
		"input_burst_window": INPUT_BURST_WINDOW_SECONDS,
		"burst_remaining": _burst_remaining,
	}


func _scale_for_grid(grid: Vector2i) -> Vector2:
	return _view_size / (Vector2(grid) * _cell_size)


func _transition_eased_progress(elapsed: float) -> float:
	if elapsed <= PRIMARY_PHASE_DURATION_SECONDS:
		var local_progress: float = clampf(
				elapsed / PRIMARY_PHASE_DURATION_SECONDS, 0.0, 1.0)
		var inverse: float = 1.0 - local_progress
		return PRIMARY_PHASE_DISTANCE * (1.0 - inverse * inverse * inverse * inverse)
	var settle_duration: float = (
			TRANSITION_DURATION_SECONDS - PRIMARY_PHASE_DURATION_SECONDS)
	var settle_progress: float = clampf(
			(elapsed - PRIMARY_PHASE_DURATION_SECONDS) / settle_duration, 0.0, 1.0)
	var settle_inverse: float = 1.0 - settle_progress
	var settle_eased: float = 1.0 - settle_inverse * settle_inverse * settle_inverse
	return PRIMARY_PHASE_DISTANCE + (1.0 - PRIMARY_PHASE_DISTANCE) * settle_eased
