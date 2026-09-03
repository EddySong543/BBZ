@tool
class_name CommandSequenceCancelGlyph
extends Control

signal tuning_changed

## 清晰双线 x：只保留米白主体和战斗 UI 同方向的右下投影。

const DEFAULT_COLOR := Color("#F2E8CC")
const IDLE_ALPHA := 1.0

@export_group("小 x 手动调整")
@export var editor_preview: bool = false:
	set(value):
		editor_preview = value
		_update_editor_preview_state()
@export var tuning_center_offset: Vector2 = Vector2.ZERO:
	set(value):
		tuning_center_offset = value
		_notify_tuning_changed()
@export_range(2.0, 12.0, 0.25) var tuning_line_length: float = 5.5:
	set(value):
		tuning_line_length = maxf(value, 1.0)
		_notify_tuning_changed()
@export_range(0.5, 6.0, 0.25) var tuning_line_width: float = 2.5:
	set(value):
		tuning_line_width = maxf(value, 0.5)
		_notify_tuning_changed()
@export var tuning_color: Color = DEFAULT_COLOR:
	set(value):
		tuning_color = value
		_notify_tuning_changed()
@export var tuning_slot_offset: Vector2 = Vector2.ZERO:
	set(value):
		tuning_slot_offset = value
		_notify_tuning_changed()
@export_group("小 x 底投影")
@export var tuning_shadow_offset: Vector2 = Vector2(3.0, 6.0):
	set(value):
		tuning_shadow_offset = value
		_notify_tuning_changed()
@export var tuning_shadow_color: Color = Color(0.02, 0.012, 0.008, 0.52):
	set(value):
		tuning_shadow_color = value
		_notify_tuning_changed()
@export_range(0.0, 10.0, 0.25) var tuning_shadow_width: float = 4.5:
	set(value):
		tuning_shadow_width = maxf(value, 0.0)
		_notify_tuning_changed()
@export_group("")

var hover_strength: float = 0.0:
	set(value):
		hover_strength = clampf(value, 0.0, 1.0)
		queue_redraw()
var _hover_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_editor_preview_state()
	queue_redraw()


func _notify_tuning_changed() -> void:
	queue_redraw()
	if is_inside_tree():
		tuning_changed.emit()


func _update_editor_preview_state() -> void:
	if editor_preview:
		visible = Engine.is_editor_hint()


func configure(normal_color: Color,
		tuning_shadow_color: Color = Color(0.02, 0.012, 0.008, 0.52),
		tuning_shadow_offset: Vector2 = Vector2(3.0, 6.0),
		source: Control = null) -> void:
	self.tuning_color = normal_color
	self.tuning_shadow_color = tuning_shadow_color
	self.tuning_shadow_offset = tuning_shadow_offset
	if source != null:
		tuning_center_offset = source.get("tuning_center_offset")
		tuning_line_length = float(source.get("tuning_line_length"))
		tuning_line_width = float(source.get("tuning_line_width"))
		self.tuning_color = source.get("tuning_color")
		tuning_slot_offset = source.get("tuning_slot_offset")
		self.tuning_shadow_offset = source.get("tuning_shadow_offset")
		self.tuning_shadow_color = source.get("tuning_shadow_color")
		tuning_shadow_width = float(source.get("tuning_shadow_width"))
	queue_redraw()


func set_hovered(value: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "hover_strength", 1.0 if value else 0.0, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func debug_geometry() -> Dictionary:
	var length: float = tuning_line_length + hover_strength * 0.7
	return {
		"center": size * 0.5 + tuning_center_offset,
		"line_length": length,
		"main_width": tuning_line_width,
		"underlay_enabled": false,
		"underlay_width": 0.0,
		"slot_offset": tuning_slot_offset,
		"bottom_shadow_color": tuning_shadow_color,
		"bottom_shadow_offset": tuning_shadow_offset,
		"bottom_shadow_width": tuning_shadow_width,
		"antialiased": false,
		"hover_strength": hover_strength,
	}


func _draw() -> void:
	var center: Vector2 = size * 0.5 + tuning_center_offset
	var length: float = tuning_line_length + hover_strength * 0.7
	var alpha: float = lerpf(IDLE_ALPHA, 1.0, hover_strength)
	var active_shadow := tuning_shadow_color
	active_shadow.a *= alpha
	var active_color := tuning_color.lerp(Color("#FFF9E8"), hover_strength * 0.20)
	active_color.a *= alpha
	var directions: Array[Vector2] = [Vector2(1.0, 1.0).normalized(),
		Vector2(1.0, -1.0).normalized()]
	for direction: Vector2 in directions:
		draw_line(center - direction * length + tuning_shadow_offset,
			center + direction * length + tuning_shadow_offset,
			active_shadow, tuning_shadow_width, false)
	for direction: Vector2 in directions:
		draw_line(center - direction * length, center + direction * length,
			active_color, tuning_line_width, false)
