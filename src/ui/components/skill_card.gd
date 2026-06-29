@tool
class_name SkillCard
extends Control

## 技能展示格 = 金色书本 / 图鉴页（方案 B+②）。
## 结构 = 烫金外框(书的装帧) + 阵营色羊皮内页 + 左侧金框「插画窗」(头像) +
##        页面右侧墨字（上=英雄名(标题) · 下=【技能名】：技能描述）。
##
## 外框与插画窗 = 金色 jelly（恒定金，书的装帧）；内页 = 羊皮纸 jelly，按阵营染色：
##   己方=冷调羊皮 / 对方=暖调羊皮。立绘一律朝右（不翻转）。文字=深褐墨字（羊皮纸上可读）。
##
## 纯展示组件：显示哪个英雄、如何翻页由外部（battle_screen）驱动。
## 玩家点击本格 → 发出 advance_requested，外部据此翻到下一个英雄。
## 节点布局在 skill_card.tscn 可视化编辑（节点名勿改，脚本按名取用）。

signal advance_requested   # 左键 → 下一个英雄
signal back_requested      # 右键 → 上一个英雄

## 内页阵营染色（乘到羊皮纸上 → 冷调 / 暖调羊皮）。金色外框与插画窗恒定不染。
const ALLY_TINT := Color(0.94, 0.95, 0.98)   # 己方·近中性微冷(2026-06-28：原0.82冷调把暖羊皮压冷显暗→提亮，阵营靠四角宝石区分)
const ENEMY_TINT := Color(1.0, 0.91, 0.80)   # 对方·暖调羊皮·小提亮

## 敌我区分（呼应战斗内头像框的四角阵营宝石语言）：插画窗四角宝石染阵营色（己方蓝 / 敌方红）。
## 注：角色名已从 skillcard 移除；主被动标签的阵营染色已按「先统一黑色」停用。
const ALLY_GEM := Color("#3f86c8")   # 己方蓝（与战斗内头像框宝石同色）
const ENEMY_GEM := Color("#d24a44")  # 敌方红

const INK := Color(0.14, 0.09, 0.04)              # 深褐墨字（描述正文）·加深提升可读性·同色描边做仿粗体

## 主动 / 被动 标签配色（在米黄羊皮纸上可读、冷暖区分）：主动=赤红（进攻），被动=靛蓝（恒常）。
# 主动/被动标签：改用暖土色系，避免鲜红/亮蓝与金色羊皮书本背景冲突。
const ACTIVE_COLOR := Color(0.66, 0.3, 0.12)   # 赭红橙（暖·主动=进攻）
const PASSIVE_COLOR := Color(0.34, 0.4, 0.46)  # 黛蓝灰（去饱和·被动=恒常，远比原亮蓝柔和）

## 头像图片路径（res://...png）；空或不存在则隐藏头像。
@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_refresh_portrait()

## 技能图标（符号徽记·插画窗右下角徽章）；空或不存在则隐藏。
@export var skill_icon_path: String = "":
	set(v):
		skill_icon_path = v
		if is_node_ready():
			_refresh_skill_icon()

## 英雄名（显示为右页顶部标题，原「主动/被动技能」位置）。
@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready():
			_refresh_text()

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
@onready var _skill_icon: TextureRect = $PortraitCell/SkillIcon
@onready var _type_label: Label = $TypeLabel
@onready var _desc_label: RichTextLabel = $DescLabel
@onready var _corners: Control = $PortraitCell/Corners

static var _tex_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_fonts()
	_refresh_faction()
	_refresh_portrait()
	_refresh_skill_icon()
	_refresh_text()


## 像素字体（assets/font 的 Ark Pixel，关 AA），经 FontManager autoload。
## 深褐墨字 + 浅描边，压在羊皮纸内页上可读（图鉴质感）。
## TypeLabel(英雄名标题)颜色与加粗在 _refresh_text 设；DescLabel 是 RichTextLabel，
## 字体/颜色用 normal_font/default_color 键，【技能名】加粗靠 BBCode 描边。
func _apply_fonts() -> void:
	var fm := get_node_or_null("/root/FontManager")
	if fm == null:
		return
	fm.apply(_type_label, 16)
	if _desc_label and fm.f16:
		_desc_label.add_theme_font_override("normal_font", fm.f16)
		_desc_label.add_theme_font_size_override("normal_font_size", 16)
		_desc_label.add_theme_color_override("default_color", INK)
		# 「太细看不清」修复：描边由原来的浅羊皮色(halo·削弱对比)改为同墨色做仿粗体
		# （笔画 1px→2px 变粗变实，与技能名同款）；像素字体保持 16px——整数倍才清晰，
		# 放大到 18/24 会糊或溢出卡片(描述区仅 230×68px)。
		_desc_label.add_theme_color_override("font_outline_color", INK)
		_desc_label.add_theme_constant_override("outline_size", 1)


## 一次性填充（外部翻页时调用）。
func populate(p_hero_name: String, p_skill_name: String, p_skill_detail: String, p_is_active: bool, p_portrait: String, p_is_ally: bool, p_skill_icon: String = "") -> void:
	hero_name = p_hero_name
	skill_name = p_skill_name
	skill_detail = p_skill_detail
	is_active_skill = p_is_active
	is_ally = p_is_ally
	portrait_path = p_portrait
	skill_icon_path = p_skill_icon


## 阵营区分：羊皮纸冷/暖 + 插画窗四角宝石蓝/红（文字一律黑色，敌我只靠宝石+羊皮冷暖）。
func _refresh_faction() -> void:
	if _page:
		_page.color = ALLY_TINT if is_ally else ENEMY_TINT
	if _corners:
		_corners.set("corner_color", ALLY_GEM if is_ally else ENEMY_GEM)   # 四角阵营宝石（同战斗内头像框）


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


func _refresh_skill_icon() -> void:
	if not _skill_icon:
		return
	if skill_icon_path == "" or not ResourceLoader.exists(skill_icon_path):
		_skill_icon.visible = false
		return
	var tex: Texture2D
	if _tex_cache.has(skill_icon_path):
		tex = _tex_cache[skill_icon_path]
	else:
		tex = load(skill_icon_path)
		_tex_cache[skill_icon_path] = tex
	_skill_icon.texture = tex
	_skill_icon.visible = true


func _refresh_text() -> void:
	if not _type_label:
		return
	# 顶部标题 = 英雄名（原「主动/被动技能」位置）；统一黑墨 + 同墨色描边仿粗体。
	_type_label.text = hero_name
	_type_label.add_theme_color_override("font_color", INK)
	_type_label.add_theme_color_override("font_outline_color", INK)
	_type_label.add_theme_constant_override("outline_size", 1)

	if not _desc_label:
		return
	# 正文 = 【技能名】：技能描述（【技能名】加粗：同墨色 BBCode 描边 → 笔画变粗；描述普通墨字）。
	# 英雄名已在上方 TypeLabel 自成一行，与本正文之间天然换行。
	var body := skill_detail.strip_edges()
	var ink_hex := INK.to_html(false)
	var bold_name := "[outline_size=1][outline_color=#%s]【%s】[/outline_color][/outline_size]" % [ink_hex, skill_name]
	if skill_name != "" and body != "":
		_desc_label.text = "%s：%s" % [bold_name, body]
	elif skill_name != "":
		_desc_label.text = bold_name
	else:
		_desc_label.text = body


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance_requested.emit()   # 左键 → 下一个
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			back_requested.emit()      # 右键 → 上一个
			accept_event()
