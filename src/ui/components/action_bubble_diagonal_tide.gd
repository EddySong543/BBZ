class_name ActionBubbleDiagonalTide
extends Control

## 技能 Bubble 的斜向像素潮。与图标收束材质分离绘制，确保原图透明后金/黑交接色
## 仍清楚可见；只占图标安全区，不触碰按钮外框。

const GRID := Vector2i(9, 9)

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var ink_color := Color("d7a43d"):
	set(value):
		ink_color = value
		queue_redraw()

var exit_direction := Vector2.ONE:
	set(value):
		exit_direction = Vector2(
			1.0 if value.x >= 0.0 else -1.0,
			1.0 if value.y >= 0.0 else -1.0)
		queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _frontier() -> float:
	# 单向通过：不在换图中点触底后反扫。少量 smoothstep 让起落更沉稳，
	# 但主体仍接近匀速，方向不会被误读。
	return lerpf(progress, smoothstep(0.0, 1.0, progress), 0.32)


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
	var dark_ink := ink_color.get_luminance() < 0.20
	# 高亮只做材质层次，不做发光扫描边；黑潮尤其保持近黑主体。
	var accent := ink_color.lightened(0.13 if dark_ink else 0.09)
	for y: int in GRID.y:
		for x: int in GRID.x:
			var strength := _cell_strength(x, y)
			if strength <= 0.0:
				continue
			var is_accent := posmod(x * 3 + y * 5, 7) == 0
			var color := accent if is_accent else ink_color
			color.a = strength
			var trail := strength < 0.78
			var block_scale := 0.78 if trail else (
				0.88 if posmod(x * 5 + y * 3, 11) == 0 else 1.0)
			var block_size := (cell_size * block_scale).ceil()
			var block_origin := (Vector2(x, y) * cell_size
					+ (cell_size - block_size) * 0.5).round()
			draw_rect(Rect2(block_origin, block_size), color)


func _cell_strength(x: int, y: int) -> float:
	var uv := (Vector2(x, y) + Vector2.ONE * 0.5) / Vector2(GRID)
	var directed := Vector2(
		uv.x if exit_direction.x > 0.0 else 1.0 - uv.x,
		uv.y if exit_direction.y > 0.0 else 1.0 - uv.y)
	var axis := (directed.x + directed.y) * 0.5
	var perpendicular := (uv.x - uv.y + 1.0) * 0.5
	var band := floori(perpendicular * 9.0)
	var band_phase := float(posmod(band, 4)) / 3.0
	var frontier := clampf(_frontier() + (band_phase - 0.5) * 0.045, 0.0, 1.0)
	var signed_distance := axis - frontier
	var distance := absf(signed_distance)
	if distance <= 0.13:
		return 0.94

	# 单向像素潮只在已经扫过的一侧留下厚而短的碎块尾迹。
	if signed_distance >= 0.0 or distance > 0.32:
		return 0.0
	var sparse_gate := posmod(x * 7 + y * 11 + band * 3, 7)
	var allowed := 4 if distance <= 0.22 else 2
	if sparse_gate > allowed:
		return 0.0
	return lerpf(0.78, 0.36, inverse_lerp(0.13, 0.32, distance))
