extends Control

## Scene2 water-board response. Battle UI controls render above these PASS
## surfaces and retain first click priority; this component never marks an
## event handled after producing its visual response.

enum EffectKind {
	WATERFALL_SPLASH,
	RIVER_RIPPLE,
}

class WaterEffect:
	var origin: Vector2
	var age: float = 0.0
	var seed: float

	func _init(effect_origin: Vector2, effect_seed: float) -> void:
		origin = effect_origin
		seed = effect_seed


signal effect_spawned(effect_kind: int, canvas_position: Vector2)

@export var effect_kind: EffectKind = EffectKind.WATERFALL_SPLASH
@export_node_path("Control") var water_target_path: NodePath
@export_range(1, 8, 1) var max_effects: int = 5
@export_range(0.3, 2.0, 0.05) var effect_lifetime: float = 0.8
@export_range(0.0, 0.5, 0.01) var click_cooldown: float = 0.1
@export_range(2.0, 8.0, 1.0) var pixel_size: float = 4.0
@export_range(0.0, 1.0, 0.01) var waterfall_hit_y_min: float = 0.1
@export_range(0.0, 1.0, 0.01) var waterfall_hit_y_max: float = 0.81
@export var bright_color: Color = Color(0.75, 0.88, 0.82, 0.9)
@export var foam_color: Color = Color(0.96, 0.95, 0.86, 0.95)
@export var shadow_color: Color = Color(0.08, 0.25, 0.29, 0.52)

var _water_target: Control
var _effects: Array[WaterEffect] = []
var _cooldown_left: float = 0.0
var _seed_counter: int = 0


func _ready() -> void:
	_water_target = get_node_or_null(water_target_path) as Control
	if _water_target == null:
		push_warning("Scene2WaterInteraction: missing water target %s" % water_target_path)
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
	if _water_target == null or _cooldown_left > 0.0:
		return false
	var target_local := _water_target.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	if not Rect2(Vector2.ZERO, _water_target.size).has_point(target_local):
		return false
	if effect_kind == EffectKind.WATERFALL_SPLASH \
			and not _is_inside_waterfall_body(target_local):
		return false

	var effect_local := get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	_seed_counter += 1
	var effect := WaterEffect.new(
			_snap_point(effect_local),
			float(_seed_counter) * 17.0 + canvas_position.x * 0.031)
	_effects.append(effect)
	if _effects.size() > max_effects:
		_effects.pop_front()
	_cooldown_left = click_cooldown
	set_process(true)
	queue_redraw()
	effect_spawned.emit(effect_kind, canvas_position)
	return true


func active_effect_count() -> int:
	return _effects.size()


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	for effect in _effects:
		effect.age += delta
	for index in range(_effects.size() - 1, -1, -1):
		if _effects[index].age >= effect_lifetime:
			_effects.remove_at(index)
	queue_redraw()
	if _effects.is_empty():
		set_process(false)


func _draw() -> void:
	for effect in _effects:
		var phase := clampf(effect.age / maxf(effect_lifetime, 0.001), 0.0, 1.0)
		if effect_kind == EffectKind.WATERFALL_SPLASH:
			_draw_waterfall_splash(effect, phase)
		else:
			_draw_river_ripple(effect, phase)


func _is_inside_waterfall_body(target_local: Vector2) -> bool:
	var target_size := _water_target.size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return false
	var material := _water_target.material as ShaderMaterial
	if material == null:
		return false
	var shader_size := _shader_vec2(material, &"size_px", target_size)
	var px := target_local / target_size * shader_size
	var qy := px.y / maxf(shader_size.y, 1.0)
	var top_y := _shader_float(material, &"top_y", 0.08)
	var bottom_y := _shader_float(material, &"bottom_y", 0.86)
	if qy < maxf(top_y, waterfall_hit_y_min) \
			or qy > minf(bottom_y, waterfall_hit_y_max):
		return false
	var fall_phase := clampf((qy - top_y) / maxf(bottom_y - top_y, 0.001), 0.0, 1.0)
	var step_one := _shader_float(material, &"vertical_step_one_y", 0.36)
	var step_two := _shader_float(material, &"vertical_step_two_y", 0.72)
	var left_edge: float
	var right_edge: float
	if fall_phase < step_one:
		left_edge = _shader_float(material, &"left_edge_upper_px", 132.0)
		right_edge = _shader_float(material, &"right_edge_upper_px", 588.0)
	elif fall_phase < step_two:
		left_edge = _shader_float(material, &"left_edge_middle_px", 138.0)
		right_edge = _shader_float(material, &"right_edge_middle_px", 594.0)
	else:
		left_edge = _shader_float(material, &"left_edge_lower_px", 120.0)
		right_edge = _shader_float(material, &"right_edge_lower_px", 624.0)
	return px.x >= left_edge and px.x <= right_edge


