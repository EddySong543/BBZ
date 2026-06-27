extends CanvasLayer

## 全局「波幕」转场管理器（autoload·BP 重做 2A 决议）。
##
## 任何场景切换的统一转场：胜方色像素波涌入盖屏 → change_scene → 波排走揭幕。
## 波幕不关心目标场景内容 → menu→bp、bp→battle、未来任意风格的 battle scene 全部自动受益。
## 颜色与推进方向继承 boot 对波胜方（BootResult），与菜单/BP 波流背景同语系。
##
## 用法（公共 API）：
##   TransitionManager.transition_to("res://src/ui/battle_screen.tscn")
##   # 即发即忘；转场期间波幕拦截输入防连点，重复调用被忽略（is_busy() 可查）。

const WAVE_SHADER := preload("res://assets/shaders/canvas_transition_wave.gdshader")
const COVER_TIME := 0.38
const REVEAL_TIME := 0.45

var _rect: ColorRect
var _mat: ShaderMaterial
var _wave_t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_mat = ShaderMaterial.new()
	_mat.shader = WAVE_SHADER
	_rect = ColorRect.new()
	_rect.name = "Veil"
	_rect.material = _mat
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # 转场期间挡输入，防连点
	_rect.visible = false
	add_child(_rect)
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)


func _update_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _process(delta: float) -> void:
	if _rect.visible:
		_wave_t += delta
		_mat.set_shader_parameter("wave_time", _wave_t)


## 是否正在转场中（期间 transition_to 会被忽略）。
func is_busy() -> bool:
	return _busy


## 波幕切场：涌入盖屏(COVER_TIME) → change_scene → 新场景就绪后排走揭幕(REVEAL_TIME)。
func transition_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	_apply_winner_style()
	_mat.set_shader_parameter("progress", 0.0)
	_rect.visible = true
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, COVER_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)
	# 等新场景完成首帧绘制再揭幕（change_scene 在下一帧才实例化新场景）
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_set_progress, 1.0, 2.0, REVEAL_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_rect.visible = false
	_busy = false


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


## 从"已被盖住"的画面接力揭幕（boot 决堤专用）：决堤已把屏幕洗成胜方色 →
## 波幕同色同向瞬时全盖 → 切场景 → 朝胜方推进方向排走揭幕。
## reveal_time 可调（boot→menu 用稍慢节奏增加仪式感）。
func reveal_into(scene_path: String, reveal_time: float = REVEAL_TIME) -> void:
	if _busy:
		return
	_busy = true
	_apply_winner_style()
	_mat.set_shader_parameter("progress", 1.0)
	_rect.visible = true
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw := create_tween()
	tw.tween_method(_set_progress, 1.0, 2.0, reveal_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_rect.visible = false
	_busy = false


## 胜方色 + 推进方向继承 boot 对波（蓝胜→蓝波向右涌；红胜→红波向左涌）。
## deep 取 crest 压暗 35%（2026-06-10 55%→35%：配合 shader body_min 提高，
## 波幕整体反转为亮色调——Eddy 反馈旧版中段过暗）。
func _apply_winner_style() -> void:
	# 方向与色相均取 effective（含界面主色翻转）：翻转开时方向曾用原始 last_blue_wins、
	# 色却用 dip_color()=effective → 推进方向与色相打架。统一为 effective（2026-06-27 修复）。
	_mat.set_shader_parameter("dir", 1.0 if BootResult.effective_blue_wins() else -1.0)
	var crest := BootResult.dip_color()
	_mat.set_shader_parameter("crest_color", crest)
	_mat.set_shader_parameter("deep_color", crest.darkened(0.35))
