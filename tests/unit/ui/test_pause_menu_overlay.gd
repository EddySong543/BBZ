extends GutTest

const PauseMenuOverlayScript := preload(
		"res://src/ui/components/pause_menu_overlay.gd")

var _previous_settings_data: Dictionary
var _previous_settings_loaded: bool


func before_each() -> void:
	get_tree().paused = false
	_previous_settings_data = GameSettings._data.duplicate(true)
	_previous_settings_loaded = GameSettings._loaded
	GameSettings._data = GameSettings.DEFAULTS.duplicate(true)
	GameSettings._loaded = true


func after_each() -> void:
	get_tree().paused = false
	GameSettings._data = _previous_settings_data
	GameSettings._loaded = _previous_settings_loaded


func _make_overlay() -> PauseMenuOverlay:
	var overlay := PauseMenuOverlayScript.new() as PauseMenuOverlay
	add_child_autofree(overlay)
	return overlay


func test_primary_menu_is_topmost_centered_text_only_ui() -> void:
	var lower_hud := CanvasLayer.new()
	lower_hud.layer = 100
	add_child_autofree(lower_hud)
	var overlay := _make_overlay()
	assert_true(get_tree().paused)
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(overlay.layer, 127)
	assert_gt(overlay.layer, lower_hud.layer)
	var screen := overlay.get_node("Screen") as Control
	assert_eq(screen.mouse_filter, Control.MOUSE_FILTER_STOP)
	var dim := screen.get_node("Dim") as ColorRect
	assert_almost_eq(dim.color.a, 0.66, 0.001)
	assert_eq(screen.find_children("*", "ColorRect", true, false).size(), 1,
			"一级菜单只能保留一个全屏暗幕形状")
	assert_eq(screen.find_children("*", "TextureRect", true, false).size(), 0,
			"纯文字方案不得实例化任何贴图 UI")
	assert_eq(screen.find_children("*", "Panel", true, false).size(), 0)
	assert_eq(screen.find_children("*", "NinePatchRect", true, false).size(), 0)
	var rig := screen.get_node("PauseRig") as Control
	assert_true(rig.size.is_equal_approx(Vector2(560.0, 360.0)))
	assert_true(rig.get_global_rect().get_center().is_equal_approx(
			screen.get_global_rect().get_center()))
	assert_null(rig.get_node_or_null("PrimaryMenu/PauseTitle"),
			"一级菜单不再显示暂停标题")
	var menu := rig.get_node("PrimaryMenu") as Control
	assert_not_null(menu.get_node_or_null("ResumeButton"))
	assert_not_null(menu.get_node_or_null("SettingsButton"))
	assert_not_null(menu.get_node_or_null("QuitButton"))
	var first := menu.get_node("ResumeButton") as Button
	var last := menu.get_node("QuitButton") as Button
	assert_almost_eq((first.position.y + last.position.y + last.size.y) * 0.5,
			rig.size.y * 0.5, 0.001,
			"去掉标题后，三项菜单整体必须重新垂直居中")
	var marker := rig.get_node("SelectionMarker") as Label
	assert_eq(marker.text, ">")
	var initial_position := marker.position
	overlay._set_menu_highlight(1)
	assert_ne(marker.position, initial_position)
	assert_eq(marker.position, marker.position.round(),
			"文字选中标记必须落在整数坐标")
	overlay._close()
	assert_false(get_tree().paused)


func test_settings_is_a_second_level_page_and_escape_returns_to_primary() -> void:
	var overlay := _make_overlay()
	var primary := overlay.get_node(
			"Screen/PauseRig/PrimaryMenu") as Control
	(primary.get_node("SettingsButton") as Button).pressed.emit()
	var settings := overlay.get_node("SettingsPanel") as SettingsPanel
	assert_not_null(settings)
	assert_false((overlay.get_node("Screen/PauseRig") as Control).visible)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	settings._input(escape)
	assert_true((overlay.get_node("Screen/PauseRig") as Control).visible)
	assert_true(get_tree().paused)
	overlay._input(escape)
	assert_false(get_tree().paused)


