extends Control

## 主菜单 = 三牌阵牌桌（第七轮设计·2026-06-11 Eddy 基本通过后实装）。
## 背景 = 单色对波波流（继承 boot 胜方色·亮主调恒定，⛔降明度=脏）。
## 中央 = 三张命运牌（ModeCard）：故事(过去) / 匹配对战(现在·稍大) / 爬塔(未来)。
##   高亮(金框)+放大 = 悬停/焦点专属效果（ModeCard 内实现），不属于某张固定的牌。
## 边缘件：顶左身份带(头像框+名字+段位占位=资料入口) / 顶右设置(icon锚位) /
##   底坞 英雄|小队|道具|商店(icon锚位+字·未来收集层入口)。
## 现仅「匹配对战」接入实际流程（→ bp_screen → 战斗），其余占位（点击弹"敬请期待"）。
## ⚠️ 历史否决（勿再走）：海面化 / 星空压暗 / 中央大物或留白 / 公告卡 / 今日一抽（第七轮裁掉）。

const BP_SCENE := "res://src/ui/bp_screen.tscn"

## 小件像素底板（设置/段位徽章用，钢蓝档；牌面金色只出现在悬停态）。
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const STEEL := {
	"fill_top": Color(0.24, 0.30, 0.44), "fill_bottom": Color(0.11, 0.14, 0.24),
	"edge_inner": Color(0.52, 0.64, 0.88), "edge_outer": Color(0.04, 0.05, 0.10),
}

# 底坞条配色（battle 框语言深色系）
const DOCK_BACKING := Color(0.05, 0.05, 0.06)
const DOCK_FILL := Color(0.10, 0.115, 0.145, 0.92)
const DOCK_TEXT := Color("#c9d2dc")

@onready var _coming_soon: Label = $UI/ComingSoon

var _toast_tween: Tween


func _ready() -> void:
	_setup_identity()
	_setup_settings()
	_setup_modes()
	_setup_dock()
	FontManager.apply(_coming_soon, 40)
	_coming_soon.modulate.a = 0.0
	_play_intro()


# ============================================================
# 各区初始化
# ============================================================

## 顶左身份带：头像框(HeroFrame)+名字+段位占位，整体=资料入口。
func _setup_identity() -> void:
	var btn: Button = $UI/IdentityButton
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var name_lbl: Label = $UI/IdentityButton/NameLabel
	FontManager.apply(name_lbl, 26)
	name_lbl.add_theme_color_override("font_color", Color("#e8edf4"))
	var rank_lbl: Label = $UI/IdentityButton/RankLabel
	FontManager.apply(rank_lbl, 16)
	rank_lbl.add_theme_color_override("font_color", Color("#aab4c4"))
	_add_plate_bg(rank_lbl)
	btn.pressed.connect(_on_placeholder_pressed.bind("个人资料"))


func _setup_settings() -> void:
	var btn: Button = $UI/SettingsButton
	FontManager.apply_btn(btn, 22)
	_apply_plate(btn)
	_set_btn_left_margin(btn, 36.0)   # 文字让出左侧 icon 锚位
	_add_icon_slot(btn, Rect2(16, 13, 28, 28))
	btn.pressed.connect(_on_placeholder_pressed.bind("设置"))
	_attach_juice(btn)


## 三牌阵：匹配对战接真实流程，故事/爬塔占位。悬停金框+放大在 ModeCard 内。
func _setup_modes() -> void:
	($UI/ModeMatch as Button).pressed.connect(_on_match_pressed)
	($UI/ModeStory as Button).pressed.connect(_on_placeholder_pressed.bind("故事模式"))
	($UI/ModeTower as Button).pressed.connect(_on_placeholder_pressed.bind("爬塔模式"))


## 底坞：四个入口连排成一根坞条（深色底+icon 锚位+字+段间分隔线）。
func _setup_dock() -> void:
	var navs: Array = [
		[$UI/NavHeroes, "英雄"], [$UI/NavSquad, "小队"],
		[$UI/NavItems, "道具"], [$UI/NavShop, "商店"],
	]
	for i in navs.size():
		var btn: Button = navs[i][0]
		_set_btn_left_margin(btn, 40.0)   # 文字让出左侧 icon 锚位
		FontManager.apply_btn(btn, 24)
		btn.add_theme_color_override("font_color", DOCK_TEXT)
		# 深色坞底两层（backing + fill）
		var backing := ColorRect.new()
		backing.name = "DockBacking"
		backing.color = DOCK_BACKING
		backing.show_behind_parent = true
		backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(backing)
		var fill := ColorRect.new()
		fill.name = "DockFill"
		fill.color = DOCK_FILL
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.offset_left = 0 if i > 0 else 3
		fill.offset_top = 3
		fill.offset_right = 0 if i < navs.size() - 1 else -3
		fill.offset_bottom = -3
		fill.show_behind_parent = true
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(fill)
		# 段间分隔线（除第一段外，画在左缘）
		if i > 0:
			var sp := ColorRect.new()
			sp.name = "DockSep"
			sp.color = Color(0.40, 0.45, 0.52, 0.40)
			sp.position = Vector2(0, 16)
			sp.size = Vector2(2, 38)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(sp)
		_add_icon_slot(btn, Rect2(34, 21, 28, 28))
		btn.pressed.connect(_on_placeholder_pressed.bind(navs[i][1]))
		_attach_juice(btn)


