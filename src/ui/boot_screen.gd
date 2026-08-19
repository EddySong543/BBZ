extends Control

## 新 Boot Screen 的最小骨架：
## 只展示 boot char2，点击或按确认键后进入 Main Menu。
## 视觉扩展会在角色母图确认后另行添加，本场景不保留旧版对波、标题或动画。

const NEXT_SCENE := "res://src/ui/main_menu.tscn"
const AudioEventsBoot := preload("res://src/core/audio_events.gd")

var _entering: bool = false
var _intro_finished: bool = false

@onready var _title: BootTitleController = $TitleColumn
@onready var _enter_prompt: BootEnterPrompt = $EnterPrompt
@onready var _intro_controller: BootIntroController = $IntroController


func _ready() -> void:
	AudioEventsBoot.ensure_buses()
	GameSettings.load_and_apply()
	_enter_prompt.synchronize_with_title(_title)
	_intro_controller.intro_finished.connect(_on_intro_finished)
	_intro_controller.play_intro()


func can_enter() -> bool:
	return _intro_finished and not _entering


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_request_enter()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_request_enter()
		get_viewport().set_input_as_handled()


func _request_enter() -> void:
	if not can_enter() or TransitionManager.is_busy():
		return
	_entering = true
	_enter_prompt.play_enter_feedback()
	_intro_controller.play_exit_impulse()
	TransitionManager.transition_from_boot(
		NEXT_SCENE,
		Vector2(0.553, 0.346))


func _on_intro_finished() -> void:
	_intro_finished = true
