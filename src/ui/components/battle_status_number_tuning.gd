@tool
class_name BattleStatusNumberTuning
extends Resource

## Buff 数字唯一调校源。buff_tuning_lab 与正式战斗行共同引用同一份 .tres；
## 运行组件只读取，不在结算或动画期间改写这些参数。

@export_group("Layout")
@export var count_offset := Vector2(7.0, 37.0):
	set(value):
		count_offset = value
		changed.emit()
@export var count_box_size := Vector2(26.0, 18.0):
	set(value):
		count_box_size = value
		changed.emit()
@export_range(8, 32, 1) var count_font_size := 18:
	set(value):
		count_font_size = value
		changed.emit()
@export_range(0.0, 1.5, 0.05) var count_embolden := 0.6:
	set(value):
		count_embolden = value
		changed.emit()
@export_range(0.0, 12.0, 1.0, "suffix:px") var count_symbol_gap := 2.0:
	set(value):
		count_symbol_gap = value
		changed.emit()

@export_group("Outline And Shadow")
@export_range(0, 8, 1) var count_outline_size := 2:
	set(value):
		count_outline_size = value
		changed.emit()
@export var count_text_color := Color("F2E8CC"):
	set(value):
		count_text_color = value
		changed.emit()
@export var count_outline_color := Color.BLACK:
	set(value):
		count_outline_color = value
		changed.emit()
@export var count_shadow_color := Color(0.0, 0.0, 0.0, 0.32):
	set(value):
		count_shadow_color = value
		changed.emit()
@export var count_shadow_offset := Vector2i(1, 1):
	set(value):
		count_shadow_offset = value
		changed.emit()
@export_range(0, 4, 1) var count_shadow_outline_size := 0:
	set(value):
		count_shadow_outline_size = value
		changed.emit()

@export_group("Increase Motion")
@export_range(0.0, 1.0, 0.01) var count_pop_duration := 0.14:
	set(value):
		count_pop_duration = value
		changed.emit()
@export_range(-4.0, 4.0, 1.0, "suffix:px") var count_increase_lift := 2.0:
	set(value):
		count_increase_lift = value
		changed.emit()
@export_range(0.5, 1.0, 0.01) var count_increase_scale := 0.9:
	set(value):
		count_increase_scale = value
		changed.emit()

@export_group("Per Icon Optical Offset")
@export var use_per_icon_count_offsets := true:
	set(value):
		use_per_icon_count_offsets = value
		changed.emit()
@export var poison_count_offset := Vector2(7.0, 37.0):
	set(value):
		poison_count_offset = value
		changed.emit()
@export var vulnerable_count_offset := Vector2(7.0, 37.0):
	set(value):
		vulnerable_count_offset = value
		changed.emit()
@export var sword_qi_count_offset := Vector2(7.0, 37.0):
	set(value):
		sword_qi_count_offset = value
		changed.emit()
