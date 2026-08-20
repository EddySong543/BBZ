class_name Scene3CloudInteraction
extends Control

## Passive Scene3 cloud-sea response. A valid cloud-area click travels from
## the strongest front layer toward the softer mid and back layers.

signal cloud_disturbed(canvas_position: Vector2)

@export_node_path("Control") var cloud_target_path: NodePath
@export_node_path("Control") var secondary_cloud_target_path: NodePath
@export_node_path("Control") var tertiary_cloud_target_path: NodePath
@export_range(0.0, 2.0, 0.05) var click_cooldown: float = 0.2
@export_range(0.4, 1.6, 0.01) var cloud_effect_lifetime: float = 0.72
@export_range(0.1, 1.0, 0.01) var primary_strength: float = 0.72
@export_range(0.0, 0.3, 0.01) var secondary_delay: float = 0.06
@export_range(0.4, 1.4, 0.01) var secondary_lifetime: float = 0.78
@export_range(0.1, 1.0, 0.01) var secondary_strength: float = 0.46
@export_range(0.0, 0.4, 0.01) var tertiary_delay: float = 0.12
@export_range(0.4, 1.6, 0.01) var tertiary_lifetime: float = 0.92
@export_range(0.1, 1.0, 0.01) var tertiary_strength: float = 0.22

var _cloud_target: Control
var _secondary_cloud_target: Control
var _tertiary_cloud_target: Control
var _cloud_material: ShaderMaterial
var _secondary_cloud_material: ShaderMaterial
var _tertiary_cloud_material: ShaderMaterial
var _next_allowed_msec: int = 0
var _front_active := false
var _secondary_active := false
var _tertiary_active := false
var _front_age := 0.0
var _secondary_age := 0.0
var _tertiary_age := 0.0
var _front_center_x := 0.5
var _secondary_center_x := 0.5
var _tertiary_center_x := 0.5
var _latest_local_origin := Vector2.ZERO


func _ready() -> void:
	_cloud_target = get_node_or_null(cloud_target_path) as Control
	_secondary_cloud_target = get_node_or_null(
			secondary_cloud_target_path) as Control
	_tertiary_cloud_target = get_node_or_null(
			tertiary_cloud_target_path) as Control
	_cloud_material = _duplicate_target_material(_cloud_target, cloud_target_path)
	_secondary_cloud_material = _duplicate_target_material(
			_secondary_cloud_target, secondary_cloud_target_path)
	_tertiary_cloud_material = _duplicate_target_material(
			_tertiary_cloud_target, tertiary_cloud_target_path)
	_reset_material(_cloud_material)
	_reset_material(_secondary_cloud_material)
	_reset_material(_tertiary_cloud_material)
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var canvas_position := get_global_transform_with_canvas() * mouse_event.position
	try_spawn_at_canvas_position(canvas_position)


func try_spawn_at_canvas_position(canvas_position: Vector2) -> bool:
	if Time.get_ticks_msec() < _next_allowed_msec:
		return false
	var local_position := get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		return false

	_front_center_x = _normalized_target_x(_cloud_target, canvas_position)
	_secondary_center_x = _normalized_target_x(
			_secondary_cloud_target, canvas_position)
	_tertiary_center_x = _normalized_target_x(
			_tertiary_cloud_target, canvas_position)
	_front_age = 0.0
	_secondary_age = -secondary_delay
	_tertiary_age = -tertiary_delay
	_front_active = true
	_secondary_active = true
	_tertiary_active = true

	_latest_local_origin = _snap_point(local_position)
	_next_allowed_msec = Time.get_ticks_msec() + int(click_cooldown * 1000.0)
	_update_cloud_materials()
	set_process(true)
	cloud_disturbed.emit(canvas_position)
	return true


func active_cloud_effect_count() -> int:
	return int(_front_active and _front_age >= 0.0) \
			+ int(_secondary_active and _secondary_age >= 0.0) \
			+ int(_tertiary_active and _tertiary_age >= 0.0)


func get_last_disturbance_origin() -> Vector2:
	return _latest_local_origin


