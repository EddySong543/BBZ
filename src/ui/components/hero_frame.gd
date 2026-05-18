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

var _portrait: TextureRect
var _name_label: Label
var _base_stylebox: StyleBoxFlat  # P1-NEW2: 从 .tscn 取 default，state 切换基于此 duplicate
static var _cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_children()
	_base_stylebox = get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
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


func _refresh_style() -> void:
	# P1-NEW2: base stylebox 来自 .tscn theme_override_styles/panel (FrameBase SubResource)
	# 美术换素材 → 改 .tscn FrameBase；state 差异（颜色/宽度）由下方 code 派生
	if _base_stylebox == null:
		return
	var sb := _base_stylebox.duplicate() as StyleBoxFlat

	if is_dead:
		sb.bg_color = Color("#1a1a1a")
		sb.border_color = Color("#444444")
		if _portrait:
			(_portrait as TextureRect).modulate = Color(0.35, 0.35, 0.35)
	elif is_active:
		sb.border_color = Color("#ffdd44")
		sb.border_width_left = 5
		sb.border_width_right = 5
		sb.border_width_top = 5
		sb.border_width_bottom = 5
		if _portrait:
			(_portrait as TextureRect).modulate = Color.WHITE
	else:
		sb.border_color = player_color
		if _portrait:
			(_portrait as TextureRect).modulate = Color.WHITE

	add_theme_stylebox_override("panel", sb)

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""


func set_hp(_hp: int, _max_hp: int) -> void:
	pass
