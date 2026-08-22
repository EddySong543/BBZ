extends Control

## 主菜单 = 晴风驿站功能大厅。远征地表与英雄只承担世界呈现；所有入口仍可直接点击。
## WASD 或左键点格可让角色在纯展示地图中逐格行走；入口按钮仍是主操作，不创建远征背包或结算状态。

const BP_SCENE := "res://src/ui/bp_screen.tscn"
const PROFILE_SCENE := "res://src/ui/profile_screen.tscn"
const BACKPACK_OVERLAY_SCENE := preload("res://src/ui/backpack_screen.tscn")
const ProfileStore := preload("res://src/core/player_profile.gd")   # 个人资料存档（headless 安全走 preload）

# ---- 匹配状态机：IDLE 点入口=开始；SEARCHING 再点/ESC/取消钮=取消；FOUND 锁输入。----
# 本地用 mock_match_seconds 定时模拟匹配成功；联机时把定时器换成真匹配回调，状态机原样复用。
enum MatchState { IDLE, SEARCHING, FOUND }

## 本地测试模拟匹配时长（秒）。联机接入后弃用。
@export var mock_match_seconds: float = 3.0

var _match_state: int = MatchState.IDLE
var _search_elapsed: float = 0.0
var _last_secs: int = -1     # 匹配中 tooltip 计时秒数（变化时才更新）
var _cancel_btn: Button   # 匹配中才出现的「✕ 取消匹配」（_setup_modes 建·常态隐藏）

## 小件像素底板（设置/退出/底坞导航/段位徽章用）。
## 2026-06-13 Eddy 选 B「典籍朱印」全局铺；2026-07-13 换 GPT 导航钮贴图
## （米金纸面+角上回纹折·9-slice 中段平铺·jelly 程序板/STEEL 色组退役）。
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")   # 235×55·v14 净面版（2026-07-16 Eddy 定内饰多余·img_inner_clear 去回纹钩+内线·只留深咖外框+净纸面）
const CODEX_ICON_TEX := preload("res://assets/ui/icons/codex_book.png")
const BACKPACK_ICON_TEX := preload("res://assets/ui/icons/backpack.png")
const CODEX_JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const UI_BOTTOM_SHADOW_OFFSET := Vector2(3.0, 6.0)
const UI_BOTTOM_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.52)
const PIXEL_FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")   # 身份带悬停金晕外环
const NAV_PLATE_MARGIN_X := 22.0   # 9-slice 边距（v14 净面后内里全纸·任意≥框厚均可·沿用实钩期数值）
const NAV_PLATE_MARGIN_Y := 20.0
const INK := Color(0.20, 0.14, 0.08)        # 墨（羊皮上的字/图标）
const CREAM := Color(0.95, 0.91, 0.80)      # 暖米白（直接压在暗波上的字·非羊皮上）

@onready var _match_entry: Button = $UI/ModeMatch
@onready var _menu_world: MainMenuWorld = $MenuWorld

var _backpack_overlay: BackpackScreen


func _ready() -> void:
	_build_vignette()
	_setup_identity()
	_setup_settings()
	_setup_modes()
	_setup_dock()
	_setup_backpack_overlay()
	# 设置面板仍通过既有广播刷新主界面颜色，世界组件只重绘视觉层。
	add_to_group("wave_flow_bg")
	_play_intro()


## 设置面板翻转界面主色时由既有广播触发。
func refresh_colors() -> void:
	_menu_world.refresh_colors()


# ============================================================
# 各区初始化
# ============================================================

## 世界边缘暗角：只压边界，让入口牌与角色保持可读。
func _build_vignette() -> void:
	var vig := TextureRect.new()
	vig.name = "Vignette"
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.02, 0.03, 0.06, 0.0),   # 中央透明（不压主战卡）
		Color(0.02, 0.03, 0.06, 0.0),
		Color(0.02, 0.03, 0.06, 0.5),   # 四周暗navy（聚光衬底·调 alpha 改浓度）
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	vig.texture = tex
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 平滑暗角（非像素硬边）
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	move_child(vig, 1)   # MenuWorld(0) < Vignette(1) < UI(2)


