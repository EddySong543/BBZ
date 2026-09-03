class_name BootMenuController
extends Control

signal start_game_requested
signal load_game_requested
signal settings_requested
signal quit_requested

@export_group("External Links")
@export var wishlist_url: String = ""
@export var steam_url: String = ""
@export var discord_url: String = ""
@export var qq_url: String = ""
@export var feedback_url: String = ""

@onready var _start_button: Button = $MainButtons/StartGame
@onready var _load_button: Button = $MainButtons/LoadGame
@onready var _wishlist_button: Button = $MainButtons/Wishlist
@onready var _quit_button: Button = $MainButtons/QuitGame
@onready var _steam_button: Button = $SmallButtons/Steam
@onready var _discord_button: Button = $SmallButtons/Discord
@onready var _qq_button: Button = $SmallButtons/QQ
@onready var _settings_button: Button = get_node_or_null(
	"SmallButtons/Settings") as Button
@onready var _feedback_button: Button = $SmallButtons/Feedback
@onready var _status_label: Label = $StatusLabel

var _buttons: Array[Button] = []
var _intro_ready: bool = false


func _ready() -> void:
	_buttons = [
		_start_button,
		_load_button,
		_wishlist_button,
		_quit_button,
	]
	_buttons.append_array(_small_buttons())
	_connect_actions()
	_configure_focus()
	_status_label.text = ""
	prepare_intro()


func prepare_intro() -> void:
	_intro_ready = false
	visible = false
	modulate.a = 0.0
	_set_buttons_enabled(false)


func set_intro_reveal(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	visible = safe_progress > 0.0
	modulate.a = smoothstep(0.0, 1.0, safe_progress)


func finish_intro() -> void:
	visible = true
	modulate.a = 1.0
	_intro_ready = true
	_set_buttons_enabled(true)
	_release_menu_focus()


func lock_interaction() -> void:
	_intro_ready = false
	_set_buttons_enabled(false)


func is_interaction_enabled() -> bool:
	return _intro_ready


func show_status(message: String) -> void:
	_status_label.text = message


func _connect_actions() -> void:
	_start_button.pressed.connect(start_game_requested.emit)
	_load_button.pressed.connect(load_game_requested.emit)
	_wishlist_button.pressed.connect(
		func() -> void: _open_external("愿望单", wishlist_url))
	_quit_button.pressed.connect(quit_requested.emit)
	_steam_button.pressed.connect(
		func() -> void: _open_external("Steam", steam_url))
	_discord_button.pressed.connect(
		func() -> void: _open_external("Discord", discord_url))
	_qq_button.pressed.connect(
		func() -> void: _open_external("QQ", qq_url))
	if _settings_button != null:
		_settings_button.pressed.connect(settings_requested.emit)
	_feedback_button.pressed.connect(
		func() -> void: _open_external("问题反馈", feedback_url))


func _open_external(label: String, url: String) -> void:
	if url.strip_edges().is_empty():
		show_status("%s链接待配置" % label)
		return
	var error := OS.shell_open(url)
	if error != OK:
		show_status("%s链接打开失败" % label)


func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in _buttons:
		# 入场期间只锁输入，不进入 Button.disabled 的灰态。所有菜单项由同一个
		# BootMenu 淡入，因此贴图和文字在同一帧以正式配色出现。
		button.disabled = false
		button.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if enabled
			else Control.MOUSE_FILTER_IGNORE)
		button.focus_mode = (
			Control.FOCUS_ALL
			if enabled
			else Control.FOCUS_NONE)


func _release_menu_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is Button and _buttons.has(focus_owner as Button):
		(focus_owner as Button).release_focus()


func _configure_focus() -> void:
	_start_button.focus_neighbor_bottom = _start_button.get_path_to(_load_button)
	_load_button.focus_neighbor_top = _load_button.get_path_to(_start_button)
	_load_button.focus_neighbor_bottom = _load_button.get_path_to(_wishlist_button)
	_wishlist_button.focus_neighbor_top = _wishlist_button.get_path_to(_load_button)
	_wishlist_button.focus_neighbor_bottom = _wishlist_button.get_path_to(_quit_button)
	_quit_button.focus_neighbor_top = _quit_button.get_path_to(_wishlist_button)
	_quit_button.focus_neighbor_bottom = _quit_button.get_path_to(_steam_button)
	for index: int in _buttons.size():
		_buttons[index].focus_mode = Control.FOCUS_ALL
	var small_buttons: Array[Button] = _small_buttons()
	for index: int in small_buttons.size():
		var button := small_buttons[index]
		button.focus_neighbor_top = button.get_path_to(_quit_button)
		if index > 0:
			button.focus_neighbor_left = button.get_path_to(small_buttons[index - 1])
		if index + 1 < small_buttons.size():
			button.focus_neighbor_right = button.get_path_to(small_buttons[index + 1])


func _small_buttons() -> Array[Button]:
	var buttons: Array[Button] = [
		_steam_button,
		_discord_button,
		_qq_button,
		_feedback_button,
	]
	if _settings_button != null:
		buttons.insert(3, _settings_button)
	return buttons
