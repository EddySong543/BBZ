class_name HeroFrame
extends Panel

## Self-contained hero frame: portrait texture + name overlay.
## Drop into any scene, set portrait_path + hero_name, resize as needed.

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

## 头像框阵营染色（乘到中性深蓝灰底 → P1 冷蓝 / P2 暖红，一眼分敌我）。
const ALLY_FRAME_TINT := Color(0.74, 0.9, 1.22)    # 己方·冷蓝（player_color 偏蓝时）
const ENEMY_FRAME_TINT := Color(1.22, 0.82, 0.78)  # 对方·暖红（player_color 偏红时）

var _portrait: TextureRect
var _name_label: Label
var _bg: ColorRect                # 边框果冻底（阵营色染到它上，不影响 modulate 出战/阵亡）
var _base_stylebox: StyleBoxFlat  # P1-NEW2: 从 .tscn 取 default，state 切换基于此 duplicate
static var _cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_children()
	_base_stylebox = get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
	_bg = get_node_or_null("Bg") as ColorRect
	_portrait = _find_or_create_texture_rect("Portrait")
	_name_label = _find_or_create_label("NameLabel")
	(_name_label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_name_label as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(_name_label as Label).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_name_label as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_name_label as Label).add_theme_font_size_override("font_size", 12)
	(_name_label as Label).add_theme_color_override("font_color", Color.WHITE)
	(_name_label as Label).add_theme_color_override("font_outline_color", Color("#000000"))
	(_name_label as Label).add_theme_constant_override("outline_size", 2)
	(_name_label as Label).visible = false   # 任务4：头像框不再显示英雄名（节点保留备用）


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
		tex = load(portrait_path)
		_cache[portrait_path] = tex
	(_portrait as TextureRect).texture = tex
	(_portrait as TextureRect).visible = true
	(_portrait as TextureRect).flip_h = flip_h


func _refresh_style() -> void:
	# 像素徽章边框由子节点 Bg(中性深蓝灰 jelly) 绘制；阵营色染到 Bg、出战/阵亡用整框 modulate。
	var faction := ALLY_FRAME_TINT if player_color.b >= player_color.r else ENEMY_FRAME_TINT
	if is_dead:
		modulate = Color(0.5, 0.5, 0.55)
		if _bg:
			_bg.modulate = Color(0.62, 0.62, 0.68)   # 阵亡：去阵营色、压暗
		if _portrait:
			(_portrait as TextureRect).modulate = Color(0.4, 0.4, 0.4)
	elif is_active:
		modulate = Color(1.16, 1.22, 1.32)           # 出战高亮：中性冷亮（不撞金/铜）
		if _bg:
			_bg.modulate = faction * 1.12             # 出战边框：阵营色更亮
		if _portrait:
			(_portrait as TextureRect).modulate = Color.WHITE
	else:
		modulate = Color.WHITE
		if _bg:
			_bg.modulate = faction                    # 待选边框：常驻阵营色
		if _portrait:
			(_portrait as TextureRect).modulate = Color.WHITE

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""


func set_hp(_hp: int, _max_hp: int) -> void:
	pass
