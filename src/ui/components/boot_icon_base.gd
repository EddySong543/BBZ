@tool
class_name BootIconBase
extends "res://src/ui/components/command_sequence_slot_skin.gd"

## Boot 底部入口直接复用顺序序列已通过的丝滑十字星轮廓与 SSAA 绘制路径。
## 本组件只负责把按钮焦点/按压映射为底座明暗，不改写十字星几何。

const IDLE_ALPHA := 0.42
const PRESSED_ALPHA := 0.82
const IDLE_STAR_COLOR := Color("#F2E8CC")
const ENERGY_GOLD := Color(1.0, 0.86, 0.54, 1.0)

var _focus_strength: float = 0.0
var _press_strength: float = 0.0


func _ready() -> void:
	super._ready()
	_sync_state()


func set_state(focus_strength: float, press_strength: float) -> void:
	_focus_strength = clampf(focus_strength, 0.0, 1.0)
	_press_strength = clampf(press_strength, 0.0, 1.0)
	_sync_state()


func debug_state() -> Dictionary:
	var geometry: Dictionary = super.debug_geometry()
	return {
		"focus_strength": _focus_strength,
		"press_strength": _press_strength,
		"hot": hot,
		"base_alpha": self_modulate.a,
		"render_path": geometry["render_path"],
		"star_color": geometry["star_color"],
	}


func _sync_state() -> void:
	set_hot(_focus_strength >= 0.5)
	ornament_color = IDLE_STAR_COLOR.lerp(ENERGY_GOLD, _focus_strength)
	var focus_alpha: float = lerpf(IDLE_ALPHA, 1.0, _focus_strength)
	self_modulate.a = focus_alpha * lerpf(1.0, PRESSED_ALPHA, _press_strength)
	queue_redraw()
