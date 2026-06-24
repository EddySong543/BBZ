extends ColorRect

## 单色对波背景驱动（main_menu / bp_screen 共用的 menu_background 顶层覆盖层）。
##
## 配合 canvas_env_wave_flow.gdshader：每帧推进横向流动相位 phase 与纵向漂浮 wave_time，
## 让竖直波列朝一个方向缓缓流过整屏。
## 颜色与方向继承 boot_screen 的对波胜方（见 BootResult）：
##   蓝胜 → 蓝色、向右流；红胜 → 红色、向左流（延续胜方波的推进方向）。

## 横向流动速度（B 平息：调慢；一道波横扫整屏 ≈ 1/drift_speed 秒）。
@export var drift_speed: float = 0.022
## 纵向波纹漂浮速度（B 平息：调慢）。
@export var y_drift_speed: float = 0.30

@export_group("B · 平息动效")
## 波振幅（B 平息：调小。⚠ 覆盖材质里的 wave_amp，驱动为准）。
@export_range(0.04, 0.30, 0.005) var wave_amp: float = 0.11
## 呼吸幅度：振幅缓慢起伏，动而不躁（0 = 关呼吸）。
@export_range(0.0, 0.5, 0.01) var breath_amt: float = 0.12
## 呼吸速度。
@export_range(0.05, 2.0, 0.05) var breath_speed: float = 0.5

@export_group("E · 静息区")
## 开 / 关 屏中央静息区（眼睛歇脚区·区内压波峰+颗粒）。
@export var rest_enable: bool = true
## 静息区中心 Y（UV·对准三卡区）。
@export_range(0.30, 0.70, 0.01) var rest_center_y: float = 0.47
## 椭圆半径（UV·x = 宽 / y = 高）。
@export var rest_size: Vector2 = Vector2(0.40, 0.33)
## 边缘羽化（越大越柔·越不像盖板/海面）。
@export_range(0.02, 1.0, 0.01) var rest_soft: float = 0.55
## 区内保留多少波振幅（0 = 静止 · 1 = 满）。
@export_range(0.0, 1.0, 0.01) var rest_motion: float = 0.25
## 区内保留多少颗粒 / 抖动（0 = 玻璃滑 · 1 = 满）。
@export_range(0.0, 1.0, 0.01) var rest_smooth: float = 0.40

var _mat: ShaderMaterial
var _phase: float = 0.0
var _wave_t: float = 0.0
var _breath_t: float = 0.0


func _ready() -> void:
	add_to_group("wave_flow_bg")   # 设置面板翻转颜色时 call_group 实时刷新
	_mat = material as ShaderMaterial
	if _mat == null:
		push_warning("wave_flow_bg: 缺少 ShaderMaterial")
		set_process(false)
		return
	_apply_winner()
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)


## 设置面板翻转「界面主色」时实时重应用（call_group("wave_flow_bg", "refresh_colors")）。
func refresh_colors() -> void:
	if _mat != null:
		_apply_winner()


## 继承 boot 胜方色与推进方向（含界面主色翻转开关）。
func _apply_winner() -> void:
	var blue: bool = BootResult.effective_blue_wins()
	_mat.set_shader_parameter("use_blue", 1.0 if blue else 0.0)
	_mat.set_shader_parameter("drift_dir", 1.0 if blue else -1.0)


func _update_aspect() -> void:
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _process(delta: float) -> void:
	_phase += delta * drift_speed
	_wave_t += delta * y_drift_speed
	_breath_t += delta * breath_speed
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("wave_time", _wave_t)
	# B + E 旋钮每帧推送 → 编辑器 Inspector 改动可实时生效（菜单背景，开销可忽略）。
	_mat.set_shader_parameter("breath", sin(_breath_t) * breath_amt)
	_mat.set_shader_parameter("wave_amp", wave_amp)
	_mat.set_shader_parameter("rest_enable", 1.0 if rest_enable else 0.0)
	_mat.set_shader_parameter("rest_center", Vector2(0.5, rest_center_y))
	_mat.set_shader_parameter("rest_size", rest_size)
	_mat.set_shader_parameter("rest_soft", rest_soft)
	_mat.set_shader_parameter("rest_motion", rest_motion)
	_mat.set_shader_parameter("rest_smooth", rest_smooth)
