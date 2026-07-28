extends Control

## battle_screen 顶部倒计时两侧的极简装饰。
## 常态色由场景注入；末三秒由中央菱形向两侧外端逐段染成警告色。

const DEFAULT_ORNAMENT_COLOR := Color(0.95, 0.91, 0.8, 1.0)
const DEFAULT_UNDERLAY_COLOR := Color(0.07, 0.04, 0.02, 0.88)
const ALERT_UNDERLAY_COLOR := Color(0.07, 0.04, 0.02, 0.72)
const TEXT_GAP := 20.0
const DIAMOND_RADIUS := 5.0
const SHAPE_GAP := 6.0
const LINE_LENGTH := 130.0
const WARNING_PROGRESS_DURATION := 0.72
const WARNING_COLOR_DURATION := 0.28

var ornament_color: Color = DEFAULT_ORNAMENT_COLOR
var underlay_color: Color = DEFAULT_UNDERLAY_COLOR
var underlay_width: float = 3.0
var warning_target: float = 0.0
var warning_progress: float = 0.0:
	set(value):
		warning_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var warning_color: Color = DEFAULT_ORNAMENT_COLOR:
	set(value):
		warning_color = value
		queue_redraw()
var _warning_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(queue_redraw)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func configure(normal_color: Color, normal_underlay_color: Color, normal_underlay_width: float) -> void:
	ornament_color = normal_color
	underlay_color = normal_underlay_color
	underlay_width = maxf(normal_underlay_width, 0.0)
	if is_zero_approx(warning_progress):
		warning_color = ornament_color
	queue_redraw()


func set_warning_state(seconds_left: int, target_color: Color, animate: bool = true) -> void:
	warning_target = _warning_progress_for_seconds(seconds_left)
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	if warning_target <= 0.0:
		warning_progress = 0.0
		warning_color = ornament_color
		return
	if not animate or not is_inside_tree():
		warning_progress = warning_target
		warning_color = target_color
		return
	_warning_tween = create_tween().set_parallel(true)
	_warning_tween.tween_property(
		self, "warning_progress", warning_target, WARNING_PROGRESS_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_warning_tween.tween_property(
		self, "warning_color", target_color, WARNING_COLOR_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _warning_progress_for_seconds(seconds_left: int) -> float:
	match seconds_left:
		3:
			return 1.0 / 3.0
		2:
			return 2.0 / 3.0
		1, 0:
			return 1.0
		_:
			return 1.0 if seconds_left < 0 else 0.0


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
	if underlay_width > 0.0 and underlay_color.a > 0.0:
		_draw_diamond(diamond_center, DIAMOND_RADIUS + underlay_width * 0.5, underlay_color)
	var diamond_warning_mix := smoothstep(0.0, 1.0 / 3.0, warning_progress)
	_draw_diamond(
		diamond_center, DIAMOND_RADIUS,
		ornament_color.lerp(warning_color, diamond_warning_mix))
	var line_inner_x := diamond_center.x + side * (DIAMOND_RADIUS + SHAPE_GAP)
	var line_outer_x := line_inner_x + side * LINE_LENGTH
	var line_points := PackedVector2Array([
		Vector2(line_inner_x, center.y), Vector2(line_outer_x, center.y)])
	# 越远离文字越淡：主体与暗衬同步渐隐，末端不留下孤立黑线。
	if underlay_width > 0.0 and underlay_color.a > 0.0:
		draw_polyline_colors(line_points, PackedColorArray([
			underlay_color, Color(underlay_color.r, underlay_color.g, underlay_color.b, 0.0)
		]), underlay_width, false)
	draw_polyline_colors(line_points, PackedColorArray([
		ornament_color,
		Color(ornament_color.r, ornament_color.g, ornament_color.b, ornament_color.a * 0.08)
	]), 2.0, false)
	if warning_progress <= 0.0:
		return
	var warning_outer_x := lerpf(line_inner_x, line_outer_x, warning_progress)
	var warning_alpha := lerpf(warning_color.a, warning_color.a * 0.08, warning_progress)
	var warning_points := PackedVector2Array([
		Vector2(line_inner_x, center.y), Vector2(warning_outer_x, center.y)])
	draw_polyline_colors(warning_points, PackedColorArray([
		ALERT_UNDERLAY_COLOR,
		Color(
			ALERT_UNDERLAY_COLOR.r,
			ALERT_UNDERLAY_COLOR.g,
			ALERT_UNDERLAY_COLOR.b,
			ALERT_UNDERLAY_COLOR.a * warning_alpha)
	]), 3.0, false)
	draw_polyline_colors(warning_points, PackedColorArray([
		warning_color,
		Color(warning_color.r, warning_color.g, warning_color.b, warning_alpha)
	]), 2.0, false)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]), color)
