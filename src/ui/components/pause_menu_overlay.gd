class_name PauseMenuOverlay
extends CanvasLayer

## 全局 ESC 菜单。画面只包含暖黑暗幕与文字，不引用任何外部 UI 美术资产。

signal closed

const SettingsPanelScript := preload("res://src/ui/components/settings_panel.gd")

const OVERLAY_LAYER: int = 127
const RIG_SIZE := Vector2(560.0, 360.0)
const MESSAGE_RECT := Rect2(0.0, 24.0, 560.0, 56.0)
const MENU_RECTS: Array[Rect2] = [
	Rect2(0.0, 80.0, 560.0, 56.0),
	Rect2(0.0, 152.0, 560.0, 56.0),
	Rect2(0.0, 224.0, 560.0, 56.0),
]
const MARKER_SIZE := Vector2(34.0, 56.0)
const MARKER_GAP: float = 14.0
const TEXT_PRIMARY := Color("c8bdad")
const TEXT_TITLE := Color("e4d8c5")
const TEXT_SELECTED := Color("ffe0a0")
const TEXT_DANGER := Color("df776b")

var _was_tree_paused: bool = false
var _pause_applied: bool = false
var _screen: Control
var _pause_rig: Control
var _selection_marker: Label
var _menu_content: Control
var _confirm_content: Control
var _settings_panel: Control


func _ready() -> void:
	layer = OVERLAY_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	_pause_applied = true


func _exit_tree() -> void:
	_restore_pause()


func _build() -> void:
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.035, 0.028, 0.028, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_screen.add_child(dim)

	_pause_rig = Control.new()
	_pause_rig.name = "PauseRig"
	_pause_rig.set_anchors_preset(Control.PRESET_CENTER)
	_pause_rig.offset_left = -RIG_SIZE.x * 0.5
	_pause_rig.offset_top = -RIG_SIZE.y * 0.5
	_pause_rig.offset_right = RIG_SIZE.x * 0.5
	_pause_rig.offset_bottom = RIG_SIZE.y * 0.5
	_pause_rig.mouse_filter = Control.MOUSE_FILTER_PASS
	_screen.add_child(_pause_rig)

	_selection_marker = _label(">", 30, TEXT_SELECTED)
	_selection_marker.name = "SelectionMarker"
	_selection_marker.size = MARKER_SIZE
	_selection_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_rig.add_child(_selection_marker)

	_build_primary_menu()
	_build_quit_confirmation()
	_set_menu_highlight(0)


func _build_primary_menu() -> void:
	_menu_content = Control.new()
	_menu_content.name = "PrimaryMenu"
	_menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_pause_rig.add_child(_menu_content)

	var labels: Array[String] = ["继续游戏", "设置", "退出游戏"]
	var names: Array[String] = ["ResumeButton", "SettingsButton", "QuitButton"]
	for index: int in labels.size():
		var button := _make_text_button(labels[index], index, false)
		button.name = names[index]
		_menu_content.add_child(button)
	(_menu_content.get_node("ResumeButton") as Button).pressed.connect(_close)
	(_menu_content.get_node("SettingsButton") as Button).pressed.connect(_open_settings)
	(_menu_content.get_node("QuitButton") as Button).pressed.connect(
			_show_quit_confirmation)
	(_menu_content.get_node("ResumeButton") as Button).call_deferred("grab_focus")


func _build_quit_confirmation() -> void:
	_confirm_content = Control.new()
	_confirm_content.name = "QuitConfirmation"
	_confirm_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_confirm_content.visible = false
	_pause_rig.add_child(_confirm_content)

	var message := _label("确定退出游戏？", 32, TEXT_TITLE)
	message.name = "QuitMessage"
	message.position = MESSAGE_RECT.position
	message.size = MESSAGE_RECT.size
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_content.add_child(message)

	var confirm := _make_text_button("确定", 1, true)
	confirm.name = "ConfirmQuitButton"
	confirm.pressed.connect(_quit_game)
	_confirm_content.add_child(confirm)
	var back := _make_text_button("返回", 2, false)
	back.name = "CancelQuitButton"
	back.pressed.connect(_hide_quit_confirmation)
	_confirm_content.add_child(back)


