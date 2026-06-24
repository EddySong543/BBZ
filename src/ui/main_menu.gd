extends Control

## 主菜单 = 三牌阵牌桌（第七轮设计·2026-06-11 Eddy 基本通过后实装）。
## 背景 = 单色对波波流（继承 boot 胜方色·亮主调恒定，⛔降明度=脏）。
## 中央 = 三张命运牌（ModeCard）：故事(过去) / 匹配对战(现在·稍大) / 爬塔(未来)。
##   高亮(金框)+放大 = 悬停/焦点专属效果（ModeCard 内实现），不属于某张固定的牌。
## 边缘件：顶左身份带(头像框+名字+段位占位=资料入口) / 顶右设置(icon锚位) /
##   底坞 英雄(图鉴·已实装)|道具|商店(icon锚位+字·未来收集层入口；小队已删 2026-06-12)。
## 现仅「匹配对战」接入实际流程（→ bp_screen → 战斗），其余占位（点击弹"敬请期待"）。
## ⚠️ 历史否决（勿再走）：海面化 / 星空压暗 / 中央大物或留白 / 公告卡 / 今日一抽（第七轮裁掉）。

const BP_SCENE := "res://src/ui/bp_screen.tscn"

# ---- 匹配状态机（临战升温·2026-06-12 改版：翻面盖牌废弃——对波卡面是全场最活的
# 东西，翻成静态王冠=出戏。匹配中改为卡面对波升温备战，取消把手独立成钮）----
# IDLE 点牌=开始匹配；SEARCHING 再点牌/ESC/取消钮=取消；FOUND 锁输入等转场。
# 本地用 mock_match_seconds 定时模拟匹配成功；联机时把定时器换成真匹配回调，状态机原样复用。
enum MatchState { IDLE, SEARCHING, FOUND }

## 本地测试模拟匹配时长（秒）。联机接入后弃用。
@export var mock_match_seconds: float = 3.0

const MATCH_TITLE := "匹配对战"
const MATCH_SUB := "1v1 同时盲选对决"

var _match_state: int = MatchState.IDLE
var _search_elapsed: float = 0.0
var _cancel_btn: Button   # 匹配中才出现的「✕ 取消匹配」（_setup_modes 建·常态隐藏）

## 小件像素底板（设置/段位徽章用）。
## 2026-06-13 Eddy 选 B「典籍朱印」全局铺·主菜单首屏：底板=哑光羊皮（关糖光渐变）
## + 墨线框；字/图标=墨色。（常量名仍叫 STEEL 是历史遗留，值已改羊皮。）
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const STEEL := {
	"fill_top": Color(0.88, 0.82, 0.68), "fill_bottom": Color(0.82, 0.75, 0.60),
	"edge_inner": Color(0.60, 0.50, 0.36), "edge_outer": Color(0.18, 0.12, 0.07),
}
const INK := Color(0.20, 0.14, 0.08)        # 墨（羊皮上的字/图标）
const INK_SOFT := Color(0.42, 0.34, 0.24)   # 淡墨（次级字）
const CREAM := Color(0.95, 0.91, 0.80)      # 暖米白（直接压在暗波上的字·非羊皮上）

# 底坞条配色（典籍羊皮：墨色书脊衬底 + 羊皮页填充 + 墨字）
const DOCK_BACKING := Color(0.16, 0.11, 0.07)
const DOCK_FILL := Color(0.86, 0.80, 0.66, 0.96)
const DOCK_TEXT := Color(0.20, 0.14, 0.08)

@onready var _coming_soon: Label = $UI/ComingSoon
@onready var _match_card: ModeCard = $UI/ModeMatch

var _toast_tween: Tween


func _ready() -> void:
	_setup_identity()
	_setup_settings()
	_setup_modes()
	_setup_dock()
	FontManager.apply(_coming_soon, 40)
	_coming_soon.add_theme_color_override("font_color", CREAM)
	_coming_soon.modulate.a = 0.0
	# 远征卡山脊母题跟随背景对波色：蓝胜=冷夜版 / 红胜=暖日版。借背景同款广播组，
	# 设置面板翻转「界面主色」时（call_group("wave_flow_bg", "refresh_colors")）一并刷新。
	add_to_group("wave_flow_bg")
	_refresh_tower_warm()
	_play_intro()


