@tool
class_name ItemTipPixelDivider
extends Control

## 道具标题下的纸面压痕：一行暖褐阴刻紧贴一行纸色亮边，
## 两端只用一像素宽短帽收口，避免长墨条与标题竞争。

const LINE_HEIGHT: float = 1.0
const HIGHLIGHT_HEIGHT: float = 1.0
const CAP_WIDTH: float = 1.0
const CAP_HEIGHT: float = 4.0

@export var shadow_color: Color = Color("8B765D"):
	set(value):
		shadow_color = value
		queue_redraw()

@export var highlight_color: Color = Color("E3CAA2"):
	set(value):
		highlight_color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func debug_geometry() -> Dictionary:
	var width: float = floorf(size.x)
	var line_width: float = maxf(width, 40.0)
	var start_x: float = 0.0
	var center_y: float = floorf(size.y * 0.5)
	var line_y: float = center_y - LINE_HEIGHT
	var cap_y: float = center_y - floorf(CAP_HEIGHT * 0.5)
	return {
		"line": Rect2(start_x, line_y, line_width, LINE_HEIGHT),
		"highlight": Rect2(
				start_x, line_y + LINE_HEIGHT, line_width, HIGHLIGHT_HEIGHT),
		"left_cap": Rect2(start_x, cap_y, CAP_WIDTH, CAP_HEIGHT),
		"right_cap": Rect2(
				start_x + line_width - CAP_WIDTH,
				cap_y,
				CAP_WIDTH,
				CAP_HEIGHT),
	}


func _draw() -> void:
	if size.x < 40.0:
		return
	var geometry: Dictionary = debug_geometry()
	draw_rect(geometry["line"] as Rect2, shadow_color)
	draw_rect(geometry["highlight"] as Rect2, highlight_color)
	draw_rect(geometry["left_cap"] as Rect2, shadow_color)
	draw_rect(geometry["right_cap"] as Rect2, shadow_color)
