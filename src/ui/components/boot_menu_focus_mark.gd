class_name BootMenuFocusMark
extends Control

const BLADE_COLOR := Color("eda63a")
const BLADE_PEAK_COLOR := Color("ffd773")
const SEPARATOR_COLOR := Color("0f1b26")
const TEXT_FOCUS_OFFSET_X: float = 4.0
const TEXT_PRESS_OFFSET_Y: float = 1.0
const BLADE_GAP: float = 16.0
const MIN_BLADE_HEIGHT: float = 4.0
const MAX_BLADE_HEIGHT: float = 18.0

var focus_strength: float = 0.0
var press_strength: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_state(focus: float, press: float) -> void:
	focus_strength = clampf(focus, 0.0, 1.0)
	press_strength = clampf(press, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if focus_strength <= 0.001:
		return
	var geometry := _blade_geometry()
	var center: Vector2 = geometry["center"]
	var half_height: float = float(geometry["blade_height"]) * 0.5
	var separator := PackedVector2Array([
		center + Vector2(-3.0, half_height + 2.0),
		center + Vector2(2.0, -half_height - 2.0),
		center + Vector2(8.0, -half_height - 2.0),
		center + Vector2(3.0, half_height + 2.0),
	])
	var blade := PackedVector2Array([
		center + Vector2(-1.0, half_height),
		center + Vector2(3.0, -half_height),
		center + Vector2(7.0, -half_height),
		center + Vector2(2.0, half_height),
	])
	draw_colored_polygon(separator, SEPARATOR_COLOR)
	draw_colored_polygon(blade, BLADE_COLOR)
	if half_height >= 5.0:
		draw_line(
			center + Vector2(4.0, -half_height + 2.0),
			center + Vector2(0.5, half_height - 2.0),
			BLADE_PEAK_COLOR,
			1.0,
			false)


func _blade_geometry() -> Dictionary:
	var parent_button := get_parent() as Button
	if parent_button == null:
		return {
			"center": Vector2.ZERO,
			"blade_height": 0.0,
		}
	var font: Font = parent_button.get_theme_font(&"font")
	var font_size: int = parent_button.get_theme_font_size(&"font_size")
	var text_width: float = font.get_string_size(
		parent_button.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size).x
	var text_left: float = (size.x - text_width) * 0.5
	text_left += focus_strength * TEXT_FOCUS_OFFSET_X
	var blade_height: float = snappedf(
		lerpf(MIN_BLADE_HEIGHT, MAX_BLADE_HEIGHT, focus_strength),
		2.0)
	var center := Vector2(
		text_left - BLADE_GAP,
		size.y * 0.5 + press_strength * TEXT_PRESS_OFFSET_Y)
	return {
		"center": center,
		"blade_height": blade_height,
	}


func debug_state() -> Dictionary:
	var geometry := _blade_geometry()
	return {
		"active": focus_strength > 0.001,
		"focus_strength": focus_strength,
		"press_strength": press_strength,
		"center": geometry["center"],
		"blade_height": geometry["blade_height"],
		"blade_color": BLADE_COLOR,
		"blade_peak_color": BLADE_PEAK_COLOR,
		"separator_color": SEPARATOR_COLOR,
	}
