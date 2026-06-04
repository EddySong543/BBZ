@tool
class_name SkillCard
extends Control

## 技能展示格 = 金色书本 / 图鉴页（方案 B+②）。
## 结构 = 烫金外框(书的装帧) + 阵营色羊皮内页 + 左侧金框「插画窗」(头像) +
##        页面右侧墨字（上=主动/被动小字 · 中=技能名 · 下=描述正文）。
##
## 外框与插画窗 = 金色 jelly（恒定金，书的装帧）；内页 = 羊皮纸 jelly，按阵营染色：
##   己方=冷调羊皮 / 对方=暖调羊皮。立绘一律朝右（不翻转）。文字=深褐墨字（羊皮纸上可读）。
##
## 纯展示组件：显示哪个英雄、如何翻页由外部（battle_screen）驱动。
## 玩家点击本格 → 发出 advance_requested，外部据此翻到下一个英雄。
## 节点布局在 skill_card.tscn 可视化编辑（节点名勿改，脚本按名取用）。

signal advance_requested

## 内页阵营染色（乘到羊皮纸上 → 冷调 / 暖调羊皮）。金色外框与插画窗恒定不染。
const ALLY_TINT := Color(0.82, 0.9, 1.0)     # 己方·冷调羊皮
const ENEMY_TINT := Color(1.0, 0.86, 0.72)   # 对方·暖调羊皮

const INK := Color(0.2, 0.14, 0.08)               # 深褐墨字
const INK_OUTLINE := Color(0.96, 0.92, 0.8, 0.45) # 浅羊皮色描边（墨字在纸纹上更清晰）

## 头像图片路径（res://...png）；空或不存在则隐藏头像。
@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_refresh_portrait()

## 英雄名（当前不单独显示，预留给后续需要时用）。
@export var hero_name: String = ""

## 技能名（显示为中间标题，如「渴血」）。
@export var skill_name: String = "":
	set(v):
		skill_name = v
		if is_node_ready():
			_refresh_text()

## 技能完整描述（显示为正文）。为空时回退显示技能名，避免空白。
@export_multiline var skill_detail: String = "":
	set(v):
		skill_detail = v
		if is_node_ready():
			_refresh_text()

## 是否主动技能（true=主动技能 / false=被动技能），决定上方小字。
@export var is_active_skill: bool = false:
	set(v):
		is_active_skill = v
		if is_node_ready():
			_refresh_text()

## 当前英雄是否己方（true=己方冷调内页 / false=对方暖调内页）。
@export var is_ally: bool = true:
	set(v):
		is_ally = v
		if is_node_ready():
			_refresh_faction()

@onready var _page: ColorRect = $Page
@onready var _portrait: TextureRect = $PortraitCell/Portrait
@onready var _type_label: Label = $TypeLabel
@onready var _desc_label: Label = $DescLabel

static var _tex_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_fonts()
	_refresh_faction()
	_refresh_portrait()
	_refresh_text()


## 像素字体（assets/font 的 Ark Pixel，关 AA），经 FontManager autoload。
## 深褐墨字 + 浅描边，压在羊皮纸内页上可读（图鉴质感）。
func _apply_fonts() -> void:
	var fm := get_node_or_null("/root/FontManager")
	if fm == null:
		return
	fm.apply(_type_label, 16)
	fm.apply(_desc_label, 16)
	for lbl in [_type_label, _desc_label]:
		lbl.add_theme_color_override("font_color", INK)
		lbl.add_theme_color_override("font_outline_color", INK_OUTLINE)
		lbl.add_theme_constant_override("outline_size", 2)


## 一次性填充（外部翻页时调用）。
func populate(p_hero_name: String, p_skill_name: String, p_skill_detail: String, p_is_active: bool, p_portrait: String, p_is_ally: bool) -> void:
	hero_name = p_hero_name
	skill_name = p_skill_name
	skill_detail = p_skill_detail
	is_active_skill = p_is_active
	is_ally = p_is_ally
	portrait_path = p_portrait


## 内页阵营染色：羊皮纸 × 冷/暖。金色外框与插画窗恒定不变。
func _refresh_faction() -> void:
	if _page:
		_page.color = ALLY_TINT if is_ally else ENEMY_TINT


func _refresh_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	var tex: Texture2D
	if _tex_cache.has(portrait_path):
		tex = _tex_cache[portrait_path]
	else:
		tex = load(portrait_path)
		_tex_cache[portrait_path] = tex
	_portrait.texture = tex
	_portrait.visible = true


func _refresh_text() -> void:
	if not _type_label:
		return
	_type_label.text = "主动技能" if is_active_skill else "被动技能"
	# 技能名与描述同段「名：描述」，名与描述间不换行（描述未补则仅显示技能名）。
	var body := skill_detail.strip_edges()
	if skill_name != "" and body != "":
		_desc_label.text = "%s：%s" % [skill_name, body]
	elif skill_name != "":
		_desc_label.text = skill_name
	else:
		_desc_label.text = body


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance_requested.emit()
			accept_event()
