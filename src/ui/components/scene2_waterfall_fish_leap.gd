extends Control

## Low-frequency Scene2 waterfall easter egg. It listens to confirmed
## waterfall splash events and never participates in input hit testing.

signal fish_leap_started(start_position: Vector2, landing_position: Vector2)

@export_node_path("Control") var water_target_path: NodePath
@export_range(2, 8, 1) var trigger_clicks: int = 3
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.25
@export_range(0.0, 1.0, 0.01) var golden_fish_chance: float = 0.05
@export_range(3, 12, 1) var pity_clicks: int = 7
@export_range(0.6, 2.0, 0.05) var leap_lifetime: float = 1.2
@export_range(0.0, 12.0, 0.25) var retrigger_cooldown: float = 6.0
@export_range(80.0, 260.0, 4.0) var jump_height: float = 172.0
@export_range(2.0, 8.0, 1.0) var pixel_size: float = 4.0
@export var fish_outline_color: Color = Color(0.05, 0.2, 0.24, 1.0)
@export var fish_body_color: Color = Color(0.5, 0.75, 0.7, 1.0)
@export var fish_highlight_color: Color = Color(0.72, 0.88, 0.84, 1.0)
@export var golden_outline_color: Color = Color(0.34, 0.2, 0.04, 1.0)
@export var golden_body_color: Color = Color(0.9, 0.61, 0.12, 1.0)
@export var golden_highlight_color: Color = Color(1.0, 0.88, 0.42, 1.0)
@export var splash_color: Color = Color(0.82, 0.91, 0.82, 0.86)
@export var splash_shadow_color: Color = Color(0.07, 0.23, 0.27, 0.5)

var _water_target: Control
var _fish_texture: ImageTexture
var _golden_fish_texture: ImageTexture
var _clicks_since_leap: int = 0
var _total_valid_clicks: int = 0
var _active: bool = false
var _age: float = 0.0
var _cooldown_left: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _landing_position: Vector2 = Vector2.ZERO
var _trajectory_height: float = 0.0
var _leap_seed: float = 0.0
var _is_golden: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_target = get_node_or_null(water_target_path) as Control
	if _water_target == null:
		push_warning("Scene2WaterfallFishLeap: missing water target %s" % water_target_path)
	else:
		_sync_rect_to_waterfall()
	_fish_texture = _build_fish_texture()
	_golden_fish_texture = ImageTexture.create_from_image(_build_golden_fish_image())
	set_process(false)


func _on_waterfall_effect_spawned(effect_kind: int, canvas_position: Vector2) -> void:
	if effect_kind != 0 or _water_target == null:
		return
	if _active or _cooldown_left > 0.0:
		return
	_clicks_since_leap += 1
	_total_valid_clicks += 1
	if _clicks_since_leap < trigger_clicks:
		return
	var roll := _hash01(
			float(_total_valid_clicks) * 31.0
			+ canvas_position.x * 0.071
			+ canvas_position.y * 0.037)
	if _clicks_since_leap < pity_clicks and roll >= trigger_chance:
		return
	var golden_roll := _hash01(
			float(_total_valid_clicks) * 67.0
			+ canvas_position.x * 0.113
			+ canvas_position.y * 0.059)
	var use_golden_fish := _can_trigger_golden_fish(canvas_position) \
			and golden_roll < golden_fish_chance
	_begin_fish_leap(canvas_position, use_golden_fish)


func active_fish_count() -> int:
	return 1 if _active else 0


func fish_vertical_drop() -> float:
	return _landing_position.y - _start_position.y


func fish_starts_above_landing() -> bool:
	return _start_position.y < _landing_position.y


func fish_texture_ready() -> bool:
	return _fish_texture != null and _fish_texture.get_width() > 0 \
			and _golden_fish_texture != null and _golden_fish_texture.get_width() > 0


func fish_start_position() -> Vector2:
	return _start_position


func fish_asset_image() -> Image:
	return _build_fish_image()


func golden_fish_asset_image() -> Image:
	return _build_golden_fish_image()


func is_golden_fish_active() -> bool:
	return _active and _is_golden


