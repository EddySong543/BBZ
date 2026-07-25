extends Control

## 故事模式选关屏（2026-07-16 家族换装·壳=任务 B 2026-07-12）：四类关卡纵列（主线/个人/
## 群像/休闲·design/worldview.md v0.2）→ 点关卡弹简介浮层（静态图+文字·全占位）→「开战」
## 经 BattleSetup 交接进 battle_screen，胜负经 BattleSetup.story_result 写回本屏
## （远征 pve_result 同款管道）。
## 视觉=图鉴家族模板（宣纸山水衬底+墨云带+整屏手卷+牌匾贴形投影+返回导航皮·配方与
## profile_screen/hero_gallery 同源）；四章两页·卷缝落在栏间隙；简介浮层=深框奶油纸
## 大板（ui_tooltip 9-slice·BP 牌池同皮）+牌匾骑缝标题+暖黑画窗。
## UI 只读进度对象与关卡表，不持有战斗状态；关卡内容全数据驱动（levels.json）。

const MENU_SCENE := "res://src/ui/main_menu.tscn"
const BATTLE_SCENE := "res://src/ui/battle_screen1.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes/"
const StoryCatalog := preload("res://src/story/story_catalog.gd")
const StoryProgress := preload("res://src/story/story_progress.gd")
const RESULT_PANEL_SCRIPT := preload("res://src/ui/components/story_result_panel.gd")   # 结算浮层骨架（2026-07-17）

# ── 家族资产（图鉴/资料/设置同源）──
const PLAQUE_TEX := preload("res://assets/ui/ui_plaque.png")
const SCROLL_TEX := preload("res://assets/ui/item_codex_scroll.png")
const BACKDROP_TEX := preload("res://assets/ui/item_codex_backdrop.png")
const PANEL_TEX := preload("res://assets/ui/ui_tooltip.png")            # 简介大板（BP 牌池同皮）
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")
const INK_CLOUDS_SHADER := preload("res://assets/shaders/canvas_ui_ink_clouds.gdshader")
const NAV_PLATE_MARGIN_X := 22   # v14（全挂点同值）
const NAV_PLATE_MARGIN_Y := 20
const PANEL_MARGIN := 20         # ui_tooltip 角钩区（battle _tip_panel 同值）

# ── 家族令牌（墨字系·图鉴同值）──
const INK := Color(0.24, 0.19, 0.12)
const INK_DIM := Color(0.48, 0.41, 0.28)
const INK_GOLD := Color("8f6a1e")               # 泥金墨（通关关卡·TIER_INK 传说档同源）
const INK_CRIMSON := Color(0.54, 0.17, 0.12)    # 朱墨（开战 CTA·BP 信息板同语）
const SHADOW_TINT := Color(0.10, 0.07, 0.05, 0.38)
const BANNER := Rect2(806, 46, 308, 78)          # 悬挂牌匾（家族同位）
const FOCUS_WARM := Color(1.18, 1.10, 0.98)      # 键盘焦点=框身轻暖提亮（图鉴选中同值）

# （旧回程通告色 COL_CLEARED/COL_INFO 已随 toast 退役——结算浮层色板在组件内）

# ── 简介浮层几何 ──
const INTRO_W := 940.0
const INTRO_IMG := Vector2(884.0, 300.0)

var _levels: Array = []
var _progress := StoryProgress.new()
var progress_path := StoryProgress.SAVE_PATH   # 探针可在入树前改为隔离路径；正式运行保持默认。
var _intro_layer: Control = null   # 简介浮层（开着时非空·ui_cancel 可关）
var _book_layer: Control = null    # 卷轴实体（入场上浮层）
var _result_panel: Control = null  # 结算浮层骨架（懒建复用·2026-07-17）
var _result_level: Dictionary = {} # 结算对应关卡（再战钮重开用）

@onready var _categories: HBoxContainer = $Categories


func _ready() -> void:
	_build_book()
	_setup_top()
	_progress.load_from_disk(progress_path)
	_levels = StoryCatalog.load_levels()
	_consume_battle_result()
	_build_columns()
	_play_intro()


## ESC/手柄取消：开着简介浮层=关浮层；否则返回大厅。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _intro_layer != null:
			_close_intro()
		else:
			TransitionManager.transition_to(MENU_SCENE)
		get_viewport().set_input_as_handled()


