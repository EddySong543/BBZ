class_name HeroFrame
extends Panel

## 竹节像素头像框(甲A + 底色兜底)：满幅头像 + canvas shader 像素边框 + 矢量菱形角饰 + 阵营暗底。
## profilePics 是带背景方图 → 填满框内(stretch COVERED + clip)；底色层(BgFill)兜底头像没覆盖处(如底部)。
## 节点层级(自下而上)：BgFill → Portrait 头像(像素化+posterize·nearest) → InnerFX 内阴影+扫描线 → Bg 像素边框 → Corners 四角阵营宝石 → NameLabel。
## 边框统一「浅锡灰」(简约像素感·中性不偏阵营·出战/替补/敌我同款)；敌我=Corners 四角阵营宝石(我方蓝 / 敌方红)。
## 内部FX：Portrait 走 PortraitMat(pixelate/posterize) 统一像素颗粒；InnerFX 走 InnerFXMat(暗角 vignette + 极淡扫描线)。阵亡=灰边/灰宝石+头像灰。

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

## 选中态：替补被点选、准备换人时高亮（提亮边框/宝石 + 轻微放大）→ 给"点击头像换人"明确反馈。
@export var is_selected: bool = false:
	set(v):
		is_selected = v
		if is_node_ready():
			_refresh_style()
			pivot_offset = size * 0.5
			scale = Vector2.ONE * (1.08 if v else 1.0)

@export var player_color: Color = Color("#3f86c8"):
	set(v):
		player_color = v
		if is_node_ready():
			_refresh_style()

## ★ 圆角统一控制 ★ —— UV 比例半径(0=直角)，一处同步到全部 4 层(边框/头像/内阴影/底色)的像素圆角。
## 想整体调圆角就改这一个值（或在 HeroFrame 节点的 Inspector 改）。
@export_range(0.0, 0.4, 0.005) var corner_radius: float = 0.3:
	set(v):
		corner_radius = v
		if is_node_ready():
			_apply_corner_radius()

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
var _inner_fx: ColorRect
var _corners: Control
static var _cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# 入树时套用 frame_size → size。frame_size 的 setter 仅在 is_node_ready() 才应用，
	# 若调用方在 add_child(节点未 ready·如游离 wrap) 之前设 frame_size，size 会停在默认值；
	# 这里在 _ready 兜底套用，保证任何用法下框尺寸都正确（修被动换人浮窗头像不对齐）。
	size = frame_size
	_setup_children()
	_apply_corner_radius()
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
	_portrait = _find_child_named("Portrait") as TextureRect
	_bg = _find_child_named("Bg") as ColorRect
	_bg_fill = _find_child_named("BgFill") as ColorRect
	_inner_fx = _find_child_named("InnerFX") as ColorRect
	_corners = _find_child_named("Corners") as Control
	_name_label = _find_child_named("NameLabel") as Label
	if _name_label:
		_name_label.visible = false   # 头像框不显示英雄名(节点保留备用)


func _find_child_named(cname: String) -> Node:
	for c in get_children():
		if c.name == cname:
			return c
	return null


## 把 corner_radius 一处同步到 4 层材质(边框/头像/内阴影/底色) → 统一控制圆角。
func _apply_corner_radius() -> void:
	for n in [_bg, _portrait, _inner_fx, _bg_fill]:
		if n != null and n.material is ShaderMaterial:
			(n.material as ShaderMaterial).set_shader_parameter("corner_radius", corner_radius)


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
	# 边框统一中性「深板岩」(faction-neutral·占位色, 出战/替补/敌我同款)；
	# 敌我改由 Corners 四角阵营宝石(蓝/红)区分。头像像素化/内阴影/扫描线由 PortraitMat + InnerFX 处理(常驻·与状态无关)。仅阵亡转灰。
	var pc := player_color
	var e_outer: Color
	var e_mid: Color
	var e_inner: Color
	var corner: Color
	var fill: Color
	if is_dead:
		e_outer = Color(0.04, 0.04, 0.05)
		e_mid = Color(0.28, 0.29, 0.32)
		e_inner = Color(0.16, 0.16, 0.18)
		corner = Color(0.4, 0.4, 0.44)
		fill = Color(0.1, 0.1, 0.11)
	else:
		e_outer = Color(0.05, 0.05, 0.06)  # 深色细描边(让浅框在夜空里清晰勾出)
		e_mid = Color(0.65, 0.67, 0.71)    # 浅锡灰(简约像素感·中性不偏阵营)
		e_inner = Color(0.34, 0.36, 0.39)  # 中灰内线
		corner = pc                         # 阵营宝石(蓝/红)
		fill = Color(0.1, 0.1, 0.12)

	# 选中高亮（换人待确认）：提亮边框 + 宝石。
	if is_selected and not is_dead:
		e_mid = e_mid.lightened(0.4)
		e_inner = e_inner.lightened(0.3)
		corner = corner.lightened(0.45)

	if _bg and _bg.material is ShaderMaterial:
		var m := _bg.material as ShaderMaterial
		m.set_shader_parameter("edge_outer", e_outer)
		m.set_shader_parameter("edge_mid", e_mid)
		m.set_shader_parameter("edge_inner", e_inner)

	if _bg_fill:
		_bg_fill.color = fill

	if _corners:
		_corners.set("corner_color", corner)
		_corners.set("dead", is_dead)   # 死亡→四角宝石对角连线成 X

	if _portrait:
		if is_dead:
			(_portrait as TextureRect).modulate = Color(0.45, 0.45, 0.5)
		else:
			(_portrait as TextureRect).modulate = Color.WHITE

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""


func set_hp(_hp: int, _max_hp: int) -> void:
	pass
