@tool
extends Control

## 编辑器专用头像网格预览。
## 运行时由 hero_gallery_screen.gd 在本节点下创建真实头像卡；这里不绘制，避免重复显示。

const ITEM_FRAME_TEX := preload("res://assets/ui/item_frame.png")
const FRAME_ART_SCALE := 87.25 / 68.0
const FRAME_OFFSET_RATIO := Vector2(-9.6 / 68.0, -10.0 / 68.0)
const CELL_INSET_RATIO := 5.5 / 68.0
const CELL_FILL := Color("71685D")
const CELL_CENTER := Color("8C7C68")
const POINTER_COLOR := Color("6B4A32")
const POINTER_FILL := Color("A9855D")

@export_group("Grid Preview")
@export_range(1, 12, 1) var columns: int = 4:
	set(value):
		columns = maxi(value, 1)
		queue_redraw()
@export_range(1, 24, 1) var cards_per_page: int = 12:
	set(value):
		cards_per_page = maxi(value, 1)
		queue_redraw()
@export_range(32.0, 180.0, 1.0) var box_size: float = 104.0:
	set(value):
		box_size = maxf(value, 32.0)
		queue_redraw()
@export_range(48.0, 260.0, 1.0) var step_x: float = 170.0:
	set(value):
		step_x = maxf(value, 48.0)
		queue_redraw()
@export_range(64.0, 280.0, 1.0) var row_height: float = 196.0:
	set(value):
		row_height = maxf(value, 64.0)
		queue_redraw()
@export_range(0.0, 24.0, 1.0) var row_stagger_x: float = 6.0:
	set(value):
		row_stagger_x = maxf(value, 0.0)
		queue_redraw()
@export_range(0.0, 24.0, 1.0) var page_curve_y: float = 5.0:
	set(value):
		page_curve_y = maxf(value, 0.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for index in cards_per_page:
		var origin := preview_card_position(index)
		var inset := box_size * CELL_INSET_RATIO
		var cell_rect := Rect2(
			origin + Vector2.ONE * inset,
			Vector2.ONE * (box_size - inset * 2.0))
		draw_rect(cell_rect, CELL_FILL)
		var center_pad := box_size * 0.22
		draw_rect(cell_rect.grow(-center_pad), CELL_CENTER)
		var frame_rect := Rect2(
			origin + Vector2.ONE * box_size * FRAME_OFFSET_RATIO,
			Vector2.ONE * box_size * FRAME_ART_SCALE)
		var frame_tint := Color("E7BA60") if index == 0 else Color.WHITE
		draw_texture_rect(ITEM_FRAME_TEX, frame_rect, false, frame_tint)
		if index == 0:
			_draw_selected_preview(origin)


func _draw_selected_preview(origin: Vector2) -> void:
	var pointer_origin := origin + Vector2(-36.0, floorf((box_size - 22.0) * 0.5))
	draw_rect(Rect2(pointer_origin + Vector2(0, 9), Vector2(9, 3)), Color(POINTER_COLOR, 0.34))
	draw_rect(Rect2(pointer_origin + Vector2(5, 5), Vector2(8, 3)), Color(POINTER_COLOR, 0.62))
	draw_rect(Rect2(pointer_origin + Vector2(5, 14), Vector2(8, 3)), Color(POINTER_COLOR, 0.62))
	var outer := PackedVector2Array([
		pointer_origin + Vector2(10, 2), pointer_origin + Vector2(17, 2),
		pointer_origin + Vector2(28, 11), pointer_origin + Vector2(17, 20),
		pointer_origin + Vector2(10, 20), pointer_origin + Vector2(20, 11)])
	draw_colored_polygon(outer, POINTER_COLOR)
	var inner := PackedVector2Array([
		pointer_origin + Vector2(14, 6), pointer_origin + Vector2(17, 6),
		pointer_origin + Vector2(23, 11), pointer_origin + Vector2(17, 16),
		pointer_origin + Vector2(14, 16), pointer_origin + Vector2(20, 11)])
	draw_colored_polygon(inner, POINTER_FILL)


func preview_card_position(index: int) -> Vector2:
	var row := floori(index / float(columns))
	var column := index % columns
	var center_column := (columns - 1) * 0.5
	var normalized_edge := absf(float(column) - center_column) / maxf(center_column, 1.0)
	return Vector2(
		column * step_x + float(row % 2) * row_stagger_x,
		row * row_height + normalized_edge * normalized_edge * page_curve_y)
