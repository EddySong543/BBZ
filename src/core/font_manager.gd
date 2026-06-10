extends Node

## Pixel font manager — loads Ark Pixel TTF, disables antialias, provides apply helpers.

var f12: FontFile
var f16: FontFile


func _ready() -> void:
	f12 = load("res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf")
	f12.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f16 = load("res://assets/font/ark-pixel-16px-proportional-zh_cn.ttf")
	f16.antialiasing = TextServer.FONT_ANTIALIASING_NONE


func apply(label: Label, px_size: int) -> void:
	if not label: return
	var f := _best_font(px_size)
	label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", px_size)


func apply_btn(btn: Button, px_size: int) -> void:
	if not btn: return
	var f := _best_font(px_size)
	btn.add_theme_font_override("font", f)
	btn.add_theme_font_size_override("font_size", px_size)


func _best_font(px_size: int) -> FontFile:
	# 12 整倍数→f12，16 整倍数→f16，其余退回 f12。
	# （2026-06-10 试过全 f12 与字号全归整，Eddy 均否——非整倍数的轻微缩放可接受。）
	if px_size % 12 == 0:
		return f12
	if px_size % 16 == 0:
		return f16
	return f12


func px_small() -> int:
	return 12


func px_med() -> int:
	return 16


func px_large() -> int:
	return 24


func px_title() -> int:
	return 48
