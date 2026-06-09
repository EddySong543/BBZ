extends ColorRect

## 单色对波背景驱动（main_menu / bp_screen 共用的 menu_background 顶层覆盖层）。
##
## 配合 canvas_env_wave_flow.gdshader：每帧推进横向流动相位 phase 与纵向漂浮 wave_time，
## 让竖直波列朝一个方向缓缓流过整屏。
## 颜色与方向继承 boot_screen 的对波胜方（见 BootResult）：
##   蓝胜 → 蓝色、向右流；红胜 → 红色、向左流（延续胜方波的推进方向）。

## 横向流动速度（缓慢；一道波横扫整屏 ≈ 1/drift_speed 秒）。
@export var drift_speed: float = 0.045
## 纵向波纹漂浮速度。
@export var y_drift_speed: float = 0.6

var _mat: ShaderMaterial
var _phase: float = 0.0
var _wave_t: float = 0.0


func _ready() -> void:
	_mat = material as ShaderMaterial
	if _mat == null:
		push_warning("wave_flow_bg: 缺少 ShaderMaterial")
		set_process(false)
		return
	_apply_winner()
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)


## 继承 boot 胜方色与推进方向。
func _apply_winner() -> void:
	var blue: bool = BootResult.last_blue_wins
	_mat.set_shader_parameter("use_blue", 1.0 if blue else 0.0)
	_mat.set_shader_parameter("drift_dir", 1.0 if blue else -1.0)


func _update_aspect() -> void:
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _process(delta: float) -> void:
	_phase += delta * drift_speed
	_wave_t += delta * y_drift_speed
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("wave_time", _wave_t)
