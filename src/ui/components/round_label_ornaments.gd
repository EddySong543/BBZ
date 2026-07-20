extends Control

## battle_screen 顶部倒计时两侧的极简装饰。
## 每侧从内向外：金色菱形 → 小间隔 → 水平金线；文字本身完全沿用原版统一样式。

const ORNAMENT_COLOR := Color(0.95, 0.91, 0.8, 1.0)   # 与中间「回合 X」完全同色
const DARK := Color(0.07, 0.04, 0.02, 0.88)
const TEXT_GAP := 20.0
const DIAMOND_RADIUS := 5.0
const SHAPE_GAP := 6.0
const LINE_LENGTH := 130.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(queue_redraw)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var label := get_parent() as Label
	if label == null or label.text.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	# 以最大两位倒计时占位宽度定位装饰：10→9→8 时数字变化，菱形与线条保持静止。
	var text_width := maxf(
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x,
		font.get_string_size("00", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var text_half := text_width * 0.5
	_draw_side(center, text_half, -1.0)
	_draw_side(center, text_half, 1.0)


func _draw_side(center: Vector2, text_half: float, side: float) -> void:
	# 菱形最靠近文字；直线再向外退 5px，保持三者边界清楚。
	var diamond_center := center + Vector2(side * (text_half + TEXT_GAP + DIAMOND_RADIUS), 0.0)
	_draw_diamond(diamond_center, DIAMOND_RADIUS + 1.5, DARK)
	_draw_diamond(diamond_center, DIAMOND_RADIUS, ORNAMENT_COLOR)
	var line_inner_x := diamond_center.x + side * (DIAMOND_RADIUS + SHAPE_GAP)
	var line_outer_x := line_inner_x + side * LINE_LENGTH
	var line_points := PackedVector2Array([
		Vector2(line_inner_x, center.y), Vector2(line_outer_x, center.y)])
	# 越远离文字越淡：主体与暗衬同步渐隐，末端不留下孤立黑线。
	draw_polyline_colors(line_points, PackedColorArray([
		DARK, Color(DARK.r, DARK.g, DARK.b, 0.0)]), 3.0, false)
	draw_polyline_colors(line_points, PackedColorArray([
		ORNAMENT_COLOR, Color(ORNAMENT_COLOR.r, ORNAMENT_COLOR.g, ORNAMENT_COLOR.b, 0.08)]), 2.0, false)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]), color)