## 顶左身份带：新版 item_frame 头像+名字+段位占位，整体=资料入口。
## 可点性三重反馈（Eddy 反馈"分不清能不能点"）：整带 ButtonJuice（悬停轻放大+手型金晕指针）
## + 悬停头像金晕外环（全游戏点选同语言·暗波底=淡金档）。
func _setup_identity() -> void:
	var btn: Button = $UI/IdentityButton
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var avatar := $UI/IdentityButton/AvatarFrame as ItemAvatarFrame
	avatar.portrait_path = ProfileStore.avatar_portrait_path()   # 资料存档选的头像英雄（缺图回落 h01）
	# ItemAvatarFrame 默认独立接收输入；身份带由父 Button 统一响应，故显式放行。
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl: Label = $UI/IdentityButton/NameLabel
	FontManager.apply(name_lbl, 26)
	name_lbl.add_theme_color_override("font_color", CREAM)   # 直接压暗波上→暖米白
	name_lbl.text = ProfileStore.get_player_name()
	# 悬停金晕外环：衬在头像框外圈（暗波底=淡金 fff0a0·图鉴亮纸才用深金 dca12e）
	var ring := ColorRect.new()
	ring.name = "HoverRing"
	ring.color = Color.WHITE
	ring.position = avatar.position - Vector2(5, 5)
	ring.size = avatar.frame_size + Vector2(10, 10)
	var rm := ShaderMaterial.new()
	rm.shader = PIXEL_FRAME_SHADER
	var gold := Color("fff0a0")
	rm.set_shader_parameter("edge_outer", gold.darkened(0.1))   # 外露带整条是金（深咖会读成黑圈）
	rm.set_shader_parameter("edge_mid", gold)
	rm.set_shader_parameter("edge_inner", gold.darkened(0.5))
	rm.set_shader_parameter("pixel_grid", (avatar.frame_size.x + 10.0) / 6.0)
	rm.set_shader_parameter("border_px", 2.0)
	rm.set_shader_parameter("noise_amt", 0.05)
	rm.set_shader_parameter("light_amount", 0.18)
	rm.set_shader_parameter("aspect", 1.0)
	rm.set_shader_parameter("corner_radius", 0.18)
	ring.material = rm
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	btn.add_child(ring)
	btn.move_child(ring, 0)   # 环衬在头像框之后（只露外扩带）
	btn.mouse_entered.connect(func() -> void: ring.visible = true)
	btn.mouse_exited.connect(func() -> void: ring.visible = false)
	_attach_juice(btn)   # 悬停轻放大+按压反馈+手型金晕指针（导航钮同手感）
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
	btn.pressed.connect(_on_profile_pressed)


## 个人资料入口：波幕转场（menu↔profile 同图鉴语言）。匹配中不离队。
func _on_profile_pressed() -> void:
	if _match_state != MatchState.IDLE:
		return
	TransitionManager.transition_to(PROFILE_SCENE)


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


## 匹配与远征改为底部直接入口，不再与展示地图的目标格绑定。
func _setup_modes() -> void:
	($UI/ModeMatch as Button).pressed.connect(_on_match_pressed)
	($UI/ModeTower as Button).pressed.connect(_on_expedition_pressed)
	_build_cancel_button()
	_build_net_button()
	_match_entry.grab_focus()


## M1：局域网对战入口（右下低调工具钮，不与三个世界入口抢层级）。
func _build_net_button() -> void:
	var b := Button.new()
	b.name = "NetLobbyButton"
	b.text = tr("联机对战·局域网")
	b.position = Vector2(1660, 980)
	b.size = Vector2(220, 52)
	b.modulate = Color(1, 1, 1, 0.75)
	FontManager.apply_btn(b, 16)
	b.pressed.connect(func() -> void:
		if _match_state == MatchState.IDLE:
			TransitionManager.transition_to("res://src/ui/net_lobby_screen.tscn"))
	$UI.add_child(b)