# ============================================================
# 卷轴实体（图鉴家族同配方：衬底 + 墨云带 + 整屏手卷）
# ============================================================

func _build_book() -> void:
	# 衬底=宣纸淡墨山水（独立静态层·不进 _book_layer——入场上浮不带背景飞）。
	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = BACKDROP_TEX
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 软笔触画面非像素资产
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1920.0, 1080.0)   # ⚠ 锚点满铺在程序容器下会塌 0，必须显式尺寸
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 1)   # Background 之上（不透明满屏整层盖住）
	# 像素墨云带（上下环绕·两条横带 quad ⛔全屏 shader·种子互异）
	_add_ink_cloud_band(Rect2(0, 0, 1920, 150), 0.37, 0.0, 0.03, 2)
	_add_ink_cloud_band(Rect2(0, 930, 1920, 150), 0.63, 5.0, -0.025, 3)

	_book_layer = Control.new()
	_book_layer.name = "BookLayer"
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book_layer)
	move_child(_book_layer, 4)

	var scroll := TextureRect.new()
	scroll.name = "Scroll"
	scroll.texture = SCROLL_TEX
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode = TextureRect.STRETCH_SCALE
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(1920.0, 1080.0)   # ⚠ _book_layer 零尺寸 Control——必须显式尺寸
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_layer.add_child(scroll)


## 像素墨云横带（图鉴同参：center_frac=垂直中心·seed 上下互异·flow=流速）。
func _add_ink_cloud_band(r: Rect2, center_frac: float, seed_v: float, flow: float, tree_idx: int) -> void:
	var band := ColorRect.new()
	band.name = "InkCloudsTop" if r.position.y < 540.0 else "InkCloudsBottom"
	band.color = Color.WHITE
	band.position = r.position
	band.size = r.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = INK_CLOUDS_SHADER
	m.set_shader_parameter("center_frac", center_frac)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("flow_speed", flow)
	band.material = m
	add_child(band)
	move_child(band, tree_idx)


# ============================================================
# 顶部浮动件：悬挂牌匾（贴形投影）+ 返回钮（导航皮）
# ============================================================

func _setup_top() -> void:
	var band := $TopBand as Control
	var shadow := _plaque_rect()
	shadow.name = "PlaqueShadow"
	shadow.position = BANNER.position + Vector2(6, 8)
	shadow.size = BANNER.size
	shadow.modulate = SHADOW_TINT
	band.add_child(shadow)
	var plaque := _plaque_rect()
	plaque.name = "Plaque"
	plaque.position = BANNER.position
	plaque.size = BANNER.size
	band.add_child(plaque)
	var title := $TopBand/Title as Label
	title.text = tr("故事")
	title.position = BANNER.position + Vector2(0, -4)   # Ark 无下伸部·居中偏下补正
	title.size = BANNER.size
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.z_index = 1
	FontManager.apply(title, 36)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)

	var back := $TopBand/BackButton as Button
	FontManager.apply_btn(back, 24)
	_set_btn_ink(back, INK)
	_apply_nav_plate(back)
	back.pressed.connect(func() -> void: TransitionManager.transition_to(MENU_SCENE))


## 墨字钮四态同色（apply_btn 默认 hover/focus 浅字在纸面上洗白·必须全覆盖）。
func _set_btn_ink(btn: Button, col: Color) -> void:
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(state, col)


func _plaque_rect() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = PLAQUE_TEX
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.patch_margin_left = 26   # 牌匾二版（265×63）角钩区实量（图鉴同值）
	p.patch_margin_right = 26
	p.patch_margin_top = 23
	p.patch_margin_bottom = 23
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 导航钮皮（9-slice·全游戏导航一语言）——返回钮 / 关卡钮 / 浮层双钮共用。
## locked=true 时压暗钮身、不挂 juice（禁用态仍要可读·字色另由 font_disabled_color 管）。
func _apply_nav_plate(btn: Button, locked: bool = false) -> void:
	for s: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var plate := NinePatchRect.new()
	plate.name = "Plate"
	plate.texture = NAV_PLATE_TEX
	plate.patch_margin_left = NAV_PLATE_MARGIN_X
	plate.patch_margin_right = NAV_PLATE_MARGIN_X
	plate.patch_margin_top = NAV_PLATE_MARGIN_Y
	plate.patch_margin_bottom = NAV_PLATE_MARGIN_Y
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.show_behind_parent = true
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击
	btn.add_child(plate)
	if locked:
		plate.self_modulate = Color(0.80, 0.77, 0.72)
		return
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
	# 键盘/手柄焦点可见：框身轻暖提亮（图鉴选中同值·hover 缩放归 juice 管）
	btn.focus_entered.connect(func() -> void: plate.self_modulate = FOCUS_WARM)
	btn.focus_exited.connect(func() -> void: plate.self_modulate = Color.WHITE)


