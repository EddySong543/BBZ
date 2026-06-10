@tool
class_name IconBadge
extends Control

## 图标内嵌数字徽章：一张图标（从精灵图取某一帧）+ 居中嵌入的数字。
## 血量爱心嵌 HP（bp 卡池卡片）、能量金币嵌消耗（战斗动作按钮）共用同一套（任务 1 / 3）。
##
## 用法：
##   - .tscn 里挂本脚本到一个 Control，Inspector 设 sheet/hframes/vframes/frame + 数字样式，自建子节点。
##   - 代码里 IconBadge.new() → set_icon(sheet, hframes, vframes, frame) + set_number(n) → add_child。
## 子节点（_ready 自建）：Icon(TextureRect·nearest) + Num(Label·居中·描边)。

@export_group("图标")
@export var sheet: Texture2D:
	set(v):
		sheet = v
		_refresh_icon()
## 精灵图横向帧数（heart_idle=4，energy_idle=4）。
@export var hframes: int = 1:
	set(v):
		hframes = maxi(v, 1)
		_refresh_icon()
## 精灵图纵向帧数（heart_idle=1，energy_idle=4）。
@export var vframes: int = 1:
	set(v):
		vframes = maxi(v, 1)
		_refresh_icon()
## 显示哪一帧（满心 / 金币 = 0）。
@export var frame: int = 0:
	set(v):
		frame = maxi(v, 0)
		_refresh_icon()
## 图标色调（禁用态压暗用）。
@export var icon_modulate: Color = Color.WHITE:
	set(v):
		icon_modulate = v
		if _icon:
			_icon.modulate = v

@export_group("数字")
@export var number: int = 0:
	set(v):
		number = v
		_refresh_number()
@export var show_number: bool = true:
	set(v):
		show_number = v
		_refresh_number()
@export var number_color: Color = Color.WHITE:
	set(v):
		number_color = v
		_style_number()
@export var number_outline: Color = Color(0.04, 0.03, 0.06, 0.95):
	set(v):
		number_outline = v
		_style_number()
@export var outline_size: int = 5:
	set(v):
		outline_size = v
		_style_number()
@export var font_size: int = 18:
	set(v):
		font_size = v
		_style_number()
## 数字加粗量（FontVariation embolden·0 = 不加粗·血量数字建议 0.7 与替补血量一致）。
@export var embolden: float = 0.0:
	set(v):
		embolden = v
		_style_number()
## 数字相对图标的微调位移（心形顶部有凹口 → 略下移看起来才居中）。
@export var number_offset: Vector2 = Vector2(0, 1):
	set(v):
		number_offset = v
		if _num:
			_num.position = v

var _icon: TextureRect
var _num: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	if _icon == null:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
	if _num == null:
		_num = Label.new()
		_num.name = "Num"
		_num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_num)
	_refresh_icon()
	_style_number()
	_refresh_number()
	_num.position = number_offset


func _refresh_icon() -> void:
	if _icon == null:
		return
	if sheet == null:
		_icon.texture = null
		return
	var fw := sheet.get_width() / hframes
	var fh := sheet.get_height() / vframes
	var fcol := frame % hframes
	var frow := frame / hframes
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(fcol * fw, frow * fh, fw, fh)
	_icon.texture = at
	_icon.modulate = icon_modulate


func _style_number() -> void:
	if _num == null:
		return
	var fm := get_node_or_null("/root/FontManager")
	if fm != null:
		fm.apply(_num, font_size)
	else:
		_num.add_theme_font_size_override("font_size", font_size)
	if embolden > 0.0:
		# 包一层 FontVariation 加粗（基底取 fm.apply 刚设置的字体，不会嵌套叠加）。
		var fv := FontVariation.new()
		fv.base_font = _num.get_theme_font("font") if fm != null else ThemeDB.fallback_font
		fv.variation_embolden = embolden
		_num.add_theme_font_override("font", fv)
	_num.add_theme_color_override("font_color", number_color)
	_num.add_theme_color_override("font_outline_color", number_outline)
	_num.add_theme_constant_override("outline_size", outline_size)


func _refresh_number() -> void:
	if _num == null:
		return
	_num.visible = show_number
	_num.text = str(number)


func set_number(n: int) -> void:
	number = n


func set_icon(s: Texture2D, hf: int, vf: int, fr: int = 0) -> void:
	sheet = s
	hframes = hf
	vframes = vf
	frame = fr
