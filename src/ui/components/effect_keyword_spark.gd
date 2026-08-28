@tool
class_name EffectKeywordSpark
extends Control

## 效果词角标：压在关键词末字右上角的四向像素星芒。
## 本节点不参与文本测量，因此不会挤动后续文字、换行或行高。

const MARK_SIZE := Vector2(7.0, 7.0)

@export var ink: Color = Color("2E2922"):
	set(value):
		ink = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = MARK_SIZE
	queue_redraw()


func configure(color: Color) -> void:
	size = MARK_SIZE
	ink = color
	queue_redraw()


func _draw() -> void:
	# 一长一短的四向光芒，全部锁在整数坐标，避免变成圆点或普通加号。
	draw_rect(Rect2(3.0, 0.0, 1.0, 7.0), ink)
	draw_rect(Rect2(0.0, 3.0, 7.0, 1.0), ink)
	draw_rect(Rect2(2.0, 2.0, 3.0, 3.0), ink)