# ============================================================
# 回程结算 + 四章纵列
# ============================================================

## 回程结算：battle_screen 写的 story_result 消费后自清（远征同款）。胜=记通关+存档。
## 提示升级（2026-07-17 打地基批·任务10 子项）：顶部 toast 退役 → 结算浮层骨架
## （story_result_panel·胜=继续/负=再战·奖励占位口）。deferred 弹=等 _build_columns 完成。
func _consume_battle_result() -> void:
	var r: Dictionary = BattleSetup.story_result
	if r.is_empty():
		return
	BattleSetup.story_result = {}
	var lv: Dictionary = StoryCatalog.find_level(_levels, String(r.get("level_id", "")))
	if lv.is_empty():
		return
	var outcome: String = String(r.get("outcome", ""))
	if outcome == "win":
		_progress.mark_cleared(String(lv["id"]))
		_progress.save_to_disk(progress_path)
	_show_result_panel.call_deferred(lv, outcome)


## 弹结算浮层（懒建单例·浮层常驻复用）。继续=关浮层重建列表恢复焦点；再战=直接重开该关。
func _show_result_panel(lv: Dictionary, outcome: String) -> void:
	if _result_panel == null:
		_result_panel = RESULT_PANEL_SCRIPT.new()
		_result_panel.name = "StoryResultPanel"
		add_child(_result_panel)
		_result_panel.continue_pressed.connect(func() -> void:
			_result_panel.close()
			_build_columns())   # 重建=恢复列表焦点（键盘/手柄可达）
		_result_panel.retry_pressed.connect(func() -> void:
			_result_panel.close()
			_start_battle(_result_level))
	_result_level = lv
	_result_panel.show_result(String(lv.get("title", "")), outcome, lv.get("rewards", []))


