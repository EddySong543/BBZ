extends CanvasLayer

## 全局场景切换协调器。通用切场保持无幕布；只有主界面传送会调用
## 从旧横向波幕改造的底部上涌波幕。Boot 继续使用独立曝光环。

const PORTAL_WAVE_SHADER := preload(
		"res://assets/shaders/canvas_portal_vertical_wave.gdshader")

const BOOT_EXIT_SHADER := preload(
	"res://assets/shaders/canvas_boot_exit_pixels.gdshader")

enum BootExitMode {
	DIRECTIONAL_CUT = 0,
	SOLID_RING = 1,
	EXPOSURE_RING = 2,
}

const BOOT_EXIT_MODE := BootExitMode.EXPOSURE_RING
const BOOT_RING_FILL_COLOR := Color.WHITE
const BOOT_RING_EDGE_COLOR := Color("#D6A33E")
const BOOT_RING_ENERGY_TINT := Color("#FFF7E8")
const BOOT_RING_EDGE_HALF_WIDTH := 0.018
const BOOT_PRE_COVER_TIME := 0.16
const BOOT_COVER_TIME := 0.74
const BOOT_HOLD_TIME := 0.03
const BOOT_REVEAL_TIME := 0.50
const PORTAL_WAVE_COVER_TIME := 0.38
const PORTAL_WAVE_REVEAL_TIME := 0.45

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

var _boot_rect: ColorRect
var _boot_mat: ShaderMaterial
var _portal_wave_rect: ColorRect
var _portal_wave_mat: ShaderMaterial
var _portal_wave_time: float = 0.0
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_portal_wave_mat = ShaderMaterial.new()
	_portal_wave_mat.shader = PORTAL_WAVE_SHADER
	_portal_wave_rect = ColorRect.new()
	_portal_wave_rect.name = "PortalWaveVeil"
	_portal_wave_rect.material = _portal_wave_mat
	_portal_wave_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portal_wave_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_portal_wave_rect.visible = false
	add_child(_portal_wave_rect)
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
		_portal_wave_mat.set_shader_parameter("aspect", s.x / s.y)
		_boot_mat.set_shader_parameter("aspect", s.x / s.y)


func _process(delta: float) -> void:
	if _portal_wave_rect.visible:
		_portal_wave_time += delta
		_portal_wave_mat.set_shader_parameter("wave_time", _portal_wave_time)


## 是否正在转场中（期间 transition_to 会被忽略）。
func is_busy() -> bool:
	return _busy


func boot_exit_mode() -> int:
	return BOOT_EXIT_MODE


## 通用切场不再绘制任何幕布；保留忙碌锁防止同一帧重复提交。
func transition_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	_busy = false


## 主界面传送专用：底部像素波盖屏，切场后继续向顶部排走。
func portal_transition_to(scene_path: String, energy_color: Color) -> void:
	if _busy:
		return
	_busy = true
	_portal_wave_mat.set_shader_parameter("crest_color", energy_color)
	_portal_wave_mat.set_shader_parameter("deep_color", energy_color.darkened(0.62))
	_portal_wave_mat.set_shader_parameter("progress", 0.0)
	_portal_wave_time = 0.0
	_portal_wave_rect.visible = true
	var cover_tween := create_tween()
	cover_tween.tween_method(
			_set_portal_wave_progress, 0.0, 1.0, PORTAL_WAVE_COVER_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await cover_tween.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var reveal_tween := create_tween()
	reveal_tween.tween_method(
			_set_portal_wave_progress, 1.0, 2.0, PORTAL_WAVE_REVEAL_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal_tween.finished
	_portal_wave_rect.visible = false
	_busy = false


func _set_portal_wave_progress(value: float) -> void:
	_portal_wave_mat.set_shader_parameter("progress", value)


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


func _set_boot_progress(value: float) -> void:
	_boot_mat.set_shader_parameter(&"progress", value)