func test_settings_page_is_complete_asset_free_and_interactive() -> void:
	var overlay := _make_overlay()
	overlay._open_settings()
	var settings := overlay.get_node("SettingsPanel") as SettingsPanel
	settings.persist_changes = false
	await get_tree().process_frame
	var content := settings.get_node("SettingsContent") as Control
	assert_true(content.size.is_equal_approx(Vector2(1040.0, 760.0)))
	assert_true(content.get_global_rect().get_center().is_equal_approx(
			settings.get_global_rect().get_center()))
	var title := content.get_node("SettingsTitle") as Label
	assert_eq(title.text, "设置")
	assert_eq(title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	var category_nav := content.get_node("CategoryNav") as Control
	var display_button := category_nav.get_node("DisplayButton") as Button
	var audio_button := category_nav.get_node("AudioButton") as Button
	var gameplay_button := category_nav.get_node("GameplayButton") as Button
	assert_lt(display_button.position.y, audio_button.position.y,
			"左侧分类固定为显示、声音、游戏")
	assert_lt(audio_button.position.y, gameplay_button.position.y)
	assert_almost_eq((display_button.position.y
			+ gameplay_button.position.y + gameplay_button.size.y) * 0.5,
			SettingsPanel.PAGE_RECT.get_center().y, 0.001,
			"左侧三项作为一个完整组与右侧内容区严格纵向同轴")
	var marker := category_nav.get_node("CategoryMarker") as Label
	assert_eq(marker.text, ">")
	assert_eq(settings.get_selected_category(), "display")
	var page_content := content.get_node("PageContent") as Control
	assert_null(page_content.get_node_or_null("PageTitle"),
			"右侧不再重复当前分类标题")
	assert_not_null(page_content.get_node_or_null("WindowModeRow"))
	assert_not_null(page_content.get_node_or_null("ResolutionRow"))
	assert_not_null(page_content.get_node_or_null("VsyncRow"))
	assert_not_null(page_content.get_node_or_null("FrameLimitRow"))
	var first_display_row := page_content.get_node("WindowModeRow") as Control
	var last_display_row := page_content.get_node("FrameLimitRow") as Control
	assert_almost_eq((first_display_row.position.y
			+ last_display_row.position.y + last_display_row.size.y) * 0.5,
			page_content.size.y * 0.5, 0.001,
			"移除右侧标题后设置行整体纵向居中")
	var window_row := page_content.get_node("WindowModeRow") as Control
	assert_eq((window_row.get_node("ValueLabel") as Label).text, "窗口化")
	(window_row.get_node("NextButton") as Button).pressed.emit()
	assert_eq(String(GameSettings.get_value("window_mode")), "borderless")
	assert_eq((window_row.get_node("ValueLabel") as Label).text, "全屏窗口化")
	var resolution_row := page_content.get_node("ResolutionRow") as Control
	assert_true((resolution_row.get_node("PreviousButton") as Button).disabled)
	assert_true((resolution_row.get_node("NextButton") as Button).disabled)
	assert_almost_eq(resolution_row.modulate.a, 0.42, 0.001)
	(page_content.get_node("VsyncRow/NextButton") as Button).pressed.emit()
	assert_false(bool(GameSettings.get_value("vsync_enabled")))
	(page_content.get_node("FrameLimitRow/NextButton") as Button).pressed.emit()
	assert_eq(int(GameSettings.get_value("frame_limit")), 30)

	var first_marker_position := marker.position
	settings._select_category(1)
	assert_eq(settings.get_selected_category(), "audio")
	assert_ne(marker.position, first_marker_position)
	assert_eq(marker.position, marker.position.round())
	assert_null(page_content.get_node_or_null("PageTitle"))
	assert_not_null(page_content.get_node_or_null("MasterVolumeRow"))
	assert_not_null(page_content.get_node_or_null("MusicVolumeRow"))
	assert_not_null(page_content.get_node_or_null("SfxVolumeRow"))
	var master_row := page_content.get_node("MasterVolumeRow") as Control
	var master_input := master_row.get_node("ValueInput") as LineEdit
	assert_eq(master_input.text, "100%")
	assert_false(master_input.editable,
			"单击数字区不直接进入编辑，避免误触")
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	master_input.gui_input.emit(left_click)
	assert_true(master_input.editable)
	assert_eq(master_input.text, "100")
	master_input.text = "37"
	master_input.text_submitted.emit(master_input.text)
	assert_false(master_input.editable)
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 0.37, 0.001)
	assert_eq(master_input.text, "37%")
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	master_input.gui_input.emit(wheel_down)
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 0.32, 0.001,
			"数字区滚轮按 5 调整，不再依赖两侧反复点击")
	assert_eq(master_input.text, "32%")
	master_input.gui_input.emit(left_click)
	var key_up := InputEventKey.new()
	key_up.keycode = KEY_UP
	key_up.pressed = true
	master_input.gui_input.emit(key_up)
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 0.37, 0.001,
			"编辑状态下上下键按 5 调整")
	assert_eq(master_input.text, "37")
	master_input.text = "999"
	master_input.text_submitted.emit(master_input.text)
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 1.0, 0.001,
			"手输音量严格限制在 0–100")
	assert_eq(master_input.text, "100%")
	master_input.gui_input.emit(left_click)
	var key_down := InputEventKey.new()
	key_down.keycode = KEY_DOWN
	key_down.pressed = true
	master_input.gui_input.emit(key_down)
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 0.95, 0.001)
	master_input.text = "abc"
	master_input.text_changed.emit(master_input.text)
	assert_eq(master_input.text, "",
			"输入期间即时过滤非数字字符")
	var cancel_edit := InputEventAction.new()
	cancel_edit.action = "ui_cancel"
	cancel_edit.pressed = true
	settings._input(cancel_edit)
	assert_true(is_instance_valid(settings),
			"编辑数字时 ESC 只取消编辑，不退出设置页")
	assert_false(master_input.editable)
	assert_eq(master_input.text, "100%")
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 1.0, 0.001,
			"ESC 同时撤回编辑期间的滚轮和键盘步进")
	master_input.gui_input.emit(left_click)
	master_input.text = "64"
	var blank_click := InputEventMouseButton.new()
	blank_click.button_index = MOUSE_BUTTON_LEFT
	blank_click.pressed = true
	blank_click.position = Vector2(10.0, 10.0)
	assert_true(settings.is_processing_input(),
			"设置页必须接收全局输入以捕获第一下空白点击")
	Input.parse_input_event(blank_click)
	await get_tree().process_frame
	assert_false(master_input.editable,
			"第一下真实空白点击就应完成编辑")
	assert_false(master_input.has_focus(),
			"空白确认后数字框应释放键盘焦点")
	assert_eq(master_input.text, "64%")
	assert_almost_eq(float(GameSettings.get_value("master_volume")), 0.64, 0.001,
			"空白确认应应用当前输入值")
	var first_audio_row := page_content.get_node("MasterVolumeRow") as Control
	var last_audio_row := page_content.get_node("SfxVolumeRow") as Control
	assert_almost_eq((first_audio_row.position.y
			+ last_audio_row.position.y + last_audio_row.size.y) * 0.5,
			page_content.size.y * 0.5, 0.001)

	settings._select_category(2)
	assert_eq(settings.get_selected_category(), "gameplay")
	assert_null(page_content.get_node_or_null("PageTitle"))
	var shake_row := page_content.get_node("ScreenShakeRow") as Control
	assert_not_null(shake_row)
	assert_almost_eq(shake_row.position.y + shake_row.size.y * 0.5,
			page_content.size.y * 0.5, 0.001)
	(shake_row.get_node("NextButton") as Button).pressed.emit()
	assert_false(bool(GameSettings.get_value("screen_shake_enabled")))

	var reset := content.get_node("ResetButton") as Button
	var back := content.get_node("BackButton") as Button
	assert_eq(reset.text, "恢复默认")
	assert_eq(back.text, "返回")
	assert_eq(back.get_theme_color("font_hover_color"), SettingsPanel.TEXT_SELECTED,
			"纯文字按钮必须用颜色反馈悬停和键盘焦点，不能退化成静态草稿")
	for text_node: Node in settings.find_children("*", "Label", true, false):
		var label := text_node as Label
		assert_eq(label.position, label.position.round(),
				"设置页文字必须落在整数像素坐标")
		assert_eq(label.size, label.size.round(),
				"设置页文字轨道必须保持整数像素尺寸")
	for text_node: Node in settings.find_children("*", "Button", true, false):
		var button := text_node as Button
		assert_eq(button.position, button.position.round(),
				"设置页按钮必须落在整数像素坐标")
		assert_eq(button.size, button.size.round(),
				"设置页按钮轨道必须保持整数像素尺寸")
	reset.pressed.emit()
	assert_eq(GameSettings._data, GameSettings.DEFAULTS)
	assert_eq(settings.find_children("*", "TextureRect", true, false).size(), 0)
	assert_eq(settings.find_children("*", "ColorRect", true, false).size(), 0)
	assert_eq(settings.find_children("*", "Panel", true, false).size(), 0)
	assert_eq(settings.find_children("*", "NinePatchRect", true, false).size(), 0)
	back.pressed.emit()
	await get_tree().process_frame
	assert_false(is_instance_valid(settings))
	assert_true((overlay.get_node("Screen/PauseRig") as Control).visible)
	overlay._close()