## 远征卡冷暖随 boot 胜方色：蓝胜→冷夜(warm 0)、红胜→暖日(warm 1)。
func _refresh_tower_warm() -> void:
	var tower := $UI/ModeTower as ModeCard
	if tower != null:
		tower.set_art_warm(0.0 if BootResult.effective_blue_wins() else 1.0)


## 设置面板翻转界面主色时由 call_group("wave_flow_bg", "refresh_colors") 触发（与背景同步）。
func refresh_colors() -> void:
	_refresh_tower_warm()


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
	name_lbl.add_theme_color_override("font_color", CREAM)   # 直接压暗波上→暖米白
	var rank_lbl: Label = $UI/IdentityButton/RankLabel
	FontManager.apply(rank_lbl, 16)
	rank_lbl.add_theme_color_override("font_color", INK)     # 段位章在羊皮板上→墨字
	_add_plate_bg(rank_lbl)
	# 段位盾徽（icon 排查清单·先程序绘制占位）
	var shield := TextureRect.new()
	shield.name = "RankIcon"
	shield.texture = PixelGlyphs.icon_texture("shield")
	shield.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shield.stretch_mode = TextureRect.STRETCH_SCALE
	shield.position = Vector2(6, 9)
	shield.size = Vector2(16, 16)
	shield.modulate = INK
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_lbl.add_child(shield)
	btn.pressed.connect(_on_placeholder_pressed.bind("个人资料"))


func _setup_settings() -> void:
	var btn: Button = $UI/SettingsButton
	FontManager.apply_btn(btn, 22)
	btn.add_theme_color_override("font_color", INK)   # 羊皮板上→墨字
	_apply_plate(btn)
	_set_btn_left_margin(btn, 36.0)   # 文字让出左侧 icon
	_add_icon(btn, Rect2(14, 11, 32, 32), "gear")
	btn.pressed.connect(_open_settings)
	_attach_juice(btn)

	# 退出游戏（PC 必备·2026-06-11 icon 排查补缺）
	var quit_btn: Button = $UI/QuitButton
	FontManager.apply_btn(quit_btn, 22)
	quit_btn.add_theme_color_override("font_color", INK)
	_apply_plate(quit_btn)
	_set_btn_left_margin(quit_btn, 32.0)
	_add_icon(quit_btn, Rect2(10, 11, 32, 32), "exit")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_attach_juice(quit_btn)

	# 版本号（角落惯例·报 bug 定位用）·压暗波上→暖灰
	var ver: Label = $UI/VersionLabel
	FontManager.apply(ver, 14)
	ver.add_theme_color_override("font_color", Color(0.74, 0.66, 0.52, 0.6))


## 打开设置弹框（单例·已开则忽略）。改动即时应用 + 持久化，颜色翻转实时刷新背景。
func _open_settings() -> void:
	if has_node("SettingsPanel"):
		return
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	add_child(panel)


## 三牌阵：匹配对战接真实流程，故事/爬塔占位。悬停金框+放大在 ModeCard 内。
func _setup_modes() -> void:
	($UI/ModeMatch as Button).pressed.connect(_on_match_pressed)
	($UI/ModeStory as Button).pressed.connect(_on_placeholder_pressed.bind("故事模式"))
	($UI/ModeTower as Button).pressed.connect(_on_placeholder_pressed.bind("远征"))   # 原爬塔模式·2026-06-12 改名
	_build_cancel_button()


