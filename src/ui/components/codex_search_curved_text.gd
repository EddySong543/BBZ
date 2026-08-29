@tool
class_name CodexSearchCurvedText
extends Control

## LineEdit 保留输入、焦点与回车行为；本层只把文字和闪烁光标沿书页弧度绘出。
## 这样输入点击区仍是规整矩形，视觉基线则与搜索框的内描边一致。

@export_node_path("LineEdit") var line_edit_path := NodePath("../SearchInput")
@export var font: Font
@export_range(8, 48, 1) var font_size := 17
@export var text_color := Color(0.203922, 0.156863, 0.113725, 1.0)
@export var placeholder_color := Color(0.403922, 0.341176, 0.27451, 0.68)
@export var caret_color := Color(0.603922, 0.407843, 0.156863, 1.0)
@export_range(0.0, 6.0, 0.5, "suffix:px") var text_curve_depth := 3.0
@export_range(0.0, 3.0, 0.5, "suffix:px") var page_rise_across_text := 1.0
@export_range(0.0, 40.0, 1.0, "suffix:px") var left_padding := 12.0
@export_range(0.0, 80.0, 1.0, "suffix:px") var right_padding := 42.0
@export_range(0.1, 1.5, 0.05, "suffix:s") var caret_blink_interval := 0.55

var _line_edit: LineEdit
var _caret_elapsed := 0.0
var _caret_visible := true
var _last_caret_column := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	_bind_line_edit(get_node_or_null(line_edit_path) as LineEdit)
	set_process(not Engine.is_editor_hint())
	queue_redraw()


func _bind_line_edit(value: LineEdit) -> void:
	if _line_edit == value:
		return
	_line_edit = value
	if _line_edit == null:
		return
	_line_edit.text_changed.connect(_on_line_edit_changed)
	_line_edit.focus_entered.connect(_on_focus_changed.bind(true))
	_line_edit.focus_exited.connect(_on_focus_changed.bind(false))
	_line_edit.gui_input.connect(_on_line_edit_gui_input)
	queue_redraw()


func _process(delta: float) -> void:
	if _line_edit == null or not _line_edit.has_focus():
		return
	var caret_column := _line_edit.caret_column
	if caret_column != _last_caret_column:
		_last_caret_column = caret_column
		_caret_elapsed = 0.0
		_caret_visible = true
		queue_redraw()
	_caret_elapsed += delta
	if _caret_elapsed < caret_blink_interval:
		return
	_caret_elapsed = fmod(_caret_elapsed, caret_blink_interval)
	_caret_visible = not _caret_visible
	queue_redraw()


func _on_line_edit_changed(_text: String) -> void:
	_caret_elapsed = 0.0
	_caret_visible = true
	queue_redraw()


func _on_focus_changed(focused: bool) -> void:
	_caret_elapsed = 0.0
	_caret_visible = focused
	_last_caret_column = _line_edit.caret_column if _line_edit != null else -1
	queue_redraw()


func _on_line_edit_gui_input(_event: InputEvent) -> void:
	# LineEdit 在 gui_input 信号返回后才可能更新 caret_column。
	queue_redraw.call_deferred()


func debug_text_baselines(value: String) -> PackedFloat32Array:
	var baselines := PackedFloat32Array()
	var widths := _character_widths(value)
	var total_width := _total_width(widths)
	var x := 0.0
	for character_width: float in widths:
		baselines.append(_text_baseline(x + character_width * 0.5, total_width))
		x += character_width
	return baselines


func _text_baseline(relative_x: float, total_width: float) -> float:
	if total_width <= 0.0:
		return 22.0
	var progress := clampf(relative_x / total_width, 0.0, 1.0)
	var distance_from_apex := absf(progress - 0.5) * 2.0
	var drop := roundf(text_curve_depth * distance_from_apex * distance_from_apex)
	# 搜索框位于左页：文字向右靠近书脊时同步上抬 1px。
	# 这也保证只有两个汉字的短查询不会再次看成完全水平。
	var page_rise := roundf(page_rise_across_text * progress)
	return 21.0 + drop - page_rise


func _character_widths(value: String) -> Array[float]:
	var widths: Array[float] = []
	for character: String in value:
		widths.append(font.get_string_size(
				character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	return widths


func _total_width(widths: Array[float]) -> float:
	var total := 0.0
	for character_width: float in widths:
		total += character_width
	return total


func _draw() -> void:
	if font == null:
		return
	var display_text := "搜索..."
	var display_color := placeholder_color
	if _line_edit != null:
		display_text = _line_edit.text
		if display_text.is_empty():
			display_text = _line_edit.placeholder_text
		else:
			display_color = text_color
	var character_widths := _character_widths(display_text)
	var total_text_width := _total_width(character_widths)
	var x := left_padding
	var caret_column := 0
	if _line_edit != null:
		caret_column = clampi(_line_edit.caret_column, 0, _line_edit.text.length())
	var caret_x := x
	var character_index := 0
	for character: String in display_text:
		if x >= size.x - right_padding:
			break
		var character_width: float = character_widths[character_index]
		if character_index == caret_column:
			caret_x = x
		var baseline := _text_baseline(
				x - left_padding + character_width * 0.5, total_text_width)
		draw_char(font, Vector2(x, baseline), character, font_size, display_color)
		x += character_width
		character_index += 1
	if character_index <= caret_column:
		caret_x = x
	if _line_edit == null or not _line_edit.has_focus() or not _caret_visible:
		return
	var caret_baseline := _text_baseline(caret_x - left_padding, total_text_width)
	draw_line(
			Vector2(roundf(caret_x), roundf(caret_baseline - font_size + 2.0)),
			Vector2(roundf(caret_x), roundf(caret_baseline + 2.0)),
			caret_color, 1.0, false)