## 四类纵列：章头墨字+通关计数+细墨线 + 关卡钮（✓=已通关泥金·【锁】=前置未通关禁用）。
func _build_columns() -> void:
	for child in _categories.get_children():
		child.queue_free()
	var cols: Dictionary = StoryCatalog.by_category(_levels)
	var first_btn: Button = null
	for cat in StoryCatalog.CATEGORIES:
		var col := VBoxContainer.new()
		col.name = "Col_" + cat
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 16)
		var head := Label.new()
		head.text = tr(String(StoryCatalog.CATEGORY_NAMES[cat]))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_color_override("font_color", INK)
		FontManager.apply(head, 26)
		col.add_child(head)
		var done := 0
		for lv in cols[cat]:
			if _progress.is_cleared(String(lv["id"])):
				done += 1
		var counter := Label.new()
		counter.text = "%d / %d" % [done, (cols[cat] as Array).size()]
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.add_theme_color_override("font_color", INK_DIM)
		FontManager.apply(counter, 16)
		col.add_child(counter)
		var rule := ColorRect.new()
		rule.color = Color(INK, 0.30)
		rule.custom_minimum_size = Vector2(0, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(rule)
		for lv in cols[cat]:
			var btn := _make_level_button(lv)
			col.add_child(btn)
			if first_btn == null and not btn.disabled:
				first_btn = btn
		_categories.add_child(col)
	if first_btn != null:
		first_btn.grab_focus()   # 键盘/手柄可达


func _make_level_button(lv: Dictionary) -> Button:
	var btn := Button.new()
	var id: String = String(lv["id"])
	var unlocked := _progress.is_unlocked(lv)
	var cleared := _progress.is_cleared(id)
	var text: String = tr(String(lv.get("title", id)))
	if cleared:
		text += " ✓"
	elif not unlocked:
		text = tr("【锁】") + text
	btn.text = text
	btn.name = "Level_" + id
	btn.disabled = not unlocked
	btn.custom_minimum_size = Vector2(0, 64)
	btn.clip_text = true   # 占位期长标题防溢出（正式标题四字+英雄名·见 story-mode 内容期约定）
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FontManager.apply_btn(btn, 24)
	_set_btn_ink(btn, INK_GOLD if cleared else INK)
	btn.add_theme_color_override("font_disabled_color", Color(INK, 0.45))   # 锁定仍要可读（BP 教训）
	_apply_nav_plate(btn, not unlocked)
	btn.pressed.connect(_open_intro.bind(lv))
	return btn


# ============================================================
# 简介浮层：暗幕 + 奶油纸大板（贴形投影）+ 牌匾骑缝标题 + 暖黑画窗 + 墨字正文
# ============================================================

## 动画=0.14s 收拢 pop（家族标准·短促=天然可跳过）。
func _open_intro(lv: Dictionary) -> void:
	if _intro_layer != null:
		return
	_intro_layer = Control.new()
	_intro_layer.name = "IntroLayer"
	_intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "IntroPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # 中心锚+双向生长=内容撑开仍居中
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(INTRO_W, 0)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 9-slice 纸面必须 NEAREST
	var sb := StyleBoxTexture.new()
	sb.texture = PANEL_TEX
	for side: String in ["left", "right", "top", "bottom"]:
		sb.set("texture_margin_" + side, PANEL_MARGIN)
		sb.set("content_margin_" + side, 34.0 if side in ["left", "right"] else 40.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE   # 中段平铺防颗粒拉伸
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	panel.add_theme_stylebox_override("panel", sb)
	_intro_layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	# 静态图区：有图贴图·无图=暖黑画窗（壳期全部无图）
	var img_path: String = String(lv.get("intro_image", ""))
	if not img_path.is_empty() and ResourceLoader.exists(img_path):
		var tex := TextureRect.new()
		tex.texture = load(img_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = INTRO_IMG
		box.add_child(tex)
	else:
		box.add_child(_make_image_window())

	var body := Label.new()
	var intro_tr: PackedStringArray = []
	for ln in (lv.get("intro_lines", []) as Array):
		intro_tr.append(tr(String(ln)))
	body.text = "\n".join(intro_tr)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 定宽+高度自适应（VBox 撑开·非固定高容器）
	body.custom_minimum_size = Vector2(INTRO_IMG.x, 0)
	FontManager.apply(body, 24)
	body.add_theme_color_override("font_color", INK)
	box.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	var fight := Button.new()
	fight.name = "FightButton"
	fight.text = tr("开 战")
	fight.custom_minimum_size = Vector2(240, 64)
	FontManager.apply_btn(fight, 24)
	_set_btn_ink(fight, INK_CRIMSON)   # 朱墨 CTA
	_apply_nav_plate(fight)
	fight.pressed.connect(_start_battle.bind(lv))
	row.add_child(fight)
	var back := Button.new()
	back.text = tr("返 回")
	back.custom_minimum_size = Vector2(240, 64)
	FontManager.apply_btn(back, 24)
	_set_btn_ink(back, INK)
	_apply_nav_plate(back)
	back.pressed.connect(_close_intro)
	row.add_child(back)
	box.add_child(row)

	add_child(_intro_layer)
	fight.grab_focus()
	_dress_intro_panel(panel, lv)


## 布局落定后补挂贴形投影+骑缝牌匾（PanelContainer 自撑高·投影/牌匾只能事后按实寸摆）。
func _dress_intro_panel(panel: PanelContainer, lv: Dictionary) -> void:
	var layer := _intro_layer
	await get_tree().process_frame
	if _intro_layer != layer or not is_instance_valid(panel):
		return   # 等待期间浮层已被关掉
	var shadow := NinePatchRect.new()
	shadow.name = "PanelShadow"
	shadow.texture = PANEL_TEX
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for side: String in ["left", "right", "top", "bottom"]:
		shadow.set("patch_margin_" + side, PANEL_MARGIN)
	shadow.position = panel.position + Vector2(6, 8)
	shadow.size = panel.size
	shadow.modulate = SHADOW_TINT
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(shadow)
	_intro_layer.move_child(shadow, 1)   # 暗幕之上·面板之下

	var plaque_size := Vector2(280, 70)
	var plaque_pos := Vector2(panel.position.x + (panel.size.x - plaque_size.x) * 0.5,
			panel.position.y - plaque_size.y * 0.5)
	var pshadow := _plaque_rect()
	pshadow.position = plaque_pos + Vector2(5, 7)
	pshadow.size = plaque_size
	pshadow.modulate = SHADOW_TINT
	_intro_layer.add_child(pshadow)
	var plaque := _plaque_rect()
	plaque.name = "IntroPlaque"
	plaque.position = plaque_pos
	plaque.size = plaque_size
	_intro_layer.add_child(plaque)
	var title := Label.new()
	title.text = tr(String(lv.get("title", "")))
	title.position = plaque_pos + Vector2(0, -3)
	title.size = plaque_size
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontManager.apply(title, 24)
	title.add_theme_color_override("font_color", INK)
	_intro_layer.add_child(title)

	# 收拢 pop（0.14s·家族标准）：面板+牌匾绕面板中心同拍缩入，暗幕单独淡入
	_dim_fade(_intro_layer.get_child(0) as ColorRect)
	var center := panel.position + panel.size * 0.5
	for n: Control in [shadow, panel, pshadow, plaque, title]:
		n.pivot_offset = center - n.position
		n.scale = Vector2(1.06, 1.06)
		var tw := create_tween()
		tw.tween_property(n, "scale", Vector2.ONE, 0.14)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _dim_fade(dim: ColorRect) -> void:
	var target := dim.color.a
	dim.color.a = 0.0
	create_tween().tween_property(dim, "color:a", target, 0.15)


## 暖黑画窗（静态图占位）：深暖底+细咖啡框线——⛔冷灰黑（衬底禁夜色同理）。
func _make_image_window() -> Control:
	var win := Control.new()
	win.custom_minimum_size = INTRO_IMG
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.11, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(bg)
	for edge: Rect2 in [Rect2(0, 0, INTRO_IMG.x, 2), Rect2(0, INTRO_IMG.y - 2, INTRO_IMG.x, 2),
			Rect2(0, 0, 2, INTRO_IMG.y), Rect2(INTRO_IMG.x - 2, 0, 2, INTRO_IMG.y)]:
		var line := ColorRect.new()
		line.color = Color(0.31, 0.18, 0.10)   # 深咖框线（内线族色）
		line.position = edge.position
		line.size = edge.size
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		win.add_child(line)
	var ph_lbl := Label.new()
	ph_lbl.text = tr("【占位】静态图待美术")
	ph_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph_lbl.add_theme_color_override("font_color", Color(0.62, 0.58, 0.52))
	ph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontManager.apply(ph_lbl, 16)
	win.add_child(ph_lbl)
	return win


func _close_intro() -> void:
	if _intro_layer != null:
		_intro_layer.queue_free()
		_intro_layer = null
		_build_columns()   # 重建以恢复焦点


func _start_battle(lv: Dictionary) -> void:
	_prepare_battle_setup(lv)
	TransitionManager.transition_to(BATTLE_SCENE)


## 交接态装填（探针单测此步·不含转场）：阵容从关卡数据加载·挂故事旗标。
func _prepare_battle_setup(lv: Dictionary) -> void:
	BattleSetup.reset()
	BattleSetup.p1_heroes = _load_team(lv.get("player_team", []))
	BattleSetup.p2_heroes = _load_team(lv.get("enemy_team", []))
	BattleSetup.story_mode = true
	BattleSetup.story_level_id = String(lv["id"])


func _load_team(ids: Array) -> Array[HeroData]:
	var t: Array[HeroData] = []
	for id in ids:
		var path: String = HERO_DATA_DIR + String(id) + ".tres"
		if ResourceLoader.exists(path):
			t.append(load(path) as HeroData)
		else:
			push_warning("StoryScreen: 缺英雄资源 %s" % path)
	return t


## 入场：牌匾/返回滑入 + 卷轴轻微上浮 + 栏目淡入（图鉴家族同手感）。
func _play_intro() -> void:
	var band := $TopBand as Control
	var band_home := band.position
	band.position.y -= 130.0
	create_tween().tween_property(band, "position", band_home, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_book_layer.position.y += 26.0
	_book_layer.modulate.a = 0.0
	var tb := create_tween()
	tb.set_parallel(true)
	tb.tween_property(_book_layer, "position:y", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tb.tween_property(_book_layer, "modulate:a", 1.0, 0.25)
	_categories.modulate.a = 0.0
	var ta := create_tween()
	ta.tween_interval(0.2)
	ta.tween_property(_categories, "modulate:a", 1.0, 0.35)


# （旧顶部 toast 已随结算浮层骨架退役——2026-07-17 打地基批·见 _show_result_panel）