## 远征模式入口：波幕转场（先行版·占位战斗）。匹配中不离队。
func _on_expedition_pressed() -> void:
	if _match_state != MatchState.IDLE:
		return
	_set_mode_entries_enabled(false)
	_menu_world.set_portal_energy(MainMenuWorld.PORTAL_ENERGY_GOLD)
	await get_tree().create_timer(MainMenuWorld.PORTAL_ACTIVATION_DURATION).timeout
	if not is_instance_valid(self):
		return
	TransitionManager.transition_to("res://src/expedition/expedition_screen.tscn")


## 「✕ 取消匹配」独立小钮（匹配中才出现·匹配入口正下方居中）。
## 不再挤在副标小字里（2026-06-12 Eddy："取消匹配感觉不明显"根修）。
func _build_cancel_button() -> void:
	var card := $UI/ModeMatch as Control
	_cancel_btn = Button.new()
	_cancel_btn.name = "CancelMatchButton"
	_cancel_btn.text = tr("✕ 取消匹配")
	var btn_size := Vector2(220, 52)
	_cancel_btn.position = Vector2(
		card.position.x + (card.size.x - btn_size.x) * 0.5,
		card.position.y - 68.0)
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
	var home_y: float = ($UI/ModeMatch as Control).position.y - 68.0
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


## 底部四入口：匹配、远征、图鉴、背包共用战斗图鉴方钮语言，点击即执行。
func _setup_dock() -> void:
	_setup_square_dock_button(
		$UI/ModeMatch as Button, PixelGlyphs.icon_texture("duel"), "匹配", true)
	_setup_square_dock_button(
		$UI/ModeTower as Button, PixelGlyphs.icon_texture("flag"), "远征", true)
	_setup_square_dock_button(
		$UI/NavHeroes as Button, CODEX_ICON_TEX, "图鉴", false)
	_setup_square_dock_button(
		$UI/NavBackpack as Button, BACKPACK_ICON_TEX, "背包", false)
	($UI/NavHeroes as Button).pressed.connect(_on_codex_pressed)
	($UI/NavBackpack as Button).pressed.connect(_on_backpack_pressed)


func _setup_backpack_overlay() -> void:
	_backpack_overlay = BACKPACK_OVERLAY_SCENE.instantiate() as BackpackScreen
	_backpack_overlay.name = "BackpackOverlay"
	add_child(_backpack_overlay)
	_backpack_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 与战斗 UI 的 BtnCodex 同尺寸、同材质；底部入口只显示居中图标。
func _setup_square_dock_button(
		btn: Button, icon_texture: Texture2D, tooltip: String, tint_icon: bool) -> void:
	btn.text = ""
	btn.clip_text = true
	btn.tooltip_text = tr(tooltip)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = CODEX_JELLY_SHADER
	material.set_shader_parameter("fill_top", Color(0.92, 0.87, 0.70))
	material.set_shader_parameter("fill_bottom", Color(0.76, 0.68, 0.50))
	material.set_shader_parameter("edge_inner", Color(1.0, 0.95, 0.80))
	material.set_shader_parameter("edge_outer", Color(0.1, 0.09, 0.11))
	material.set_shader_parameter("fill_alpha", 1.0)
	material.set_shader_parameter("pixel_grid", 38.0)
	material.set_shader_parameter("corner", 0.22)
	material.set_shader_parameter("edge_px", 2.0)
	material.set_shader_parameter("aspect", 1.0)
	material.set_shader_parameter("noise_amt", 0.08)
	material.set_shader_parameter("wear", 0.24)
	material.set_shader_parameter("solid_rim", true)
	material.set_shader_parameter("rim_px", 1.5)
	bg.material = material
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var icon := TextureRect.new()
	icon.name = "BookIcon" if btn == $UI/NavHeroes else "Icon"
	icon.texture = icon_texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 22.0
	icon.offset_top = 22.0
	icon.offset_right = -22.0
	icon.offset_bottom = -22.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = INK if tint_icon else Color.WHITE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	_attach_juice(btn)
	_attach_bottom_shadow(btn)


