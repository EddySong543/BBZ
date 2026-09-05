class_name SettingsPanel
extends Control

## 完整纯文字设置页：分类、设置值、恢复默认与返回均不引用外部 UI 美术资产。

signal closed

const CONTENT_SIZE := Vector2(1040.0, 760.0)
const CATEGORY_KEYS: Array[String] = ["display", "audio", "gameplay"]
const CATEGORY_LABELS: Array[String] = ["显示", "声音", "游戏"]
const PAGE_RECT := Rect2(344.0, 148.0, 630.0, 430.0)
const CATEGORY_GROUP_TOP: float = 265.0
const CATEGORY_RECTS: Array[Rect2] = [
	Rect2(54.0, CATEGORY_GROUP_TOP, 224.0, 52.0),
	Rect2(54.0, CATEGORY_GROUP_TOP + 72.0, 224.0, 52.0),
	Rect2(54.0, CATEGORY_GROUP_TOP + 144.0, 224.0, 52.0),
]
const MARKER_SIZE := Vector2(30.0, 52.0)
const MARKER_GAP: float = 12.0
const ROW_HEIGHT: float = 54.0
const ROW_GAP: float = 18.0
const VOLUME_STEP: float = 0.05
const WINDOW_MODES: Array[String] = ["windowed", "borderless", "fullscreen"]
const WINDOW_MODE_LABELS := {
	"windowed": "窗口化",
	"borderless": "全屏窗口化",
	"fullscreen": "独占全屏",
}
const TEXT_TITLE := Color("e4d8c5")
const TEXT_PRIMARY := Color("b8aea1")
const TEXT_SELECTED := Color("ffe0a0")
const TEXT_SECONDARY := Color("91887d")
const TEXT_DISABLED := Color("6f6860")

## 测试可关闭实际应用与落盘，生产默认始终即时应用并保存。
var persist_changes: bool = true

var _content: Control
var _page_content: Control
var _category_buttons: Array[Button] = []
var _category_marker: Label
var _selected_index: int = 0
var _hovered_index: int = -1
var _focused_index: int = -1
var _value_labels: Dictionary = {}
var _selector_rows: Dictionary = {}
var _editing_volume_key: String = ""
var _editing_volume_original: String = ""
var _normalizing_volume_text: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	_content = Control.new()
	_content.name = "SettingsContent"
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.offset_left = -CONTENT_SIZE.x * 0.5
	_content.offset_top = -CONTENT_SIZE.y * 0.5
	_content.offset_right = CONTENT_SIZE.x * 0.5
	_content.offset_bottom = CONTENT_SIZE.y * 0.5
	_content.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_content)

	var title := _label("设置", 40, TEXT_TITLE)
	title.name = "SettingsTitle"
	title.position = Vector2(0.0, 38.0)
	title.size = Vector2(CONTENT_SIZE.x, 64.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var category_nav := Control.new()
	category_nav.name = "CategoryNav"
	category_nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	category_nav.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(category_nav)

	for index: int in CATEGORY_LABELS.size():
		var button := _category_button(CATEGORY_LABELS[index], index)
		button.name = "%sButton" % CATEGORY_KEYS[index].capitalize()
		_category_buttons.append(button)
		category_nav.add_child(button)

	_category_marker = _label(">", 28, TEXT_SELECTED)
	_category_marker.name = "CategoryMarker"
	_category_marker.size = MARKER_SIZE
	_category_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category_nav.add_child(_category_marker)

	_page_content = Control.new()
	_page_content.name = "PageContent"
	_page_content.position = PAGE_RECT.position
	_page_content.size = PAGE_RECT.size
	_page_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_page_content)

	var reset := _plain_button("恢复默认", 22, TEXT_SECONDARY)
	reset.name = "ResetButton"
	reset.position = Vector2(292.0, 654.0)
	reset.size = Vector2(210.0, 48.0)
	reset.pressed.connect(_reset_defaults)
	_content.add_child(reset)

	var back := _plain_button("返回", 24, TEXT_PRIMARY)
	back.name = "BackButton"
	back.position = Vector2(538.0, 654.0)
	back.size = Vector2(210.0, 48.0)
	back.pressed.connect(_close)
	_content.add_child(back)

	_refresh_category_visuals()
	_build_current_page()
	_category_buttons[0].call_deferred("grab_focus")


