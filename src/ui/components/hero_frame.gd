class_name HeroFrame
extends Panel

## 竹节像素头像框(甲A + 底色兜底)：满幅头像 + canvas shader 像素边框 + 矢量菱形角饰 + 阵营暗底。
## profilePics 是带背景方图 → 填满框内(stretch COVERED + clip)；底色层(BgFill)兜底头像没覆盖处(如底部)。
## 节点层级(自下而上)：BgFill 底色 → Portrait 头像 → Bg shader 边框 → Corners 矢量菱形角饰 → NameLabel。
## 状态：出战=亮阵营边/角+略亮底；替补=暗阵营边/角；阵亡=灰边/角+头像灰。阵营色 P1蓝/P2红。

@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_refresh_portrait()

@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready() and _name_label:
			(_name_label as Label).text = v.substr(0, 2)

@export var is_active: bool = false:
	set(v):
		is_active = v
		if is_node_ready():
			_refresh_style()

@export var player_color: Color = Color("#3388dd"):
	set(v):
		player_color = v
		if is_node_ready():
			_refresh_style()

@export var is_dead: bool = false:
	set(v):
		is_dead = v
		if is_node_ready():
			_refresh_style()

@export var frame_size: Vector2 = Vector2(72, 72):
	set(v):
		frame_size = v
		if is_node_ready():
			size = v

## 头像水平翻转（P2 对手头像朝左用）。
@export var flip_h: bool = false:
	set(v):
		flip_h = v
		if is_node_ready() and _portrait:
			(_portrait as TextureRect).flip_h = v

var _portrait: TextureRect
var _name_label: Label
var _bg: ColorRect
var _bg_fill: ColorRect
var _corners: Control
static var _cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_setup_children()
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
	_portrait = _find_child_named("Portrait") as TextureRect
	_bg = _find_child_named("Bg") as ColorRect
	_bg_fill = _find_child_named("BgFill") as ColorRect
	_corners = _find_child_named("Corners") as Control
	_name_label = _find_child_named("NameLabel") as Label
	if _name_label:
		_name_label.visible = false   # 头像框不显示英雄名(节点保留备用)


func _find_child_named(cname: String) -> Node:
	for c in get_children():
		if c.name == cname:
			return c
	return null


func _refresh_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	# profilePics 是带背景方图(无透明边)，整图填满即可，无需裁切。
	var tex: Texture2D
	if _cache.has(portrait_path):
		tex = _cache[portrait_path]
	else:
		tex = load(portrait_path)
		_cache[portrait_path] = tex
	(_portrait as TextureRect).texture = tex
	(_portrait as TextureRect).visible = true
	(_portrait as TextureRect).flip_h = flip_h


func _refresh_style() -> void:
	var pc := player_color
	var e_outer := Color(0.04, 0.04, 0.06)
	var e_mid: Color
	var e_inner: Color
	var corner: Color
	var fill: Color
	if is_dead:
		e_mid = Color(0.3, 0.3, 0.34)
		e_inner = Color(0.18, 0.18, 0.2)
		corner = Color(0.36, 0.36, 0.4)
		fill = Color(0.1, 0.1, 0.12)
	elif is_active:
		e_mid = pc.lightened(0.2)
		e_inner = pc.darkened(0.35)
		corner = pc.lightened(0.45)
		fill = pc.darkened(0.6)
	else:
		e_mid = pc.darkened(0.12)
		e_inner = pc.darkened(0.45)
		corner = pc
		fill = pc.darkened(0.72)

	if _bg and _bg.material is ShaderMaterial:
		var m := _bg.material as ShaderMaterial
		m.set_shader_parameter("edge_outer", e_outer)
		m.set_shader_parameter("edge_mid", e_mid)
		m.set_shader_parameter("edge_inner", e_inner)

	if _bg_fill:
		_bg_fill.color = fill

	if _corners:
		_corners.set("corner_color", corner)

	if _portrait:
		if is_dead:
			(_portrait as TextureRect).modulate = Color(0.45, 0.45, 0.5)
		elif is_active:
			(_portrait as TextureRect).modulate = Color.WHITE
		else:
			(_portrait as TextureRect).modulate = Color(0.85, 0.85, 0.9)

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""


func set_hp(_hp: int, _max_hp: int) -> void:
	pass
