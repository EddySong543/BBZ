extends Control

## 战斗画面中央的瞬时回合宣告。
## 与顶部倒计时共用「文字 → 菱形 → 向外渐隐线」语法，以尺寸、间距和动画区分层级。

const ORNAMENT_COLOR := Color(0.95, 0.91, 0.8, 1.0)
const DARK := Color(0.07, 0.04, 0.02, 0.82)

const FONT_SIZE := 56
const TEXT_GAP := 24.0
const DIAMOND_RADIUS := 5.0
const SHAPE_GAP := 7.0
const LINE_LENGTH := 112.0

var _label: Label
var _intro_tween: Tween
var _fade_tween: Tween

var presentation_alpha := 1.0:
	set(value):
		presentation_alpha = clampf(value, 0.0, 1.0)
		if _label != null:
			_label.modulate.a = presentation_alpha
		queue_redraw()

var line_reveal := 1.0:
	set(value):
		line_reveal = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(_refresh_layout)

	_label = Label.new()
	_label.name = "CueText"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bold_font := FontVariation.new()
	bold_font.base_font = FontManager.f16
	bold_font.variation_embolden = 0.55
	_label.add_theme_font_override("font", bold_font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", ORNAMENT_COLOR)
	# 方案 3：无描边、无底衬，以明确的右下定向投影从月亮高光中分离字形。
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.60))
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_constant_override("shadow_offset_x", 3)
	_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(_label)
	_refresh_layout()


func show_turn_start(text: String) -> void:
	_kill_tweens()
	_label.text = text
	presentation_alpha = 0.0
	line_reveal = 0.0
	_label.scale = Vector2.ONE * 0.96
	_refresh_layout()

	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(self, "presentation_alpha", 1.0, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(self, "line_reveal", 1.0, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_label, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 总时长再次延长至 1.4 秒；各相位同步放慢，并保留稳定阅读窗口。
	_fade_tween = create_tween()
	_fade_tween.tween_interval(1.0)
	_fade_tween.tween_property(self, "presentation_alpha", 0.0, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _refresh_layout() -> void:
	if _label == null:
		return
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.pivot_offset = size * 0.5
	queue_redraw()


func _kill_tweens() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


func _draw() -> void:
	if _label == null or _label.text.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var center := size * 0.5
	_draw_side(center, text_width * 0.5, -1.0)
	_draw_side(center, text_width * 0.5, 1.0)


func _draw_side(center: Vector2, text_half: float, side: float) -> void:
	var diamond_center := center + Vector2(
		side * (text_half + TEXT_GAP + DIAMOND_RADIUS), 0.0)
	var dark := Color(DARK.r, DARK.g, DARK.b, DARK.a * presentation_alpha)
	var bright := Color(
		ORNAMENT_COLOR.r, ORNAMENT_COLOR.g, ORNAMENT_COLOR.b,
		ORNAMENT_COLOR.a * presentation_alpha)
	_draw_diamond(diamond_center, DIAMOND_RADIUS + 1.5, dark)
	_draw_diamond(diamond_center, DIAMOND_RADIUS, bright)

	var visible_length := LINE_LENGTH * line_reveal
	if visible_length <= 0.5:
		return
	var line_inner_x := diamond_center.x + side * (DIAMOND_RADIUS + SHAPE_GAP)
	var line_outer_x := line_inner_x + side * visible_length
	var points := PackedVector2Array([
		Vector2(line_inner_x, center.y), Vector2(line_outer_x, center.y)])
	# 暗衬和米色主线同步渐隐；近端清晰，外端完全退入场景。
	draw_polyline_colors(points, PackedColorArray([
		dark, Color(DARK.r, DARK.g, DARK.b, 0.0)]), 3.0, false)
	draw_polyline_colors(points, PackedColorArray([
		bright, Color(ORNAMENT_COLOR.r, ORNAMENT_COLOR.g, ORNAMENT_COLOR.b, 0.04),
	]), 2.0, false)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]), color)