func _attach_bottom_shadow(btn: Button) -> void:
	var source_bg := btn.get_node("Bg") as ColorRect
	var shadow := ColorRect.new()
	shadow.name = "BottomShadow"
	shadow.color = Color.WHITE
	var material := (source_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
	var opaque_shadow := Color(
			UI_BOTTOM_SHADOW_COLOR.r,
			UI_BOTTOM_SHADOW_COLOR.g,
			UI_BOTTOM_SHADOW_COLOR.b,
			1.0)
	for parameter: String in ["fill_top", "fill_bottom", "edge_inner", "edge_outer"]:
		material.set_shader_parameter(parameter, opaque_shadow)
	material.set_shader_parameter("fill_alpha", 1.0)
	material.set_shader_parameter("noise_amt", 0.0)
	material.set_shader_parameter("wear", 0.0)
	shadow.material = material
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = UI_BOTTOM_SHADOW_OFFSET.x
	shadow.offset_top = UI_BOTTOM_SHADOW_OFFSET.y
	shadow.offset_right = UI_BOTTOM_SHADOW_OFFSET.x
	shadow.offset_bottom = UI_BOTTOM_SHADOW_OFFSET.y
	shadow.self_modulate = Color(1.0, 1.0, 1.0, UI_BOTTOM_SHADOW_COLOR.a)
	btn.add_child(shadow)
	btn.move_child(shadow, 0)


## 统一图鉴入口：波幕转场；匹配中不离队。
func _on_codex_pressed() -> void:
	if _match_state != MatchState.IDLE:
		return
	TransitionManager.transition_to("res://src/ui/codex_screen.tscn")


func _on_backpack_pressed() -> void:
	if _match_state != MatchState.IDLE:
		return
	_backpack_overlay.open()


# ============================================================
# 入场 / 转场
# ============================================================

## 入场：世界先落定，两个入口与边缘功能随后浮入。
func _play_intro() -> void:
	# Boot 转场余势只作用于世界，不改变地图构图。
	pivot_offset = size * 0.5
	scale = Vector2(1.045, 1.045)
	var tz := create_tween()
	tz.tween_property(self, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animate_in()


## 入口入场：远征主入口先出现，其余入口与边缘件跟进。
func _animate_in() -> void:
	var order: Array = [
		$UI/ModeTower, $UI/ModeMatch,
		$UI/IdentityButton, $UI/QuitButton, $UI/SettingsButton,
		$UI/NavHeroes, $UI/NavBackpack,
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
			_begin_match_entry()
		MatchState.SEARCHING:
			_cancel_search()   # 点卡仍可取消（取消钮是主把手，这是顺手路径）
		MatchState.FOUND:
			pass


func _begin_match_entry() -> void:
	_start_search()


## ESC 取消匹配（与取消钮/再点入口等价）。
func _unhandled_input(event: InputEvent) -> void:
	if _match_state == MatchState.SEARCHING and event.is_action_pressed("ui_cancel"):
		_cancel_search()


# ============================================================
# 匹配状态机：临战升温（对波加速备战）+正计时 → 对撞一拍 → 波幕转场
# ============================================================

func _start_search() -> void:
	_match_state = MatchState.SEARCHING
	_search_elapsed = 0.0
	_last_secs = -1
	_set_mode_entries_enabled(true)
	_set_side_cards_enabled(false)
	_set_match_button_emphasized(true)
	_set_match_button_status("匹配中", "0:00")
	_menu_world.set_portal_energy(MainMenuWorld.PORTAL_ENERGY_BLUE)
	_show_cancel_button(true)


func _cancel_search() -> void:
	_match_state = MatchState.IDLE
	_set_match_button_emphasized(false)
	_set_match_button_status("匹配", "")
	_menu_world.reset_portal_energy()
	_show_cancel_button(false)
	_set_side_cards_enabled(true)
	_menu_world.reset_home()


## 匹配中每帧只维护状态计时；底栏保持纯图标，计时写入悬停提示。
func _process(delta: float) -> void:
	if _match_state != MatchState.SEARCHING:
		return
	_search_elapsed += delta
	var secs := int(_search_elapsed)
	if secs != _last_secs:
		_last_secs = secs
		_set_match_button_status("匹配中",
				"%d:%02d" % [floori(secs / 60.0), secs % 60])
	if _search_elapsed >= mock_match_seconds:
		_on_match_found()


## 匹配成功：地图入口闪亮、屏幕轻震后进入备战。
func _on_match_found() -> void:
	_match_state = MatchState.FOUND
	_set_match_button_status("已找到", "")
	_show_cancel_button(false)
	_flash_dock_button(_match_entry)
	_shake_screen()
	await get_tree().create_timer(0.45).timeout
	# 波幕转场（BP 重做 2A）：胜方色波卷入 → 切 BP → 波退去揭幕
	TransitionManager.transition_to(BP_SCENE)


## 匹配中远征入口压暗禁点；底栏与设置保持可用。
func _set_side_cards_enabled(on: bool) -> void:
	for n in [$UI/ModeTower]:
		var card := n as Button
		card.disabled = not on
		var tw := create_tween()
		tw.tween_property(card, "modulate",
			Color.WHITE if on else Color(0.55, 0.55, 0.55), 0.25)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_mode_entries_enabled(on: bool) -> void:
	for entry: Button in [
		$UI/ModeMatch as Button,
		$UI/ModeTower as Button,
	]:
		entry.disabled = not on


func _set_match_button_status(title: String, timer_text: String) -> void:
	_match_entry.tooltip_text = tr(title) if timer_text.is_empty() \
			else "%s %s" % [tr(title), timer_text]


func _set_match_button_emphasized(on: bool) -> void:
	var bg := _match_entry.get_node_or_null("Bg") as ColorRect
	if bg != null:
		bg.self_modulate = Color("FFD4B8") if on else Color.WHITE


func _flash_dock_button(button: Button) -> void:
	var tween := create_tween().bind_node(button)
	tween.tween_property(button, "modulate", Color(1.0, 0.82, 0.58), 0.08)
	tween.tween_property(button, "modulate", Color.WHITE, 0.14)


## 匹配成功轻震屏：±6px 衰减抖 5 下回位（菜单唯一震屏点，幅度克制）。
func _shake_screen() -> void:
	var tw := create_tween()
	for i in 5:
		var amp := 6.0 * (1.0 - i / 5.0)
		tw.tween_property(self, "position",
			Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)


# ============================================================
# 小件样式辅助
# ============================================================

## 给按钮挂导航钮贴图底板（GPT 回纹折纸面·2026-07-13 换皮）：清空默认 stylebox + Bg NinePatch 衬底。
func _apply_plate(btn: Button) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	btn.add_child(_make_plate_bg())


## 给任意 Control（如段位 Label）衬导航钮贴图底板。
func _add_plate_bg(ctrl: Control) -> void:
	ctrl.add_child(_make_plate_bg())


## 导航钮底板（NinePatch）：四角回纹折整块保形·中段横竖平铺防颗粒拉伸·像素点采样。
func _make_plate_bg() -> NinePatchRect:
	var bg := NinePatchRect.new()
	bg.name = "Bg"
	bg.texture = NAV_PLATE_TEX
	bg.patch_margin_left = int(NAV_PLATE_MARGIN_X)
	bg.patch_margin_right = int(NAV_PLATE_MARGIN_X)
	bg.patch_margin_top = int(NAV_PLATE_MARGIN_Y)
	bg.patch_margin_bottom = int(NAV_PLATE_MARGIN_Y)
	bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


## 清空按钮默认皮肤，但保留左内边距（给 icon 锚位让位，文字在余下区域居中）。
func _set_btn_left_margin(btn: Button, left: float) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = left
		btn.add_theme_stylebox_override(s, sb)


## 导航 icon。图鉴复用项目既有书本图标，其余仍由 PixelGlyphs 程序绘制。
## 美术期换素材：替换 Icon 节点的 texture 即可，位置不动。
func _add_icon(host: Control, r: Rect2, icon_name: String) -> void:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = CODEX_ICON_TEX if icon_name == "codex" else PixelGlyphs.icon_texture(icon_name)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = r.position
	icon.size = r.size
	icon.modulate = INK   # 墨色图标（压在羊皮底板/坞页上）
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(icon)


## 给按钮挂 ButtonJuice（hover 缩放 / 按下反馈）→ 手感与战斗/选人界面统一。
## 世界入口拥有自己的焦点反馈，不再额外挂 ButtonJuice。
func _attach_juice(btn: Button) -> void:
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
