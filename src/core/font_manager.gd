extends Node

## Pixel font manager — loads the shared Z Labs Pixel UI preset:
## grayscale antialiasing + light embolden + 6% vertical compression.

const UI_FONT_PATH := "res://assets/font/zlabs_pixel_ui.tres"

var f12: Font
var f16: Font


func _ready() -> void:
	f12 = load(UI_FONT_PATH)
	# Z工坊当前只有 12px 基准；保留 f16 公开别名，避免破坏成熟调用端。
	f16 = f12


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


func _best_font(px_size: int) -> Font:
	# 保留现有字号层级，所有尺寸统一由 CN 字体渲染。
	return f12
