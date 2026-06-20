class_name ItemDraftPopup
extends Control

## 道具 3 选 1 弹窗（抽取 / 升级·M3）：模态全屏暗幕 + 居中候选卡（jelly 圆角卡·维度色·名 + 一句话描述）。
## 卡片 = 与道具栏/动作按钮同款 canvas_button_jelly 语言（2026-06-20 配色统一·取代旧暖骨像素边框）。
## ⚠ 占位：程序化建子节点 + 占位文字，待 scene 化 + 换美术（图标任务延后）。
## 用法：实例化 → add_child（覆盖在 battle_screen 上）→ setup(options, can_cancel, title)
##   → `var choice: int = await popup.resolved`（返回选中 index；-1 = 取消）→ 调用方 queue_free。

signal resolved(choice: int)

const CARD_W := 240.0
const CARD_H := 320.0
const CARD_GAP := 28.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

## 维度 → 卡底色（与 ItemSlotRow / 动作按钮同源的语义色板）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}

## jelly 卡底（与按钮 / 道具芯片同款 shader → 统一 UI 语言）。
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const EDGE_OUTER := Color(0.10, 0.09, 0.11)   # 统一暗轮廓（场景无关）

var _can_cancel := true
var _done := false   # 防重复 resolve（连点 / ESC 抢答）


func setup(options: Array, can_cancel: bool = true, title_text: String = "抽取道具（3 选 1）") -> void:
	_can_cancel = can_cancel
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉所有背景点击（模态）

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := Label.new()
	title.text = title_text   # 区分「抽取」/「升级」3 选 1
	title.position = Vector2(0.0, SCREEN_H * 0.5 - CARD_H * 0.5 - 70.0)
	title.size = Vector2(SCREEN_W, 48.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var n: int = options.size()
	var total_w: float = n * CARD_W + maxf(0.0, (n - 1)) * CARD_GAP
	var start_x: float = (SCREEN_W - total_w) * 0.5
	var card_y: float = (SCREEN_H - CARD_H) * 0.5
	for i in range(n):
		var item: ItemData = options[i]
		_build_card(item, Vector2(start_x + i * (CARD_W + CARD_GAP), card_y), i)

	if can_cancel:
		var cancel := Button.new()
		cancel.text = "取消"
		cancel.size = Vector2(160.0, 48.0)
		cancel.position = Vector2((SCREEN_W - 160.0) * 0.5, card_y + CARD_H + 36.0)
		cancel.focus_mode = Control.FOCUS_NONE
		cancel.pressed.connect(_resolve.bind(-1))
		add_child(cancel)


func _build_card(item: ItemData, pos: Vector2, idx: int) -> void:
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.position = pos
	card.size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())   # 去默认按钮底 → 露出 jelly
	card.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	card.pressed.connect(_resolve.bind(idx))
	add_child(card)

	var dim: Color = DIM_COLOR.get(item.dimension if item != null else "", Color(0.42, 0.42, 0.47))
	# 图标（缺图 → 描述区维持原位、卡面与现状一像素不变·零回归）。
	var tex: Texture2D = ItemCatalog.load_icon(item.item_id) if item != null else null
	var scrim_top := 184.0 if tex != null else 92.0    # 有图 → 描述区下移给图标腾窗
	var desc_top := 192.0 if tex != null else 100.0
	# jelly 卡底（圆角果冻·维度色渐变·与道具栏/按钮同语言）。子节点 IGNORE，点击穿透到 card。
	var jelly := ColorRect.new()
	jelly.color = Color.WHITE   # jelly shader 乘 COLOR，须白
	jelly.position = Vector2.ZERO
	jelly.size = Vector2(CARD_W, CARD_H)
	jelly.material = _make_card_jelly(dim)
	jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(jelly)

	# 描述区暗衬（内缩不碰圆角）：提升长描述在饱和卡上的可读性。
	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.26)
	scrim.position = Vector2(14.0, scrim_top)
	scrim.size = Vector2(CARD_W - 28.0, CARD_H - scrim_top - 16.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(scrim)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name if item != null else "?"
	name_lbl.position = Vector2(12.0, 18.0)
	name_lbl.size = Vector2(CARD_W - 24.0, 64.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.99, 0.97, 0.92))   # 亮米白压饱和卡
	name_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 5)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.position = Vector2(CARD_W * 0.5 - 48.0, 84.0)
		icon.size = Vector2(96.0, 96.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素清晰
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description if item != null else ""
	desc_lbl.position = Vector2(18.0, desc_top)
	desc_lbl.size = Vector2(CARD_W - 36.0, CARD_H - desc_top - 24.0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
	desc_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.85))
	desc_lbl.add_theme_constant_override("outline_size", 3)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)


## 造 jelly 卡底材质：维度色竖直渐变 + 立体边 + 大卡小圆角（aspect=宽/高·tall 卡像素方正）。
func _make_card_jelly(dim: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY_SHADER
	m.set_shader_parameter("fill_top", dim.lightened(0.12))
	m.set_shader_parameter("fill_bottom", dim.darkened(0.32))
	m.set_shader_parameter("edge_inner", dim.lightened(0.38))
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 60.0)        # 大卡 → 更细像素格
	m.set_shader_parameter("corner", 0.07)            # 大卡小圆角（避免过圆）
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", CARD_W / CARD_H) # tall 卡 → 像素方正、圆角/边四周等宽
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("wear", 0.18)
	return m


func _input(event: InputEvent) -> void:
	if _can_cancel and event.is_action_pressed("ui_cancel"):
		accept_event()
		_resolve(-1)


func _resolve(choice: int) -> void:
	if _done:
		return
	_done = true
	resolved.emit(choice)