func _category_button(label_text: String, index: int) -> Button:
	var button := _plain_button(label_text, 30, TEXT_PRIMARY)
	button.position = CATEGORY_RECTS[index].position
	button.size = CATEGORY_RECTS[index].size
	button.pressed.connect(_select_category.bind(index))
	button.mouse_entered.connect(_preview_category.bind(index))
	button.mouse_exited.connect(_clear_category_preview.bind(index))
	button.focus_entered.connect(_focus_category.bind(index))
	button.focus_exited.connect(_unfocus_category.bind(index))
	return button


func _plain_button(label_text: String, font_size: int, color: Color) -> Button:
	var button := Button.new()
	button.text = tr(label_text)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply_btn(button, font_size)
	_set_button_color(button, color)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("disabled", empty)
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = tr(text_value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.04, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	FontManager.apply(label, font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _select_category(index: int) -> void:
	_selected_index = clampi(index, 0, CATEGORY_KEYS.size() - 1)
	_focused_index = _selected_index
	_category_buttons[_selected_index].grab_focus()
	_refresh_category_visuals()
	_build_current_page()


func _preview_category(index: int) -> void:
	_hovered_index = clampi(index, 0, CATEGORY_KEYS.size() - 1)
	_refresh_category_visuals()


func _clear_category_preview(index: int) -> void:
	if _hovered_index == index:
		_hovered_index = -1
		_refresh_category_visuals()


func _focus_category(index: int) -> void:
	_focused_index = clampi(index, 0, CATEGORY_KEYS.size() - 1)
	_refresh_category_visuals()


func _unfocus_category(index: int) -> void:
	if _focused_index == index:
		_focused_index = -1
		_refresh_category_visuals()


func _refresh_category_visuals() -> void:
	if _category_buttons.is_empty() or not is_instance_valid(_category_marker):
		return
	var visual_index: int = _selected_index
	if _focused_index >= 0:
		visual_index = _focused_index
	if _hovered_index >= 0:
		visual_index = _hovered_index
	for index: int in _category_buttons.size():
		var color: Color = TEXT_SELECTED if index == visual_index else TEXT_PRIMARY
		_set_button_color(_category_buttons[index], color)
	_move_marker(visual_index)


func _set_button_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", TEXT_SELECTED)
	button.add_theme_color_override("font_pressed_color", TEXT_SELECTED)
	button.add_theme_color_override("font_focus_color", TEXT_SELECTED)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	button.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.04, 0.82))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)


func _move_marker(index: int) -> void:
	var button: Button = _category_buttons[index]
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var rect: Rect2 = CATEGORY_RECTS[index]
	_category_marker.position = Vector2(
			rect.get_center().x - text_width * 0.5 - MARKER_SIZE.x - MARKER_GAP,
			rect.position.y).round()


func _build_current_page() -> void:
	for child: Node in _page_content.get_children():
		_page_content.remove_child(child)
		child.queue_free()
	_value_labels.clear()
	_selector_rows.clear()
	_editing_volume_key = ""
	_editing_volume_original = ""

	match CATEGORY_KEYS[_selected_index]:
		"audio":
			_build_audio_page()
		"display":
			_build_display_page()
		"gameplay":
			_build_gameplay_page()
		_:
			return
	_refresh_page_values()


func _build_audio_page() -> void:
	_add_selector_row("MasterVolumeRow", "总音量", "master_volume", 0, 3,
			_change_volume.bind("master_volume", -VOLUME_STEP),
			_change_volume.bind("master_volume", VOLUME_STEP))
	_add_selector_row("MusicVolumeRow", "音乐", "music_volume", 1, 3,
			_change_volume.bind("music_volume", -VOLUME_STEP),
			_change_volume.bind("music_volume", VOLUME_STEP))
	_add_selector_row("SfxVolumeRow", "音效", "sfx_volume", 2, 3,
			_change_volume.bind("sfx_volume", -VOLUME_STEP),
			_change_volume.bind("sfx_volume", VOLUME_STEP))


