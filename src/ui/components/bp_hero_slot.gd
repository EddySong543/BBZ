class_name BPHeroSlot
extends Panel

## BP 阶段阵容预览中的单个英雄槽位。
## placeholder — 后期换美术素材时整体替换本 .tscn / .gd。

@export var player_color: Color = Color("#444466"):
	set(v):
		player_color = v
		if is_node_ready():
			_apply_border()

@onready var _portrait: TextureRect = $PortraitThumb
@onready var _name_label: Label = $NameLabel
@onready var _hp_label: Label = $HPLabel

static var _portrait_cache: Dictionary = {}


func _ready() -> void:
	FontManager.apply(_name_label, 13)
	FontManager.apply(_hp_label, 12)
	_apply_border()


## 用一个英雄填充槽位（显示立绘 + 名字 + HP，边框高亮为 player_color）。
func set_hero(h: HeroData) -> void:
	if not is_node_ready():
		return
	_name_label.text = h.hero_name
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.text = "❤%d" % h.max_hp
	_hp_label.add_theme_color_override("font_color", Color("#ff6666"))
	_hp_label.visible = true
	_load_portrait(h.portrait_path)
	_set_border_active(true)


## 清空槽位（显示"英雄"占位文本，灰色边框）。
func clear() -> void:
	if not is_node_ready():
		return
	_name_label.text = "英雄"
	_name_label.add_theme_color_override("font_color", Color("#aaaacc"))
	_hp_label.visible = false
	_portrait.visible = false
	_set_border_active(false)


func _load_portrait(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		_portrait.visible = false
		return
	var tex: Texture2D
	if _portrait_cache.has(path):
		tex = _portrait_cache[path]
	else:
		tex = load(path)
		_portrait_cache[path] = tex
	_portrait.texture = tex
	_portrait.visible = true


func _apply_border() -> void:
	_set_border_active(false)


func _set_border_active(active: bool) -> void:
	# P1-NEW2: base stylebox 是 .tscn 内 StyleBoxFlat_default SubResource。
	# inactive 状态 = base (灰边 2px); active = duplicate base + 改 border_color/width
	remove_theme_stylebox_override("panel")
	if active:
		var base := get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if base == null:
			return
		var sb := base.duplicate() as StyleBoxFlat
		sb.border_color = player_color
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		add_theme_stylebox_override("panel", sb)
