extends Control

## 头像框四角矢量菱形角饰（独立节点，排在边框之上 → 稳定可见，不依赖 show_behind_parent）。
## 颜色由父 HeroFrame 通过 set("corner_color", ...) 设置。

@export var inset: float = 6.0
@export var radius: float = 2.5

var corner_color: Color = Color(0.5, 0.7, 1.0):
	set(v):
		corner_color = v
		if is_node_ready():
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var sz := size
	var cs := [
		Vector2(inset, inset),
		Vector2(sz.x - inset, inset),
		Vector2(inset, sz.y - inset),
		Vector2(sz.x - inset, sz.y - inset),
	]
	for c in cs:
		var pts := PackedVector2Array([
			c + Vector2(0.0, -radius), c + Vector2(radius, 0.0),
			c + Vector2(0.0, radius), c + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(pts, corner_color)