func _build_display_page() -> void:
	_add_selector_row("WindowModeRow", "显示模式", "window_mode", 0, 4,
			_cycle_setting.bind("window_mode", WINDOW_MODES, -1),
			_cycle_setting.bind("window_mode", WINDOW_MODES, 1))
	var resolutions: Array[String] = _available_resolutions()
	_add_selector_row("ResolutionRow", "分辨率", "resolution", 1, 4,
			_cycle_setting.bind("resolution", resolutions, -1),
			_cycle_setting.bind("resolution", resolutions, 1))
	_add_selector_row("VsyncRow", "垂直同步", "vsync_enabled", 2, 4,
			_toggle_setting.bind("vsync_enabled"),
			_toggle_setting.bind("vsync_enabled"))
	_add_selector_row("FrameLimitRow", "帧率上限", "frame_limit", 3, 4,
			_cycle_setting.bind("frame_limit", GameSettings.FRAME_LIMIT_PRESETS, -1),
			_cycle_setting.bind("frame_limit", GameSettings.FRAME_LIMIT_PRESETS, 1))


func _build_gameplay_page() -> void:
	_add_selector_row("ScreenShakeRow", "画面震动", "screen_shake_enabled", 0, 1,
			_toggle_setting.bind("screen_shake_enabled"),
			_toggle_setting.bind("screen_shake_enabled"))


