@tool
class_name ReserveHpRow
extends Control

## 顶部替补英雄的紧凑生命显示：单个平行四边形血量符号 + 数字。
## 版式沿用英雄图鉴的「图标 + 数字」，只把心形换成战斗主血条同语汇的斜切血块。
## 护盾存在时追加一组银灰斜切块 + 数字。两组都按实际文本宽度整体居中。

@export_group("斜切血量符号")
@export var icon_w: float = 26.0:
	set(v):
		icon_w = maxf(v, 8.0)
		queue_redraw()
@export var icon_h: float = 9.0:
	set(v):
		icon_h = maxf(v, 4.0)
		queue_redraw()
## 正值向右倾，负值向左倾；左右阵营可在场景里镜像。
@export var icon_slant: float = -3.0:
	set(v):
		icon_slant = v
		queue_redraw()
@export var icon_border: float = 1.5:
	set(v):
		icon_border = maxf(v, 0.0)
		queue_redraw()
@export var icon_band: float = 1.5:
	set(v):
		icon_band = maxf(v, 0.0)
		queue_redraw()

@export_group("排版")
@export var gap_icon_num: float = 7.0
@export var gap_segments: float = 9.0
@export var font_size: int = 18
@export var embolden: float = 0.7
@export var outline_size: int = 4

@export_group("配色")
@export var hp_fill: Color = Color("#e5443c")
@export var hp_top: Color = Color("#ff6a5c")
@export var hp_bottom: Color = Color("#a5312b")
@export var hp_number_color: Color = Color("#ef5148")
@export var shield_fill: Color = Color("#dcdfe6")
@export var shield_top: Color = Color("#f4f6fa")
@export var shield_bottom: Color = Color("#9ea4ae")
@export var shield_number_color: Color = Color("#c2c7d0")
@export var backing_color: Color = Color(0.04, 0.03, 0.06, 0.95)
@export var number_outline: Color = Color(0.04, 0.03, 0.06, 0.95)

@export_group("Battle HUD 定向阴影")
@export var bottom_shadow_enabled := false:
	set(v):
		bottom_shadow_enabled = v
		queue_redraw()
@export var bottom_shadow_offset := Vector2(1.5, 3.0):
	set(v):
		bottom_shadow_offset = v
		queue_redraw()
@export var bottom_shadow_color := Color(0.02, 0.012, 0.008, 0.30):
	set(v):
		bottom_shadow_color = v
		queue_redraw()
## 小字号数字需要比图形阴影更实，且使用整数偏移避免像素字体出现半像素虚边。
@export var number_shadow_offset := Vector2(2.0, 3.0):
	set(v):
		number_shadow_offset = v.round()
		queue_redraw()
@export var number_shadow_color := Color(0.02, 0.012, 0.008, 0.62):
	set(v):
		number_shadow_color = v
		queue_redraw()

@export_group("编辑器预览")
@export var preview_hp: float = 4.5:
	set(v):
		preview_hp = v
		queue_redraw()
@export var preview_shield: float = 0.0:
	set(v):
		preview_shield = v
		queue_redraw()

var _hp: float = 0.0
var _shield: float = 0.0
var _font: Font


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(hp: float, shield: float = 0.0) -> void:
	_hp = maxf(hp, 0.0)
	_shield = maxf(shield, 0.0)
	queue_redraw()


func _resolve_font() -> Font:
	var fm := get_node_or_null("/root/FontManager")
	var base: Font = fm.f16 if (fm != null and fm.f16 != null) else ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = embolden
	return fv


func _fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v


func _seg_width(text: String) -> float:
	return icon_w + gap_icon_num + _font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _draw() -> void:
	if _font == null:
		_font = _resolve_font()
	var hp := _hp
	var shield := _shield
	if Engine.is_editor_hint() and hp <= 0.0 and shield <= 0.0:
		hp = preview_hp
		shield = preview_shield

	var hp_txt := _fmt(hp)
	var sh_txt := _fmt(shield)
	var has_shield := shield > 0.0
	var total := _seg_width(hp_txt)
	if has_shield:
		total += gap_segments + _seg_width(sh_txt)
	var x := (size.x - total) * 0.5
	var cy := size.y * 0.5

	x = _draw_segment(x, cy, hp_txt, hp_fill, hp_top, hp_bottom, hp_number_color)
	if has_shield:
		x += gap_segments
		_draw_segment(x, cy, sh_txt, shield_fill, shield_top, shield_bottom, shield_number_color)


func _draw_segment(x: float, cy: float, text: String, fill: Color, top: Color,
		bottom: Color, text_color: Color) -> float:
	var y := cy - icon_h * 0.5
	var p := icon_border
	if bottom_shadow_enabled:
		draw_colored_polygon(_quad(
				x - p + bottom_shadow_offset.x,
				y - p + bottom_shadow_offset.y,
				icon_w + p * 2.0,
				icon_h + p * 2.0,
				icon_slant), bottom_shadow_color)
	draw_colored_polygon(_quad(x - p, y - p, icon_w + p * 2.0,
		icon_h + p * 2.0, icon_slant), backing_color)
	draw_colored_polygon(_quad(x, y, icon_w, icon_h, icon_slant), fill)
	if icon_band > 0.0:
		draw_colored_polygon(_quad_band(x, y, icon_w, icon_h, icon_slant,
			0.0, minf(icon_band, icon_h)), top)
		draw_colored_polygon(_quad_band(x, y, icon_w, icon_h, icon_slant,
			maxf(icon_h - icon_band, 0.0), icon_h), bottom)

	var nx := x + icon_w + gap_icon_num
	var baseline := cy + (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5
	if bottom_shadow_enabled:
		var shadow_position := Vector2(nx, baseline) + number_shadow_offset
		if outline_size > 0:
			draw_string_outline(_font, shadow_position, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, number_shadow_color)
		draw_string(_font, shadow_position, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, number_shadow_color)
	if outline_size > 0:
		draw_string_outline(_font, Vector2(nx, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, number_outline)
	draw_string(_font, Vector2(nx, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	return nx + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## icon_w 是包含斜切量的最终可见宽度，确保测宽与绘制严格一致。
func _quad(x: float, y: float, w: float, h: float, slant: float) -> PackedVector2Array:
	var s := clampf(slant, -w * 0.45, w * 0.45)
	if s >= 0.0:
		return PackedVector2Array([
			Vector2(x + s, y), Vector2(x + w, y),
			Vector2(x + w - s, y + h), Vector2(x, y + h)])
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w + s, y),
		Vector2(x + w, y + h), Vector2(x - s, y + h)])


func _quad_band(x: float, y: float, w: float, h: float, slant: float,
		y0: float, y1: float) -> PackedVector2Array:
	var s := clampf(slant, -w * 0.45, w * 0.45)
	var a0 := 1.0 - y0 / maxf(h, 0.001)
	var a1 := 1.0 - y1 / maxf(h, 0.001)
	if s >= 0.0:
		return PackedVector2Array([
			Vector2(x + s * a0, y + y0), Vector2(x + w - s * (1.0 - a0), y + y0),
			Vector2(x + w - s * (1.0 - a1), y + y1), Vector2(x + s * a1, y + y1)])
	return PackedVector2Array([
		Vector2(x - s * (1.0 - a0), y + y0), Vector2(x + w + s * a0, y + y0),
		Vector2(x + w + s * a1, y + y1), Vector2(x - s * (1.0 - a1), y + y1)])
