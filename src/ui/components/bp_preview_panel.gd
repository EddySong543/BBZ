class_name BPPreviewPanel
extends Control

## BP 阶段单方阵容预览面板（标题 + 3 个 BPHeroSlot）。
## placeholder — 后期换美术素材时整体替换本 .tscn / .gd。

@export_enum("P1:0", "P2:1") var player: int = 0:
	set(v):
		player = v
		if is_node_ready():
			_apply_player_style()

@onready var _title_label: Label = $TitleLabel
@onready var _slot0: BPHeroSlot = $Slot0
@onready var _slot1: BPHeroSlot = $Slot1
@onready var _slot2: BPHeroSlot = $Slot2

var _slots: Array[BPHeroSlot] = []


func _ready() -> void:
	_slots = [_slot0, _slot1, _slot2]
	_style_title()
	_apply_player_style()
	for s in _slots:
		if s:
			s.clear()


## 标题：像素字体放大·加粗·描边 → 在波动背景上醒目清晰（修"太细/看不清"·任务2）。
func _style_title() -> void:
	FontManager.apply(_title_label, 20)
	var bold := FontVariation.new()
	bold.base_font = FontManager.f16
	bold.variation_embolden = 0.9
	_title_label.add_theme_font_override("font", bold)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_constant_override("outline_size", 5)
	_title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))


## 用 picks（英雄索引数组）+ all_heroes 填充槽位。
## 不足 3 个的槽位显示空状态。
func set_picks(picks: Array, all_heroes: Array) -> void:
	if not is_node_ready():
		return
	for i in range(_slots.size()):
		if i < picks.size():
			_slots[i].set_hero(all_heroes[picks[i]])
		else:
			_slots[i].clear()


func _apply_player_style() -> void:
	if _title_label == null:
		return
	var color := Color("#3388dd") if player == 0 else Color("#dd3333")
	_title_label.text = "P1 阵容" if player == 0 else "P2 阵容"
	_title_label.add_theme_color_override("font_color", color)
	for s in _slots:
		if s:
			s.player_color = color
