@tool
class_name CodexSearchFieldFrame
extends Control

## 复刻左页顶部内描边：中段拱起，靠外沿与书脊两端缓慢回落。
## 只负责绘制，不改变 LineEdit 的规则点击矩形。

## 与书页“上一页 / 下一页”共用柔和墨色，不再像放大镜一样抢眼。
@export var passive_color := Color(0.278431, 0.227451, 0.168627, 0.9):
	set(value):
		passive_color = value
		queue_redraw()
@export var focused_color := Color(0.278431, 0.227451, 0.168627, 0.9):
	set(value):
		focused_color = value
		queue_redraw()
@export_range(1.0, 8.0, 1.0, "suffix:px") var page_curve_depth := 5.0:
	set(value):
		page_curve_depth = value
		queue_redraw()
@export_range(0.5, 4.0, 0.5, "suffix:px") var line_width := 2.0:
	set(value):
		line_width = value
		queue_redraw()

var _focused := false


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()


func debug_top_curve() -> PackedVector2Array:
	return _curve_points(3.0)


func debug_bottom_curve() -> PackedVector2Array:
	return _curve_points(maxf(size.y - 8.0, 3.0))


func _curve_points(base_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var width := maxf(size.x - 1.0, 1.0)
	# 13 个均匀采样点形成稳定的 2px 级阶梯；二次曲线与书本顶部
	# 由中段拱起、向两侧回落的轮廓一致，而不是旧版单向斜线。
	for index: int in 13:
		var progress := float(index) / 12.0
		var distance_from_apex := absf(progress - 0.5) * 2.0
		var drop := roundf(page_curve_depth * distance_from_apex * distance_from_apex)
		points.append(Vector2(roundf(width * progress), base_y + drop))
	return points


func _draw() -> void:
	var color := focused_color if _focused else passive_color
	var top := debug_top_curve()
	var bottom := debug_bottom_curve()
	draw_polyline(top, color, line_width, false)
	draw_polyline(bottom, color, line_width, false)
	draw_line(top[0], bottom[0], color, line_width, false)
	draw_line(top[top.size() - 1], bottom[bottom.size() - 1], color, line_width, false)
