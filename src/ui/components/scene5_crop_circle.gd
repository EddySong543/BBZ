extends Node

## Scene5 low-probability secret: a completed cluster of far-wheat clicks earns
## one random roll. A successful roll slowly presses one crop circle through
## all three derived depth layers; a miss simply starts the gesture over.

signal achievement_progress_changed(progress: int, required: int)
signal achievement_completed(center: Vector2)

@export var interaction_path := NodePath("../WindField")
@export var wheat_layer_paths: Array[NodePath] = []
@export_range(3, 8, 1) var required_clicks: int = 5
@export_range(0.0, 1.0, 0.01) var trigger_probability: float = 0.08
@export_range(2.0, 15.0, 0.25) var achievement_window_sec: float = 8.0
@export_range(80.0, 480.0, 8.0) var cluster_radius_px: float = 320.0
@export_range(0.2, 4.0, 0.05) var reveal_duration_sec: float = 1.2
@export_range(0.5, 10.0, 0.1) var hold_duration_sec: float = 4.5
@export_range(0.2, 4.0, 0.05) var recover_duration_sec: float = 1.5

var _materials: Array[ShaderMaterial] = []
var _achievement_progress: int = 0
var _window_started_msec: int = 0
var _cluster_center: Vector2 = Vector2.ZERO
var _achievement_is_completed: bool = false
var _reveal_elapsed_sec: float = 0.0
var _visual_is_active: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)
	_rng.randomize()
	var depth_scales: Array[float] = [0.92, 1.0, 1.08]
	for index: int in wheat_layer_paths.size():
		var layer := get_node_or_null(wheat_layer_paths[index]) as CanvasItem
		if layer == null or not layer.material is ShaderMaterial:
			continue
		var material := layer.material as ShaderMaterial
		_materials.append(material)
		material.set_shader_parameter("crop_circle_strength", 0.0)
		material.set_shader_parameter("crop_circle_reveal", 0.0)
		material.set_shader_parameter(
				"crop_circle_depth_scale",
				depth_scales[mini(index, depth_scales.size() - 1)])
	var interaction := get_node_or_null(interaction_path)
	if interaction != null and interaction.has_signal("far_wheat_clicked"):
		interaction.connect("far_wheat_clicked", _on_far_wheat_clicked)
	else:
		push_warning(
				"Scene5CropCircle: missing far-wheat interaction %s"
				% interaction_path)


func get_achievement_progress() -> int:
	return _achievement_progress


func is_achievement_completed() -> bool:
	return _achievement_is_completed


func is_visual_active() -> bool:
	return _visual_is_active


func register_far_click(canvas_position: Vector2) -> void:
	if _achievement_is_completed or _materials.size() != 3:
		return
	var now_msec := Time.get_ticks_msec()
	var window_expired := _achievement_progress > 0 \
			and now_msec - _window_started_msec \
			> roundi(achievement_window_sec * 1000.0)
	var left_cluster := _achievement_progress > 0 \
			and canvas_position.distance_to(_cluster_center) > cluster_radius_px
	if window_expired or left_cluster:
		_reset_progress()
	if _achievement_progress == 0:
		_window_started_msec = now_msec
		_cluster_center = canvas_position
	else:
		_cluster_center = (
				_cluster_center * float(_achievement_progress) + canvas_position
				) / float(_achievement_progress + 1)
	_achievement_progress += 1
	achievement_progress_changed.emit(_achievement_progress, required_clicks)
	if _achievement_progress >= required_clicks:
		_attempt_achievement()


func _on_far_wheat_clicked(canvas_position: Vector2) -> void:
	register_far_click(canvas_position)


func _process(delta: float) -> void:
	_reveal_elapsed_sec += delta
	if _reveal_elapsed_sec < reveal_duration_sec:
		var reveal_progress := clampf(
				_reveal_elapsed_sec / maxf(reveal_duration_sec, 0.001),
				0.0,
				1.0)
		var eased_reveal := 1.0 - pow(1.0 - reveal_progress, 3.0)
		_set_effect_values(eased_reveal, eased_reveal)
		return
	var recover_start := reveal_duration_sec + hold_duration_sec
	if _reveal_elapsed_sec < recover_start:
		_set_effect_values(1.0, 1.0)
		return
	var recover_progress := clampf(
			(_reveal_elapsed_sec - recover_start)
					/ maxf(recover_duration_sec, 0.001),
			0.0,
			1.0)
	var eased_recover := recover_progress * recover_progress \
			* (3.0 - 2.0 * recover_progress)
	_set_effect_values(1.0 - eased_recover, 1.0)
	if recover_progress >= 1.0:
		_set_effect_values(0.0, 0.0)
		_visual_is_active = false
		set_process(false)


func _reset_progress() -> void:
	if _achievement_progress == 0:
		return
	_achievement_progress = 0
	_window_started_msec = 0
	_cluster_center = Vector2.ZERO
	achievement_progress_changed.emit(0, required_clicks)


func _attempt_achievement() -> void:
	var roll_succeeded := trigger_probability >= 1.0
	if trigger_probability > 0.0 and trigger_probability < 1.0:
		roll_succeeded = _rng.randf() < trigger_probability
	if roll_succeeded:
		_complete_achievement()
		return
	_reset_progress()


func _complete_achievement() -> void:
	_achievement_is_completed = true
	var viewport_size := get_viewport().get_visible_rect().size
	var normalized_center := Vector2(
			_cluster_center.x / maxf(viewport_size.x, 1.0),
			_cluster_center.y / maxf(viewport_size.y, 1.0))
	normalized_center.x = clampf(normalized_center.x, 0.38, 0.62)
	normalized_center.y = 0.56
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("crop_circle_center", normalized_center)
		material.set_shader_parameter("crop_circle_strength", 0.0)
		material.set_shader_parameter("crop_circle_reveal", 0.0)
	_reveal_elapsed_sec = 0.0
	_visual_is_active = true
	set_process(true)
	achievement_completed.emit(normalized_center)


func _set_effect_values(strength: float, reveal: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("crop_circle_strength", strength)
		material.set_shader_parameter("crop_circle_reveal", reveal)
