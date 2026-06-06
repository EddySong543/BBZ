extends Control

## 头像框四角阵营宝石（独立节点，排在边框之上 → 稳定可见，不依赖 show_behind_parent）。
## 颜色由父 HeroFrame 通过 set("corner_color", ...) 按阵营设置 → 这是当前的敌我区分方式（边框统一中性色）。
## inset 较大 → 宝石落在头像内部、脱离边框；每颗宝石 = 暗边 + 阵营主体 + 高光核(三层菱形)。

@export var inset: float = 13.0
@export var radius: float = 4.0

@export var corner_color: Color = Color(0.5, 0.7, 1.0):
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
		_diamond(c, radius + 1.2, Color(0.03, 0.03, 0.05, 0.85))  # 暗边(衬底)
		_diamond(c, radius, corner_color)                          # 阵营主体
		_diamond(c, radius * 0.42, corner_color.lightened(0.55))   # 高光核


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0),
	]), col)
