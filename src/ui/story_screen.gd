extends Control

## 故事模式选关屏（任务 B 壳·2026-07-12）：四类关卡纵列（主线/个人/群像/休闲·
## design/worldview.md v0.2）→ 点关卡弹简介浮层（静态图+文字·全占位）→「开战」经
## BattleSetup 交接进 battle_screen，胜负经 BattleSetup.story_result 写回本屏
## （远征 pve_result 同款管道）。视觉=占位壳（沿用画廊屏顶带/背景）·UI 资产期换皮。
## UI 只读进度对象与关卡表，不持有战斗状态；关卡内容全数据驱动（levels.json）。

const MENU_SCENE := "res://src/ui/main_menu.tscn"
const BATTLE_SCENE := "res://src/ui/battle_screen.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes/"
const StoryCatalog := preload("res://src/story/story_catalog.gd")
const StoryProgress := preload("res://src/story/story_progress.gd")

const COL_HEADER := Color(0.85, 0.78, 0.62)      # 类别标题=暖骨（像素框同族）
const COL_CLEARED := Color(0.62, 0.92, 0.55)     # 通关记号=治疗绿同族
const COL_PLACEHOLDER := Color(0.55, 0.52, 0.48) # 占位说明小字

var _levels: Array = []
var _progress := StoryProgress.new()
var _intro_layer: Control = null   # 简介浮层（开着时非空·ui_cancel 可关）

@onready var _categories: HBoxContainer = $Categories


func _ready() -> void:
	FontManager.apply($TopBand/Title, 36)
	FontManager.apply_btn($TopBand/BackButton, 24)
	($TopBand/BackButton as Button).pressed.connect(
		func() -> void: TransitionManager.transition_to(MENU_SCENE))
	_progress.load_from_disk()
	_levels = StoryCatalog.load_levels()
	_consume_battle_result()
	_build_columns()


## ESC/手柄取消：开着简介浮层=关浮层；否则返回大厅。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _intro_layer != null:
			_close_intro()
		else:
			TransitionManager.transition_to(MENU_SCENE)
		get_viewport().set_input_as_handled()


## 回程结算：battle_screen 写的 story_result 消费后自清（远征同款）。胜=记通关+存档。
func _consume_battle_result() -> void:
	var r: Dictionary = BattleSetup.story_result
	if r.is_empty():
		return
	BattleSetup.story_result = {}
	var lv: Dictionary = StoryCatalog.find_level(_levels, String(r.get("level_id", "")))
	if lv.is_empty():
		return
	var title: String = String(lv.get("title", ""))
	if String(r.get("outcome", "")) == "win":
		_progress.mark_cleared(String(lv["id"]))
		_progress.save_to_disk()
		_toast(tr("「%s」通关！") % tr(title), COL_CLEARED)
	else:
		_toast(tr("「%s」未通关，再试一次") % tr(title), Color(0.87, 0.85, 0.82))


## 四类纵列：类别标题 + 关卡按钮（✓=已通关·【锁】=前置未通关禁用）。
func _build_columns() -> void:
	for child in _categories.get_children():
		child.queue_free()
	var cols: Dictionary = StoryCatalog.by_category(_levels)
	var first_btn: Button = null
	for cat in StoryCatalog.CATEGORIES:
		var col := VBoxContainer.new()
		col.name = "Col_" + cat
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 14)
		var head := Label.new()
		head.text = tr(String(StoryCatalog.CATEGORY_NAMES[cat]))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_color_override("font_color", COL_HEADER)
		FontManager.apply(head, 28)
		col.add_child(head)
		col.add_child(HSeparator.new())
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
	var text: String = tr(String(lv.get("title", id)))
	if _progress.is_cleared(id):
		text += " ✓"
	elif not unlocked:
		text = tr("【锁】") + text
	btn.text = text
	btn.name = "Level_" + id
	btn.disabled = not unlocked
	btn.custom_minimum_size = Vector2(0, 64)
	FontManager.apply_btn(btn, 16)
	btn.pressed.connect(_open_intro.bind(lv))
	return btn


## 简介浮层：压暗底 + 居中面板（标题/静态图占位/文本/开战·返回）。动画零帧=天然可跳过。
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
	panel.custom_minimum_size = Vector2(940, 0)
	_intro_layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = tr(String(lv.get("title", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_HEADER)
	FontManager.apply(title, 28)
	box.add_child(title)

	# 静态图区：有图贴图·无图=占位底（壳期全部无图）
	var img_path: String = String(lv.get("intro_image", ""))
	if not img_path.is_empty() and ResourceLoader.exists(img_path):
		var tex := TextureRect.new()
		tex.texture = load(img_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(884, 300)
		box.add_child(tex)
	else:
		var ph := ColorRect.new()
		ph.color = Color(0.09, 0.08, 0.11)
		ph.custom_minimum_size = Vector2(884, 300)
		var ph_lbl := Label.new()
		ph_lbl.text = tr("【占位】静态图待美术")
		ph_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph_lbl.add_theme_color_override("font_color", COL_PLACEHOLDER)
		FontManager.apply(ph_lbl, 16)
		ph.add_child(ph_lbl)
		box.add_child(ph)

	var body := Label.new()
	var intro_tr: PackedStringArray = []
	for ln in (lv.get("intro_lines", []) as Array):
		intro_tr.append(tr(String(ln)))
	body.text = "\n".join(intro_tr)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 定宽+高度自适应（VBox 撑开·非固定高容器）
	body.custom_minimum_size = Vector2(884, 0)
	FontManager.apply(body, 16)
	box.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	var fight := Button.new()
	fight.name = "FightButton"
	fight.text = tr("开 战")
	fight.custom_minimum_size = Vector2(240, 64)
	FontManager.apply_btn(fight, 20)
	fight.pressed.connect(_start_battle.bind(lv))
	row.add_child(fight)
	var back := Button.new()
	back.text = tr("返 回")
	back.custom_minimum_size = Vector2(240, 64)
	FontManager.apply_btn(back, 20)
	back.pressed.connect(_close_intro)
	row.add_child(back)
	box.add_child(row)

	add_child(_intro_layer)
	fight.grab_focus()


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


## 顶部通告（回程结算提示）：淡入停留淡出。
func _toast(text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.04, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	FontManager.apply(lbl, 24)
	lbl.position = Vector2(0, 128)
	lbl.size = Vector2(1920, 40)
	lbl.modulate.a = 0.0
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)
