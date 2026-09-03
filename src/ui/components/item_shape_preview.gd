@tool
extends Control

## 道具图鉴的初始占格缩略图。每个占用格画成略带错位的双层手绘方框；
## 只表达初始形状，背包中的当前旋转态由背包视图负责。

const CELL_SOURCE_SIZE := 40.0
const CELL_OUTER_STROKE := [
	Vector2(5, 7), Vector2(34, 6), Vector2(35, 34), Vector2(6, 35), Vector2(5, 7),
]
const CELL_INNER_STROKE := [
	Vector2(8, 9), Vector2(32, 8), Vector2(33, 32), Vector2(9, 33), Vector2(8, 9),
]

@export var shape_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]:
	set(value):
		shape_cells = value.duplicate()
		queue_redraw()
@export var fill_color := Color("8B6B43"):
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := Color("3B2C20"):
	set(value):
		edge_color = value
		queue_redraw()
@export_range(0.0, 6.0, 1.0) var cell_gap: float = 2.0:
	set(value):
		cell_gap = maxf(value, 0.0)
		queue_redraw()


func set_shape(cells: Array[Vector2i]) -> void:
	shape_cells = cells


func _draw() -> void:
	if shape_cells.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var normalized: Array[Vector2i] = _normalized_shape(shape_cells)
	var bounds: Vector2i = _shape_size(normalized)
	var horizontal_space: float = size.x - cell_gap * float(bounds.x - 1)
	var vertical_space: float = size.y - cell_gap * float(bounds.y - 1)
	var side: float = floorf(minf(
			horizontal_space / float(bounds.x),
			vertical_space / float(bounds.y)))
	if side < 2.0:
		return
	var drawing_size := Vector2(
			float(bounds.x) * side + float(bounds.x - 1) * cell_gap,
			float(bounds.y) * side + float(bounds.y - 1) * cell_gap)
	var origin: Vector2 = (size - drawing_size) * 0.5
	origin = origin.floor()
	for cell: Vector2i in normalized:
		var position := origin + Vector2(cell) * (side + cell_gap)
		var rect := Rect2(position, Vector2.ONE * side)
		_draw_hand_cell(rect)


func _draw_hand_cell(rect: Rect2) -> void:
	var inset := maxf(1.0, rect.size.x * 0.05)
	var drawing_rect := rect.grow(-inset)
	var ink_width := clampf(rect.size.x * 0.055, 1.0, 2.4)
	for source_points: Array in [CELL_OUTER_STROKE, CELL_INNER_STROKE]:
		var points := PackedVector2Array()
		for point: Vector2 in source_points:
			points.append(drawing_rect.position + Vector2(
				point.x / CELL_SOURCE_SIZE * drawing_rect.size.x,
				point.y / CELL_SOURCE_SIZE * drawing_rect.size.y))
		draw_polyline(points, edge_color, ink_width + 1.0, false)
		draw_polyline(points, fill_color, ink_width, false)


func _normalized_shape(cells: Array[Vector2i]) -> Array[Vector2i]:
	var minimum: Vector2i = cells[0]
	for cell: Vector2i in cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
	var normalized: Array[Vector2i] = []
	for cell: Vector2i in cells:
		normalized.append(cell - minimum)
	return normalized


func _shape_size(cells: Array[Vector2i]) -> Vector2i:
	var maximum := Vector2i.ZERO
	for cell: Vector2i in cells:
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	return maximum + Vector2i.ONE