func _begin_fish_leap(canvas_position: Vector2, use_golden_fish: bool = false) -> void:
	_sync_rect_to_waterfall()
	_start_position = _snap_point(
			get_global_transform_with_canvas().affine_inverse() * canvas_position)
	_is_golden = use_golden_fish
	var random := RandomNumberGenerator.new()
	var seed_value := int(absf(
			canvas_position.x * 97.0
			+ canvas_position.y * 53.0
			+ float(_total_valid_clicks) * 7919.0))
	random.seed = seed_value
	var start_phase := _waterfall_fall_phase_at_canvas_position(canvas_position)
	var landing_phase := random.randf_range(0.72, 0.8)
	if _is_golden:
		landing_phase = maxf(0.1, start_phase - random.randf_range(0.3, 0.42))
	var direction := -1.0 if random.randf() < 0.5 else 1.0
	var landing_edges := _waterfall_edges(landing_phase)
	var lateral_reach := random.randf_range(
			72.0 if _is_golden else 112.0,
			136.0 if _is_golden else 176.0) * direction
	var material := _water_target.material as ShaderMaterial
	var shader_size := _shader_vec2(material, &"size_px", _water_target.size)
	var start_x_px := _start_position.x / maxf(size.x, 1.0) * shader_size.x
	var landing_x := clampf(
			start_x_px + lateral_reach,
			landing_edges.x + pixel_size * 5.0,
			landing_edges.y - pixel_size * 5.0)
	_landing_position = _waterfall_point(landing_x, landing_phase)
	if _is_golden:
		_landing_position.y = minf(
				_landing_position.y,
				_start_position.y - random.randf_range(260.0, 340.0))
	else:
		_landing_position.y = maxf(
				_landing_position.y,
				_start_position.y + random.randf_range(260.0, 340.0))
	_trajectory_height = jump_height * random.randf_range(
			0.82 if _is_golden else 0.9,
			1.0 if _is_golden else 1.08)
	_leap_seed = random.randf_range(10.0, 1000.0)
	_clicks_since_leap = 0
	_age = 0.0
	_active = true
	_cooldown_left = retrigger_cooldown
	set_process(true)
	queue_redraw()
	fish_leap_started.emit(_start_position, _landing_position)


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _active:
		_age += delta
		if _age >= leap_lifetime:
			_active = false
		queue_redraw()
	if not _active and _cooldown_left <= 0.0:
		set_process(false)


