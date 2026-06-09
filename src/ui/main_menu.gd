extends Control

## 主菜单（Main Menu）—— boot_screen 之后的主画面。
## 背景为单色对波波流（继承 boot 胜方色，见 wave_flow_bg / BootResult）+ 浮于其上的菜单按钮。
## 现仅"匹配对战"接入实际流程（→ bp_screen → 战斗），其余按钮占位（点击弹"敬请期待"）。

const BP_SCENE := "res://src/ui/bp_screen.tscn"

## 按钮像素底板（复用战斗动作按钮同款 jelly shader）。三档配色区分操作层级。
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const PLATE_TIERS := {
	"gold": {   # 主行动「匹配对战」——暖金
		"fill_top": Color(0.64, 0.46, 0.17), "fill_bottom": Color(0.33, 0.21, 0.07),
		"edge_inner": Color(0.98, 0.82, 0.42), "edge_outer": Color(0.12, 0.08, 0.03),
	},
	"steel": {  # 模式 / 顶栏——蓝钢
		"fill_top": Color(0.24, 0.30, 0.44), "fill_bottom": Color(0.11, 0.14, 0.24),
		"edge_inner": Color(0.52, 0.64, 0.88), "edge_outer": Color(0.04, 0.05, 0.10),
	},
	"copper": { # 底部导航坞——古铜
		"fill_top": Color(0.35, 0.27, 0.20), "fill_bottom": Color(0.17, 0.13, 0.10),
		"edge_inner": Color(0.74, 0.56, 0.34), "edge_outer": Color(0.08, 0.06, 0.04),
	},
}

@onready var _coming_soon: Label = $UI/ComingSoon

var _toast_tween: Tween


func _ready() -> void:
	_setup_buttons()
	_coming_soon.modulate.a = 0.0
	_play_intro()
	_start_match_glow()


## 入场转场：承接 boot 决堤色幕 —— 全屏胜方色幕淡出，波流背景从同色光中浮现。
## boot 末尾决堤洗成胜方色 → 菜单从同一胜方色淡出露出同色波流，色相连贯、无白闪硬切。
func _play_intro() -> void:
	var fade := ColorRect.new()
	fade.color = BootResult.dip_color()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 4096   # 盖住一切，最后淡出
	add_child(fade)
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(fade, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fade.queue_free)

	_animate_buttons_in()


## 按钮错落浮入：白幕淡出的同时，菜单按钮按顺序淡入 + 轻微上浮回弹 → 开屏仪式感。
## 只动运行时的 modulate/position，不改 .tscn 里手调的最终落位。
func _animate_buttons_in() -> void:
	var order: Array = [
		$UI/MatchButton,
		$UI/TowerButton, $UI/StoryButton,
		$UI/ProfileButton, $UI/SettingsButton,
		$UI/NavHeroes, $UI/NavSquad, $UI/NavItems, $UI/NavShop,
	]
	var step := 0.0
	for n in order:
		var b := n as Control
		if b == null:
			continue
		var home := b.position
		b.position = home + Vector2(0.0, 30.0)
		b.modulate.a = 0.0
		var delay := 0.12 + step
		var ta := create_tween()
		ta.tween_interval(delay)
		ta.tween_property(b, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var tp := create_tween()
		tp.tween_interval(delay)
		tp.tween_property(b, "position", home, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		step += 0.06


## 主行动「匹配对战」克制呼吸金光：缓慢脉冲底板 Bg 的 modulate（与进场淡入 / juice 缩放互不干扰）。
func _start_match_glow() -> void:
	var bg := get_node_or_null("UI/MatchButton/Bg") as CanvasItem
	if bg == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(bg, "modulate", Color(1.25, 1.12, 0.8), 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bg, "modulate", Color.WHITE, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_buttons() -> void:
	# 主行动：匹配对战 → 进入 BP 选人 → 战斗
	var match_btn: Button = $UI/MatchButton
	FontManager.apply_btn(match_btn, 40)
	_apply_plate(match_btn, "gold")
	match_btn.pressed.connect(_on_match_pressed)
	_attach_juice(match_btn)

	# 占位按钮（点击弹"敬请期待"）：[按钮, 功能名, 底板档]
	var placeholders: Array = [
		[$UI/ProfileButton, "个人资料", "steel"],
		[$UI/SettingsButton, "设置", "steel"],
		[$UI/TowerButton, "爬塔模式", "steel"],
		[$UI/StoryButton, "故事模式", "steel"],
		[$UI/NavHeroes, "英雄", "copper"],
		[$UI/NavSquad, "小队", "copper"],
		[$UI/NavItems, "道具", "copper"],
		[$UI/NavShop, "商店", "copper"],
	]
	for entry in placeholders:
		var btn: Button = entry[0]
		FontManager.apply_btn(btn, 26)
		_apply_plate(btn, entry[2])
		btn.pressed.connect(_on_placeholder_pressed.bind(entry[1]))
		_attach_juice(btn)

	FontManager.apply(_coming_soon, 40)


## 给按钮挂像素底板（jelly shader）：清空默认 stylebox + 一层 Bg ColorRect 衬在按钮文字后。
## aspect 按按钮宽/高算 → 长矩形像素格保持方形不拉糊（见 canvas_button_jelly 注释）。
func _apply_plate(btn: Button, tier: String) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var preset: Dictionary = PLATE_TIERS.get(tier, PLATE_TIERS["steel"])
	var mat := ShaderMaterial.new()
	mat.shader = JELLY_SHADER
	mat.set_shader_parameter("fill_top", preset["fill_top"])
	mat.set_shader_parameter("fill_bottom", preset["fill_bottom"])
	mat.set_shader_parameter("edge_inner", preset["edge_inner"])
	mat.set_shader_parameter("edge_outer", preset["edge_outer"])
	mat.set_shader_parameter("corner", 0.2)
	mat.set_shader_parameter("edge_px", 2.0)
	mat.set_shader_parameter("noise_amt", 0.05)
	mat.set_shader_parameter("wear", 0.18)
	mat.set_shader_parameter("pixel_grid", 38.0)
	mat.set_shader_parameter("fill_alpha", 0.95)
	var w := btn.offset_right - btn.offset_left
	var h := btn.offset_bottom - btn.offset_top
	mat.set_shader_parameter("aspect", w / maxf(h, 1.0))
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = mat
	btn.add_child(bg)


## 给按钮挂 ButtonJuice（hover 缩放 / 按下反馈）→ 手感与战斗/选人界面统一。
func _attach_juice(btn: Button) -> void:
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)


func _on_match_pressed() -> void:
	get_tree().change_scene_to_file(BP_SCENE)


## 占位功能提示：淡入 → 停留 → 淡出。
func _on_placeholder_pressed(feature: String) -> void:
	_coming_soon.text = feature + " · 敬请期待"
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_coming_soon.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_coming_soon, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(_coming_soon, "modulate:a", 0.0, 0.4)
