extends Control

## Boot 主入口：标题/角色动画由现有控制器负责，菜单只在入场完成后接收输入。

const NEXT_SCENE := "res://src/ui/main_menu.tscn"
const AudioEventsBoot := preload("res://src/core/audio_events.gd")

var _entering: bool = false
var _intro_finished: bool = false

@onready var _title: BootTitleController = $TitleColumn
@onready var _menu: BootMenuController = $InterfaceLayer/BootMenu
@onready var _intro_controller: BootIntroController = $IntroController


func _ready() -> void:
	AudioEventsBoot.ensure_buses()
	GameSettings.load_and_apply()
	_menu.start_game_requested.connect(_request_enter)
	_menu.load_game_requested.connect(_on_load_game_requested)
	_menu.settings_requested.connect(_open_settings)
	_menu.quit_requested.connect(_quit_game)
	_intro_controller.intro_finished.connect(_on_intro_finished)
	_intro_controller.play_intro()


func can_enter() -> bool:
	return _intro_finished and not _entering


func _request_enter() -> void:
	if not can_enter() or TransitionManager.is_busy():
		return
	_entering = true
	_menu.lock_interaction()
	_intro_controller.play_exit_impulse()
	TransitionManager.transition_from_boot(
		NEXT_SCENE,
		Vector2(0.553, 0.346))


func _on_intro_finished() -> void:
	_intro_finished = true


func _on_load_game_requested() -> void:
	_menu.show_status("读取存档功能待接入")


func _open_settings() -> void:
	if has_node("SettingsPanel"):
		return
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	add_child(panel)


func _quit_game() -> void:
	get_tree().quit()
