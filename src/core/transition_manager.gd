extends CanvasLayer

## 全局「波幕」转场管理器（autoload·BP 重做 2A 决议）。
##
## 任何场景切换的统一转场：胜方色像素波涌入盖屏 → change_scene → 波排走揭幕。
## 波幕不关心目标场景内容 → menu→bp、bp→battle、未来任意风格的 battle scene 全部自动受益。
## 颜色与推进方向继承 boot 对波胜方（BootResult），与菜单/BP 波流背景同语系。
##
## 用法（公共 API）：
##   TransitionManager.transition_to("res://src/ui/battle_screen1.tscn")
##   # 即发即忘；转场期间波幕拦截输入防连点，重复调用被忽略（is_busy() 可查）。

const WAVE_SHADER := preload("res://assets/shaders/canvas_transition_wave.gdshader")
const BOOT_EXIT_SHADER := preload(
	"res://assets/shaders/canvas_boot_exit_pixels.gdshader")

enum BootExitMode {
	DIRECTIONAL_CUT = 0,
	SOLID_RING = 1,
	EXPOSURE_RING = 2,
}

const COVER_TIME := 0.38
const REVEAL_TIME := 0.45
const BOOT_EXIT_MODE := BootExitMode.EXPOSURE_RING
const BOOT_RING_FILL_COLOR := Color.WHITE
const BOOT_RING_EDGE_COLOR := Color("#D6A33E")
const BOOT_RING_ENERGY_TINT := Color("#FFF7E8")
const BOOT_RING_EDGE_HALF_WIDTH := 0.018
const BOOT_PRE_COVER_TIME := 0.16
const BOOT_COVER_TIME := 0.74
const BOOT_HOLD_TIME := 0.03
const BOOT_REVEAL_TIME := 0.50

# 自定义鼠标指针（G 件·程序生成 tools/gen_ui_cursor.gd v8）：
# ①GPT 出图理解不好→程序实现转正 ②尾腿怎么做都怪→纯箭镞 ③悬停深色金身看不出还误导⛔
# ④悬停手型读作竖中指⛔→保持箭头形·悬停只加右下金色偏移边·⛔变暗⛔换形。
# 借这个常驻视觉 autoload 开机注册·零 project.godot 改动。两态箭镞同形同色（柔和暖灰米白+近黑描边·
# 36×36·18 设计格 ×2），悬停只在右下受光侧追加 1 设计格深金偏移边（按钮侧由 ButtonJuice
# 挂载时开 POINTING_HAND）。hotspot 两态同=描边尖端（金晕只占透明区·切换零跳动点击点不漂）。
# 改形状=调 gen_ui_cursor.gd 形状表重跑+--import；悬停退回"什么都不变"=下行 CURSOR_HAND 改 CURSOR_ARROW。
const CURSOR_ARROW := preload("res://assets/ui/cursor_arrow.png")
const CURSOR_HAND := preload("res://assets/ui/cursor_hand.png")
const CURSOR_HOTSPOT := Vector2(4, 2)

var _rect: ColorRect
var _mat: ShaderMaterial
var _boot_rect: ColorRect
var _boot_mat: ShaderMaterial
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
	_boot_mat = ShaderMaterial.new()
	_boot_mat.shader = BOOT_EXIT_SHADER
	_boot_mat.set_shader_parameter(
		&"transition_mode",
		BOOT_EXIT_MODE)
	_boot_mat.set_shader_parameter(
		&"ring_fill_color",
		BOOT_RING_FILL_COLOR)
	_boot_mat.set_shader_parameter(
		&"ring_edge_color",
		BOOT_RING_EDGE_COLOR)
	_boot_mat.set_shader_parameter(
		&"ring_energy_tint",
		BOOT_RING_ENERGY_TINT)
	_boot_mat.set_shader_parameter(
		&"ring_edge_half_width",
		BOOT_RING_EDGE_HALF_WIDTH)
	_boot_rect = ColorRect.new()
	_boot_rect.name = "BootPixelVeil"
	_boot_rect.material = _boot_mat
	_boot_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_boot_rect.visible = false
	add_child(_boot_rect)
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)
	Input.set_custom_mouse_cursor(CURSOR_ARROW, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	Input.set_custom_mouse_cursor(CURSOR_HAND, Input.CURSOR_POINTING_HAND, CURSOR_HOTSPOT)


func _update_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)
		_boot_mat.set_shader_parameter("aspect", s.x / s.y)


func _process(delta: float) -> void:
	if _rect.visible:
		_wave_t += delta
		_mat.set_shader_parameter("wave_time", _wave_t)


## 是否正在转场中（期间 transition_to 会被忽略）。
func is_busy() -> bool:
	return _busy


func boot_exit_mode() -> int:
	return BOOT_EXIT_MODE


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


## Boot 专用离场：手掌能量沿右上—左下贯穿成像素切面，切面扩宽盖屏，
## 切场后继续沿原方向离开。只复用常驻 CanvasLayer 与忙碌锁，不复用旧波幕。
func transition_from_boot(
	scene_path: String,
	energy_origin: Vector2 = Vector2(0.553, 0.346),
) -> void:
	if _busy:
		return
	_busy = true
	_boot_mat.set_shader_parameter(
		&"energy_origin",
		Vector2(
			clampf(energy_origin.x, 0.0, 1.0),
			clampf(energy_origin.y, 0.0, 1.0)))
	_boot_mat.set_shader_parameter(&"progress", 0.0)
	_boot_rect.visible = true

	await get_tree().create_timer(BOOT_PRE_COVER_TIME).timeout
	var cover_tween := create_tween()
	cover_tween.tween_method(
		_set_boot_progress,
		0.0,
		1.0,
		BOOT_COVER_TIME,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await cover_tween.finished

	await get_tree().create_timer(BOOT_HOLD_TIME).timeout
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame

	var reveal_tween := create_tween()
	reveal_tween.tween_method(
		_set_boot_progress,
		1.0,
		2.0,
		BOOT_REVEAL_TIME,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal_tween.finished
	_boot_rect.visible = false
	_busy = false


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


func _set_boot_progress(value: float) -> void:
	_boot_mat.set_shader_parameter(&"progress", value)


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
## deep 取 crest 压暗 62%（2026-07-17 35%→62%：波家族 v3 暗场化——boot 底=暗档能量场、
## 亮只留芯线/浪尖，波幕跟队。⛔旧「亮幕」决定（2026-06-10 中段过暗反转）随 v3 作废）。
func _apply_winner_style() -> void:
	# 方向与色相均取 effective（含界面主色翻转）：翻转开时方向曾用原始 last_blue_wins、
	# 色却用 dip_color()=effective → 推进方向与色相打架。统一为 effective（2026-06-27 修复）。
	_mat.set_shader_parameter("dir", 1.0 if BootResult.effective_blue_wins() else -1.0)
	var crest := BootResult.dip_color()
	_mat.set_shader_parameter("crest_color", crest)
	_mat.set_shader_parameter("deep_color", crest.darkened(0.62))