# ============================================================
# 入场 / 转场
# ============================================================

## 入场：boot 决堤由全局波幕接力揭幕（TransitionManager.reveal_into·胜方波亲手掀开菜单），
## 本场只做"水面落定"：① 整屏缩放沉降 ② 波流从激荡平息 ③ 发牌——三张牌+边缘件错落浮入。
func _play_intro() -> void:
	# ① 余势缩放沉降（整屏含波流背景一起落定）
	pivot_offset = size * 0.5
	scale = Vector2(1.045, 1.045)
	var tz := create_tween()
	tz.tween_property(self, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# ② 波流平息：决堤的能量延续进菜单背景，流速/亮度缓落常态（只动运动不动颜色）
	var wave := get_node_or_null("Background/WaveFlow")
	if wave != null:
		var calm_drift: float = wave.drift_speed
		var calm_y: float = wave.y_drift_speed
		wave.drift_speed = calm_drift * 8.0
		wave.y_drift_speed = calm_y * 3.0
		var ts := create_tween().set_parallel(true)
		ts.tween_property(wave, "drift_speed", calm_drift, 1.4)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ts.tween_property(wave, "y_drift_speed", calm_y, 1.4)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var mat := wave.material as ShaderMaterial
		if mat != null:
			var calm_i: float = mat.get_shader_parameter("intensity")
			var ti := create_tween()
			ti.tween_method(
				func(v: float) -> void: mat.set_shader_parameter("intensity", v),
				calm_i * 1.3, calm_i, 1.2
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_animate_in()


## ③ 发牌入场：中牌先落、两翼跟进、边缘件最后浮入（只动运行时 modulate/position，不改落位）。
func _animate_in() -> void:
	var order: Array = [
		$UI/ModeMatch, $UI/ModeStory, $UI/ModeTower,
		$UI/IdentityButton, $UI/SettingsButton,
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
		step += 0.07


func _on_match_pressed() -> void:
	# 波幕转场（BP 重做 2A）：胜方色波卷入 → 切 BP → 波退去揭幕
	TransitionManager.transition_to(BP_SCENE)


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


# ============================================================
# 小件样式辅助
# ============================================================

## 给按钮挂像素底板（jelly 钢蓝档）：清空默认 stylebox + Bg ColorRect 衬底。
func _apply_plate(btn: Button) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = _jelly_mat(btn.size)
	btn.add_child(bg)


## 给任意 Control（如段位 Label）衬 jelly 底板。
func _add_plate_bg(ctrl: Control) -> void:
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = _jelly_mat(ctrl.size)
	ctrl.add_child(bg)


func _jelly_mat(plate_size: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = JELLY_SHADER
	mat.set_shader_parameter("fill_top", STEEL["fill_top"])
	mat.set_shader_parameter("fill_bottom", STEEL["fill_bottom"])
	mat.set_shader_parameter("edge_inner", STEEL["edge_inner"])
	mat.set_shader_parameter("edge_outer", STEEL["edge_outer"])
	mat.set_shader_parameter("corner", 0.2)
	mat.set_shader_parameter("edge_px", 2.0)
	mat.set_shader_parameter("noise_amt", 0.05)
	mat.set_shader_parameter("wear", 0.18)
	mat.set_shader_parameter("pixel_grid", 38.0)
	mat.set_shader_parameter("fill_alpha", 0.95)
	mat.set_shader_parameter("aspect", plate_size.x / maxf(plate_size.y, 1.0))
	return mat


## 清空按钮默认皮肤，但保留左内边距（给 icon 锚位让位，文字在余下区域居中）。
func _set_btn_left_margin(btn: Button, left: float) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = left
		btn.add_theme_stylebox_override(s, sb)


## icon 锚位占位：28px 像素空格（UI icon 素材到位后原位替换为 TextureRect）。
func _add_icon_slot(host: Control, r: Rect2) -> void:
	var backing := ColorRect.new()
	backing.name = "IconSlot"
	backing.color = Color(0.05, 0.05, 0.06, 0.8)
	backing.position = r.position
	backing.size = r.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backing)
	var inner := ColorRect.new()
	inner.name = "IconSlotInner"
	inner.color = Color(0.22, 0.25, 0.30, 0.9)
	inner.position = r.position + Vector2(2, 2)
	inner.size = r.size - Vector2(4, 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(inner)


## 给按钮挂 ButtonJuice（hover 缩放 / 按下反馈）→ 手感与战斗/选人界面统一。
## 注：三张牌(ModeCard)自带悬停金框+放大，不挂 ButtonJuice 防双重缩放。
func _attach_juice(btn: Button) -> void:
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
