extends Control

## 波波攒 · 对波加载界面（原型 · 网格纯色版）
## 左蓝 / 右红 竖直波列在中央对撞僵持；加载完成后提示"点击屏幕进入游戏"，
## 点击后随机一方盖过另一方 → 进入游戏（占位，不切场景）。
##
## 像素机制：背景 ColorRect 用 shader 在【原生分辨率】做网格吸附——横 24 格、正方形，
## 每格只在格心采样一次、整格填纯色（无渐变/无平滑/无抖动）。不经任何上采样。
## 文字层不走网格：原生高分辨率 Label，用项目像素字体 Ark Pixel 整数倍字号（清晰）。
## 仅原型用，不接入游戏。

const LOAD_TIME := 1.2    # 模拟加载时长（秒）
const SWEEP_TIME := 0.85  # 点击后盖过时长（秒）

@onready var _wave: ColorRect = $Wave

var _mat: ShaderMaterial
var _t := 0.0
var _phase := "loading"   # loading → ready → sweeping → done
var _load_elapsed := 0.0
var _title: Label
var _prompt: Label


func _ready() -> void:
	_mat = _wave.material as ShaderMaterial
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)
	_build_labels()
	# 入场淡入
	_mat.set_shader_parameter("intensity", 0.0)
	var tw := create_tween()
	tw.tween_method(_set_intensity, 0.0, 1.0, 0.8)


## 把宽高比喂给 shader（用于算正方形格高 + 暗角圆度）。
func _update_aspect() -> void:
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


## 文字：用项目自带 FontManager（Ark Pixel 像素字体，已关抗锯齿）。
## 字号取 12 的整数倍（FontManager 会选 12px 字体）：标题 96=8× / 提示 36=3×。
func _build_labels() -> void:
	_title = Label.new()
	_title.text = "波波攒之王"
	FontManager.apply(_title, 96)
	_title.add_theme_color_override("font_color", Color("#fdf3d0"))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 80.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_prompt = Label.new()
	_prompt.text = "加载中"
	FontManager.apply(_prompt, 36)
	_prompt.add_theme_color_override("font_color", Color("#e8eef7"))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -150.0
	_prompt.offset_bottom = -90.0
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"loading":
			_load_elapsed += delta
			var dots := int(_t * 2.0) % 4
			_prompt.text = "加载中" + ".".repeat(dots)
			_struggle()
			if _load_elapsed >= LOAD_TIME:
				_phase = "ready"
				_prompt.text = "点击屏幕进入游戏"
		"ready":
			_struggle()
			_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)  # 呼吸


## 僵持期：边界在 0.5 附近双频率游走（互不相让的活感）。
func _struggle() -> void:
	var pos := 0.5 + sin(_t * 1.3) * 0.05 + sin(_t * 2.9 + 1.0) * 0.025
	_mat.set_shader_parameter("clash_pos", pos)


func _input(event: InputEvent) -> void:
	if _phase != "ready":
		return
	var go := false
	if event is InputEventMouseButton:
		go = event.pressed
	elif event is InputEventScreenTouch:
		go = event.pressed
	elif event is InputEventKey:
		go = event.pressed and not event.echo
	if go:
		_trigger_clash()


## 点击 → 随机一方盖过另一方。
func _trigger_clash() -> void:
	_phase = "sweeping"
	var blue_wins := randf() < 0.5
	var target := 1.0 if blue_wins else 0.0  # 1 蓝盖过 / 0 红盖过

	var pt := create_tween()
	pt.tween_property(_prompt, "modulate:a", 0.0, 0.25)

	var cur := _mat.get_shader_parameter("clash_pos") as float
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(_set_clash, cur, target, SWEEP_TIME)
	tw.parallel().tween_method(_set_jitter, 1.0, 0.2, SWEEP_TIME)  # 收束抖动
	tw.tween_callback(_on_swept.bind(blue_wins))


func _on_swept(blue_wins: bool) -> void:
	_phase = "done"
	var who := "蓝方" if blue_wins else "红方"
	print("[wave_clash] %s 盖过 → 进入游戏 (placeholder, 未接入)" % who)
	# 短促全屏闪光收束（原型不切场景，停在胜方满屏）
	var fl := create_tween()
	fl.tween_method(_set_intensity, 1.0, 1.7, 0.12)
	fl.tween_method(_set_intensity, 1.7, 1.0, 0.30)


func _set_clash(v: float) -> void:
	_mat.set_shader_parameter("clash_pos", v)


func _set_intensity(v: float) -> void:
	_mat.set_shader_parameter("intensity", v)


func _set_jitter(v: float) -> void:
	_mat.set_shader_parameter("edge_jitter", v)
