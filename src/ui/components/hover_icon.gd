@tool
class_name HoverIcon
extends Control

## 悬停播放的按钮图标。作为 [Button]（或任意 [BaseButton]）的子节点使用：
## 平时静止停在 [member rest_frame]，鼠标悬停在父按钮上时循环播放 idle 逐帧动画，
## 移开后回到静止帧。按钮 disabled 时不播放并变暗。
##
## **稳健性**：本节点锚定填满父按钮（程序挂载时设 PRESET_FULL_RECT），故父按钮被
## 移动/缩放后图标自动跟随；悬停经由父按钮的 mouse_entered/exited 信号触发，与位置无关；
## 图标画在按钮 stylebox（边框/底）之上并留 inset 内边距，故后续加/换边框不影响图标。
##
## 图集为逐帧 spritesheet：[member hframes]×[member vframes] 网格，左上→右排、逐行。
## [member frame_count]>0 时只播到该帧（避免网格末尾的空白格被播成"图标消失"）。
##
## 用法（代码挂载）：
## [codeblock]
## var icon := HoverIcon.new()
## icon.sheet = load("res://.../Zan_idle.png")
## icon.hframes = 4; icon.vframes = 2; icon.frame_count = 5
## button.add_child(icon)
## icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
## [/codeblock]

@export_group("精灵图")
## idle 逐帧图集。
@export var sheet: Texture2D:
	set(v):
		sheet = v
		queue_redraw()
## 横向帧数。
@export var hframes: int = 1:
	set(v):
		hframes = maxi(v, 1)
		queue_redraw()
## 纵向帧数。
@export var vframes: int = 1:
	set(v):
		vframes = maxi(v, 1)
		queue_redraw()
## 实际帧数（0 = 用 hframes×vframes 全部；网格末尾有空白格时填实际帧数）。
@export var frame_count: int = 0
## 悬停播放速度（帧/秒）。
@export var fps: float = 10.0
## 悬停时是否循环（false = 播一遍后停在末帧）。
@export var loop_on_hover: bool = true
## 静止时停留的帧。
@export var rest_frame: int = 0:
	set(v):
		rest_frame = maxi(v, 0)
		if not _hovering:
			_frame = rest_frame
		queue_redraw()

@export_group("排布")
## 图标相对按钮的内边距比例（按短边），留出边框空间。0.14 ≈ 留 14%。
@export_range(0.0, 0.45) var inset_ratio: float = 0.14:
	set(v):
		inset_ratio = clampf(v, 0.0, 0.45)
		queue_redraw()
## 内容缩放：不同素材在各自帧里留白不同，用它让每个图标看起来差不多大。
## 1.0 = 填满 inset 方框；>1 放大、<1 缩小。可在编辑器逐个微调。
@export_range(0.2, 2.0) var content_scale: float = 1.0:
	set(v):
		content_scale = v
		queue_redraw()
## 按钮 disabled 时图标的不透明度。
@export_range(0.0, 1.0) var disabled_alpha: float = 0.35

var _hovering: bool = false
var _time: float = 0.0
var _frame: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击穿透给父按钮
	_frame = rest_frame
	var par := get_parent()
	if par is BaseButton:
		if not par.mouse_entered.is_connected(_on_parent_enter):
			par.mouse_entered.connect(_on_parent_enter)
		if not par.mouse_exited.is_connected(_on_parent_exit):
			par.mouse_exited.connect(_on_parent_exit)
	set_process(not Engine.is_editor_hint())


func _total_frames() -> int:
	var grid := hframes * vframes
	if frame_count > 0:
		return mini(frame_count, grid)
	return grid


## 返回指定帧的 AtlasTexture，供别处静态显示同一图标（如回合揭示气泡）。
func make_frame_texture(frame: int = 0) -> AtlasTexture:
	var at := AtlasTexture.new()
	if sheet == null:
		return at
	var fw := sheet.get_width() / hframes
	var fh := sheet.get_height() / vframes
	at.atlas = sheet
	at.region = Rect2((frame % hframes) * fw, (frame / hframes) * fh, fw, fh)
	return at


func _process(delta: float) -> void:
	if not _hovering:
		return
	var total := _total_frames()
	if total <= 1 or fps <= 0.0:
		return
	_time += delta
	var nf := int(_time * fps)
	if loop_on_hover:
		nf = nf % total
	else:
		nf = mini(nf, total - 1)
	if nf != _frame:
		_frame = nf
		queue_redraw()


func _on_parent_enter() -> void:
	var par := get_parent()
	if par is BaseButton and par.disabled:
		return
	_hovering = true
	_time = 0.0
	_frame = 0
	queue_redraw()


func _on_parent_exit() -> void:
	_hovering = false
	_time = 0.0
	if _frame != rest_frame:
		_frame = rest_frame
	queue_redraw()


func _draw() -> void:
	if sheet == null:
		return
	var total := _total_frames()
	var f := clampi(_frame, 0, maxi(total - 1, 0))
	var fw := sheet.get_width() / hframes
	var fh := sheet.get_height() / vframes
	var src := Rect2((f % hframes) * fw, (f / hframes) * fh, fw, fh)

	# 在按钮矩形内留 inset，居中放一个正方形（帧本身为正方形）；content_scale 微调大小。
	var inset := minf(size.x, size.y) * inset_ratio
	var box := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var side := minf(box.size.x, box.size.y) * content_scale
	var dst := Rect2(size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))

	var mod := Color.WHITE
	var par := get_parent()
	if par is BaseButton and par.disabled:
		mod.a = disabled_alpha
	draw_texture_rect_region(sheet, dst, src, mod)