func _draw() -> void:
	var active_texture := _golden_fish_texture if _is_golden else _fish_texture
	if not _active or active_texture == null:
		return
	var phase := clampf(_age / maxf(leap_lifetime, 0.001), 0.0, 1.0)
	var takeoff_phase := clampf(phase / 0.24, 0.0, 1.0)
	_draw_endpoint_splash(_start_position, takeoff_phase, _leap_seed)
	if phase > 0.76:
		var landing_phase := clampf((phase - 0.76) / 0.24, 0.0, 1.0)
		_draw_endpoint_splash(_landing_position, landing_phase, _leap_seed + 47.0)

	var visibility := smoothstep(0.025, 0.1, phase) \
			* (1.0 - smoothstep(0.88, 0.97, phase))
	if visibility <= 0.0:
		return
	var fish_position := _trajectory_position(phase)
	var tangent := _trajectory_tangent(phase)
	var angle_step := PI / 8.0
	var fish_angle := roundf(tangent.angle() / angle_step) * angle_step
	var fish_modulate := Color(1.0, 1.0, 1.0, visibility)
	draw_set_transform(_snap_point(fish_position), fish_angle, Vector2(2.3, 2.3))
	draw_texture(active_texture, Vector2(-9.0, -5.0), fish_modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _trajectory_position(phase: float) -> Vector2:
	var position := _start_position.lerp(_landing_position, phase)
	position.y -= _trajectory_height * 4.0 * phase * (1.0 - phase)
	return position


func _trajectory_tangent(phase: float) -> Vector2:
	return (_landing_position - _start_position) \
			+ Vector2(0.0, -_trajectory_height * 4.0 * (1.0 - phase * 2.0))


func _draw_endpoint_splash(origin: Vector2, phase: float, seed: float) -> void:
	var fade := (1.0 - phase) * (1.0 - phase)
	if fade <= 0.0:
		return
	var shadow := splash_shadow_color
	shadow.a *= fade
	var light := splash_color
	light.a *= fade
	var half_width := lerpf(pixel_size * 2.0, pixel_size * 7.0, phase)
	for segment in 5:
		if _hash01(seed + float(segment) * 13.0) < 0.25:
			continue
		var x := origin.x - half_width + float(segment) * half_width * 0.5
		draw_rect(Rect2(
				_snap_point(Vector2(x, origin.y + pixel_size)),
				Vector2(pixel_size * 2.0, pixel_size)), shadow)
		draw_rect(Rect2(
				_snap_point(Vector2(x, origin.y)),
				Vector2(pixel_size * 2.0, pixel_size)), light)
	for drop_index in 3:
		var direction := -1.0 if drop_index % 2 == 0 else 1.0
		var height := pixel_size * (4.0 + float(drop_index) * 1.5)
		var drop_position := origin + Vector2(
				direction * pixel_size * float(drop_index + 2) * phase,
				-height * 4.0 * phase * (1.0 - phase))
		draw_rect(Rect2(
				_snap_point(drop_position),
				Vector2(pixel_size, pixel_size)), light)


func _waterfall_point(x_px: float, fall_phase: float) -> Vector2:
	var material := _water_target.material as ShaderMaterial
	var shader_size := _shader_vec2(material, &"size_px", _water_target.size)
	var top_y := _shader_float(material, &"top_y", 0.08)
	var bottom_y := _shader_float(material, &"bottom_y", 0.86)
	var y_px := lerpf(top_y, bottom_y, fall_phase) * shader_size.y
	return Vector2(
			x_px / maxf(shader_size.x, 1.0) * size.x,
			y_px / maxf(shader_size.y, 1.0) * size.y)


func _waterfall_edges(fall_phase: float) -> Vector2:
	var material := _water_target.material as ShaderMaterial
	var step_one := _shader_float(material, &"vertical_step_one_y", 0.36)
	var step_two := _shader_float(material, &"vertical_step_two_y", 0.72)
	if fall_phase < step_one:
		return Vector2(
				_shader_float(material, &"left_edge_upper_px", 132.0),
				_shader_float(material, &"right_edge_upper_px", 588.0))
	if fall_phase < step_two:
		return Vector2(
				_shader_float(material, &"left_edge_middle_px", 138.0),
				_shader_float(material, &"right_edge_middle_px", 594.0))
	return Vector2(
			_shader_float(material, &"left_edge_lower_px", 120.0),
			_shader_float(material, &"right_edge_lower_px", 624.0))


func _waterfall_fall_phase_at_canvas_position(canvas_position: Vector2) -> float:
	var target_local := _water_target.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	var material := _water_target.material as ShaderMaterial
	var shader_size := _shader_vec2(material, &"size_px", _water_target.size)
	var top_y := _shader_float(material, &"top_y", 0.08)
	var bottom_y := _shader_float(material, &"bottom_y", 0.86)
	var qy := target_local.y / maxf(_water_target.size.y, 1.0)
	return clampf((qy - top_y) / maxf(bottom_y - top_y, 0.001), 0.0, 1.0)


func _can_trigger_golden_fish(canvas_position: Vector2) -> bool:
	var material := _water_target.material as ShaderMaterial
	var first_step := _shader_float(material, &"vertical_step_one_y", 0.36)
	return _waterfall_fall_phase_at_canvas_position(canvas_position) >= first_step


func _sync_rect_to_waterfall() -> void:
	position = _water_target.position
	size = _water_target.size


func _build_fish_texture() -> ImageTexture:
	return ImageTexture.create_from_image(_build_fish_image())


func _build_fish_image() -> Image:
	return _build_fish_image_with_palette(
			fish_outline_color, fish_body_color, fish_highlight_color)


func _build_golden_fish_image() -> Image:
	return _build_fish_image_with_palette(
			golden_outline_color, golden_body_color, golden_highlight_color)


func _build_fish_image_with_palette(
		outline_color: Color,
		body_color: Color,
		highlight_color: Color) -> Image:
	var image := Image.create(18, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 10:
		for x in 18:
			var body_delta := Vector2(
					(float(x) - 10.5) / 6.5,
					(float(y) - 4.5) / 3.35)
			var body_distance := body_delta.length()
			var tail_half_height := 3.3 - float(x) * 0.62
			var in_tail := x <= 4 and absf(float(y) - 4.5) <= tail_half_height
			if body_distance <= 1.0 or in_tail:
				var color := body_color
				if body_distance > 0.72 or (in_tail and x <= 1):
					color = outline_color
				image.set_pixel(x, y, color)
	image.set_pixel(14, 3, highlight_color)
	image.set_pixel(15, 4, outline_color)
	return image


func _shader_float(material: ShaderMaterial, parameter: StringName, fallback: float) -> float:
	if material == null:
		return fallback
	var value: Variant = material.get_shader_parameter(parameter)
	return float(value) if value != null else fallback


func _shader_vec2(material: ShaderMaterial, parameter: StringName, fallback: Vector2) -> Vector2:
	if material == null:
		return fallback
	var value: Variant = material.get_shader_parameter(parameter)
	return value as Vector2 if value is Vector2 else fallback


func _snap_point(point: Vector2) -> Vector2:
	return (point / pixel_size).round() * pixel_size


func _hash01(value: float) -> float:
	return fposmod(sin(value * 12.9898) * 43758.5453, 1.0)
