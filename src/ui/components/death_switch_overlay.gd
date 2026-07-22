class_name DeathSwitchOverlay
extends Control

## 阵亡替补选择浮窗 —— 全屏暗化背景 + 居中提示 + 倒计时 + 横排新版 item_frame 头像。
## 通过 show_selection(player, reserves) 弹出；用户点击某个头像框后发出 selection_made(slot)。
##
## 倒计时(PICK_SECONDS=10 秒)：到点未选则自动选最左侧(reserves[0]，即首个存活替补)并发出 selection_made。
## 血量显示 = 现役 ReserveHpRow：单个平行四边形血块 + 数字。
## 每个替补 = 居中竖排：新版头像框 + 名字 + 斜切血量（固定 FRAME_SIZE 宽对齐）。

const ItemAvatarFrameScene := preload("res://src/ui/components/item_avatar_frame.tscn")
const ReserveHpRowScript := preload("res://src/ui/components/reserve_hp_row.gd")
const FRAME_SIZE := 120.0
const PICK_SECONDS := 10

signal selection_made(slot: int)

@onready var _prompt: Label = $PromptLabel
@onready var _countdown: Label = $CountdownLabel
@onready var _card_container: HBoxContainer = $CardContainer

var _time_left: float = 0.0
var _counting: bool = false
var _default_slot: int = -1   # 倒计时归零时自动选的槽位（= 最左侧 / 首个存活替补）


func _ready() -> void:
	FontManager.apply(_prompt, 32)   # 32=16×2 整数倍·清晰
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(_countdown, 48)   # 倒计时大数字（48=16×3 整数倍·清晰）
	_countdown.add_theme_color_override("font_color", Color.WHITE)
	visible = false
	set_process(false)


## 弹出浮窗。reserves 数组每项为 [slot_idx:int, hero:HeroData, hp:float]（多余元素忽略）。
## title 可覆盖提示文案（加时赛选人复用本浮窗·2026-07-03）。
func show_selection(player: int, reserves: Array, title: String = "选择出战英雄") -> void:
	_prompt.text = tr(title)

	for child in _card_container.get_children():
		child.queue_free()

	_default_slot = int(reserves[0][0]) if reserves.size() > 0 else -1

	var pcolor := Color("#3f86c8") if player == 0 else Color("#d24a44")  # 阵营宝石色(与战斗内一致)
	for entry in reserves:
		var slot_idx: int = int(entry[0])
		var h: HeroData = entry[1]
		var hp: float = float(entry[2])
		_card_container.add_child(_create_frame_entry(h, hp, slot_idx, pcolor))

	visible = true
	_time_left = float(PICK_SECONDS)
	_counting = true
	_update_countdown_label()
	set_process(true)


## 倒计时：每帧递减，归零自动选最左侧替补。
func _process(delta: float) -> void:
	if not _counting:
		return
	_time_left -= delta
	_update_countdown_label()
	if _time_left <= 0.0:
		_counting = false
		set_process(false)
		_on_selected(_default_slot)


func _update_countdown_label() -> void:
	var secs := maxi(int(ceil(_time_left)), 0)
	_countdown.text = "%d" % secs
	# 最后 3 秒转红催促。
	_countdown.add_theme_color_override("font_color", Color("#ff6666") if secs <= 3 else Color.WHITE)


## 单个替补 = 居中竖排：新版 item_frame 头像 + 名字 + 平行四边形血量。
func _create_frame_entry(h: HeroData, hp: float, slot: int, pcolor: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE + 72.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := ItemAvatarFrameScene.instantiate() as ItemAvatarFrame
	wrap.add_child(frame)
	frame.position = Vector2.ZERO
	frame.frame_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	frame.portrait_path = h.portrait_path
	frame.set_faction_color(pcolor)
	frame.gui_input.connect(_on_frame_input.bind(slot))

	var name_lbl := Label.new()
	name_lbl.text = h.hero_name
	name_lbl.position = Vector2(0, FRAME_SIZE + 6.0)
	name_lbl.size = Vector2(FRAME_SIZE, 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(name_lbl)

	var hp_row := ReserveHpRowScript.new() as ReserveHpRow
	hp_row.name = "HpRow"
	hp_row.position = Vector2(0.0, FRAME_SIZE + 28.0)
	hp_row.size = Vector2(FRAME_SIZE, 40.0)
	hp_row.icon_slant = -4.0 if pcolor.b >= pcolor.r else 4.0
	hp_row.set_values(hp, 0.0)
	wrap.add_child(hp_row)

	return wrap


func _on_frame_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_selected(slot)


func _on_selected(slot: int) -> void:
	_counting = false
	set_process(false)
	visible = false
	selection_made.emit(slot)
