class_name ReserveAvatarHitGlow
extends Control

## H19替补头像的局部红光：透明填色贴合菱形，不生成方块冲击圈。

signal finished

const RED_CORE: Color = Color("d7333f")
const RED_EDGE: Color = Color("ff6a62")

var strength: float = 0.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		queue_redraw()

var _target: Control
var _base_modulate: Color = Color.WHITE
var _base_position: Vector2 = Vector2.ZERO
var _flash_color: Color = Color.WHITE
var _impact_tint: Color = Color.WHITE
var _shake_x := PackedFloat32Array()
var _shake_y := PackedFloat32Array()
var _elapsed_seconds: float = 0.0
var _duration_seconds: float = 0.35


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	queue_redraw()


func play(target: Control, base_modulate: Color, base_position: Vector2,
		flash_color: Color, impact_tint: Color, shake_x: PackedFloat32Array,
		shake_y: PackedFloat32Array, duration: float = 0.35) -> void:
	_target = target
	_base_modulate = base_modulate
	_base_position = base_position
	_flash_color = flash_color
	_impact_tint = impact_tint
	_shake_x = shake_x
	_shake_y = shake_y
	_duration_seconds = maxf(0.001, duration)
	_elapsed_seconds = 0.0
	_apply_progress(0.0)
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	# Node.PROCESS_MODE_ALWAYS 解决暂停；除以time_scale再抵消命中顿帧/终结慢放。
	_elapsed_seconds += delta / maxf(Engine.time_scale, 0.001)
	var progress_value: float = clampf(
		_elapsed_seconds / _duration_seconds, 0.0, 1.0)
	_apply_progress(progress_value)
	if progress_value >= 1.0:
		set_process(false)
		finished.emit()


func _apply_progress(progress_value: float) -> void:
	if not is_instance_valid(_target) or _shake_x.size() < 5 or _shake_y.size() < 5:
		return
	var from_index: int
	var to_index: int
	var local_t: float
	var from_color: Color
	var to_color: Color
	var from_glow: float
	var to_glow: float
	if progress_value < 0.143:
		from_index = 4
		to_index = 0
		local_t = _smoothstep(progress_value / 0.143)
		from_color = _base_modulate
		to_color = _flash_color
		from_glow = 0.0
		to_glow = 1.0
	elif progress_value < 0.343:
		from_index = 0
		to_index = 1
		local_t = _smoothstep((progress_value - 0.143) / 0.20)
		from_color = _flash_color
		to_color = _impact_tint
		from_glow = 1.0
		to_glow = 0.82
	elif progress_value < 0.514:
		from_index = 1
		to_index = 2
		local_t = _smoothstep((progress_value - 0.343) / 0.171)
		from_color = _impact_tint
		to_color = _impact_tint
		from_glow = 0.82
		to_glow = 0.58
	elif progress_value < 0.657:
		from_index = 2
		to_index = 3
		local_t = _smoothstep((progress_value - 0.514) / 0.143)
		from_color = _impact_tint
		to_color = _impact_tint
		from_glow = 0.58
		to_glow = 0.36
	else:
		from_index = 3
		to_index = 4
		local_t = _smoothstep((progress_value - 0.657) / 0.343)
		from_color = _impact_tint
		to_color = _base_modulate
		from_glow = 0.36
		to_glow = 0.0
	var from_offset := Vector2(_shake_x[from_index], _shake_y[from_index])
	var to_offset := Vector2(_shake_x[to_index], _shake_y[to_index])
	_target.position = _base_position + from_offset.lerp(to_offset, local_t).round()
	_target.modulate = from_color.lerp(to_color, local_t)
	strength = lerpf(from_glow, to_glow, local_t)


func _smoothstep(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func debug_strength() -> float:
	return strength


func debug_is_driving() -> bool:
	return is_processing()


func _draw() -> void:
	if strength <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var center := size * 0.5
	var inset := 4.0
	var diamond := PackedVector2Array([
		Vector2(center.x, inset), Vector2(size.x - inset, center.y),
		Vector2(center.x, size.y - inset), Vector2(inset, center.y),
	])
	draw_colored_polygon(diamond, Color(RED_CORE, strength * 0.32))
	var closed := PackedVector2Array(diamond)
	closed.append(diamond[0])
	draw_polyline(closed, Color(RED_EDGE, strength * 0.82), 3.0, false)
	var outer := PackedVector2Array([
		Vector2(center.x, 1.0), Vector2(size.x - 1.0, center.y),
		Vector2(center.x, size.y - 1.0), Vector2(1.0, center.y),
		Vector2(center.x, 1.0),
	])
	draw_polyline(outer, Color(RED_CORE, strength * 0.38), 2.0, false)