func _add_selector_row(node_name: String, label_text: String, key: String,
		row_index: int, row_count: int,
		previous_action: Callable, next_action: Callable) -> void:
	var row := Control.new()
	row.name = node_name
	var group_height: float = row_count * ROW_HEIGHT + (row_count - 1) * ROW_GAP
	var group_top: float = (PAGE_RECT.size.y - group_height) * 0.5
	row.position = Vector2(0.0, group_top + row_index * (ROW_HEIGHT + ROW_GAP)).round()
	row.size = Vector2(PAGE_RECT.size.x, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_page_content.add_child(row)

	var setting_label := _label(label_text, 24, TEXT_PRIMARY)
	setting_label.name = "SettingLabel"
	setting_label.position = Vector2(0.0, 0.0)
	setting_label.size = Vector2(210.0, ROW_HEIGHT)
	setting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(setting_label)

	var previous := _plain_button("<", 24, TEXT_PRIMARY)
	previous.name = "PreviousButton"
	previous.position = Vector2(250.0, 0.0)
	previous.size = Vector2(52.0, ROW_HEIGHT)
	previous.pressed.connect(previous_action)
	row.add_child(previous)

	var value: Control
	if key in ["master_volume", "music_volume", "sfx_volume"]:
		value = _volume_editor(key)
	else:
		var value_label := _label("", 23, TEXT_TITLE)
		value_label.name = "ValueLabel"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value = value_label
	value.position = Vector2(304.0, 0.0)
	value.size = Vector2(220.0, ROW_HEIGHT)
	row.add_child(value)

	var next := _plain_button(">", 24, TEXT_PRIMARY)
	next.name = "NextButton"
	next.position = Vector2(526.0, 0.0)
	next.size = Vector2(52.0, ROW_HEIGHT)
	next.pressed.connect(next_action)
	row.add_child(next)

	_value_labels[key] = value
	_selector_rows[key] = {
		"row": row,
		"previous": previous,
		"next": next,
	}


func _volume_editor(key: String) -> LineEdit:
	var editor := LineEdit.new()
	editor.name = "ValueInput"
	editor.alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor.editable = false
	editor.max_length = 4
	editor.placeholder_text = "0–100"
	editor.select_all_on_focus = false
	editor.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	editor.add_theme_font_override("font", FontManager._best_font(23))
	editor.add_theme_font_size_override("font_size", 23)
	editor.add_theme_color_override("font_color", TEXT_TITLE)
	editor.add_theme_color_override("font_uneditable_color", TEXT_TITLE)
	editor.add_theme_color_override("caret_color", TEXT_SELECTED)
	editor.add_theme_color_override("selection_color", Color(0.58, 0.43, 0.24, 0.72))
	for state: String in ["normal", "focus", "read_only"]:
		editor.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	editor.gui_input.connect(_on_volume_editor_gui_input.bind(key, editor))
	editor.text_changed.connect(_on_volume_editor_text_changed.bind(editor))
	editor.text_submitted.connect(_commit_volume_edit.bind(key, editor))
	editor.focus_exited.connect(_on_volume_editor_focus_exited.bind(key, editor))
	editor.mouse_entered.connect(_set_volume_editor_emphasis.bind(editor, true))
	editor.mouse_exited.connect(_set_volume_editor_emphasis.bind(editor, false))
	return editor


func _on_volume_editor_gui_input(event: InputEvent, key: String,
		editor: LineEdit) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				if not editor.editable:
					_begin_volume_edit(key, editor)
					editor.accept_event()
				elif mouse_event.double_click:
					editor.select_all()
					editor.accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				_step_volume(key, 1, editor)
				editor.accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				_step_volume(key, -1, editor)
				editor.accept_event()
		return
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_UP:
			_step_volume(key, 1, editor)
			editor.accept_event()
		KEY_DOWN:
			_step_volume(key, -1, editor)
			editor.accept_event()


func _on_volume_editor_text_changed(text_value: String, editor: LineEdit) -> void:
	if _normalizing_volume_text or not editor.editable:
		return
	var digits := ""
	for character: String in text_value:
		var codepoint: int = character.unicode_at(0)
		if codepoint >= 48 and codepoint <= 57:
			digits += character
	if digits.length() > 3:
		digits = digits.left(3)
	if digits == text_value:
		return
	_normalizing_volume_text = true
	editor.text = digits
	editor.caret_column = digits.length()
	_normalizing_volume_text = false


func _set_volume_editor_emphasis(editor: LineEdit, emphasized: bool) -> void:
	var color: Color = TEXT_SELECTED if emphasized or editor.editable else TEXT_TITLE
	editor.add_theme_color_override("font_color", color)
	editor.add_theme_color_override("font_uneditable_color", color)


func _step_volume(key: String, direction: int, editor: LineEdit) -> void:
	var current_percent: int = roundi(float(GameSettings.get_value(key)) * 100.0)
	if editor.editable and editor.text.is_valid_int():
		current_percent = editor.text.to_int()
	var next_percent: int = clampi(
			current_percent + direction * roundi(VOLUME_STEP * 100.0), 0, 100)
	_write_setting(key, float(next_percent) / 100.0)
	if editor.editable:
		editor.text = str(next_percent)
		editor.call_deferred("select_all")
	else:
		_refresh_page_values()


func _begin_volume_edit(key: String, editor: LineEdit) -> void:
	if not _editing_volume_key.is_empty() and _editing_volume_key != key:
		var active_editor := _value_labels.get(_editing_volume_key) as LineEdit
		if is_instance_valid(active_editor):
			_commit_volume_edit(active_editor.text, _editing_volume_key, active_editor)
	if _editing_volume_key.is_empty():
		_editing_volume_original = _setting_text(key)
	_editing_volume_key = key
	editor.editable = true
	editor.text = str(roundi(float(GameSettings.get_value(key)) * 100.0))
	_set_volume_editor_emphasis(editor, true)
	editor.grab_focus()
	editor.edit()
	editor.call_deferred("select_all")


func _commit_volume_edit(text_value: String, key: String, editor: LineEdit) -> void:
	if _editing_volume_key != key:
		return
	var cleaned := text_value.strip_edges()
	if cleaned.is_valid_int():
		var percent: int = clampi(cleaned.to_int(), 0, 100)
		_write_setting(key, float(percent) / 100.0)
	_finish_volume_edit(editor)


func _on_volume_editor_focus_exited(key: String, editor: LineEdit) -> void:
	_commit_volume_edit(editor.text, key, editor)


func _cancel_volume_edit() -> void:
	if _editing_volume_key.is_empty():
		return
	var editor := _value_labels.get(_editing_volume_key) as LineEdit
	if is_instance_valid(editor):
		var original_number := _editing_volume_original.trim_suffix("%")
		if original_number.is_valid_int():
			_write_setting(_editing_volume_key,
					float(original_number.to_int()) / 100.0)
		editor.text = _editing_volume_original
		_finish_volume_edit(editor)


func _finish_volume_edit(editor: LineEdit) -> void:
	editor.editable = false
	editor.unedit()
	_set_volume_editor_emphasis(editor, false)
	_editing_volume_key = ""
	_editing_volume_original = ""
	editor.release_focus()
	_refresh_page_values()


func _change_volume(key: String, delta: float) -> void:
	var current: float = float(GameSettings.get_value(key))
	_write_setting(key, snappedf(clampf(current + delta, 0.0, 1.0), VOLUME_STEP))
	_refresh_page_values()


func _cycle_setting(key: String, options: Array, direction: int) -> void:
	if options.is_empty():
		return
	var current: Variant = GameSettings.get_value(key)
	var index: int = options.find(current)
	if index < 0:
		index = 0
	index = posmod(index + direction, options.size())
	_write_setting(key, options[index])
	_refresh_page_values()


func _toggle_setting(key: String) -> void:
	_write_setting(key, not bool(GameSettings.get_value(key)))
	_refresh_page_values()


func _write_setting(key: String, value: Variant) -> void:
	if persist_changes:
		GameSettings.set_value(key, value)
		return
	GameSettings._loaded = true
	GameSettings._data[key] = GameSettings.sanitize(key, value)


func _refresh_page_values() -> void:
	for key: String in _value_labels.keys():
		var value_control := _value_labels[key] as Control
		if value_control is LineEdit:
			var editor := value_control as LineEdit
			if _editing_volume_key != key:
				editor.text = _setting_text(key)
		elif value_control is Label:
			(value_control as Label).text = _setting_text(key)
	if _selector_rows.has("resolution"):
		var enabled: bool = String(GameSettings.get_value("window_mode")) == "windowed"
		var row_data: Dictionary = _selector_rows["resolution"]
		var row := row_data["row"] as Control
		var previous := row_data["previous"] as Button
		var next := row_data["next"] as Button
		row.modulate.a = 1.0 if enabled else 0.42
		previous.disabled = not enabled
		next.disabled = not enabled


func _setting_text(key: String) -> String:
	match key:
		"master_volume", "music_volume", "sfx_volume":
			return "%d%%" % roundi(float(GameSettings.get_value(key)) * 100.0)
		"window_mode":
			return tr(String(WINDOW_MODE_LABELS.get(
					String(GameSettings.get_value(key)), "窗口化")))
		"resolution":
			return String(GameSettings.get_value(key)).replace("x", " × ")
		"vsync_enabled", "screen_shake_enabled":
			return tr("开启" if bool(GameSettings.get_value(key)) else "关闭")
		"frame_limit":
			var limit: int = int(GameSettings.get_value(key))
			return tr("不限制") if limit == 0 else "%d FPS" % limit
		_:
			return ""


func _available_resolutions() -> Array[String]:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return GameSettings.RESOLUTION_PRESETS.duplicate()
	var available: Array[String] = []
	for resolution: String in GameSettings.RESOLUTION_PRESETS:
		var size: Vector2i = GameSettings.parse_resolution(resolution)
		if size.x <= screen_size.x and size.y <= screen_size.y:
			available.append(resolution)
	if available.is_empty():
		available.append("1920x1080")
	return available


func _reset_defaults() -> void:
	if persist_changes:
		GameSettings.reset_defaults()
	else:
		GameSettings._data = GameSettings.DEFAULTS.duplicate(true)
		GameSettings._loaded = true
	_build_current_page()
	_refresh_category_visuals()


func get_selected_category() -> String:
	return CATEGORY_KEYS[_selected_index]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT \
				and not _editing_volume_key.is_empty():
			var editor := _value_labels.get(_editing_volume_key) as LineEdit
			if is_instance_valid(editor) \
					and not editor.get_global_rect().has_point(mouse_event.position):
				_commit_volume_edit(editor.text, _editing_volume_key, editor)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _editing_volume_key.is_empty():
			_cancel_volume_edit()
			return
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
