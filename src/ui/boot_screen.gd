extends Control

## 新 Boot Screen 的最小骨架：
## 只展示 boot char2，点击或按确认键后进入 Main Menu。
## 视觉扩展会在角色母图确认后另行添加，本场景不保留旧版对波、标题或动画。

const NEXT_SCENE := "res://src/ui/main_menu.tscn"
const AudioEventsBoot := preload("res://src/core/audio_events.gd")

var _entering: bool = false


func _ready() -> void:
	AudioEventsBoot.ensure_buses()
	GameSettings.load_and_apply()


func can_enter() -> bool:
	return not _entering


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
	if _entering or TransitionManager.is_busy():
		return
	_entering = true
	TransitionManager.transition_to(NEXT_SCENE)