func _make_text_button(label_text: String, row_index: int, danger: bool) -> Button:
	var button := Button.new()
	button.text = tr(label_text)
	button.position = MENU_RECTS[row_index].position
	button.size = MENU_RECTS[row_index].size
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply_btn(button, 32)
	var base_color: Color = TEXT_DANGER if danger else TEXT_PRIMARY
	var selected_color: Color = TEXT_DANGER.lightened(0.12) if danger else TEXT_SELECTED
	button.add_theme_color_override("font_color", base_color)
	button.add_theme_color_override("font_hover_color", selected_color)
	button.add_theme_color_override("font_pressed_color", selected_color)
	button.add_theme_color_override("font_focus_color", selected_color)
	button.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.04, 0.82))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.mouse_entered.connect(_set_menu_highlight.bind(row_index))
	button.mouse_exited.connect(_clear_menu_highlight.bind(button, row_index))
	button.focus_entered.connect(_set_menu_highlight.bind(row_index))
	button.focus_exited.connect(_clear_menu_highlight.bind(button, row_index))
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


func _set_menu_highlight(index: int) -> void:
	var safe_index: int = clampi(index, 0, MENU_RECTS.size() - 1)
	var rect: Rect2 = MENU_RECTS[safe_index]
	var button: Button = _button_for_row(safe_index)
	var text_width: float = 0.0
	if is_instance_valid(button):
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		text_width = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, font_size).x
	_selection_marker.position = Vector2(
			(RIG_SIZE.x - text_width) * 0.5 - MARKER_SIZE.x - MARKER_GAP,
			rect.position.y).round()
	_selection_marker.visible = true


func _button_for_row(row_index: int) -> Button:
	if _confirm_content != null and _confirm_content.visible:
		if row_index == 1:
			return _confirm_content.get_node_or_null("ConfirmQuitButton") as Button
		if row_index == 2:
			return _confirm_content.get_node_or_null("CancelQuitButton") as Button
	if _menu_content == null:
		return null
	var names: Array[String] = ["ResumeButton", "SettingsButton", "QuitButton"]
	return _menu_content.get_node_or_null(names[row_index]) as Button


func _clear_menu_highlight(button: Button, index: int) -> void:
	var rect: Rect2 = MENU_RECTS[index]
	if is_equal_approx(_selection_marker.position.y, rect.position.y) \
			and not button.has_focus() \
			and not button.get_global_rect().has_point(button.get_global_mouse_position()):
		_selection_marker.visible = false


func _open_settings() -> void:
	if is_instance_valid(_settings_panel):
		return
	_pause_rig.visible = false
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.closed.connect(_on_settings_closed)
	add_child(_settings_panel)


func _on_settings_closed() -> void:
	_settings_panel = null
	_pause_rig.visible = true
	_hide_quit_confirmation()


func _show_quit_confirmation() -> void:
	_menu_content.visible = false
	_confirm_content.visible = true
	_selection_marker.visible = false
	(_confirm_content.get_node("CancelQuitButton") as Button).grab_focus()


func _hide_quit_confirmation() -> void:
	_menu_content.visible = true
	_confirm_content.visible = false
	_selection_marker.visible = false
	(_menu_content.get_node("ResumeButton") as Button).grab_focus()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(_settings_panel):
		return
	get_viewport().set_input_as_handled()
	if _confirm_content.visible:
		_hide_quit_confirmation()
	else:
		_close()


func _quit_game() -> void:
	get_tree().quit()


func _close() -> void:
	if is_instance_valid(_settings_panel):
		return
	_restore_pause()
	closed.emit()
	queue_free()


func _restore_pause() -> void:
	if not _pause_applied or get_tree() == null:
		return
	get_tree().paused = _was_tree_paused
	_pause_applied = false
