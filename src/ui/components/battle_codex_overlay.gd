extends Control
## 场景内图鉴浮层只负责生命周期；主菜单与战斗共用同一个 CodexScreen。

const CODEX_SCENE_PATH := "res://src/ui/codex_screen.tscn"

var _codex: Control
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var codex_scene := load(CODEX_SCENE_PATH) as PackedScene
	_codex = codex_scene.instantiate() as Control
	_codex.name = "CodexScreen"
	_codex.set("embedded_close", Callable(self, "close"))
	add_child(_codex)
	_codex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_codex.process_mode = Node.PROCESS_MODE_DISABLED


func open() -> void:
	_closing = false
	_codex.call("reset_for_open")
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_codex.process_mode = Node.PROCESS_MODE_INHERIT
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	move_to_front()
	_codex.call("play_overlay_open_animation")


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	await _codex.call("play_overlay_close_animation")
	if not _closing:
		return
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_codex.process_mode = Node.PROCESS_MODE_DISABLED
	_closing = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
