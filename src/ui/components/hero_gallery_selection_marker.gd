@tool
class_name HeroGallerySelectionMarker
extends Control

## 英雄图鉴选中标记：无描边的实心三角像素箭头。
## 以 4px 为基础像素逐行扩展，使用单一书页棕，避免双层颜色显脏。

@export var color: Color = Color("7B5E3E"):
	set(value):
		color = value
		queue_redraw()

const PIXEL_SIZE := 4.0
const ROW_COUNT := 9
const APEX_ROW := 4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(20, 36)
	queue_redraw()


func _draw() -> void:
	for row: int in ROW_COUNT:
		var column_count: int = row + 1 if row <= APEX_ROW else ROW_COUNT - row
		var y := float(row) * PIXEL_SIZE
		for column: int in column_count:
			var x := float(column) * PIXEL_SIZE
			draw_rect(Rect2(x, y, PIXEL_SIZE, PIXEL_SIZE), color)