## 「✕ 取消匹配」独立小钮（匹配中才出现·中牌正下方居中）——取消把手必须可见可点，
## 不再挤在副标小字里（2026-06-12 Eddy："取消匹配感觉不明显"根修）。
func _build_cancel_button() -> void:
	var card := $UI/ModeMatch as Control
	_cancel_btn = Button.new()
	_cancel_btn.name = "CancelMatchButton"
	_cancel_btn.text = "✕ 取消匹配"
	var btn_size := Vector2(220, 52)
	_cancel_btn.position = Vector2(
		card.position.x + (card.size.x - btn_size.x) * 0.5,
		card.position.y + card.size.y + 16.0)
	_cancel_btn.size = btn_size
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		_cancel_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	FontManager.apply_btn(_cancel_btn, 22)
	_cancel_btn.add_theme_color_override("font_color", Color("#e86060"))
	_cancel_btn.add_theme_color_override("font_hover_color", Color("#ff8a7a"))
	# 红描边 + 深底（图鉴返回钮同范式·装饰必须 IGNORE 防吞点击）
	var edge := ColorRect.new()
	edge.color = Color(0.83, 0.30, 0.27, 0.65)
	edge.show_behind_parent = true
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = -2
	edge.offset_top = -2
	edge.offset_right = 2
	edge.offset_bottom = 2
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_btn.add_child(edge)
	var backing := ColorRect.new()
	backing.color = Color(0.08, 0.05, 0.06, 0.94)
	backing.show_behind_parent = true
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_btn.add_child(backing)
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_btn_pressed)
	_attach_juice(_cancel_btn)
	$UI.add_child(_cancel_btn)


func _on_cancel_btn_pressed() -> void:
	if _match_state == MatchState.SEARCHING:
		_cancel_search()