func test_pause_and_settings_sources_reference_no_external_ui_assets() -> void:
	var pause_source := FileAccess.get_file_as_string(
			"res://src/ui/components/pause_menu_overlay.gd")
	var settings_source := FileAccess.get_file_as_string(
			"res://src/ui/components/settings_panel.gd")
	for source: String in [pause_source, settings_source]:
		assert_false(source.contains("res://assets/ui/"))
		assert_false(source.contains("TextureRect"))
		assert_false(source.contains("NinePatchRect"))
		assert_false(source.contains("StyleBoxFlat"))
		assert_false(source.contains("create_tween"))
		assert_false(source.contains("AnimationPlayer"))
	assert_false(pause_source.contains("pause_menu_board"))
	assert_false(settings_source.contains("settings_board"))
	assert_false(settings_source.contains("invert_colors"))
	assert_false(settings_source.contains("手柄"))


func test_quit_requires_confirmation_and_escape_cancels_confirmation() -> void:
	var overlay := _make_overlay()
	var primary := overlay.get_node(
			"Screen/PauseRig/PrimaryMenu") as Control
	var confirmation := overlay.get_node(
			"Screen/PauseRig/QuitConfirmation") as Control
	(primary.get_node("QuitButton") as Button).pressed.emit()
	assert_false(primary.visible)
	assert_true(confirmation.visible)
	var message := confirmation.get_node("QuitMessage") as Label
	assert_eq(message.text, "确定退出游戏？")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	overlay._input(escape)
	assert_true(primary.visible)
	assert_false(confirmation.visible)
	assert_true(get_tree().paused)
	overlay._close()
