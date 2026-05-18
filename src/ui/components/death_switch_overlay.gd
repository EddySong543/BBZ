class_name DeathSwitchOverlay
extends Control

## 阵亡替补选择浮窗 placeholder — 全屏暗化背景 + 居中提示 + 横排卡片。
## 通过 show_selection(player, reserves) 弹出；用户选择后发出 selection_made(slot)。

const CARD_W := 160
const CARD_H := 200

signal selection_made(slot: int)

@onready var _prompt: Label = $PromptLabel
@onready var _card_container: HBoxContainer = $CardContainer


func _ready() -> void:
	FontManager.apply(_prompt, 28)
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	visible = false


## 弹出浮窗。reserves 数组每项为 [slot_idx: int, hero: HeroData, hp: int]
func show_selection(player: int, reserves: Array) -> void:
	_prompt.text = "P%d 选择替补英雄" % (player + 1)

	for child in _card_container.get_children():
		child.queue_free()

	var border_color := Color("#4488ff") if player == 0 else Color("#ff4444")
	for entry in reserves:
		var slot_idx: int = entry[0]
		var h: HeroData = entry[1]
		var hp: int = entry[2]
		var card := _create_card(h, hp, border_color)
		var captured := slot_idx
		card.pressed.connect(func() -> void: _on_card_selected(captured))
		_card_container.add_child(card)

	visible = true


func _create_card(h: HeroData, hp: int, border_color: Color) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#252540")
	sb.border_color = border_color
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color("#3a3a5a")
	sb_hover.border_color = Color("#ffdd44")
	card.add_theme_stylebox_override("hover", sb_hover)

	if h.portrait_path != "" and ResourceLoader.exists(h.portrait_path):
		var tex: Texture2D = load(h.portrait_path)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(10, 10)
		tr.size = Vector2(CARD_W - 20, CARD_H - 48)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text = h.hero_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, CARD_H - 36)
	name_lbl.size = Vector2(CARD_W, 20)
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "❤ %d" % hp
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.position = Vector2(0, CARD_H - 18)
	hp_lbl.size = Vector2(CARD_W, 16)
	FontManager.apply(hp_lbl, 13)
	hp_lbl.add_theme_color_override("font_color", Color("#ff6666"))
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hp_lbl)

	return card


func _on_card_selected(slot: int) -> void:
	visible = false
	selection_made.emit(slot)
