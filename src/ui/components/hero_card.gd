class_name HeroCard
extends Button

## Ban/Pick 英雄卡 —— 像素框风格（复用战斗/图鉴的边框 shader + 四角阵营宝石 corner_overlay）。
## 结构（hero_card.tscn）：PortraitCell( BgFill 暗底 + Portrait 头像 posterize + InnerFX 内阴影
##   + Frame 像素边框 + Corners 四角宝石 + HPBadge ) + NameLabel。
## 5 态视觉由代码设 Frame 的 edge_* uniform + Corners.corner_color/dead 实现：
##   NORMAL 锡灰 / SELECTED 描金+宝石 / PICKED_P1 蓝 / PICKED_P2 红 / BANNED 灰暗+对角X+头像灰。
## 选中态额外走 ButtonJuice 放大；禁用态走 corner_overlay 的 dead（四角宝石连成 X，呼应"禁用"）。

enum CardState { NORMAL, SELECTED, PICKED_P1, PICKED_P2, BANNED }

@export var hero_id: String = ""
@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready():
			_refresh_text()
@export var max_hp: int = 10:
	set(v):
		max_hp = v
		if is_node_ready():
			_refresh_text()
@export var role_text: String = ""        # 保留字段（调用方设置）；当前卡面暂不展示职业
@export var position_text: String = ""     # 同上
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

var _portrait: TextureRect
var _frame: ColorRect
var _corners: Control
var _name_label: Label
var _hp_badge: IconBadge          # 爱心内嵌血量数字（骑在框外左上角·任务1）
var _juice: ButtonJuice
static var _portrait_cache: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(130, 158)
	# 去掉默认按钮外观（像素框 shader 当外观），各态统一空 stylebox。
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())

	_portrait = $PortraitCell/Portrait
	_frame = $PortraitCell/Frame
	_corners = $PortraitCell/Corners
	_name_label = $NameLabel
	_hp_badge = $HPBadge

	FontManager.apply(_name_label, 16)
	_style_text(_name_label, Color.WHITE)

	_juice = ButtonJuice.new()
	_juice.name = "ButtonJuice"
	add_child(_juice)

	_load_portrait()
	_refresh_text()
	_refresh_style()


## 文字描黑边 + 投影 → 在头像/夜空上清晰可读。
func _style_text(lbl: Label, col: Color) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))


func _refresh_text() -> void:
	if _name_label:
		_name_label.text = hero_name
	if _hp_badge:
		_hp_badge.set_number(max_hp)


func _load_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	var tex: Texture2D
	if _portrait_cache.has(portrait_path):
		tex = _portrait_cache[portrait_path]
	else:
		tex = load(portrait_path)
		_portrait_cache[portrait_path] = tex
	_portrait.texture = tex
	_portrait.visible = true


func _refresh_style() -> void:
	# 边框三层色 + 四角宝石色 + 头像变灰 + 选中放大，按 card_state 切换。
	var e_outer := Color(0.05, 0.05, 0.06)
	var e_mid := Color(0.65, 0.67, 0.71)   # 锡灰（中性）
	var e_inner := Color(0.34, 0.36, 0.39)
	var gem := Color(0.55, 0.58, 0.64)     # 中性淡宝石
	var dead := false
	var port_mod := Color.WHITE
	var name_col := Color.WHITE

	match card_state:
		CardState.SELECTED:
			e_mid = Color(0.99, 0.85, 0.5)     # 描金
			e_inner = Color(0.6, 0.46, 0.16)
			gem = Color(0.99, 0.85, 0.5)
			name_col = Color(1.0, 0.92, 0.66)
		CardState.PICKED_P1:
			e_mid = Color(0.36, 0.6, 0.9)      # 我方蓝
			e_inner = Color(0.16, 0.28, 0.48)
			gem = Color(0.4, 0.66, 1.0)
			name_col = Color(0.74, 0.86, 1.0)
		CardState.PICKED_P2:
			e_mid = Color(0.85, 0.36, 0.32)    # 敌方红
			e_inner = Color(0.46, 0.16, 0.15)
			gem = Color(0.95, 0.42, 0.38)
			name_col = Color(1.0, 0.78, 0.74)
		CardState.BANNED:
			e_outer = Color(0.03, 0.03, 0.04)
			e_mid = Color(0.3, 0.3, 0.33)
			e_inner = Color(0.15, 0.15, 0.17)
			gem = Color(0.62, 0.63, 0.7)       # 禁用灰（四角宝石 + 对角 X 共用此色）
			dead = true                         # 四角宝石对角连成 X（=禁用）
			port_mod = Color(0.38, 0.38, 0.43) # 头像压暗转灰
			name_col = Color(0.5, 0.5, 0.56)

	if _frame and _frame.material is ShaderMaterial:
		var m := _frame.material as ShaderMaterial
		m.set_shader_parameter("edge_outer", e_outer)
		m.set_shader_parameter("edge_mid", e_mid)
		m.set_shader_parameter("edge_inner", e_inner)

	if _corners:
		_corners.set("corner_color", gem)
		_corners.set("dead", dead)

	if _portrait:
		_portrait.modulate = port_mod

	if _name_label:
		_name_label.add_theme_color_override("font_color", name_col)
	if _hp_badge:
		_hp_badge.modulate = Color(0.5, 0.5, 0.56) if card_state == CardState.BANNED else Color.WHITE

	if _juice:
		_juice.set_selected(card_state == CardState.SELECTED)
