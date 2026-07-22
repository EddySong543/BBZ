@tool
class_name ItemAvatarFrame
extends Control

## 用新版 item_frame 承载英雄头像的通用组件。
## frame_size 表示最终可见外框尺寸；内部头像孔按道具框已验收的透明边几何反推，
## 因此不会出现四角露底、填充越界，调用侧也无需理解素材透明边。

const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
const FRAME_PALETTE_SHADER := preload("res://assets/shaders/canvas_ui_item_frame_palette.gdshader")
const FRAME_ART_SCALE := 87.25 / 68.0
const FRAME_OFFSET_RATIO := Vector2(-9.6 / 68.0, -10.0 / 68.0)
const CELL_INSET_RATIO := 5.5 / 68.0

const PLAYER_SHADOW := Color("#102C4A")
const PLAYER_MID := Color("#4A86C2")
const PLAYER_HIGHLIGHT := Color("#B9D9F2")
const ENEMY_SHADOW := Color("#4A1110")
const ENEMY_MID := Color("#B64A43")
const ENEMY_HIGHLIGHT := Color("#F0B0A8")

@export var portrait_path: String = "":
	set(value):
		portrait_path = value
		if is_node_ready():
			_refresh_portrait()

## 最终可见的 item_frame 外框尺寸，而不是内部头像孔尺寸。
@export var frame_size := Vector2(84.0, 84.0):
	set(value):
		frame_size = Vector2(maxf(value.x, 16.0), maxf(value.y, 16.0))
		if is_node_ready():
			_apply_layout()

@export_group("框体配色")
@export var frame_shadow := Color("#3A2410"):
	set(value):
		frame_shadow = value
		if is_node_ready():
			_apply_colors()
@export var frame_mid := Color("#A4773D"):
	set(value):
		frame_mid = value
		if is_node_ready():
			_apply_colors()
@export var frame_highlight := Color("#F0D9A2"):
	set(value):
		frame_highlight = value
		if is_node_ready():
			_apply_colors()

@export_group("头像孔配色")
@export var fill_color := Color("#221C15"):
	set(value):
		fill_color = value
		if is_node_ready():
			_apply_colors()
@export var fill_center := Color("#2E2720"):
	set(value):
		fill_center = value
		if is_node_ready():
			_apply_colors()

@onready var _cell: ColorRect = $Cell
@onready var _portrait: TextureRect = $Portrait
@onready var _frame: TextureRect = $Frame


func _ready() -> void:
	_setup_materials()
	_apply_layout()
	_apply_colors()
	_refresh_portrait()


func _setup_materials() -> void:
	var cell_mat := ShaderMaterial.new()
	cell_mat.shader = CELL_BG_SHADER
	_cell.material = cell_mat
	var frame_mat := ShaderMaterial.new()
	frame_mat.shader = FRAME_PALETTE_SHADER
	_frame.material = frame_mat


func _apply_layout() -> void:
	size = frame_size
	# 已验收几何的逆变换：已知最终外框尺寸，反推旧代码中的 slot_rect。
	var slot_size := frame_size / FRAME_ART_SCALE
	var slot_pos := -slot_size * FRAME_OFFSET_RATIO
	var inset := slot_size * CELL_INSET_RATIO
	var inner_pos := slot_pos + inset
	var inner_size := slot_size - inset * 2.0
	_cell.position = inner_pos
	_cell.size = inner_size
	_portrait.position = inner_pos
	_portrait.size = inner_size
	_frame.position = Vector2.ZERO
	_frame.size = frame_size
	if _cell.material is ShaderMaterial:
		(_cell.material as ShaderMaterial).set_shader_parameter(
			"pixel_grid", minf(slot_size.x, slot_size.y) / 6.0)


func _apply_colors() -> void:
	if _cell.material is ShaderMaterial:
		var cell_mat := _cell.material as ShaderMaterial
		cell_mat.set_shader_parameter("fill_color", fill_color)
		cell_mat.set_shader_parameter("inner_color", fill_center)
		cell_mat.set_shader_parameter("center_glow", 1.0)
		cell_mat.set_shader_parameter("corner_radius", 0.0)
		cell_mat.set_shader_parameter("cloud_on", 0.0)
	if _frame.material is ShaderMaterial:
		var frame_mat := _frame.material as ShaderMaterial
		frame_mat.set_shader_parameter("shadow_color", frame_shadow)
		frame_mat.set_shader_parameter("mid_color", frame_mid)
		frame_mat.set_shader_parameter("highlight_color", frame_highlight)


func _refresh_portrait() -> void:
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path)
		_portrait.visible = true
	else:
		_portrait.texture = null
		_portrait.visible = false


func set_palette(shadow: Color, mid: Color, highlight: Color) -> void:
	frame_shadow = shadow
	frame_mid = mid
	frame_highlight = highlight


## 被迫换人浮层沿用原有敌我颜色语义，主菜单/图鉴则保留默认暖金中性色。
func set_faction_color(color: Color) -> void:
	if color.r > color.b:
		set_palette(ENEMY_SHADOW, ENEMY_MID, ENEMY_HIGHLIGHT)
		fill_color = Color("#321918")
		fill_center = Color("#462321")
	else:
		set_palette(PLAYER_SHADOW, PLAYER_MID, PLAYER_HIGHLIGHT)
		fill_color = Color("#152536")
		fill_center = Color("#20364D")
