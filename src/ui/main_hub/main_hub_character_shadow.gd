@tool
class_name MainHubCharacterShadow
extends Control

## One shared, character-independent contact shadow for the main hub.

const BASE_WIDTH: float = 62.0
const MINIMUM_WIDTH: float = 42.0
const BASE_HEIGHT: float = 12.0
const MINIMUM_HEIGHT: float = 8.0
const BASE_OPACITY: float = 0.46
const MINIMUM_OPACITY: float = 0.24
const SHADOW_RGB := Color(0.025, 0.070, 0.050, 1.0)

@export_range(0.25, 3.0, 0.05) var display_scale: float = 1.5

var _current_lift: float = 0.0
var _direction_x: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_motion(lift: float, direction_x: float) -> void:
	_current_lift = clampf(lift, 0.0, 1.0)
	_direction_x = clampf(direction_x, -1.0, 1.0)
	queue_redraw()


func style_signature() -> Dictionary:
	return {
		"base_width": BASE_WIDTH,
		"minimum_width": MINIMUM_WIDTH,
		"base_height": BASE_HEIGHT,
		"minimum_height": MINIMUM_HEIGHT,
		"base_opacity": BASE_OPACITY,
		"minimum_opacity": MINIMUM_OPACITY,
		"display_scale": display_scale,
		"current_lift": _current_lift,
	}


func _draw() -> void:
	var width := lerpf(BASE_WIDTH, MINIMUM_WIDTH, _current_lift) * display_scale
	var height := lerpf(BASE_HEIGHT, MINIMUM_HEIGHT, _current_lift) * display_scale
	var opacity := lerpf(BASE_OPACITY, MINIMUM_OPACITY, _current_lift)
	var center_offset := Vector2(
			roundf(_direction_x * _current_lift * 2.0) * display_scale, 0.0)
	draw_set_transform(center_offset, 0.0, Vector2(width, height))
	draw_circle(Vector2.ZERO, 0.5, Color(SHADOW_RGB, opacity), true, -1.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
