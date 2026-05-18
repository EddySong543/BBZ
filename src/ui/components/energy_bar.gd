class_name EnergyBar
extends Control

## 双行能量条 placeholder — 每个 "O" 代表 1 点能量，第 1 行 0-10，第 2 行 11-20。
## 后期换美术素材时整体替换本 .tscn / .gd。

@export_enum("P1:0", "P2:1") var player: int = 0:
	set(v):
		player = v
		if is_node_ready():
			_apply_alignment()

@onready var _row0: Label = $Row0
@onready var _row1: Label = $Row1


func _ready() -> void:
	FontManager.apply(_row0, 16)
	FontManager.apply(_row1, 16)
	var color := Color("#f5c518")
	_row0.add_theme_color_override("font_color", color)
	_row1.add_theme_color_override("font_color", color)
	_apply_alignment()
	set_energy(0)


## 根据 amount (0~20) 渲染两行 "O" 字符。
func set_energy(amount: int) -> void:
	if not is_node_ready():
		return
	_row0.text = _row_text(amount, 0)
	_row1.text = _row_text(amount, 10)


func _row_text(amount: int, start: int) -> String:
	var count: int = clampi(amount - start, 0, 10)
	var txt := ""
	for i in range(count):
		txt += "O "
	return txt


func _apply_alignment() -> void:
	var align := HORIZONTAL_ALIGNMENT_LEFT if player == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	if _row0:
		_row0.horizontal_alignment = align
	if _row1:
		_row1.horizontal_alignment = align
