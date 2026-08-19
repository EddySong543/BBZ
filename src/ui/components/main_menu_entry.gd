class_name MainMenuEntry
extends Button

## 主界面地图入口牌：只承担功能名称、焦点与点击反馈，不承载地图玩法。

@export var destination_id: String = ""
@export var entry_title: String = "入口"
@export var entry_subtitle: String = ""
@export var accent_color: Color = Color("e2b84f")
@export var prominent: bool = false

var _title_label: Label
var _subtitle_label: Label
var _focused: bool = false
var _emphasized: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s · %s" % [entry_title, entry_subtitle]
	_build_labels()
	mouse_entered.connect(_set_focused.bind(true))
	mouse_exited.connect(_set_focused.bind(false))
	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))
	set_process(true)
	queue_redraw()


func _build_labels() -> void:
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.position = Vector2(28.0, 18.0)
	_title_label.size = Vector2(size.x - 56.0, 46.0)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(_title_label, 34 if prominent else 28)
	_title_label.add_theme_color_override("font_color", Color("fff1bb"))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.04, 0.03, 0.02, 0.9))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.position = Vector2(30.0, 63.0 if prominent else 58.0)
	_subtitle_label.size = Vector2(size.x - 60.0, 30.0)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(_subtitle_label, 17 if prominent else 15)
	_subtitle_label.add_theme_color_override("font_color", Color("d8cba7"))
	add_child(_subtitle_label)
	_apply_copy(entry_title, entry_subtitle)


func _apply_font(label: Label, pixel_size: int) -> void:
	var font_manager: Node = get_node_or_null("/root/FontManager")
	if font_manager != null:
		font_manager.call("apply", label, pixel_size)
	else:
		label.add_theme_font_size_override("font_size", pixel_size)


func set_status(title_text: String, subtitle_text: String) -> void:
	_apply_copy(title_text, subtitle_text)


func reset_copy() -> void:
	_apply_copy(entry_title, entry_subtitle)


func set_emphasized(enabled: bool) -> void:
	_emphasized = enabled
	queue_redraw()


func flash_confirm() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.045, 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_copy(title_text: String, subtitle_text: String) -> void:
	if _title_label != null:
		_title_label.text = title_text
	if _subtitle_label != null:
		_subtitle_label.text = subtitle_text


func _set_focused(enabled: bool) -> void:
	_focused = enabled
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	if _focused or _emphasized:
		queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 3.2)
	var active: bool = _focused or has_focus() or _emphasized
	var border_alpha: float = 0.92 if active else 0.52
	if _emphasized:
		border_alpha = lerpf(0.78, 1.0, pulse)
	var panel_rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 14.0))
	var outer: PackedVector2Array = _chamfered_rect(panel_rect, 13.0)
	var inner: PackedVector2Array = _chamfered_rect(panel_rect.grow(-3.0), 10.0)
	draw_colored_polygon(outer, Color(accent_color, border_alpha))
	draw_colored_polygon(inner, Color(0.055, 0.075, 0.060, 0.90 if active else 0.80))
	draw_rect(Rect2(panel_rect.position + Vector2(18.0, 11.0),
			Vector2(7.0, panel_rect.size.y - 22.0)), Color(accent_color, 0.82))
	var pointer_center := Vector2(size.x * 0.5, size.y - 2.0)
	var pointer := PackedVector2Array([
		pointer_center + Vector2(-13.0, -8.0),
		pointer_center + Vector2(13.0, -8.0),
		pointer_center + Vector2(0.0, 8.0),
	])
	draw_colored_polygon(pointer, Color(accent_color, border_alpha))
	if active:
		draw_line(Vector2(31.0, panel_rect.end.y - 11.0),
				Vector2(panel_rect.end.x - 20.0, panel_rect.end.y - 11.0),
				Color(accent_color, 0.36 + pulse * 0.24), 3.0)


func _chamfered_rect(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x - cut, rect.position.y),
		rect.end - Vector2(0.0, rect.size.y - cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x + cut, rect.end.y),
		rect.position + Vector2(0.0, rect.size.y - cut),
		rect.position + Vector2(0.0, cut),
	])
