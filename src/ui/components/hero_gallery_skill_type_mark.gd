@tool
class_name HeroGallerySkillTypeMark
extends Control

## 主/被动技能标签底：恢复最初通过的深墨外沿 + 红蓝长方形印签。

@export var passive: bool = true:
	set(value):
		passive = value
		queue_redraw()
@export var passive_color: Color = Color("59738B"):
	set(value):
		passive_color = value
		queue_redraw()
@export var active_color: Color = Color("A9503F"):
	set(value):
		active_color = value
		queue_redraw()
@export var edge_color: Color = Color("3D301E"):
	set(value):
		edge_color = value
		queue_redraw()
@export_range(0.0, 1.0, 0.05) var edge_alpha: float = 0.75:
	set(value):
		edge_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(80, 34)
	queue_redraw()


func set_passive(value: bool) -> void:
	passive = value


func _draw() -> void:
	var fill_color := passive_color if passive else active_color
	draw_rect(Rect2(0, 0, 80, 34), Color(edge_color, edge_alpha))
	draw_rect(Rect2(2, 2, 76, 30), fill_color)
