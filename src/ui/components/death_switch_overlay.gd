class_name DeathSwitchOverlay
extends Control

## 阵亡替补选择浮窗 —— 全屏暗化背景 + 居中提示 + 横排「头像框」(HeroFrame 同款，与战斗内一致)。
## 通过 show_selection(player, reserves) 弹出；用户点击某个头像框后发出 selection_made(slot)。

const HeroFrameScene := preload("res://src/ui/components/hero_frame.tscn")
const FRAME_SIZE := 120.0

signal selection_made(slot: int)

@onready var _prompt: Label = $PromptLabel
@onready var _card_container: HBoxContainer = $CardContainer


func _ready() -> void:
	FontManager.apply(_prompt, 32)   # 32=16×2 整数倍·清晰
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	visible = false


## 弹出浮窗。reserves 数组每项为 [slot_idx: int, hero: HeroData, hp: int]
func show_selection(player: int, reserves: Array) -> void:
	_prompt.text = "选择出战英雄"

	for child in _card_container.get_children():
		child.queue_free()

	var pcolor := Color("#3f86c8") if player == 0 else Color("#d24a44")  # 阵营宝石色(与战斗内一致)
	for entry in reserves:
		var slot_idx: int = entry[0]
		var h: HeroData = entry[1]
		var hp: int = entry[2]
		_card_container.add_child(_create_frame_entry(h, hp, slot_idx, pcolor))

	visible = true


## 单个替补 = HeroFrame 头像框(与左右上角同款) + 名字 + 血量，整体可点。
func _create_frame_entry(h: HeroData, hp: int, slot: int, pcolor: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE + 46.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := HeroFrameScene.instantiate() as HeroFrame
	frame.position = Vector2.ZERO
	frame.frame_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	frame.portrait_path = h.portrait_path
	frame.hero_name = h.hero_name
	frame.player_color = pcolor
	frame.is_active = false
	frame.is_dead = false
	frame.gui_input.connect(_on_frame_input.bind(slot))
	wrap.add_child(frame)

	var name_lbl := Label.new()
	name_lbl.text = h.hero_name
	name_lbl.position = Vector2(0, FRAME_SIZE + 2.0)
	name_lbl.size = Vector2(FRAME_SIZE, 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(name_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "❤ %d" % hp
	hp_lbl.position = Vector2(0, FRAME_SIZE + 24.0)
	hp_lbl.size = Vector2(FRAME_SIZE, 18)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply(hp_lbl, 12)
	hp_lbl.add_theme_color_override("font_color", Color("#ff6666"))
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hp_lbl)

	return wrap


func _on_frame_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_selected(slot)


func _on_selected(slot: int) -> void:
	visible = false
	selection_made.emit(slot)
