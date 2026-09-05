@tool
extends Control

## 编辑器专用的道具网格占位预览。运行时由 item_gallery_screen.gd 填入真实道具卡。
const ITEM_FRAME_TEX := ItemFrameStyle.FRAME_TEXTURE
const PREVIEW_CELL_TOP := ItemFrameStyle.CELL_TOP[1]
const PREVIEW_CELL_BOTTOM := ItemFrameStyle.CELL_BOTTOM[1]
# 兼容旧测试/编辑器工具命名。
const PREVIEW_CELL_FILL := PREVIEW_CELL_TOP
const PREVIEW_CELL_CENTER := PREVIEW_CELL_BOTTOM

@export_group("Grid Preview")
@export_range(1, 12, 1) var columns: int = 4:
	set(value):
		columns = maxi(value, 1)
		queue_redraw()
@export_range(1, 36, 1) var cards_per_page: int = 12:
	set(value):
		cards_per_page = maxi(value, 1)
		queue_redraw()
@export_range(48.0, 160.0, 1.0) var box_size: float = 104.0:
	set(value):
		box_size = maxf(value, 48.0)
		queue_redraw()
@export_range(64.0, 220.0, 1.0) var step_x: float = 170.0:
	set(value):
		step_x = maxf(value, 64.0)
		queue_redraw()
@export_range(80.0, 240.0, 1.0) var row_height: float = 196.0:
	set(value):
		row_height = maxf(value, 80.0)
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
		var layout := ItemFrameStyle.item_frame_layout(
			&"gallery_left", origin, box_size)
		var cell_rect: Rect2 = layout["cell_rect"]
		for band in range(12):
			var band_t := float(band) / 11.0
			var band_rect := Rect2(
				cell_rect.position + Vector2(0.0, floorf(cell_rect.size.y * band_t)),
				Vector2(cell_rect.size.x, ceilf(cell_rect.size.y / 11.0) + 1.0))
			draw_rect(band_rect, PREVIEW_CELL_TOP.lerp(PREVIEW_CELL_BOTTOM, band_t))
		var frame_rect: Rect2 = layout["frame_rect"]
		var frame_shadow_rect: Rect2 = layout["frame_shadow_rect"]
		draw_texture_rect(ITEM_FRAME_TEX,
			frame_shadow_rect,
			false, ItemFrameStyle.DROP_SHADOW_COLOR)
		draw_texture_rect(ITEM_FRAME_TEX, frame_rect, false)
		draw_line(
			origin + Vector2(12.0, box_size + 10.0),
			origin + Vector2(box_size - 12.0, box_size + 10.0),
			Color(0.24, 0.19, 0.12, 0.38), 2.0)


func preview_card_position(index: int) -> Vector2:
	var row := floori(index / float(columns))
	var column := index % columns
	var center_column := (columns - 1) * 0.5
	var normalized_edge := absf(float(column) - center_column) / maxf(center_column, 1.0)
	return Vector2(
		column * step_x + float(row % 2) * row_stagger_x,
		row * row_height + normalized_edge * normalized_edge * page_curve_y)
