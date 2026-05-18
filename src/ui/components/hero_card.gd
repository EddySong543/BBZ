class_name HeroCard
extends Button

## Self-contained hero card for the Ban/Pick screen.
## Drop into any scene, set hero data via exports, see layout in editor.

@export var hero_id: String = ""
@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready() and _name_label:
			(_name_label as Label).text = v
@export var max_hp: int = 10:
	set(v):
		max_hp = v
		if is_node_ready() and _hp_label:
			(_hp_label as Label).text = "❤ %d" % v
@export var role_text: String = "":
	set(v):
		role_text = v
		if is_node_ready() and _role_label:
			(_role_label as Label).text = v
			(_role_label as Label).add_theme_color_override("font_color", _role_color(v))
@export var position_text: String = "":
	set(v):
		position_text = v
		if is_node_ready() and _pos_label:
			(_pos_label as Label).text = v
@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_load_portrait()

@export var card_state: int = 0:
	set(v):
		card_state = v
		if is_node_ready():
			_refresh_style()

enum CardState { NORMAL, SELECTED, PICKED_P1, PICKED_P2, BANNED }

var _portrait: TextureRect
var _name_label: Label
var _hp_label: Label
var _role_label: Label
var _pos_label: Label
static var _portrait_cache: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(130, 130)
	_setup_children()
	_load_portrait()
	_refresh_style()


func _setup_children() -> void:
	_portrait = _find_or_create_texture_rect("PortraitThumb", Vector2(4, 4), Vector2(40, 40))
	_name_label = _create_label("NameLabel", hero_name, 16, Color.WHITE, Vector2(0, 8), Vector2(130, 22))
	_hp_label = _create_label("HPLabel", "❤ %d" % max_hp, 12, Color("#ff6666"), Vector2(0, 32), Vector2(130, 18))
	_role_label = _create_label("RoleLabel", role_text, 12, _role_color(role_text), Vector2(0, 52), Vector2(130, 18))
	_pos_label = _create_label("PosLabel", position_text, 12, Color("#777799"), Vector2(0, 70), Vector2(130, 16))


func _find_or_create_texture_rect(cname: String, pos: Vector2, sz: Vector2) -> TextureRect:
	for c in get_children():
		if c is TextureRect and c.name == cname:
			return c as TextureRect
	var tr := TextureRect.new()
	tr.name = cname
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = pos
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _create_label(cname: String, text: String, size_px: int, color: Color, pos: Vector2, sz: Vector2) -> Label:
	var lbl := Label.new()
	lbl.name = cname
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = pos
	lbl.size = sz
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontManager.apply(lbl, size_px)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	add_child(lbl)
	return lbl


func _load_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		(_portrait as TextureRect).visible = false
		(_portrait as TextureRect).position = Vector2(4, 4)
		(_portrait as TextureRect).size = Vector2(40, 40)
		_set_labels_visible(true)
		return
	var tex: Texture2D
	if _portrait_cache.has(portrait_path):
		tex = _portrait_cache[portrait_path]
	else:
		tex = load(portrait_path)
		_portrait_cache[portrait_path] = tex
	(_portrait as TextureRect).texture = tex
	(_portrait as TextureRect).visible = true
	(_portrait as TextureRect).position = Vector2(8, 8)
	(_portrait as TextureRect).size = Vector2(114, 114)
	_set_labels_visible(false)


func _set_labels_visible(vis: bool) -> void:
	if _name_label:
		(_name_label as Label).visible = vis
	if _hp_label:
		(_hp_label as Label).visible = vis
	if _role_label:
		(_role_label as Label).visible = vis
	if _pos_label:
		(_pos_label as Label).visible = vis


func _refresh_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#252540")
	sb.border_color = Color("#3a3a5a")
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)

	match card_state:
		CardState.SELECTED:
			sb.border_color = Color("#ffdd44")
			sb.border_width_left = 4
			sb.border_width_right = 4
			sb.border_width_top = 4
			sb.border_width_bottom = 4
		CardState.PICKED_P1:
			sb.border_color = Color("#4488ff")
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
		CardState.PICKED_P2:
			sb.border_color = Color("#ff4444")
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
		CardState.BANNED:
			sb.bg_color = Color("#1a1a1a")
			sb.border_color = Color("#442222")

	add_theme_stylebox_override("normal", sb)

	var sb_hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color("#303055")
	sb_hover.border_color = Color("#5a5a8a")
	add_theme_stylebox_override("hover", sb_hover)


func _role_color(role: String) -> Color:
	match role:
		"进攻型": return Color("#dd4444")
		"防御型": return Color("#4488dd")
		"反制型": return Color("#dd8833")
		"经济型": return Color("#33aa33")
		"骗招型": return Color("#aa44aa")
		"爆发型": return Color("#dd3333")
		"赌博型": return Color("#ddaa33")
		"切换型": return Color("#33aaaa")
		"蓄势型": return Color("#8888cc")
	return Color("#888899")
