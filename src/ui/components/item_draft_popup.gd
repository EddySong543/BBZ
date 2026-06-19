class_name ItemDraftPopup
extends Control

## 道具 3 选 1 抽取弹窗（M3·占位）：模态全屏暗幕 + 居中候选卡（名 / 维度色 / 一句话描述）。
## ⚠ 占位实现：程序化建子节点 + 默认配色/尺寸，待 Eddy 在编辑器定稿后 scene 化 + 换美术。
## 用法：实例化 → add_child（覆盖在 battle_screen 上）→ setup(options, can_cancel)
##   → `var choice: int = await popup.resolved`（返回选中 index；-1 = 取消）→ 调用方 queue_free。

signal resolved(choice: int)

const CARD_W := 240.0
const CARD_H := 320.0
const CARD_GAP := 28.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

## 维度 → 卡底色（与 ItemSlotRow 同源）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}

var _can_cancel := true
var _done := false   # 防重复 resolve（连点 / ESC 抢答）


func setup(options: Array, can_cancel: bool = true) -> void:
	_can_cancel = can_cancel
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉所有背景点击（模态）

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := Label.new()
	title.text = "抽取道具（3 选 1）"
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
	card.pressed.connect(_resolve.bind(idx))
	add_child(card)

	# 卡底色（维度色）——子节点 IGNORE，点击穿透到 card。
	var face := ColorRect.new()
	face.color = DIM_COLOR.get(item.dimension if item != null else "", Color(0.42, 0.42, 0.47))
	face.position = Vector2(4.0, 4.0)
	face.size = Vector2(CARD_W - 8.0, CARD_H - 8.0)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(face)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name if item != null else "?"
	name_lbl.position = Vector2(12.0, 18.0)
	name_lbl.size = Vector2(CARD_W - 24.0, 64.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description if item != null else ""
	desc_lbl.position = Vector2(14.0, 96.0)
	desc_lbl.size = Vector2(CARD_W - 28.0, CARD_H - 116.0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)


func _input(event: InputEvent) -> void:
	if _can_cancel and event.is_action_pressed("ui_cancel"):
		accept_event()
		_resolve(-1)


func _resolve(choice: int) -> void:
	if _done:
		return
	_done = true
	resolved.emit(choice)
