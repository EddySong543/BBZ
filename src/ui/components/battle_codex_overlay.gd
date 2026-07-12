extends Control
## 战斗内图鉴浮层（2026-07-13·Eddy 定）：底部「图鉴」钮呼出——英雄/道具图鉴以缩小尺寸内嵌
## （0.86×≈1651×929·占大部分屏幕不占满·四周暗幕衬托）。
## 只读浏览：图鉴屏本身零引擎写入（ui-code 规则）；对局计时照走，不暂停。
## 关闭路径：ESC / 点四周暗幕 / 图鉴自带「返回」钮（经 embedded_close 重定向）/ 再按「图鉴」钮。
## 图鉴场景懒加载：首开各实例化一次后缓存（战斗中途一次性构建卡顿可接受·关闭仅隐藏）。
## ⚠ 隐藏的图鉴必须关掉 unhandled_input——否则其 ESC/方向键处理会漏进战斗层。

const HERO_GALLERY_SCENE := preload("res://src/ui/hero_gallery_screen.tscn")
const ITEM_GALLERY_SCENE := preload("res://src/ui/item_gallery_screen.tscn")

const DESIGN := Vector2(1920.0, 1080.0)   # 图鉴屏设计分辨率（缩放前）
const PANEL_SCALE := 0.86                  # 「大部分屏幕但不占满」
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.62)
const TAB_SIZE := Vector2(200.0, 46.0)
const TAB_GAP := 24.0
const TAB_Y := 16.0

const INK := Color(0.24, 0.19, 0.12)             # 墨字（亮纸底·与主菜单导航钮同语言）
const PAPER := Color(0.90, 0.85, 0.72)           # 选中页签=亮羊皮
const PAPER_DIM := Color(0.62, 0.58, 0.48)       # 未选中页签=压暗羊皮
const TAB_EDGE_SEL := Color("#e8bb52")           # 选中描边=泥金
const TAB_EDGE_OFF := Color(0.22, 0.19, 0.13)    # 未选中描边=深墨

var _holder: Control = null
var _galleries: Array = [null, null]   # 0=英雄图鉴 1=道具图鉴（懒加载缓存）
var _tab_btns: Array = []
var _current_tab: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# 四周暗幕：拦截点击（点暗幕=关闭）。
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# 内容容器：按设计分辨率摆放图鉴场景，整体缩放居中。
	_holder = Control.new()
	_holder.name = "Holder"
	_holder.size = DESIGN
	_holder.scale = Vector2(PANEL_SCALE, PANEL_SCALE)
	_holder.position = (DESIGN - DESIGN * PANEL_SCALE) * 0.5
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)

	# 顶部页签：英雄图鉴 / 道具图鉴（文字引擎渲·i18n 走 tr）。
	var labels: Array = [tr("英雄图鉴"), tr("道具图鉴")]
	var total_w: float = TAB_SIZE.x * labels.size() + TAB_GAP * (labels.size() - 1)
	for i in labels.size():
		var btn := Button.new()
		btn.name = "Tab%d" % i
		btn.text = String(labels[i])
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = Vector2((DESIGN.x - total_w) * 0.5 + i * (TAB_SIZE.x + TAB_GAP), TAB_Y)
		btn.size = TAB_SIZE
		btn.pressed.connect(_show_tab.bind(i))
		var fm := get_node_or_null("/root/FontManager")
		if fm != null:
			fm.apply_btn(btn, 22)
		btn.add_theme_color_override("font_color", INK)
		btn.add_theme_color_override("font_hover_color", Color(0.14, 0.10, 0.06))
		add_child(btn)
		_tab_btns.append(btn)
	_refresh_tabs()


func open() -> void:
	visible = true
	move_to_front()   # 压过战斗 HUD/悬停提示层
	if _current_tab < 0:
		_show_tab(0)
	else:
		_set_gallery_input(_current_tab)


func close() -> void:
	visible = false
	_set_gallery_input(-1)   # 全部图鉴停收输入——防隐藏后 ESC/方向键漏进战斗


func _show_tab(idx: int) -> void:
	if _galleries[idx] == null:
		var scene: PackedScene = HERO_GALLERY_SCENE if idx == 0 else ITEM_GALLERY_SCENE
		var g := scene.instantiate() as Control
		g.set("embedded_close", close)   # 图鉴「返回/ESC」→ 关浮层（不切场景）
		_holder.add_child(g)
		_galleries[idx] = g
	for j in _galleries.size():
		if _galleries[j] != null:
			(_galleries[j] as Control).visible = (j == idx)
	_current_tab = idx
	_set_gallery_input(idx)
	_refresh_tabs()


## 只让当前可见的图鉴收 unhandled_input（-1=全关）。
func _set_gallery_input(active_idx: int) -> void:
	for j in _galleries.size():
		var g: Control = _galleries[j]
		if g != null:
			g.set_process_unhandled_input(visible and j == active_idx)


func _refresh_tabs() -> void:
	for i in _tab_btns.size():
		var btn: Button = _tab_btns[i]
		var sel: bool = (i == _current_tab)
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAPER if sel else PAPER_DIM
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = TAB_EDGE_SEL if sel else TAB_EDGE_OFF
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(st, sb)


func _on_dim_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