func get_active_cloud_layer() -> StringName:
	return &"propagating" if _has_pending_or_active_effects() else &"none"


func is_cloud_layer_active(layer_name: StringName) -> bool:
	match layer_name:
		&"front":
			return _front_active and _front_age >= 0.0
		&"mid":
			return _secondary_active and _secondary_age >= 0.0
		&"back":
			return _tertiary_active and _tertiary_age >= 0.0
	return false


func _process(delta: float) -> void:
	if _front_active:
		_front_age += delta
		if _front_age >= cloud_effect_lifetime:
			_front_active = false
	if _secondary_active:
		_secondary_age += delta
		if _secondary_age >= secondary_lifetime:
			_secondary_active = false
	if _tertiary_active:
		_tertiary_age += delta
		if _tertiary_age >= tertiary_lifetime:
			_tertiary_active = false
	_update_cloud_materials()
	if not _has_pending_or_active_effects():
		set_process(false)


func _update_cloud_materials() -> void:
	var front_phase := 1.0
	var front_strength := 0.0
	var secondary_phase_value := 1.0
	var secondary_strength_value := 0.0
	var tertiary_phase_value := 1.0
	var tertiary_strength_value := 0.0
	if _front_active and _front_age >= 0.0:
		front_phase = clampf(
				_front_age / maxf(cloud_effect_lifetime, 0.001), 0.0, 1.0)
		front_strength = _strength_envelope(front_phase) * primary_strength
	if _secondary_active and _secondary_age >= 0.0:
		secondary_phase_value = clampf(
				_secondary_age / maxf(secondary_lifetime, 0.001), 0.0, 1.0)
		secondary_strength_value = _strength_envelope(
				secondary_phase_value) * secondary_strength
	if _tertiary_active and _tertiary_age >= 0.0:
		tertiary_phase_value = clampf(
				_tertiary_age / maxf(tertiary_lifetime, 0.001), 0.0, 1.0)
		tertiary_strength_value = _strength_envelope(
				tertiary_phase_value) * tertiary_strength
	_set_material_press(
			_cloud_material, _front_center_x, front_strength, front_phase)
	_set_material_press(
			_secondary_cloud_material,
			_secondary_center_x,
			secondary_strength_value,
			secondary_phase_value)
	_set_material_press(
			_tertiary_cloud_material,
			_tertiary_center_x,
			tertiary_strength_value,
			tertiary_phase_value)


func _has_pending_or_active_effects() -> bool:
	return _front_active or _secondary_active or _tertiary_active


func _normalized_target_x(target: Control, canvas_position: Vector2) -> float:
	var local_position := target.get_global_transform_with_canvas() \
			.affine_inverse() * canvas_position
	return clampf(local_position.x / maxf(target.size.x, 1.0), 0.0, 1.0)


func _strength_envelope(phase: float) -> float:
	return 1.0 if phase < 1.0 else 0.0


func _set_material_press(
		material: ShaderMaterial,
		center_x: float,
		strength: float,
		phase: float) -> void:
	if material == null:
		return
	material.set_shader_parameter("cloud_press_center_x", center_x)
	material.set_shader_parameter("cloud_press_strength", strength)
	material.set_shader_parameter("cloud_press_phase", phase)


func _reset_material(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("cloud_press_strength", 0.0)
	material.set_shader_parameter("cloud_press_phase", 1.0)


func _duplicate_target_material(
		target: Control,
		target_path: NodePath) -> ShaderMaterial:
	if target == null:
		push_warning("Scene3CloudInteraction: missing cloud target %s" % target_path)
		return null
	if not (target.material is ShaderMaterial):
		push_warning(
				"Scene3CloudInteraction: target %s has no ShaderMaterial" % target_path)
		return null
	var material := (target.material as ShaderMaterial).duplicate() as ShaderMaterial
	target.material = material
	return material


func _snap_point(point: Vector2) -> Vector2:
	const POSITION_GRID := 4.0
	return (point / POSITION_GRID).round() * POSITION_GRID
