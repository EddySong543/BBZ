class_name DamageNumberVerticalTide
extends Control

## H18「游丝引」伤害数字专用黑色像素潮。
## 前半段从下向上覆盖数字区域；全覆盖交接后，后半段仍沿同一方向揭开数字。
## 两段边界都只向上移动，不在触顶后反向扫描。

const GRID := Vector2i(9, 7)

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var ink_color := Color("17131d"):
	set(value):
		ink_color = value
		queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _local_phase() -> float:
	return progress * 2.0 if progress < 0.5 else (progress - 0.5) * 2.0


func _frontier_y() -> float:
	var local_progress: float = _local_phase()
	var eased: float = lerpf(
		local_progress, smoothstep(0.0, 1.0, local_progress), 0.24)
	return lerpf(1.10, -0.10, eased)


func debug_visible_block_count() -> int:
	if progress <= 0.0 or progress >= 1.0:
		return 0
	var count := 0
	for y: int in GRID.y:
		for x: int in GRID.x:
			if _cell_strength(x, y) > 0.0:
				count += 1
	return count


func _draw() -> void:
	if progress <= 0.0 or progress >= 1.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var cell_size := size / Vector2(GRID)
	var accent := ink_color.lightened(0.13)
	for y: int in GRID.y:
		for x: int in GRID.x:
			var strength: float = _cell_strength(x, y)
			if strength <= 0.0:
				continue
			var color: Color = accent if posmod(x * 3 + y * 5, 7) == 0 else ink_color
			color.a = strength
			var edge_cell: bool = strength < 0.90
			var block_scale: float = 0.82 if edge_cell else (
				0.90 if posmod(x * 5 + y * 3, 11) == 0 else 1.0)
			var block_size: Vector2 = (cell_size * block_scale).ceil()
			var block_origin: Vector2 = (Vector2(x, y) * cell_size
				+ (cell_size - block_size) * 0.5).round()
			draw_rect(Rect2(block_origin, block_size), color)


func _cell_strength(x: int, y: int) -> float:
	var uv := (Vector2(x, y) + Vector2.ONE * 0.5) / Vector2(GRID)
	var column_phase: float = (float(posmod(x * 5, 7)) / 6.0 - 0.5) * 0.10
	var frontier: float = _frontier_y() + column_phase
	var distance: float = absf(uv.y - frontier)
	var covered: bool
	if progress < 0.5:
		# 覆盖段：潮头以下已经被黑潮吞没。
		covered = uv.y >= frontier
	else:
		# 揭示段：潮头以下已经退场，潮头以上仍遮住数字。
		covered = uv.y <= frontier
	if covered:
		return 0.98 if distance <= 0.18 else 0.92
	# 潮头外沿保留一层稀疏碎块，保持 H13 黑潮的像素颗粒边缘。
	if distance > 0.18:
		return 0.0
	return 0.72 if posmod(x * 7 + y * 11, 5) <= 2 else 0.0