func _draw_waterfall_splash(effect: WaterEffect, phase: float) -> void:
	var fade := 1.0 - phase * phase
	var opening := minf(phase / 0.22, 1.0)
	var base_half_width := lerpf(pixel_size * 2.0, pixel_size * 9.0, phase)
	var base_y := effect.origin.y + pixel_size * minf(phase * 2.0, 1.0)
	var shadow := shadow_color
	shadow.a *= fade * 0.62
	var light := bright_color
	light.a *= fade
	var foam := foam_color
	foam.a *= fade * opening
	_draw_broken_horizontal(base_y + pixel_size, effect.origin.x,
			base_half_width, shadow, effect.seed + 41.0)
	_draw_broken_horizontal(base_y, effect.origin.x,
			base_half_width * 0.86, foam, effect.seed)

	for index in 5:
		var h := _hash(effect.seed, float(index))
		var h2 := _hash(effect.seed + 23.0, float(index))
		var direction := -1.0 if index % 2 == 0 else 1.0
		if index == 4:
			direction = 0.2
		var reach := lerpf(pixel_size * 4.0, pixel_size * 12.0, h)
		var height := lerpf(pixel_size * 7.0, pixel_size * 14.0, h2)
		var drop_x := effect.origin.x + direction * reach * phase
		var drop_y := effect.origin.y \
				- height * 4.0 * phase * (1.0 - phase) \
				+ pixel_size * 3.0 * phase
		var drop_size := pixel_size * (2.0 if index == 0 else 1.0)
		var drop_color := foam if index < 2 else light
		draw_rect(Rect2(
				_snap_point(Vector2(drop_x, drop_y)) - Vector2(drop_size, drop_size) * 0.5,
				Vector2(drop_size, drop_size)), drop_color)
		if phase < 0.38 and index < 3:
			var jet_height := pixel_size * lerpf(2.0, 5.0, h2) * opening
			draw_rect(Rect2(
					_snap_point(Vector2(
						effect.origin.x + direction * pixel_size * float(index + 1),
						effect.origin.y - jet_height)),
					Vector2(pixel_size, jet_height)), light)


func _draw_river_ripple(effect: WaterEffect, phase: float) -> void:
	_draw_ripple_ring(effect.origin, phase, effect.seed, 1.0)
	var delayed_phase := clampf((phase - 0.18) / 0.82, 0.0, 1.0)
	if phase > 0.18:
		_draw_ripple_ring(effect.origin, delayed_phase, effect.seed + 37.0, 0.72)


func _draw_ripple_ring(
		origin: Vector2,
		phase: float,
		seed: float,
		alpha_scale: float) -> void:
	var eased := 1.0 - (1.0 - phase) * (1.0 - phase)
	var radius_x := lerpf(pixel_size * 3.0, pixel_size * 27.0, eased)
	var radius_y := radius_x * 0.19
	var fade := (1.0 - phase) * (1.0 - phase) * alpha_scale
	var shadow := shadow_color
	shadow.a *= fade
	var light := bright_color
	light.a *= fade * 0.9
	for segment in 32:
		if _hash(seed, float(segment)) < 0.26:
			continue
		var angle_a := TAU * float(segment) / 32.0
		var angle_b := TAU * float(segment + 1) / 32.0
		var point_a := _snap_point(origin + Vector2(
				cos(angle_a) * radius_x, sin(angle_a) * radius_y))
		var point_b := _snap_point(origin + Vector2(
				cos(angle_b) * radius_x, sin(angle_b) * radius_y))
		draw_line(point_a + Vector2(0.0, pixel_size),
				point_b + Vector2(0.0, pixel_size), shadow, pixel_size, false)
		draw_line(point_a, point_b, light, pixel_size, false)


func _draw_broken_horizontal(
		y: float,
		center_x: float,
		half_width: float,
		color: Color,
		seed: float) -> void:
	var cell_count := maxi(2, int(ceil(half_width * 2.0 / (pixel_size * 2.0))))
	for cell in cell_count:
		if _hash(seed, float(cell)) < 0.3:
			continue
		var x := center_x - half_width + float(cell) * pixel_size * 2.0
		draw_rect(Rect2(_snap_point(Vector2(x, y)),
				Vector2(pixel_size * 2.0, pixel_size)), color)


func _shader_float(material: ShaderMaterial, parameter: StringName, fallback: float) -> float:
	var value: Variant = material.get_shader_parameter(parameter)
	return float(value) if value != null else fallback


func _shader_vec2(material: ShaderMaterial, parameter: StringName, fallback: Vector2) -> Vector2:
	var value: Variant = material.get_shader_parameter(parameter)
	return value as Vector2 if value is Vector2 else fallback


func _snap_point(point: Vector2) -> Vector2:
	return (point / pixel_size).round() * pixel_size


func _hash(seed: float, index: float) -> float:
	return fposmod(sin(seed * 12.9898 + index * 78.233) * 43758.5453, 1.0)