## 取消钮显隐：出现=淡入上浮；收起=即时隐藏（取消瞬间不该有残影挡点击）。
func _show_cancel_button(on: bool) -> void:
	var home_y: float = ($UI/ModeMatch as Control).position.y + ($UI/ModeMatch as Control).size.y + 16.0
	if not on:
		_cancel_btn.visible = false
		_cancel_btn.position.y = home_y
		return
	_cancel_btn.visible = true
	_cancel_btn.modulate.a = 0.0
	_cancel_btn.position.y = home_y + 14.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cancel_btn, "modulate:a", 1.0, 0.25)
	tw.tween_property(_cancel_btn, "position:y", home_y, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 底坞：三个入口连排成一根坞条（深色底+icon 锚位+字+段间分隔线）。
## 「小队」已删（2026-06-12 Eddy）；「英雄」接英雄图鉴，道具/商店仍占位。
func _setup_dock() -> void:
	var navs: Array = [
		[$UI/NavHeroes, "英雄", "hero"],
		[$UI/NavItems, "道具", "potion"], [$UI/NavShop, "商店", "coin"],
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
			sp.color = Color(0.45, 0.36, 0.24, 0.45)   # 暖墨分隔（羊皮坞上）
			sp.position = Vector2(0, 16)
			sp.size = Vector2(2, 38)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(sp)
		_add_icon(btn, Rect2(30, 19, 32, 32), navs[i][2])
		if btn == $UI/NavHeroes:
			btn.pressed.connect(_on_heroes_pressed)   # 英雄图鉴（2026-06-12 实装）
		else:
			btn.pressed.connect(_on_placeholder_pressed.bind(navs[i][1]))
		_attach_juice(btn)


## 英雄图鉴入口：波幕转场（menu↔bp 同语言）。匹配中不离队。
func _on_heroes_pressed() -> void:
	if _match_state != MatchState.IDLE:
		return
	TransitionManager.transition_to("res://src/ui/hero_gallery_screen.tscn")


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
		$UI/IdentityButton, $UI/QuitButton, $UI/SettingsButton,
		$UI/NavHeroes, $UI/NavItems, $UI/NavShop,
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
	match _match_state:
		MatchState.IDLE:
			_start_search()
		MatchState.SEARCHING:
			_cancel_search()   # 点卡仍可取消（取消钮是主把手，这是顺手路径）
		MatchState.FOUND:
			pass   # 成功一拍期间锁输入，等波幕转场接管


## ESC 取消匹配（与取消钮/再点牌等价）。
func _unhandled_input(event: InputEvent) -> void:
	if _match_state == MatchState.SEARCHING and event.is_action_pressed("ui_cancel"):
		_cancel_search()


# ============================================================
# 匹配状态机：临战升温（对波加速备战）+正计时 → 对撞一拍 → 波幕转场
# ============================================================

func _start_search() -> void:
	_match_state = MatchState.SEARCHING
	_search_elapsed = 0.0
	_set_side_cards_enabled(false)
	_match_card.set_battle_ready(true)
	_match_card.card_title = "匹配中"
	_match_card.card_subtitle = "0:00"
	_show_cancel_button(true)


func _cancel_search() -> void:
	_match_state = MatchState.IDLE
	_match_card.set_battle_ready(false)
	_match_card.card_title = MATCH_TITLE
	_match_card.card_subtitle = MATCH_SUB
	_show_cancel_button(false)
	_set_side_cards_enabled(true)


## 匹配中每帧：标题省略号逐点（0.5s/点）+ 副标正计时每秒跳；到时触发成功。
func _process(delta: float) -> void:
	if _match_state != MatchState.SEARCHING:
		return
	_search_elapsed += delta
	var dots := int(_search_elapsed * 2.0) % 4
	_match_card.card_title = "匹配中" + ".".repeat(dots)
	var secs := int(_search_elapsed)
	_match_card.card_subtitle = "%d:%02d" % [floori(secs / 60.0), secs % 60]
	if _search_elapsed >= mock_match_seconds:
		_on_match_found()


## 成功一拍（~0.45s）：对波真撞一次（ModeCard.found_flash：撞闪+涟漪+波速尖峰）
## + 屏幕轻震 → 波幕转场进 BP——卡里的战争打响，与进 BP 叙事连贯。
func _on_match_found() -> void:
	_match_state = MatchState.FOUND
	_match_card.card_title = "对手已找到！"
	_match_card.card_subtitle = ""
	_show_cancel_button(false)
	_match_card.found_flash()
	_shake_screen()
	await get_tree().create_timer(0.45).timeout
	# 波幕转场（BP 重做 2A）：胜方色波卷入 → 切 BP → 波退去揭幕
	TransitionManager.transition_to(BP_SCENE)


## 匹配中两翼牌压暗禁点（防误触离队）；坞条/设置保持可用（占位 toast 无副作用）。
func _set_side_cards_enabled(on: bool) -> void:
	for n in [$UI/ModeStory, $UI/ModeTower]:
		var card := n as Button
		card.disabled = not on
		var tw := create_tween()
		tw.tween_property(card, "modulate",
			Color.WHITE if on else Color(0.55, 0.55, 0.55), 0.25)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 匹配成功轻震屏：±6px 衰减抖 5 下回位（菜单唯一震屏点，幅度克制）。
func _shake_screen() -> void:
	var tw := create_tween()
	for i in 5:
		var amp := 6.0 * (1.0 - i / 5.0)
		tw.tween_property(self, "position",
			Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)


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
	mat.set_shader_parameter("noise_amt", 0.08)   # 纸纤维
	mat.set_shader_parameter("wear", 0.24)         # 做旧
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


## 程序绘制像素 icon（PixelGlyphs 12×12 白剪影+黑描边·原生 16 含留白 → ×2 显示=32px）。
## 美术期换素材：替换 Icon 节点的 texture 即可，位置不动。
func _add_icon(host: Control, r: Rect2, icon_name: String) -> void:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = PixelGlyphs.icon_texture(icon_name)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = r.position
	icon.size = r.size
	icon.modulate = INK   # 墨色图标（压在羊皮底板/坞页上）
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(icon)


## 给按钮挂 ButtonJuice（hover 缩放 / 按下反馈）→ 手感与战斗/选人界面统一。
## 注：三张牌(ModeCard)自带悬停金框+放大，不挂 ButtonJuice 防双重缩放。
func _attach_juice(btn: Button) -> void:
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
