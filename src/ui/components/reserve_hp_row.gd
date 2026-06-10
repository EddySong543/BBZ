@tool
class_name ReserveHpRow
extends Control

## 替补英雄血量/护甲紧凑居中显示：❤X（红心 + 红色加粗数字）+ 可选 灰❤X（护甲灰心 + 灰色数字·任务4）。
## 本组件**只负责居中布局**（修任务3b：整数/小数共用定宽布局导致小数 4.5 不居中）——
## 按实际内容测宽后整体水平居中、垂直按字体升降部精确居中 → 整数/小数都居中。
## 配色/加粗沿用 06-07 版本：HP = #d7342e 红 + embolden；护甲灰心参考 HUD 护盾灰心。
## 用 set_values(hp, shield)；shield<=0 时只画 ❤X。后期换美术：换 heart_sheet 即可。

@export var heart_sheet: Texture2D:
	set(v):
		heart_sheet = v
		_measure_visible()
		_rebuild_gray()
		queue_redraw()
## 心形精灵图横/纵帧数（heart_idle = 4×1，取第 0 帧）。
@export var hframes: int = 4
@export var vframes: int = 1
## 单颗心绘制边长。
@export var heart_px: float = 34.0:
	set(v):
		heart_px = v
		queue_redraw()
## 心与其数字之间的间距（按心形**可见边缘**起算，帧内透明留白已被 _measure_visible 移出布局）。
@export var gap_icon_num: float = 5.0
## 血量段与护甲段之间的间距。
@export var gap_segments: float = 8.0
## 16 = f16 原生字号（整数倍·像素干净）·与 bp 血量徽章同字号。
@export var font_size: int = 16
## 数字加粗量（沿用 06-07 版本 embolden 0.7）。
@export var embolden: float = 0.7
## HP 数字颜色（= 爱心红·06-07 版本 #d7342e）。
@export var hp_number_color: Color = Color("#d7342e")
## 护甲数字颜色（浅灰·配灰心）。
@export var shield_number_color: Color = Color("#c2c7d0")
@export var number_outline: Color = Color(0.04, 0.03, 0.06, 0.95)
@export var outline_size: int = 4
## 护甲灰心色调（同 HUD IconPipRow 护盾 extra_modulate）。
@export var shield_tint: Color = Color(0.8, 0.82, 0.86)

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
var _gray_tex: Texture2D
var _font: Font
var _vis_u0: float = 0.0   # 心形帧内可见像素左边界（0-1 帧宽比例）
var _vis_u1: float = 1.0   # 可见右边界


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure_visible()
	if _gray_tex == null:
		_rebuild_gray()


## 扫描第 0 帧的不透明横向边界：心形美术在帧内有透明留白，按整帧宽布局会产生
## "心与数字假间距" + 整体偏移不居中。量出可见边界后布局/居中全按可见宽度算（换美术自适应）。
func _measure_visible() -> void:
	_vis_u0 = 0.0
	_vis_u1 = 1.0
	if heart_sheet == null:
		return
	var img := heart_sheet.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var fw := img.get_width() / hframes
	var fh := img.get_height() / vframes
	var lo := fw
	var hi := -1
	for xx in fw:
		for yy in fh:
			if img.get_pixel(xx, yy).a > 0.05:
				lo = mini(lo, xx)
				hi = maxi(hi, xx)
				break
	if hi >= lo:
		_vis_u0 = float(lo) / float(fw)
		_vis_u1 = float(hi + 1) / float(fw)


## 心形可见绘制宽度（heart_px 乘可见比例）。
func _vis_w() -> float:
	return (_vis_u1 - _vis_u0) * heart_px


func set_values(hp: float, shield: float = 0.0) -> void:
	_hp = maxf(hp, 0.0)
	_shield = maxf(shield, 0.0)
	queue_redraw()


## 加粗像素字体（embolden 沿用 06-07·基底 f16 与 font_size=16 整数倍匹配）。
func _resolve_font() -> Font:
	var fm := get_node_or_null("/root/FontManager")
	var base: Font = fm.f16 if (fm != null and fm.f16 != null) else ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = embolden
	return fv


## 半点制：整数显示整数，半点显示一位小数。
func _fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v


## 单段宽度 = 心可见宽 + 间距 + 数字文本宽。
func _seg_width(text: String) -> float:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _vis_w() + gap_icon_num + tw


func _draw() -> void:
	if heart_sheet == null:
		return
	if _font == null:
		_font = _resolve_font()
	var hp := _hp
	var shield := _shield
	if Engine.is_editor_hint() and hp <= 0.0 and shield <= 0.0:
		hp = preview_hp
		shield = preview_shield

	var hp_txt := _fmt(hp)
	var has_shield := shield > 0.0
	var sh_txt := _fmt(shield)

	# 按内容测总宽 → 水平居中起点（整数/小数一致居中·任务3b）。
	var total := _seg_width(hp_txt)
	if has_shield:
		total += gap_segments + _seg_width(sh_txt)
	var x := (size.x - total) * 0.5
	var cy := size.y * 0.5
	var src := Rect2(0.0, 0.0, float(heart_sheet.get_width()) / float(hframes), float(heart_sheet.get_height()) / float(vframes))

	# 段1：红心 + 红色加粗 HP 数字
	x = _draw_segment(heart_sheet, Color.WHITE, hp_txt, hp_number_color, x, cy, src)
	# 段2：灰心 + 灰色护甲数字（任务4）
	if has_shield:
		x += gap_segments
		var stex: Texture2D = _gray_tex if _gray_tex != null else heart_sheet
		x = _draw_segment(stex, shield_tint, sh_txt, shield_number_color, x, cy, src)


## 画一段（心 + 数字），返回下一段起点 x。数字按字体升降部垂直居中（与心对齐）。
## 心按**可见左缘**对齐光标 x（整帧绘制位置向左补回帧内留白）。
func _draw_segment(tex: Texture2D, icon_mod: Color, text: String, txt_col: Color, x: float, cy: float, src: Rect2) -> float:
	var dst := Rect2(x - _vis_u0 * heart_px, cy - heart_px * 0.5, heart_px, heart_px)
	draw_texture_rect_region(tex, dst, src, icon_mod)
	var nx := x + _vis_w() + gap_icon_num
	# 基线 = cy + (ascent - descent)/2 → 文本垂直居中于 cy（与心同高）。
	var baseline := cy + (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5
	if outline_size > 0:
		draw_string_outline(_font, Vector2(nx, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, number_outline)
	draw_string(_font, Vector2(nx, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, txt_col)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return nx + tw


## 生成去色版心形（护甲灰心用）：红心经亮度去色 → 灰度，再 × shield_tint 得真灰（红×灰=暗红，必须先去色）。
func _rebuild_gray() -> void:
	if heart_sheet == null:
		_gray_tex = null
		return
	var img := heart_sheet.get_image()
	if img == null:
		_gray_tex = null
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var lb := clampf(l * 1.1 + 0.5, 0.0, 1.0)
			img.set_pixel(xx, yy, Color(lb, lb, lb, c.a))
	_gray_tex = ImageTexture.create_from_image(img)
