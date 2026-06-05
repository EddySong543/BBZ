class_name HeroFrame
extends Panel

## 竹节叠框头像框(乙)：多层像素描边 + 四角东方菱形角饰 + 底部锚定 + 阵营色。
## 全部 _draw() 程序化绘制(无贴图)。状态：出战=边/角全亮+底略亮；替补=边角压暗；阵亡=灰化+头像灰。
## 构图不齐用"底锚"近似统一：Portrait rect 偏下，各英雄肩部大致落在框底同一带。

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
			queue_redraw()

## 头像水平翻转（P2 对手头像朝左用）。
@export var flip_h: bool = false:
	set(v):
		flip_h = v
		if is_node_ready() and _portrait:
			(_portrait as TextureRect).flip_h = v

## 头像内容自动裁切的留白比例：检测非透明内容边界后向外留这么多边，再放大填充框。
## 0=内容贴边填满；越大留白越多。把"构图疏"的头像自动放大、减少框内空旷。
@export var trim_padding: float = 0.12:
	set(v):
		trim_padding = v
		_cache.clear()
		if is_node_ready():
			_refresh_portrait()

var _portrait: TextureRect
var _name_label: Label
# 当前状态色（由 _refresh_style 写、_draw 读）
var _bg_top: Color = Color(0.12, 0.13, 0.17)
var _bg_bottom: Color = Color(0.07, 0.08, 0.11)
var _edge_outer: Color = Color(0.04, 0.04, 0.06)
var _edge_mid: Color = Color(0.3, 0.5, 0.85)
var _edge_inner: Color = Color(0.15, 0.25, 0.45)
var _corner_color: Color = Color(0.5, 0.7, 1.0)
static var _cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # 关闭默认 Panel 底，全靠 _draw
	_setup_children()
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
	_portrait = _find_or_create_texture_rect("Portrait")
	_name_label = _find_or_create_label("NameLabel")
	(_name_label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_name_label as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(_name_label as Label).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_name_label as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_name_label as Label).visible = false


func _find_or_create_texture_rect(cname: String) -> TextureRect:
	for c in get_children():
		if c is TextureRect and c.name == cname:
			return c as TextureRect
	var tr := TextureRect.new()
	tr.name = cname
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tr)
	return tr


func _find_or_create_label(cname: String) -> Label:
	for c in get_children():
		if c is Label and c.name == cname:
			return c as Label
	var lbl := Label.new()
	lbl.name = cname
	add_child(lbl)
	return lbl


func _refresh_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	var tex: Texture2D
	if _cache.has(portrait_path):
		tex = _cache[portrait_path]
	else:
		tex = _build_trimmed_texture(portrait_path)
		_cache[portrait_path] = tex
	(_portrait as TextureRect).texture = tex
	(_portrait as TextureRect).visible = true
	(_portrait as TextureRect).flip_h = flip_h


## 裁掉头像四周透明留白(向外留 trim_padding 边)，返回 AtlasTexture。
## "构图疏"的头像内容区小 → 裁出后由 KEEP_ASPECT 放大填充框 → 自动减少框内空旷。
func _build_trimmed_texture(path: String) -> Texture2D:
	var src: Texture2D = load(path)
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return src
	var pad := int(round(float(maxi(used.size.x, used.size.y)) * trim_padding))
	used = used.grow(pad)
	used = used.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = Rect2(used)
	return atlas


func _refresh_style() -> void:
	var pc := player_color
	if is_dead:
		_bg_top = Color(0.11, 0.11, 0.13)
		_bg_bottom = Color(0.06, 0.06, 0.08)
		_edge_outer = Color(0.04, 0.04, 0.05)
		_edge_mid = Color(0.3, 0.3, 0.34)
		_edge_inner = Color(0.18, 0.18, 0.2)
		_corner_color = Color(0.32, 0.32, 0.36)
	elif is_active:
		_bg_top = pc.darkened(0.5)
		_bg_bottom = pc.darkened(0.68)
		_edge_outer = Color(0.04, 0.04, 0.06)
		_edge_mid = pc.lightened(0.2)
		_edge_inner = pc.darkened(0.35)
		_corner_color = pc.lightened(0.4)
	else:
		_bg_top = pc.darkened(0.62)
		_bg_bottom = pc.darkened(0.76)
		_edge_outer = Color(0.04, 0.04, 0.06)
		_edge_mid = pc.darkened(0.1)
		_edge_inner = pc.darkened(0.45)
		_corner_color = pc.darkened(0.02)

	if _portrait:
		if is_dead:
			(_portrait as TextureRect).modulate = Color(0.42, 0.42, 0.47)
		elif is_active:
			(_portrait as TextureRect).modulate = Color.WHITE
		else:
			(_portrait as TextureRect).modulate = Color(0.86, 0.86, 0.92)

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""

	queue_redraw()


func _draw() -> void:
	var sz := size
	var full := Rect2(Vector2.ZERO, sz)
	# 三层像素描边(从外到内填充叠加)：外暗轮廓 1px → 中阵营 2px → 内深阵营 1px
	draw_rect(full, _edge_outer, true)
	draw_rect(full.grow(-1.0), _edge_mid, true)
	draw_rect(full.grow(-3.0), _edge_inner, true)
	# 内部底色：竖向两段近似渐变(上稍亮、下稍暗)
	var inner := full.grow(-4.0)
	draw_rect(inner, _bg_bottom, true)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5)), _bg_top, true)
	# 四角东方菱形角饰(钉饰)
	var inset := 7.0
	var r := 2.5
	var corners := [
		Vector2(inset, inset),
		Vector2(sz.x - inset, inset),
		Vector2(inset, sz.y - inset),
		Vector2(sz.x - inset, sz.y - inset),
	]
	for c in corners:
		var pts := PackedVector2Array([
			c + Vector2(0.0, -r), c + Vector2(r, 0.0),
			c + Vector2(0.0, r), c + Vector2(-r, 0.0),
		])
		draw_colored_polygon(pts, _corner_color)


func set_hp(_hp: int, _max_hp: int) -> void:
	pass
